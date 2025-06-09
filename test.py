# test_basic.py

import os
from fastapi.testclient import TestClient
from main import app

os.environ["STRESS_TEST_FLAG"] = "true"

client = TestClient(app)

def test_home_status_code():
    response = client.get("/")
    assert response.status_code == 200

def test_start_stop_cpu_stress():
    response = client.get("/start_cpu_stress?duration=1&load=10")
    assert response.status_code == 200
    response = client.get("/stop_cpu_stress")
    assert response.status_code == 200
