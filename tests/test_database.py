import sqlite3
from contextlib import closing

import pytest
from registry import connect


def test_commit_visible_from_second_connection(dbpath):
    with closing(connect(dbpath)) as writer, writer:
        writer.execute('INSERT INTO students(name,email,cohort) VALUES(?,?,?)',('Ali','a@example.test','IT-1'))
    with closing(connect(dbpath)) as reader:
        assert reader.execute('SELECT cohort FROM students').fetchone()[0]=='IT-1'


def test_failed_transaction_rolls_back(dbpath):
    with closing(connect(dbpath)) as writer:
        with writer:
            writer.execute('INSERT INTO students(name,email,cohort) VALUES(?,?,?)',('Old','old@example.test','IT'))
        original=[tuple(r) for r in writer.execute('SELECT * FROM students ORDER BY id')]
        with pytest.raises(sqlite3.IntegrityError,match='NOT NULL constraint failed: students.name'):
            with writer:
                writer.execute("UPDATE students SET cohort='NEW'")
                writer.execute('INSERT INTO students(name,email,cohort) VALUES(?,?,?)',(None,'new@example.test','IT'))
    with closing(connect(dbpath)) as reader:
        assert [tuple(r) for r in reader.execute('SELECT * FROM students ORDER BY id')]==original
        assert reader.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
