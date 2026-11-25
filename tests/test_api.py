from contextlib import closing
from registry import connect


def test_create_persists(api, dbpath, student):
    r=api('POST','/api/students',json=student)
    assert r.status_code==201
    assert r.json()==dict(student,id=1)
    with closing(connect(dbpath)) as db:
        assert dict(db.execute('SELECT * FROM students').fetchone())==r.json()


def test_list(api, student):
    created=api('POST','/api/students',json=student).json()
    r=api('GET','/api/students',role='reader')
    assert r.status_code==200 and r.json()==[created]


def test_get_one(api, student):
    created=api('POST','/api/students',json=student).json()
    r=api('GET',f"/api/students/{created['id']}",role='reader')
    assert r.status_code==200 and r.json()==created


def test_update(api, student):
    sid=api('POST','/api/students',json=student).json()['id']
    update=dict(student,cohort='IT-4')
    r=api('PUT',f'/api/students/{sid}',json=update)
    assert r.status_code==200 and r.json()==dict(update,id=sid)
    assert api('GET',f'/api/students/{sid}').json()==r.json()


def test_delete(api, student):
    sid=api('POST','/api/students',json=student).json()['id']
    r=api('DELETE',f'/api/students/{sid}')
    assert r.status_code==204 and r.content==b''
    assert api('GET',f'/api/students/{sid}').status_code==404


def test_nonexistent_user(api):
    r=api('GET','/api/users/99999')
    assert r.status_code==404 and r.json()=={'error':'User not found'}


def test_empty_body(api):
    assert api('POST','/api/students').status_code==400


def test_malformed_json(api):
    r=api('POST','/api/students',data='{',headers={'Content-Type':'application/json'})
    assert r.status_code==400 and r.json()=={'error':'Expected name, email and cohort'}


def test_duplicate_keeps_original(api,student):
    assert api('POST','/api/students',json=student).status_code==201
    r=api('POST','/api/students',json=dict(student,email=student['email'].upper()))
    assert r.status_code==409 and r.json()=={'error':'Email already registered'}
    assert len(api('GET','/api/students').json())==1
