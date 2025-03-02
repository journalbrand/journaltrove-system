#!/bin/bash
set -e

# Configuration
SCRIPT_DIR=$(dirname "$0")
BASE_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
RESULTS_DIR="${1:-$BASE_DIR/compliance/results}"
OUTPUT_DIR="${2:-$BASE_DIR/compliance/reports}"
OUTPUT_FILE="$OUTPUT_DIR/compliance_matrix.jsonld"

echo "== Todo App Compliance Matrix Generation =="
echo "Input directory: $RESULTS_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Output file: $OUTPUT_FILE"
echo

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Check if system requirements exist and are valid
SYSTEM_REQ="$BASE_DIR/requirements/requirements.jsonld"
if [ ! -f "$SYSTEM_REQ" ]; then
  echo "✗ Error: System requirements not found at $SYSTEM_REQ"
  exit 1
fi

# Initialize the compliance matrix
cat > "$OUTPUT_FILE" << EOF
{
  "@context": "../requirements/context/requirements-context.jsonld",
  "@graph": [
    {
      "@id": "compliance-matrix",
      "@type": "ComplianceMatrix",
      "name": "Todo App Compliance Matrix",
      "description": "Generated compliance matrix aggregating test results from all components",
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "components": [],
      "testCases": []
    }
  ]
}
EOF

echo "✓ Created initial compliance matrix structure"

# Process component test results
# First, find all test result files
find "$RESULTS_DIR" -name "*.jsonld" -type f | while read -r result_file; do
  echo "Processing $result_file..."
  
  # Extract component name from the file path or content
  component=$(basename "$(dirname "$result_file")")
  echo "Component: $component"
  
  # Validate JSON-LD format
  if ! jq empty "$result_file" 2>/dev/null; then
    echo "✗ Error: Invalid JSON-LD in $result_file"
    continue
  fi
  
  # Add component to the compliance matrix
  jq --arg component "$component" '.["@graph"][0].components += [$component]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
  
  # Extract test cases and add them to the compliance matrix
  # The hierarchical IDs are already in the correct format (System.X.X.Component.X)
  jq -r '.["@graph"][0].testSuites[].testCases[] | {
    "@id": .["@id"], 
    "@type": "TestCase", 
    "component": "'"$component"'", 
    "name": .name, 
    "verifies": .verifies,
    "result": .result
  }' "$result_file" > test_case.json
  
  # Check if the test_case.json file is not empty
  if [ -s test_case.json ]; then
    cat test_case.json | jq -c '.' | while read -r test_case; do
      # Add the test case to the compliance matrix
      jq --argjson test_case "$test_case" '.["@graph"][0].testCases += [$test_case]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    done
  fi
  
  rm -f test_case.json
done

# Generate statistics
echo "Generating statistics..."

# Count total requirements
TOTAL_REQS=$(jq -r '.["@graph"][] | select(.type == "Requirement" or .["@type"] == "Requirement") | .id' "../requirements/requirements.jsonld" | wc -l | xargs)

# Count total tests
TOTAL_TESTS=$(jq -r '.["@graph"][0].testCases | length' "$OUTPUT_FILE")

# Count passed tests
PASSED_TESTS=$(jq -r '.["@graph"][0].testCases[] | select(.result == "Pass" or .result == "Passed") | .id' "$OUTPUT_FILE" | wc -l | xargs)

# Count failed tests
FAILED_TESTS=$(jq -r '.["@graph"][0].testCases[] | select(.result == "Fail" or .result == "Failed") | .id' "$OUTPUT_FILE" | wc -l | xargs)

# Add statistics to the compliance matrix
jq --arg total_reqs "$TOTAL_REQS" \
   --arg total_tests "$TOTAL_TESTS" \
   --arg passed_tests "$PASSED_TESTS" \
   --arg failed_tests "$FAILED_TESTS" \
   '.["@graph"][0].statistics = {
      "totalRequirements": $total_reqs | tonumber,
      "totalTests": $total_tests | tonumber,
      "passedTests": $passed_tests | tonumber,
      "failedTests": $failed_tests | tonumber
    }' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# Generate an HTML report
echo "Generating HTML report..."

# Copy the compliance matrix to the dashboard directory
mkdir -p "../compliance/dashboard"
cp "$OUTPUT_FILE" "../compliance/dashboard/compliance_matrix.jsonld"

echo "Compliance matrix generated: $OUTPUT_FILE"
echo "Dashboard updated with compliance matrix"
echo "Statistics:"
echo "- Total requirements: $TOTAL_REQS"
echo "- Total tests: $TOTAL_TESTS"
echo "- Passed tests: $PASSED_TESTS"
echo "- Failed tests: $FAILED_TESTS"

# Create a simple HTML report for convenience
REPORT_DIR="$BASE_DIR/compliance/reports"
HTML_REPORT="$REPORT_DIR/requirements.html"

cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Todo App Compliance Matrix</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
    .status { margin: 20px 0; padding: 15px; border-radius: 4px; }
    .status.success { background-color: #e6f7e6; border: 1px solid #c3e6c3; }
    .status.warning { background-color: #fff9e6; border: 1px solid #ffe0b2; }
    .button { display: inline-block; background: #0366d6; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px; }
    .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin: 20px 0; }
    .stat-card { border: 1px solid #ddd; border-radius: 4px; padding: 15px; text-align: center; }
    .stat-card h3 { margin: 0; font-size: 14px; color: #666; }
    .stat-card .value { font-size: 24px; font-weight: bold; margin: 10px 0; }
  </style>
</head>
<body>
  <h1>Todo App Compliance Matrix</h1>
  <p>Generated on $(date)</p>
  
  <div class="stats">
    <div class="stat-card">
      <h3>Requirements</h3>
      <div class="value">$(jq -r '.["@graph"][0].statistics.totalRequirements' "$OUTPUT_FILE")</div>
    </div>
    <div class="stat-card">
      <h3>Tests</h3>
      <div class="value">$(jq -r '.["@graph"][0].statistics.totalTests' "$OUTPUT_FILE")</div>
    </div>
    <div class="stat-card">
      <h3>Passing</h3>
      <div class="value">$(jq -r '.["@graph"][0].statistics.passedTests' "$OUTPUT_FILE")</div>
    </div>
    <div class="stat-card">
      <h3>Failing</h3>
      <div class="value">$(jq -r '.["@graph"][0].statistics.failedTests' "$OUTPUT_FILE")</div>
    </div>
  </div>
  
  <div class="status $(if [ "$(jq -r '.["@graph"][0].statistics.failedTests' "$OUTPUT_FILE")" -eq 0 ]; then echo "success"; else echo "warning"; fi)">
    <h2>$(if [ "$(jq -r '.["@graph"][0].statistics.failedTests' "$OUTPUT_FILE")" -eq 0 ]; then echo "✓ All Tests Passing"; else echo "⚠ Some Tests Failing"; fi)</h2>
    <p>$(if [ "$(jq -r '.["@graph"][0].statistics.failedTests' "$OUTPUT_FILE")" -eq 0 ]; then echo "All tests are passing successfully."; else echo "There are failing tests that need attention."; fi)</p>
  </div>
  
  <p>
    <a href="../dashboard/index.html" class="button">View Interactive Dashboard</a>
  </p>
</body>
</html>
EOF

echo "Created HTML report at $HTML_REPORT" 