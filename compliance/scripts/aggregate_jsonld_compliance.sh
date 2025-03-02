# === WATCHER HEADER START ===
# File: journaltrove-system/compliance/scripts/aggregate_jsonld_compliance.sh
# Managed by file watcher
# === WATCHER HEADER END ===
#!/bin/bash
set -e

# Configuration
SCRIPT_DIR=$(dirname "$0")
BASE_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)
RESULTS_DIR="${1:-$BASE_DIR/compliance/results}"

# Handle the second parameter which can be either a directory or a full file path
if [[ "$2" == *".jsonld" ]]; then
  # Full file path provided
  OUTPUT_FILE="$2"
  OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
else
  # Only directory provided
  OUTPUT_DIR="${2:-$BASE_DIR/compliance/reports}"
  OUTPUT_FILE="$OUTPUT_DIR/compliance_matrix.jsonld"
fi

echo "== journaltrove App Compliance Matrix Generation =="
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
      "name": "journaltrove App Compliance Matrix",
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
TOTAL_REQS=$(jq -r '.["@graph"][] | select(.type == "Requirement" or .["@type"] == "Requirement") | .id' "$BASE_DIR/requirements/requirements.jsonld" | wc -l | xargs)

# Count total tests
TOTAL_TESTS=$(jq -r '.["@graph"][0].testCases | length' "$OUTPUT_FILE")

# Count passed tests
PASSED_TESTS=$(jq -r '.["@graph"][0].testCases[] | select(.result == "Pass" or .result == "Passed") | .["@id"]' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)

# Count failed tests
FAILED_TESTS=$(jq -r '.["@graph"][0].testCases[] | select(.result == "Fail" or .result == "Failed") | .["@id"]' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)

# Count components
COMPONENTS_COUNT=$(jq -r '.["@graph"][0].components | length' "$OUTPUT_FILE")

# Add statistics to the compliance matrix
jq --arg total_reqs "$TOTAL_REQS" \
   --arg total_tests "$TOTAL_TESTS" \
   --arg passed_tests "$PASSED_TESTS" \
   --arg failed_tests "$FAILED_TESTS" \
   --arg components_count "$COMPONENTS_COUNT" \
   '.["@graph"][0].statistics = {
      "totalRequirements": $total_reqs | tonumber,
      "totalTests": $total_tests | tonumber,
      "passingTests": $passed_tests | tonumber,
      "failingTests": $failed_tests | tonumber,
      "components": $components_count | tonumber
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
echo "- Components: $COMPONENTS_COUNT"

# The HTML report generation code has been removed as requested 
