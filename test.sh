#!/bin/bash
echo "Running tests..."

# Example: run a hypothetical test command
expected="Hello, DevOps"
output=$(python app.py)

if [[ "$output" == "$expected" ]]; then
  echo "Tests passed!"
  exit 0  # success
else
  echo "Tests failed!"
  exit 1  # failure
fi
