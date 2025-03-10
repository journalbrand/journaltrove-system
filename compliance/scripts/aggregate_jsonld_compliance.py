#!/usr/bin/env python3
import os
import sys
import json
import shutil
import tempfile
from datetime import datetime
from pathlib import Path

def main(results_dir=None, output_path=None):
    script_dir = Path(__file__).resolve().parent
    base_dir = script_dir.parent.parent
    results_dir = Path(results_dir or base_dir / "compliance/results")

    if output_path and output_path.endswith(".jsonld"):
        output_file = Path(output_path)
        output_dir = output_file.parent
    else:
        output_dir = Path(output_path or base_dir / "compliance/reports")
        output_file = output_dir / "compliance_matrix.jsonld"

    print("== journaltrove App Compliance Matrix Generation ==")
    print(f"Input directory: {results_dir}")
    print(f"Output directory: {output_dir}")
    print(f"Output file: {output_file}\n")

    output_dir.mkdir(parents=True, exist_ok=True)

    system_req = base_dir / "requirements/requirements.jsonld"
    if not system_req.exists():
        print(f"✗ Error: System requirements not found at {system_req}")
        sys.exit(1)

    temp_dir = Path(tempfile.mkdtemp())
    try:
        print("Collecting all requirements from system and components...")

        # Extract system requirements
        all_requirements = []
        with open(system_req, 'r') as f:
            system_data = json.load(f)
            for item in system_data.get('@graph', []):
                if (item.get('type') == 'Requirement' or item.get('@type') == 'Requirement') and \
                   (item.get('component') == 'System' or item.get('component') is None):
                    # Convert id to @id if needed
                    req_id = item.get('@id', item.get('id', ''))
                    all_requirements.append({
                        '@id': req_id,
                        '@type': 'Requirement',
                        'name': item.get('name', ''),
                        'description': item.get('description', ''),
                        'component': 'System',
                        'status': item.get('status', ''),
                        'priority': item.get('priority', ''),
                        'parent': item.get('parent', '')
                    })

        # Check for component requirements
        components_dir = base_dir / "components"
        print(f"Checking for component requirements in directory: {components_dir}")

        if components_dir.exists():
            print("Directory exists. Listing contents:")
            for item in components_dir.glob('**/*'):
                print(f"  {item.relative_to(components_dir)}")

            for component_dir in components_dir.iterdir():
                if component_dir.is_dir():
                    component = component_dir.name
                    print(f"Processing requirements for component: {component}")

                    req_file = component_dir / "requirements.jsonld"
                    if req_file.exists():
                        print(f"Found requirements file: {req_file}")
                        
                        try:
                            with open(req_file, 'r') as f:
                                comp_data = json.load(f)
                                for item in comp_data.get('@graph', []):
                                    if item.get('type') == 'Requirement' or item.get('@type') == 'Requirement':
                                        # Convert id to @id if needed
                                        req_id = item.get('@id', item.get('id', ''))
                                        all_requirements.append({
                                            '@id': req_id,
                                            '@type': 'Requirement',
                                            'name': item.get('name', ''),
                                            'description': item.get('description', ''),
                                            'component': component,
                                            'status': item.get('status', ''),
                                            'priority': item.get('priority', ''),
                                            'parent': item.get('parent', '')
                                        })
                            print(f"✅ Successfully processed requirements for {component}")
                        except json.JSONDecodeError:
                            print(f"✗ Error: Invalid JSON-LD in {req_file}")
                    else:
                        print(f"⚠️ Warning: No requirements.jsonld found for component: {component}")
        else:
            print(f"✗ Error: Components directory does not exist: {components_dir}")

        print(f"Found {len(all_requirements)} total requirements across all components")

        # Create initial structure
        compliance_matrix = {
            "@context": "../requirements/context/requirements-context.jsonld",
            "@graph": [
                {
                    "@id": "compliance-matrix",
                    "@type": "ComplianceMatrix",
                    "name": "journaltrove App Compliance Matrix",
                    "description": "Generated compliance matrix aggregating test results from all components",
                    "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "components": [],
                    "requirements": [],
                    "testCases": []
                }
            ]
        }

        # Add all requirements to the compliance matrix
        compliance_matrix["@graph"][0]["requirements"] = all_requirements

        with open(output_file, "w") as f:
            json.dump(compliance_matrix, f, indent=2)

        print("✓ Created initial compliance matrix with all requirements")

        # Process component test results
        print("Processing test results from each component...")

        # Find all test result files
        for result_file in results_dir.glob("**/*.jsonld"):
            print(f"Processing {result_file}...")
            
            # Extract component name from the file path
            component = result_file.parent.name
            print(f"Component: {component}")
            
            # Validate JSON-LD format
            try:
                with open(result_file, 'r') as f:
                    result_data = json.load(f)
                
                # Add component to the compliance matrix if not already there
                with open(output_file, "r") as f:
                    compliance_matrix = json.load(f)
                
                if component not in compliance_matrix["@graph"][0]["components"]:
                    compliance_matrix["@graph"][0]["components"].append(component)
                
                # Extract test cases
                test_cases = []
                try:
                    for test_suite in result_data.get('@graph', [])[0].get('testSuites', []):
                        for test_case in test_suite.get('testCases', []):
                            test_case_obj = {
                                '@id': test_case.get('@id', ''),
                                '@type': 'TestCase',
                                'component': component,
                                'name': test_case.get('name', ''),
                                'verifies': test_case.get('verifies', ''),
                                'result': test_case.get('result', '')
                            }
                            test_cases.append(test_case_obj)
                except (IndexError, KeyError, AttributeError):
                    print(f"⚠️ Warning: Could not extract test cases from {result_file}")
                
                # Add test cases to the compliance matrix
                for test_case in test_cases:
                    compliance_matrix["@graph"][0]["testCases"].append(test_case)
                
                with open(output_file, "w") as f:
                    json.dump(compliance_matrix, f, indent=2)
                
            except json.JSONDecodeError:
                print(f"✗ Error: Invalid JSON-LD in {result_file}")
                continue

        # Create a temp file with all verified requirements
        with open(output_file, "r") as f:
            compliance_matrix = json.load(f)
        
        tested_req_ids = {tc.get("verifies", "") for tc in compliance_matrix["@graph"][0]["testCases"]}
        
        # Update the status of each requirement in the matrix
        for req in compliance_matrix["@graph"][0]["requirements"]:
            req["tested"] = req.get("@id", "") in tested_req_ids
        
        # Generate statistics
        print("Generating statistics...")
        
        total_reqs = len(compliance_matrix["@graph"][0]["requirements"])
        tested_reqs = sum(1 for req in compliance_matrix["@graph"][0]["requirements"] if req.get("tested", False))
        untested_reqs = total_reqs - tested_reqs
        
        total_tests = len(compliance_matrix["@graph"][0]["testCases"])
        passed_tests = sum(1 for tc in compliance_matrix["@graph"][0]["testCases"] if tc.get("result") in ["Pass", "Passed"])
        failed_tests = sum(1 for tc in compliance_matrix["@graph"][0]["testCases"] if tc.get("result") in ["Fail", "Failed"])
        
        components_count = len(set(compliance_matrix["@graph"][0]["components"]))
        
        coverage_pct = 0
        if total_reqs > 0:
            coverage_pct = round(tested_reqs * 100 / total_reqs, 1)
        
        # Add statistics to the compliance matrix
        compliance_matrix["@graph"][0]["statistics"] = {
            "totalRequirements": total_reqs,
            "testedRequirements": tested_reqs,
            "untestedRequirements": untested_reqs,
            "coveragePercentage": coverage_pct,
            "totalTests": total_tests,
            "passingTests": passed_tests,
            "failingTests": failed_tests,
            "components": components_count
        }
        
        with open(output_file, "w") as f:
            json.dump(compliance_matrix, f, indent=2)
        
        # Copy the compliance matrix to the dashboard directory
        dashboard_dir = base_dir / "compliance/dashboard"
        dashboard_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy(output_file, dashboard_dir / "compliance_matrix.jsonld")
        
        print(f"Compliance matrix generated: {output_file}")
        print("Dashboard updated with compliance matrix")
        print("Statistics:")
        print(f"- Total requirements: {total_reqs}")
        print(f"- Tested requirements: {tested_reqs} ({coverage_pct}%)")
        print(f"- Untested requirements: {untested_reqs}")
        print(f"- Total tests: {total_tests}")
        print(f"- Passed tests: {passed_tests}")
        print(f"- Failed tests: {failed_tests}")
        print(f"- Components: {components_count}")

    finally:
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        main() 