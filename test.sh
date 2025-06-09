import os
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
import multiprocessing
import main  # נניח שקובץ הקוד שלך נקרא main.py

client = TestClient(main.app)

@pytest.fixture(autouse=True)
def clear_global_state():
    # לפני כל טסט לאפס משתנים גלובליים
    main.cpu_stress_processes = []
    main.global_iterations = None
    main.stop_flag = None
    main.cpu_stress_status_data = {}
    yield
    # אחרי כל טסט ניקוי חוזר
    main.cpu_stress_processes = []
    main.global_iterations = None
    main.stop_flag = None
    main.cpu_stress_status_data = {}

def test_homepage_stress_flag_true():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "true"}):
        response = client.get("/")
        assert response.status_code == 200
        assert "stress_test_enabled" in response.text or "true" in response.text.lower()

def test_homepage_stress_flag_false():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "false"}):
        response = client.get("/")
        assert response.status_code == 200
        # לפי קוד המקור stress_test_enabled=False
        assert "true" not in response.text.lower()

@patch("main.requests.get")
def test_weather_success(mock_get):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "current_condition": [{"temp_C": "20", "weatherDesc": [{"value": "Sunny"}]}],
        "nearest_area": [{"areaName": [{"value": "Tel Aviv"}], "latitude": "32.08", "longitude": "34.78"}],
    }
    mock_get.return_value = mock_resp

    response = client.get("/weather?location=tel+aviv")
    assert response.status_code == 200
    data = response.json()
    assert data["location"] == "Tel Aviv"
    assert data["temperature"] == "20"
    assert data["description"] == "Sunny"
    assert data["lat"] == 32.08
    assert data["lon"] == 34.78

@patch("main.requests.get")
def test_weather_failure_status_code(mock_get):
    mock_resp = MagicMock()
    mock_resp.status_code = 404
    mock_get.return_value = mock_resp

    response = client.get("/weather?location=unknownplace")
    assert response.status_code == 404

@patch("main.requests.get")
def test_weather_bad_response_format(mock_get):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"wrong_key": []}
    mock_get.return_value = mock_resp

    response = client.get("/weather?location=tel+aviv")
    assert response.status_code == 500

def test_start_cpu_stress_flag_disabled():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "false"}):
        response = client.get("/start_cpu_stress?duration=1&load=50")
        assert response.status_code == 403

def test_start_cpu_stress_invalid_params():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "true"}):
        response = client.get("/start_cpu_stress?duration=0&load=50")
        assert response.status_code == 400
        response = client.get("/start_cpu_stress?duration=10&load=150")
        assert response.status_code == 400

@patch("multiprocessing.Process.start")
@patch("multiprocessing.Process")
def test_start_cpu_stress_success(mock_process_class, mock_start):
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "true"}):
        # Mock Process object
        mock_proc = MagicMock()
        mock_process_class.return_value = mock_proc
        response = client.get("/start_cpu_stress?duration=1&load=50")
        assert response.status_code == 200
        data = response.json()
        assert data["message"] == "CPU stress test started"
        assert data["load"] == 50
        assert data["duration"] == 1
        assert data["workers"] == (os.cpu_count() or 1)
        # לוודא שהתהליך התחיל
        mock_start.assert_called()

def test_stop_cpu_stress_flag_disabled():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "false"}):
        response = client.get("/stop_cpu_stress")
        assert response.status_code == 403

def test_stop_cpu_stress_success():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "true"}):
        # הכן משתנים גלובליים כראוי
        main.stop_flag = multiprocessing.Value("b", False)
        p = multiprocessing.Process()
        p.join = MagicMock()
        main.cpu_stress_processes = [p]
        main.cpu_stress_status_data = {"running": True}
        response = client.get("/stop_cpu_stress")
        assert response.status_code == 200
        assert response.json() == {"message": "CPU stress test stopped"}
        assert main.cpu_stress_status_data["running"] is False
        p.join.assert_called_once()

def test_stress_status_flag_disabled():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "false"}):
        response = client.get("/stress_status")
        assert response.status_code == 403

def test_stress_status_running():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "true"}):
        main.cpu_stress_status_data = {
            "running": True,
            "end_time": time.time() + 5,
        }
        main.global_iterations = multiprocessing.Value("i", 42)
        response = client.get("/stress_status")
        assert response.status_code == 200
        data = response.json()
        assert data["running"] is True
        assert data["iterations"] == 42
        assert data["remaining_seconds"] > 0

def test_stress_status_not_running():
    with patch.dict(os.environ, {"STRESS_TEST_FLAG": "true"}):
        main.cpu_stress_status_data = {
            "running": False,
            "end_time": time.time() - 10,
        }
        main.global_iterations = multiprocessing.Value("i", 100)
        response = client.get("/stress_status")
        assert response.status_code == 200
        data = response.json()
        assert data["running"] is False
        assert data["iterations"] == 100
        assert data["remaining_seconds"] == 0
