#!/bin/bash

# Ensure the script stops on any error
set -e

# Assuming .github/workflows/test_workflow_scripts/test-iid.sh is executable and has the needed shebang
sudo bash ./.github/workflows/test_workflow_scripts/test-iid.sh

# Optionally switch to a specific branch if needed
# Uncomment and set to your required branch if needed
# git fetch origin
# git checkout your-branch-name


# Start a MongoDB container for the application's database needs
docker-compose up -d

# Clean existing Keploy configuration if present

# Generate a new Keploy configuration file
# Ensure keployv2 binary is in the PATH or provide an absolute path
keploy config --generate

# Update Keploy configuration for test specifics
sed -i 's/global: {}/global: {"body": {"ts":[]}}/' "./keploy.yml"
sed -i 's/ports: 0/ports: 5432/' "./keploy.yml"

# Remove old Keploy test data to start fresh
rm -rf ./keploy/

# Build the application binary
go build -o echoSql

# Record test cases and mocks with Keploy, adjusting for the application's startup
for i in {1..2}; do
  # Ensure Keploy and the application are available in the PATH or use absolute paths
  sudo keploy record -c "./echoSql" &
  sleep 10 # Adjust based on application start time

  # Make API calls to record
curl --request POST \
  --url http://localhost:8082/url \
  --header 'content-type: application/json' \
  --data '{
  "url": "https://google.com"
}'  
curl --request GET \
  --url http://localhost:8082/Lhr4BWAi

  sleep 5 # Allow time for recording
  sudo kill $(pgrep echoSql)
  sleep 5
done

# Run recorded tests
# Ensure Keploy is in the PATH or use an absolute path
sudo keploy test -c "./echoSql" --delay 7

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
