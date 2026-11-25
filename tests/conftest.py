import json
import secrets
import threading
from contextlib import closing
from pathlib import Path

import pytest
import requests
from werkzeug.serving import make_server

from registry import add_user, connect, create_app, init_db


def pytest_addoption(parser):
    parser.addoption('--http-evidence', default=None)


@pytest.fixture(scope='session')
def deployment(tmp_path_factory):
    path = tmp_path_factory.mktemp('registry') / 'test.sqlite3'
    init_db(path)
    password = secrets.token_urlsafe(24)
    for role in ['admin','reader']:
        add_user(path, role, password, role)
    server = make_server('127.0.0.1',0,create_app(path),threaded=True)
    thread = threading.Thread(target=server.serve_forever,daemon=True)
    thread.start()
    url = f'http://127.0.0.1:{server.server_port}'
    headers = {}
    for role in ['admin','reader']:
        r = requests.post(url+'/api/login',json=dict(login=role,password=password),timeout=4)
        r.raise_for_status()
        headers[role] = {'Authorization':'Bearer '+r.json()['token']}
    yield path,url,headers,password
    server.shutdown()
    thread.join()
    server.server_close()


@pytest.fixture
def dbpath(deployment):
    path = deployment[0]
    with closing(connect(path)) as db, db:
        db.execute('DELETE FROM students')
    return path


@pytest.fixture
def api(deployment, dbpath, request):
    def call(method, route, role='admin', **kwargs):
        headers = dict(deployment[2].get(role, {}))
        headers.update(kwargs.pop('headers', {}))
        response = requests.request(method,deployment[1]+route,headers=headers,timeout=5,**kwargs)
        report = request.config.getoption('--http-evidence')
        if report:
            payload = response.json() if response.content and response.headers.get('Content-Type','').startswith('application/json') else None
            if isinstance(payload,dict) and 'token' in payload:
                payload={'token':'[redacted]'}
            with Path(report).open('a',encoding='utf-8') as f:
                f.write(json.dumps(dict(test=request.node.name, method=method, route=route,
                                        role=role, status=response.status_code, body=payload),ensure_ascii=False)+'\n')
        return response
    return call


@pytest.fixture
def student():
    return dict(name='Dana Ali',email='dana@example.test',cohort='IT-3')
