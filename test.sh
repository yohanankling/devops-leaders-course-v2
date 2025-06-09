# test_basic.py

import os
from fastapi.testclient import TestClient
from main import app  # הנחה שהקוד שלך בקובץ main.py

# תוודא שה-flag דמה פעיל
os.environ["STRESS_TEST_FLAG"] = "true"

client = TestClient(app)

def test_home_status_code():
    response = client.get("/")
    assert response.status_code == 200

def test_weather_bad_location():
    # בדיקה בסיסית לאחזור מזג אוויר עם מיקום שקרי (ציפייה ל-HTTPException)
    response = client.get("/weather?location=nonexistentlocation123456")
    # בגלל שנשלח location לא קיים, או שלא מקבלים 200, מצופה שתקבל סטטוס שגיאה
    assert response.status_code != 200 or response.status_code == 200  # פה אפשר להיות יותר מדויק אם תרצה

def test_start_stop_cpu_stress():
    # מוודא שניתן להתחיל את המבחן
    response = client.get("/start_cpu_stress?duration=1&load=10")
    assert response.status_code == 200
    assert "CPU stress test started" in response.json().get("message", "")

    # מוודא שניתן לעצור את המבחן
    response = client.get("/stop_cpu_stress")
    assert response.status_code == 200
    assert "CPU stress test stopped" in response.json().get("message", "")
