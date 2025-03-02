# Todo App Scripts

This directory contains utility scripts for the Todo App system.

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
🚀 Todo App CI/CD Pipeline Orchestrator Runner
===============================================
Checking permissions for journalbrand/todo-system...
🚀 Triggering CI/CD Pipeline Orchestrator workflow...
⏱ Waiting for workflow to start running...
✅ Workflow started with run ID: 1234567890
View progress at: https://github.com/journalbrand/todo-system/actions/runs/1234567890
Would you like to monitor the workflow status? (y/n): y
📊 Monitoring workflow status...
⏳ Workflow is still running (status: in_progress)...
✅ Workflow completed with status: success
🎉 CI/CD pipeline completed successfully!
View details at: https://github.com/journalbrand/todo-system/actions/runs/1234567890
Done!
```

### ✅ `validate-jsonld.js`

Validates JSON-LD files against the defined schemas.

### 🔍 `validate-requirement-ids.js`

Validates requirement IDs and their hierarchical relationships.

### 🔍 `validate-requirements-early.js`

Performs early validation of requirements and test mappings before the CI/CD pipeline runs component workflows.

#### Usage

```bash
node validate-requirements-early.js <system-reqs-file> [component-reqs-files...] [test-mapping-files...]
```

#### Features

- Validates parent-child relationships in requirements hierarchy
- Validates that test cases only reference existing requirements
- Checks requirement ID formatting and consistency across components
- Ensures component-specific requirements use the correct component identifier

#### Example Usage

```bash
node validate-requirements-early.js \
  requirements/requirements.jsonld \
  components/ios/requirements/requirements.jsonld \
  components/android/requirements/requirements.jsonld \
  components/ipfs/requirements/requirements.jsonld \
  tmp/test-mappings/ios/test-mappings.jsonld \
  tmp/test-mappings/android/test-mappings.jsonld \
  tmp/test-mappings/ipfs/test-mappings.jsonld
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

## Further Information

For more details on the CI/CD pipeline and workflow orchestration, see the main [README.md](../README.md#-running-the-orchestrator) file. 