#!/bin/bash
set -e

# Configuration
SCRIPT_DIR=$(dirname "$0")
BASE_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
RESULTS_DIR="${1:-$BASE_DIR/compliance/results}"
OUTPUT_FILE="${2:-$BASE_DIR/compliance/reports/compliance_matrix.jsonld}"

echo "== Todo App Compliance Matrix Generation =="
echo "Input directory: $RESULTS_DIR"
echo "Output file: $OUTPUT_FILE"
echo

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if system requirements exist and are valid
SYSTEM_REQ="$BASE_DIR/requirements/requirements.jsonld"
if [ ! -f "$SYSTEM_REQ" ]; then
  echo "✗ Error: System requirements not found at $SYSTEM_REQ"
  exit 1
fi

# Initialize the compliance matrix
cat > "$OUTPUT_FILE" << EOF
{
  "@context": "https://raw.githubusercontent.com/journalbrand/todo-system/main/requirements/context/requirements-context.jsonld",
  "@graph": [
    {
      "@id": "todo-compliance-matrix",
      "@type": "ComplianceMatrix",
      "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
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
  jq -r '.["@graph"][0].testSuites[].testCases[] | {"@id": .["@id"], "@type": "TestCase", "component": "'"$component"'", "name": .name, "verifies": .verifies, "result": .result}' "$result_file" > test_case.json
  
  # Check if the test_case.json file is not empty
  if [ -s test_case.json ]; then
    cat test_case.json | jq -c '.' | while read -r test_case; do
      # Add the test case to the compliance matrix
      jq --argjson test_case "$test_case" '.["@graph"][0].testCases += [$test_case]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    done
  fi
  
  rm -f test_case.json
done

# Calculate compliance statistics
jq '
  .["@graph"][0].statistics = {
    "totalRequirements": (.["@graph"][0].testCases | map(.verifies) | unique | length),
    "totalTests": (.["@graph"][0].testCases | length),
    "passingTests": (.["@graph"][0].testCases | map(select(.result == "Pass")) | length),
    "failingTests": (.["@graph"][0].testCases | map(select(.result == "Fail")) | length),
    "components": (.["@graph"][0].components | length)
  }
' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

echo
echo "✓ Compliance matrix generation complete"
echo "Statistics:"
jq -r '.["@graph"][0].statistics | "Total Requirements: \(.totalRequirements)\nTotal Tests: \(.totalTests)\nPassing Tests: \(.passingTests)\nFailing Tests: \(.failingTests)\nComponents: \(.components)"' "$OUTPUT_FILE"

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
      <div class="value">$(jq -r '.["@graph"][0].statistics.passingTests' "$OUTPUT_FILE")</div>
    </div>
    <div class="stat-card">
      <h3>Failing</h3>
      <div class="value">$(jq -r '.["@graph"][0].statistics.failingTests' "$OUTPUT_FILE")</div>
    </div>
    <div class="stat-card">
      <h3>Components</h3>
      <div class="value">$(jq -r '.["@graph"][0].statistics.components' "$OUTPUT_FILE")</div>
    </div>
  </div>
  
  <div class="status $(if [ "$(jq -r '.["@graph"][0].statistics.failingTests' "$OUTPUT_FILE")" -eq 0 ]; then echo "success"; else echo "warning"; fi)">
    <h2>$(if [ "$(jq -r '.["@graph"][0].statistics.failingTests' "$OUTPUT_FILE")" -eq 0 ]; then echo "✓ All Tests Passing"; else echo "⚠ Some Tests Failing"; fi)</h2>
    <p>$(if [ "$(jq -r '.["@graph"][0].statistics.failingTests' "$OUTPUT_FILE")" -eq 0 ]; then echo "All tests are passing successfully."; else echo "There are failing tests that need attention."; fi)</p>
  </div>
  
  <p>
    <a href="../dashboard/index.html" class="button">View Interactive Dashboard</a>
  </p>
</body>
</html>
EOF

echo "Created HTML report at $HTML_REPORT" 