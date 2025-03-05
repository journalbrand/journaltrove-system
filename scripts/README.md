# journaltrove App Scripts

This directory contains utility scripts for the journaltrove App system.

## Available Scripts

### 🚀 `run-cicd-pipeline.sh`

Triggers the CI/CD pipeline orchestrator workflow in GitHub Actions.

#### Usage

```bash
./run-cicd-pipeline.sh
```

#### Requirements

- GitHub CLI installed (`gh`)
- Authenticated with GitHub (`gh auth login`)
- Appropriate permissions to the repository

#### Features

- Automatically triggers the orchestrator workflow
- Provides a link to monitor the workflow progress
- Can optionally monitor the workflow status in real-time
- Shows detailed status and completion results

#### Example Output

```
===============================================
🚀 journaltrove App CI/CD Pipeline Orchestrator Runner
===============================================
Checking permissions for journalbrand/journaltrove-system...
🚀 Triggering CI/CD Pipeline Orchestrator workflow...
⏱ Waiting for workflow to start running...
✅ Workflow started with run ID: 1234567890
View progress at: https://github.com/journalbrand/journaltrove-system/actions/runs/1234567890
Would you like to monitor the workflow status? (y/n): y
📊 Monitoring workflow status...
⏳ Workflow is still running (status: in_progress)...
✅ Workflow completed with status: success
🎉 CI/CD pipeline completed successfully!
View details at: https://github.com/journalbrand/journaltrove-system/actions/runs/1234567890
Done!
```

### ✅ `validate-jsonld.js`

Validates JSON-LD files against the defined schemas.

### 🔍 `validate-requirements.js`

Unified validation script for requirements, test mappings, and test results. This script supports two modes:
1. Early validation - Validates requirements structure and test mappings before tests run
2. Test results validation - Validates test results against requirements after tests run

#### Usage (Early Validation Mode)

```bash
node validate-requirements.js --early <system-reqs-file> <component1-reqs-file> [component2-reqs-file...] [--test-mappings <test-mapping-files>]
```

#### Usage (Test Results Validation Mode)

```bash
node validate-requirements.js --test-results <test-results-dir> <system-reqs-file> <component1-reqs-file> [component2-reqs-file...]
```

#### Features

- Validates parent-child relationships in requirements hierarchy
- Validates that test cases only reference existing requirements
- Checks requirement ID formatting and consistency across components
- Ensures component-specific requirements use the correct component identifier
- Validates test results against actual requirements
- Supports component-centered architecture where requirements are maintained in individual repositories

#### Example Usage (Early Validation)

```bash
node validate-requirements.js --early \
  requirements/requirements.jsonld \
  components/ios/requirements/requirements.jsonld \
  components/android/requirements/requirements.jsonld \
  components/ipfs/requirements/requirements.jsonld \
  --test-mappings "tmp/test-mappings/**/test-mappings.jsonld"
```

#### Example Usage (Test Results Validation)

```bash
node validate-requirements.js --test-results compliance/results \
  requirements/requirements.jsonld \
  components/ios/requirements/requirements.jsonld \
  components/android/requirements/requirements.jsonld \
  components/ipfs/requirements/requirements.jsonld
```

### 📥 `fetch-test-mappings.sh`

Fetches test mapping files from all component repositories for early validation.

#### Usage

```bash
./fetch-test-mappings.sh
```

#### Features

- Downloads test mapping files from iOS, Android, and IPFS repositories
- Organizes them in a standard directory structure for validation
- Authenticates with GitHub API to access repositories

### 📥 `fetch-component-requirements.sh`

Fetches requirements files from all component repositories.

#### Usage

```bash
./fetch-component-requirements.sh
```

#### Features

- Downloads requirements files from iOS, Android, and IPFS repositories
- Organizes them in a standard directory structure for validation
- Authenticates with GitHub API to access repositories

## Further Information

For more details on the CI/CD pipeline and workflow orchestration, see the main [README.md](../README.md#-running-the-orchestrator) file. 