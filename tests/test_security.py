import pytest
from registry import add_user


@pytest.mark.parametrize('password',['','short'])
def test_password_policy(dbpath,password):
    with pytest.raises(ValueError,match='12 to 128'):
        add_user(dbpath,'new-user',password,'reader')


@pytest.mark.parametrize('login,password',[('admin',''),('unknown-user','test-only-bogus')])
def test_bad_login(api,login,password):
    r=api('POST','/api/login',role=None,json=dict(login=login,password=password))
    assert r.status_code==401 and r.json()=={'error':'Invalid credentials'}


def test_missing_session(api):
    r=api('GET','/api/students',role=None)
    assert r.status_code==401 and r.json()=={'error':'Authentication required'}


def test_role_denied(api,student):
    r=api('POST','/api/students',role='reader',json=student)
    assert r.status_code==403 and r.json()=={'error':'Admin role required'}
    assert api('GET','/api/students',role='reader').json()==[]


def test_bad_field_format(api,student):
    r=api('POST','/api/students',json=dict(student,email=100))
    assert r.status_code==400 and r.json()=={'error':'Fields must be text'}


def test_error_and_logs_omit_secrets(api,caplog,deployment,dbpath):
    marker='synthetic-log-marker'
    with caplog.at_level('INFO'):
        r=api('POST','/api/login',role=None,json=dict(login='admin',password=marker))
        denied=api('DELETE','/api/students/1',role='reader')
    assert r.status_code==401 and denied.status_code==403
    assert 'login_denied' in caplog.text and 'role_denied' in caplog.text
    observed=r.text+denied.text+caplog.text
    for value in [marker,deployment[3],deployment[2]['reader']['Authorization'][7:],str(dbpath),'Traceback']:
        assert value not in observed
