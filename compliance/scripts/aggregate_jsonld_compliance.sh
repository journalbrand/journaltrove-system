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

# Create temp directory for processing
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Step 1: Extract all requirements from the system requirements file and component requirement files
echo "Collecting all requirements from system and components..."

# Extract system requirements - only include system-level requirements, not component-specific ones
jq -r '.["@graph"][] | select(.type == "Requirement" or .["@type"] == "Requirement") | 
  select(.component == "System" or .component == null) | {
  "@id": (.id // .["@id"]),
  "@type": "Requirement",
  "name": .name,
  "description": .description,
  "component": "System",
  "status": .status,
  "priority": .priority,
  "parent": .parent
}' "$SYSTEM_REQ" > "$TEMP_DIR/system_requirements.json"

# Create an array to hold all requirements
ALL_REQUIREMENTS=()

# Add system requirements to the array
while read -r req; do
  ALL_REQUIREMENTS+=("$req")
done < <(jq -c '.' "$TEMP_DIR/system_requirements.json")

# Check for component requirements in the components directory
COMPONENTS_DIR="$BASE_DIR/components"
echo "Checking for component requirements in directory: $COMPONENTS_DIR"

if [ -d "$COMPONENTS_DIR" ]; then
  echo "Directory exists. Listing contents:"
  ls -R "$COMPONENTS_DIR"

  # Find all component requirement files dynamically
  find "$COMPONENTS_DIR" -path "*/requirements/requirements.jsonld" | while read -r req_file; do
    echo "Found requirements file: $req_file"

    # Extract component name from path
    component=$(basename "$(dirname "$(dirname "$req_file")")")
    echo "Processing requirements for component: $component"

    # Extract requirements for this component - include ALL component requirements
    if jq empty "$req_file"; then
      jq -r --arg component "$component" '."@graph"[] | select(.type == "Requirement" or ."@type" == "Requirement") | {
        "@id": (.id // ."@id"),
        "@type": "Requirement",
        "name": .name,
        "description": .description,
        "component": $component,
        "status": .status,
        "priority": .priority,
        "parent": .parent
      }' "$req_file" > "$TEMP_DIR/${component}_requirements.json"

      # Add component requirements to the array
      while read -r comp_req; do
        ALL_REQUIREMENTS+=("$comp_req")
      done < <(jq -c '.' "$TEMP_DIR/${component}_requirements.json")
    else
      echo "✗ Error: Invalid JSON-LD in $req_file"
    fi
  done
else
  echo "✗ Error: Components directory does not exist: $COMPONENTS_DIR"
fi

# Count unique requirements
echo "Found ${#ALL_REQUIREMENTS[@]} total requirements across all components"

# Step 2: Initialize the compliance matrix with all requirements
echo "Initializing compliance matrix with all requirements..."

# Create initial structure
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
      "requirements": [],
      "testCases": []
    }
  ]
}
EOF

# Add all requirements to the compliance matrix
for req in "${ALL_REQUIREMENTS[@]}"; do
  jq --argjson req "$req" '.["@graph"][0].requirements += [$req]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
done

echo "✓ Created initial compliance matrix with all requirements"

# Step 3: Process component test results
echo "Processing test results from each component..."

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
  }' "$result_file" > "$TEMP_DIR/test_case.json"
  
  # Check if the test_case.json file is not empty
  if [ -s "$TEMP_DIR/test_case.json" ]; then
    cat "$TEMP_DIR/test_case.json" | jq -c '.' | while read -r test_case; do
      # Add the test case to the compliance matrix
      jq --argjson test_case "$test_case" '.["@graph"][0].testCases += [$test_case]' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    done
  fi
done

# Step 4: Calculate coverage and update requirement status
echo "Calculating coverage and updating requirement status..."

# Create a temp file with all test cases
jq -r '.["@graph"][0].testCases[]' "$OUTPUT_FILE" > "$TEMP_DIR/all_test_cases.json"

# Create a temporary file with all verified requirements
jq -r '.["@graph"][0].testCases[].verifies' "$OUTPUT_FILE" | sort | uniq > "$TEMP_DIR/tested_requirements.txt"

# Update the status of each requirement in the matrix
# Using string comparison instead of inside() which was causing the jq error
jq -r --slurpfile tested_reqs <(jq -Rs 'split("\n") | map(select(length > 0))' "$TEMP_DIR/tested_requirements.txt") '
  .["@graph"][0].requirements = .["@graph"][0].requirements | map(
    . + {
      "tested": (reduce $tested_reqs[] as $req (false; 
        if . then . else (.["@id"] == $req) end
      ))
    }
  )
' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# Step 5: Generate statistics
echo "Generating statistics..."

# Count total requirements
TOTAL_REQS=$(jq -r '.["@graph"][0].requirements | length' "$OUTPUT_FILE")

# Count tested requirements
TESTED_REQS=$(jq -r '.["@graph"][0].requirements[] | select(.tested == true) | .["@id"]' "$OUTPUT_FILE" | wc -l | xargs)

# Count untested requirements
UNTESTED_REQS=$(jq -r '.["@graph"][0].requirements[] | select(.tested == false) | .["@id"]' "$OUTPUT_FILE" | wc -l | xargs)

# Count total tests
TOTAL_TESTS=$(jq -r '.["@graph"][0].testCases | length' "$OUTPUT_FILE")

# Count passed tests
PASSED_TESTS=$(jq -r '.["@graph"][0].testCases[] | select(.result == "Pass" or .result == "Passed") | .["@id"]' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)

# Count failed tests
FAILED_TESTS=$(jq -r '.["@graph"][0].testCases[] | select(.result == "Fail" or .result == "Failed") | .["@id"]' "$OUTPUT_FILE" 2>/dev/null | wc -l | xargs)

# Count components
COMPONENTS_COUNT=$(jq -r '.["@graph"][0].components | length' "$OUTPUT_FILE")

# Calculate coverage percentage
COVERAGE_PCT=0
if [ "$TOTAL_REQS" -gt 0 ]; then
  COVERAGE_PCT=$(echo "scale=1; $TESTED_REQS * 100 / $TOTAL_REQS" | bc)
fi

# Add statistics to the compliance matrix
jq --arg total_reqs "$TOTAL_REQS" \
   --arg tested_reqs "$TESTED_REQS" \
   --arg untested_reqs "$UNTESTED_REQS" \
   --arg coverage_pct "$COVERAGE_PCT" \
   --arg total_tests "$TOTAL_TESTS" \
   --arg passed_tests "$PASSED_TESTS" \
   --arg failed_tests "$FAILED_TESTS" \
   --arg components_count "$COMPONENTS_COUNT" \
   '.["@graph"][0].statistics = {
      "totalRequirements": $total_reqs | tonumber,
      "testedRequirements": $tested_reqs | tonumber,
      "untestedRequirements": $untested_reqs | tonumber,
      "coveragePercentage": $coverage_pct | tonumber,
      "totalTests": $total_tests | tonumber,
      "passingTests": $passed_tests | tonumber,
      "failingTests": $failed_tests | tonumber,
      "components": $components_count | tonumber
    }' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# Copy the compliance matrix to the dashboard directory
mkdir -p "$BASE_DIR/compliance/dashboard"
cp "$OUTPUT_FILE" "$BASE_DIR/compliance/dashboard/compliance_matrix.jsonld"

echo "Compliance matrix generated: $OUTPUT_FILE"
echo "Dashboard updated with compliance matrix"
echo "Statistics:"
echo "- Total requirements: $TOTAL_REQS"
echo "- Tested requirements: $TESTED_REQS ($COVERAGE_PCT%)"
echo "- Untested requirements: $UNTESTED_REQS"
echo "- Total tests: $TOTAL_TESTS"
echo "- Passed tests: $PASSED_TESTS"
echo "- Failed tests: $FAILED_TESTS"
echo "- Components: $COMPONENTS_COUNT"

# The HTML report generation code has been removed as requested 
