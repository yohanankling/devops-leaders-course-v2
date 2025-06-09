#!/bin/bash
echo "Running basic test..."

# דוגמה להרצת הקובץ הראשי (כאן main.py)
# מצפים שפלט מסוים יתקבל - צריך להתאים לפי מה שהקוד שלך באמת מדפיס ל-console

expected="INFO:     Started server process"
output=$(python main.py 2>&1 | head -n 1)

if [[ "$output" == *"$expected"* ]]; then
  echo "Basic test passed!"
  exit 0
else
  echo "Basic test failed!"
  echo "Got output:"
  echo "$output"
  exit 1
fi
