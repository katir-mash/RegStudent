"""Prepare a disposable Android integration database alongside registry.py."""
import os
import sys
from contextlib import closing
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[2]))
from registry import init_db, add_user, connect

path = sys.argv[1]
init_db(path)
for login,role in [('registrar','admin'),('observer','reader')]:
    add_user(path,login,os.environ['LAB_PASSWORD'],role)
with closing(connect(path)) as db,db:
    db.execute('INSERT INTO students(name,email,cohort) VALUES(?,?,?)',
               ('Dana Ali','dana@example.test','IT-3'))
