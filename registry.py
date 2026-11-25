import argparse
import functools
import logging
import os
import re
import secrets
import sqlite3
from contextlib import closing
from getpass import getpass
from pathlib import Path

from flask import Flask, g, jsonify, request, send_from_directory
from itsdangerous import BadSignature, URLSafeTimedSerializer
from waitress import serve
from werkzeug.security import check_password_hash, generate_password_hash

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
 id INTEGER PRIMARY KEY, login TEXT NOT NULL UNIQUE, digest TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN ('reader','admin'))
);
CREATE TABLE IF NOT EXISTS students (
 id INTEGER PRIMARY KEY, name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 80),
 email TEXT NOT NULL UNIQUE COLLATE NOCASE, cohort TEXT NOT NULL CHECK(length(cohort) BETWEEN 1 AND 24)
);
"""
FIELDS = ('name', 'email', 'cohort')


def connect(path):
    db = sqlite3.connect(path, timeout=5)
    db.row_factory = sqlite3.Row
    return db


def init_db(path):
    with closing(connect(path)) as db, db:
        db.execute('PRAGMA journal_mode=WAL')
        db.executescript(SCHEMA)


def add_user(path, login, password, role):
    if not isinstance(password, str) or not 12 <= len(password) <= 128:
        raise ValueError('Password must be 12 to 128 characters')
    if not login.strip() or role not in ('reader','admin'):
        raise ValueError('Invalid login or role')
    with closing(connect(path)) as db, db:
        db.execute('INSERT INTO users(login,digest,role) VALUES(?,?,?)',
                   (login, generate_password_hash(password), role))


def student_fields(data):
    if not isinstance(data, dict) or set(data) != set(FIELDS):
        raise ValueError('Expected name, email and cohort')
    if any(not isinstance(data[k], str) for k in FIELDS):
        raise ValueError('Fields must be text')
    name, email, cohort = (data[k].strip() for k in FIELDS)
    if not 1 <= len(name) < 80 or not 1 <= len(cohort) <= 24:
        raise ValueError('Invalid name or cohort length')
    if len(email) > 254 or not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+', email):
        raise ValueError('Invalid email')
    return name, email.lower(), cohort


def create_app(path, key=None):
    app = Flask(__name__)
    app.config['MAX_CONTENT_LENGTH'] = 8192
    tokens = URLSafeTimedSerializer(key or secrets.token_hex(32), salt='registry-login')
    audit = logging.getLogger('registry.audit')
    audit.setLevel(logging.INFO)
    dummy = generate_password_hash(secrets.token_urlsafe(24))

    def db():
        if 'db' not in g:
            g.db = connect(path)
        return g.db

    @app.teardown_appcontext
    def close_db(_error):
        conn = g.pop('db', None)
        if conn is not None:
            conn.close()

    def error(message, status):
        return jsonify(error=message), status

    def protect(admin=False):
        def decorator(fn):
            @functools.wraps(fn)
            def checked(*args, **kwargs):
                header = request.headers.get('Authorization', '')
                if not header.startswith('Bearer '):
                    return error('Authentication required', 401)
                try:
                    uid = tokens.loads(header[7:], max_age=3600)
                except BadSignature:
                    return error('Invalid session', 401)
                user = db().execute('SELECT role FROM users WHERE id=?', (uid,)).fetchone()
                if not user:
                    return error('Invalid session', 401)
                if admin and user['role'] != 'admin':
                    audit.info('role_denied')
                    return error('Admin role required', 403)
                return fn(*args, **kwargs)
            return checked
        return decorator

    @app.get('/')
    def home():
        return send_from_directory(Path(__file__).resolve().parent, 'index.html')

    @app.post('/api/login')
    def login():
        data = request.get_json(silent=True)
        if not isinstance(data, dict) or not all(isinstance(data.get(k), str) for k in ('login','password')):
            return error('Expected login and password', 400)
        row = db().execute('SELECT id,digest FROM users WHERE login=?', (data['login'],)).fetchone()
        match = check_password_hash(row['digest'] if row else dummy, data['password'])
        if not row or not match:
            audit.info('login_denied')
            return error('Invalid credentials', 401)
        return jsonify(token=tokens.dumps(row['id']))

    @app.get('/api/users/<int:uid>')
    @protect(admin=True)
    def user_detail(uid):
        row = db().execute('SELECT id,login,role FROM users WHERE id=?', (uid,)).fetchone()
        return jsonify(dict(row)) if row else error('User not found', 404)

    @app.get('/api/students')
    @protect()
    def students():
        rows = db().execute('SELECT * FROM students ORDER BY id').fetchall()
        return jsonify([dict(r) for r in rows])

    @app.get('/api/students/<int:sid>')
    @protect()
    def one(sid):
        row = db().execute('SELECT * FROM students WHERE id=?', (sid,)).fetchone()
        return jsonify(dict(row)) if row else error('Student not found', 404)

    @app.post('/api/students')
    @app.put('/api/students/<int:sid>')
    @protect(admin=True)
    def save(sid=None):
        try:
            values = student_fields(request.get_json(silent=True))
            with db():
                if sid is None:
                    sid = db().execute('INSERT INTO students(name,email,cohort) VALUES(?,?,?)', values).lastrowid
                else:
                    cur = db().execute('UPDATE students SET name=?,email=?,cohort=? WHERE id=?', (*values,sid))
                    if not cur.rowcount:
                        return error('Student not found', 404)
        except ValueError as exc:
            return error(str(exc), 400)
        except sqlite3.IntegrityError:
            return error('Email already registered', 409)
        return jsonify(dict(zip(FIELDS,values), id=sid)), 201 if request.method=='POST' else 200

    @app.delete('/api/students/<int:sid>')
    @protect(admin=True)
    def delete(sid):
        with db():
            cur = db().execute('DELETE FROM students WHERE id=?', (sid,))
        return ('', 204) if cur.rowcount else error('Student not found', 404)

    return app


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--db', default='registry.sqlite3')
    parser.add_argument('--port', type=int, default=8080)
    parser.add_argument('--add-user')
    parser.add_argument('--role', choices=['admin','reader'], default='reader')
    args = parser.parse_args()
    init_db(args.db)
    if args.add_user:
        add_user(args.db, args.add_user, getpass('Password (12–128 characters): '), args.role)
    else:
        logging.basicConfig(level=logging.INFO)
        serve(create_app(args.db), host='127.0.0.1', port=args.port, threads=8)
