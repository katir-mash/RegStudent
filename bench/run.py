"""Run all four Locust profiles against an isolated loopback registry."""
import csv
import os
import secrets
import subprocess
import sys
import tempfile
import time
from contextlib import closing
from pathlib import Path

import psutil
import requests

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from registry import add_user, connect, init_db

out = ROOT / 'evidence' / 'load'
out.mkdir(parents=True, exist_ok=True)
url = 'http://127.0.0.1:18738'
with tempfile.TemporaryDirectory() as temp:
    path = Path(temp) / 'bench.db'
    init_db(path)
    password = secrets.token_urlsafe(20)
    add_user(path, 'load-reader', password, 'reader')
    with closing(connect(path)) as db, db:
        db.executemany('INSERT INTO students(name,email,cohort) VALUES(?,?,?)',
                       [(f'Student {i}', f's{i}@example.test', 'IT-3') for i in range(1,101)])
    with (out/'server.log').open('w') as log:
        server = subprocess.Popen([sys.executable,'registry.py','--db',str(path),'--port','18738'],
                                  cwd=ROOT, stdout=log, stderr=log)
        try:
            for _ in range(60):
                if server.poll() is not None:
                    raise RuntimeError('Server exited')
                try:
                    login = requests.post(url+'/api/login',json={'login':'load-reader','password':password},timeout=2)
                    login.raise_for_status()
                    break
                except requests.ConnectionError:
                    time.sleep(.2)
            env = dict(os.environ, LAB_BENCH_TOKEN=login.json()['token'])
            proc = psutil.Process(server.pid)
            for users, seconds in [(5,60),(20,120),(50,180),(100,180)]:
                label = out/f'vu{users}'
                print(f'{users} users for {seconds}s',flush=True)
                with Path(str(label)+'.log').open('w') as logfile:
                    job = subprocess.Popen([sys.executable,'-m','locust','-f','bench/locustfile.py','--headless',
                         '--host',url,'-u',str(users),'-r',str(users),'-t',f'{seconds}s',
                         '--csv',str(label),'--only-summary'],cwd=ROOT,env=env,stdout=logfile,stderr=logfile)
                    with Path(str(label)+'_resources.csv').open('w',newline='') as f:
                        w=csv.writer(f); w.writerow(['elapsed_s','server_cpu_percent','server_rss_mib'])
                        start=time.monotonic();proc.cpu_percent()
                        while job.poll() is None:
                            time.sleep(1)
                            w.writerow([round(time.monotonic()-start,2),proc.cpu_percent(),round(proc.memory_info().rss/2**20,2)])
                    if job.returncode:
                        stats_file = Path(str(label) + '_stats.csv')
                        if job.returncode != 1 or not stats_file.exists():
                            raise RuntimeError(f'Locust returned {job.returncode}, inspect {logfile.name}')
                        with stats_file.open(newline='') as stats:
                            total = next((r for r in csv.DictReader(stats) if r['Name'] == 'Aggregated'), None)
                        if not total or not int(total['Failure Count']):
                            raise RuntimeError(f'No complete request results, inspect {logfile.name}')
                        print(f"Measured request failures: {total['Failure Count']}", flush=True)
        finally:
            server.terminate()
            server.wait()
