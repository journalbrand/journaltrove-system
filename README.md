<!-- === WATCHER HEADER START === -->
<!-- File: journaltrove-system/README.md -->
<!-- Managed by file watcher -->
<!-- === WATCHER HEADER END === -->
# 🌹 journaltrove App System

This repository is the system-level coordinator for the journaltrove App ecosystem, defining requirements, CI/CD workflows, and compliance tracking for:

- iOS Client (Swift)
- Android Client (Kotlin) 
- IPFS Node (Go)

## 📚 System Overview

The journaltrove App is a distributed application that enables users to create, manage, and synchronize journaltrove lists across multiple devices. It offers:

- Secure local storage on mobile devices
- IPFS-based data synchronization
- Cryptographic identity for secure data ownership
- Cross-platform compatibility (iOS, Android)

## 🏗️ Repository Structure

The journaltrove App ecosystem is composed of multiple repositories:

- **[journaltrove-system](https://github.com/journalbrand/journaltrove-system)** - System-level coordination and requirements (this repo)
- **[journaltrove-ios](https://github.com/journalbrand/journaltrove-ios)** - iOS client (Swift)
- **[journaltrove-android](https://github.com/journalbrand/journaltrove-android)** - Android client (Kotlin)
- **[journaltrove-ipfs](https://github.com/journalbrand/journaltrove-ipfs)** - IPFS node implementation (Go)

### Key Directories in This Repository

```
journaltrove-system/
├── .github/workflows/      # CI/CD workflows
├── compliance/             # Compliance tracking
│   ├── dashboard/          # Compliance visualization
│   ├── reports/            # Generated compliance reports
│   ├── results/            # Test results from components
│   └── scripts/            # Compliance processing scripts
├── requirements/           # System requirements
│   └── context/            # JSON-LD context definitions
└── schema/                 # JSON schemas for validation
```

## 🚀 Getting Started

### Setting Up Your Development Environment

1. Clone all repositories:

```bash
git clone https://github.com/journalbrand/journaltrove-system.git
git clone https://github.com/journalbrand/journaltrove-ios.git
git clone https://github.com/journalbrand/journaltrove-android.git
git clone https://github.com/journalbrand/journaltrove-ipfs.git
```

2. Open the workspace in VSCode:

```bash
code journaltrove-system/journaltrove-app.code-workspace
```

This will open all repositories in a single VSCode window with recommended extensions.

3. Install required tools:
   - Node.js and npm (for compliance dashboard)
   - jq (for JSON processing)
   - GitHub CLI (for workflow management)

## 📋 Requirements Management

This ecosystem uses structured JSON-LD for requirements management and traceability.

### Requirements Structure

- System-level requirements are defined in `journaltrove-system/requirements/requirements.jsonld`
- Component-level requirements are defined in each component repository
- The JSON-LD schema is defined in `journaltrove-system/requirements/context/requirements-context.jsonld`

### Requirements Hierarchy

Requirements follow a hierarchical structure:
- `System.X` - Top-level system requirements
- `System.X.Y` - Sub-requirements
- `System.X.Y.Component.Z` - Component-specific requirements

### Adding New Requirements

1. For system-level requirements, edit `journaltrove-system/requirements/requirements.jsonld`
2. For component-level requirements, edit the appropriate component repository
3. Ensure that component requirements reference their parent system requirements
4. Add test mappings to link tests to requirements

## 🧪 Compliance Tracking

The journaltrove App uses a sophisticated compliance tracking system to ensure requirements are met.

### Compliance Matrix

The compliance matrix aggregates test results from all components and maps them to requirements.
- Generated by the `compliance-matrix.yml` workflow
- Stored in `compliance/reports/compliance_matrix.jsonld`
- Visualized in the compliance dashboard

### Compliance Dashboard

The compliance dashboard provides a visual representation of requirements coverage:
1. Run the dashboard locally:
```bash
cd journaltrove-system
./serve-dashboard.sh
```
2. Open `http://localhost:8000/compliance/dashboard/` in your browser

## 🔄 CI/CD Pipeline

The journaltrove App implements a fully automated CI/CD pipeline across all repositories.

### CI/CD Structure

- **Component Level**: Each repository has its own CI workflow for building, testing, and validating requirements
- **System Level**: The system repository coordinates cross-repository workflows
- **Orchestrator**: A single workflow that triggers all component and system workflows

### Workflow Overview

1. **Orchestrator Workflow**: `journaltrove-system/.github/workflows/orchestrator.yml`
   - Triggers all component workflows
   - Waits for completion
   - Triggers system-level workflows

2. **Component Workflows**:
   - iOS CI: `journaltrove-ios/.github/workflows/ci.yml`
   - Android CI: `journaltrove-android/.github/workflows/ci.yml`
   - IPFS CI: `journaltrove-ipfs/.github/workflows/ci.yml`

3. **System Workflows**:
   - Compliance Matrix: `journaltrove-system/.github/workflows/compliance-matrix.yml`
   - Test Results Validation: `journaltrove-system/.github/workflows/test-results-validation.yml`

### Running the CI/CD Pipeline

The CI/CD pipeline can be triggered in several ways:
1. **Manual Trigger**: Via GitHub Actions UI
2. **Automated Trigger**: On push to main branch
3. **Completion Trigger**: When dependent workflows complete

## 🧪 Current Project State

The project is currently in active development with:

- ✅ System-level requirements defined
- ✅ JSON-LD requirements schema implemented
- ✅ Multi-repository structure established
- ✅ CI/CD pipeline automation complete
- ✅ Compliance tracking and dashboard implemented
- ✅ Basic component implementations (Echo services)
- 🚧 Full component implementations in progress

## 🚀 Running the Orchestrator

The journaltrove App uses a unified CI/CD pipeline orchestrator that triggers all component and system workflows in the correct sequence. This ensures consistent testing, validation, and reporting.

### Early Validation

The orchestrator starts with an early validation phase that performs proactive checks before triggering any component workflows:

- **Requirement Hierarchy Validation**: Ensures all parent-child relationships in requirements are valid
- **Test-to-Requirement Mapping Validation**: Validates that tests only reference existing requirements
- **Component ID Consistency**: Checks that requirement IDs follow the correct format and naming conventions
- **Cross-Repository Validation**: Validates requirements across all component repositories

This early validation catches issues up front, allowing you to fix problems before running the full test suite.

### Triggering the Pipeline

You can trigger the orchestrator in two ways:

1. **Via GitHub Actions UI**: Go to the [Actions tab](https://github.com/journalbrand/journaltrove-system/actions/workflows/orchestrator.yml) in the journaltrove-system repository and click "Run workflow"

2. **Via Command Line**: Use the provided script:
   ```bash
   cd journaltrove-system
   ./scripts/run-cicd-pipeline.sh
   ```

The orchestrator will:

1. Perform early validation of requirements and test mappings
2. Trigger component workflows (iOS, Android, IPFS) in parallel
3. Wait for component workflows to complete
4. Trigger system workflows (Compliance Matrix, Test Results Validation)
5. Generate final compliance reports

### Pipeline Flow

```
                                ┌─────────────────────┐
                                │ Early Validation    │
                                │ - Requirements      │
                                │ - Test Mappings     │
                                └──────────┬──────────┘
                                           │
                                           ▼
                 ┌─────────────────────────┼─────────────────────────┐
                 │                         │                         │
                 ▼                         ▼                         ▼
     ┌────────────────────┐   ┌────────────────────┐   ┌────────────────────┐
     │ iOS CI Workflow    │   │ Android CI Workflow│   │ IPFS CI Workflow   │
     └──────────┬─────────┘   └──────────┬─────────┘   └──────────┬─────────┘
                │                         │                        │
                └─────────────────────────┼────────────────────────┘
                                          │
                                          ▼
                           ┌─────────────────────────────┐
                           │ Compliance Matrix Generation │
                           └───────────────┬─────────────┘
                                           │
                                           ▼
                           ┌─────────────────────────────┐
                           │   Test Results Validation   │
                           └─────────────────────────────┘
```

### Viewing Results

The compliance dashboard provides a visual overview of test coverage and requirement status:

```bash
cd journaltrove-system
./serve-dashboard.sh
```

Then open `http://localhost:8000/compliance/dashboard/` in your browser.

## 📝 Contributing

To contribute to the journaltrove App System:

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add appropriate tests that map to requirements
5. Ensure the CI/CD pipeline succeeds
6. Submit a pull request

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details. 
