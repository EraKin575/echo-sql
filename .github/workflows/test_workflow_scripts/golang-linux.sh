#!/bin/bash

# Assuming .github/workflows/test_workflow_scripts/test-iid.sh is executable and has the needed shebang
./../../.github/workflows/test_workflow_scripts/test-iid.sh

# Switch to a specific branch if needed, this might be optional based on your CI/CD flow
git fetch origin
git checkout native-linux

# Start a MongoDB container for the application's database needs
docker run --rm -d -p 27017:27017 --name mongoDb mongo

# Clean existing Keploy configuration if present
[ -f "./keploy.yml" ] && rm ./keploy.yml

# Generate a new Keploy configuration file
sudo ./../../keployv2 config --generate

# Update Keploy configuration for test specifics
sed -i 's/global: {}/global: {"body": {"ts":[]}}/' "./keploy.yml"
sed -i 's/ports: 0/ports: 27017/' "./keploy.yml"

# Remove old Keploy test data to start fresh
rm -rf ./keploy/

# Build the application binary
go build -o ginApp

# Record test cases and mocks with Keploy, adjusting for the application's startup
for i in {1..2}; do
  sudo -E env PATH="$PATH" ./../../keployv2 record -c "./ginApp" &
  sleep 10 # Adjust based on application start time

  # Make API calls to record
  curl --request POST --url http://localhost:8080/url --header 'content-type: application/json' --data '{"url": "https://google.com"}'
  curl --request POST --url http://localhost:8080/url --header 'content-type: application/json' --data '{"url": "https://facebook.com"}'
  curl -X GET http://localhost:8080/CJBKJd92

  sleep 5 # Allow time for recording
  sudo kill $(pgrep ginApp)
  sleep 5
done

# Run recorded tests
sudo -E env PATH="$PATH" ./../../keployv2 test -c "./ginApp" --delay 7

# Process test results for CI/CD feedback
report_file="./keploy/reports/test-run-0/test-set-0-report.yaml"
test_status1=$(grep 'status:' "$report_file" | head -n 1 | awk '{print $2}')
report_file2="./keploy/reports/test-run-0/test-set-1-report.yaml"
test_status2=$(grep 'status:' "$report_file2" | head -n 1 | awk '{print $2}')

if [ "$test_status1" = "PASSED" ] && [ "$test_status2" = "PASSED" ]; then
    echo "Tests passed"
    exit 0
else
    echo "Some tests failed"
    exit 1
fi
