import pytest
from registry import student_fields


def test_whitespace_and_email(student):
    assert student_fields(dict(student,email='  DANA@example.TEST '))[1]=='dana@example.test'


@pytest.mark.parametrize('length',[1,80])
def test_valid_name_boundaries(student,length):
    assert len(student_fields(dict(student,name='A'*length))[0])==length


@pytest.mark.parametrize('field,value',[('name',''),('name','A'*81),('cohort',' '),('cohort','A'*25),('email','invalid')])
def test_invalid_fields(student,field,value):
    with pytest.raises(ValueError):
        student_fields(dict(student,**{field:value}))


def test_group_maximum(student):
    assert len(student_fields(dict(student,cohort='A'*24))[2])==24
