import os
from locust import HttpUser, constant, task


class RegistryReader(HttpUser):
    wait_time = constant(0.5)

    def on_start(self):
        self.client.headers.update({'Authorization': 'Bearer ' + os.environ['LAB_BENCH_TOKEN']})

    @task(3)
    def list_students(self):
        self.client.get('/api/students', timeout=5)

    @task
    def read_student(self):
        self.client.get('/api/students/1', timeout=5)
