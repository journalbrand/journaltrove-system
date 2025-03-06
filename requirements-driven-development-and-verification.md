# Requirements-Driven Development and Verification

This guide outlines the complete workflow for implementing and verifying new features in the JournalTrove system following a requirements-driven approach. By following these steps, you'll ensure that all new functionality is properly documented, tested, and verified in the compliance matrix.

## Table of Contents

1. [Overview](#overview)
2. [Understanding the Compliance Matrix](#understanding-the-compliance-matrix)
3. [Modifying Component Requirements](#modifying-component-requirements)
4. [Implementing the Function](#implementing-the-function)
5. [Writing Tests](#writing-tests)
6. [Creating Test Mappings](#creating-test-mappings)
7. [Running the Orchestrator](#running-the-orchestrator)
8. [Downloading the Compliance Matrix](#downloading-the-compliance-matrix)
9. [Viewing the Compliance Dashboard](#viewing-the-compliance-dashboard)
10. [Troubleshooting](#troubleshooting)
11. [Complete Example Workflow](#complete-example-workflow)

## Overview

The JournalTrove system follows a requirements-driven development approach where:

1. Requirements are defined before implementation
2. Code is written to satisfy specific requirements
3. Tests verify that the implementation meets the requirements
4. Test mappings connect tests to requirements
5. A compliance matrix shows which requirements are verified by tests

This approach ensures traceability from requirements to implementation to verification, providing visibility into the system's compliance with its requirements.

## Understanding the Compliance Matrix

The compliance matrix is a core concept in our development process that connects requirements, implementations, and tests.

### What is the Compliance Matrix?

The compliance matrix is a JSON-LD document that serves as the single source of truth for:

1. **Requirements tracking**: All system and component requirements are listed
2. **Test coverage**: Which tests verify which requirements
3. **Verification status**: Whether requirements have passed their tests
4. **Traceability**: The hierarchical relationships between requirements

### How the Compliance Matrix is Generated

The compliance matrix is automatically generated through our CI/CD pipeline:

1. Component CI workflows run tests and produce test result files
2. Component requirements are collected from each repository
3. The `aggregate_jsonld_compliance.sh` script combines all requirements and test results
4. The resulting compliance matrix is stored as an artifact in GitHub Actions
5. The `download_compliance_matrix.py` script fetches the latest matrix for local viewing

### Structure of the Compliance Matrix

The compliance matrix has the following key sections:

```json
{
  "@context": "...",
  "@graph": [
    {
      "@id": "compliance-matrix",
      "@type": "ComplianceMatrix",
      "name": "JournalTrove App Compliance Matrix",
      "description": "...",
      "timestamp": "2025-03-06T03:57:21Z",
      "components": ["ios", "android", "ipfs"],
      "requirements": [
        {
          "@id": "System.1.1.iOS.1",
          "@type": "Requirement",
          "name": "iOS journaltrove Management",
          "description": "...",
          "component": "ios",
          "status": "Draft",
          "priority": "High",
          "parent": "System.1.1"
        },
        // More requirements...
      ],
      "testCases": [
        {
          "@id": "testEcho",
          "@type": "TestCase",
          "component": "ios",
          "name": "testEcho",
          "verifies": "System.1.1.iOS.1",
          "result": "Pass"
        },
        // More test cases...
      ],
      "statistics": {
        "totalRequirements": 31,
        "testedRequirements": 15,
        "untestedRequirements": 16,
        "coveragePercentage": 48.3,
        "totalTests": 11,
        "passingTests": 11,
        "failingTests": 0,
        "components": 3
      }
    }
  ]
}
```

### Benefits of the Compliance Matrix

The compliance matrix provides several benefits:

1. **Visibility**: Stakeholders can see which requirements are implemented and tested
2. **Accountability**: Teams can track their progress toward full coverage
3. **Traceability**: Requirements can be traced to their implementing code and tests
4. **Compliance**: Regulatory or contractual compliance can be demonstrated
5. **Quality Assurance**: Gaps in testing or requirements can be identified and addressed

## Modifying Component Requirements

The first step is to add or modify the requirements for the component you're working on.

### Step 1: Locate the Component Requirements File

Each component has its own requirements file located at:

- iOS: `journaltrove-ios/requirements/requirements.jsonld`
- Android: `journaltrove-android/requirements/requirements.jsonld`
- IPFS: `journaltrove-ipfs/requirements/requirements.jsonld`

### Step 2: Add the New Requirement

Add your requirement to the `@graph` array in the requirements file. Follow these guidelines:

- Use hierarchical IDs that reflect the component and parent requirement
- Include a clear name and description
- Specify the component, priority, status, and parent

Example:

```json
{
  "id": "System.2.1.iOS.3",
  "type": "Requirement",
  "name": "iOS Offline Mode Support",
  "description": "The iOS client shall support offline operation when no network connection is available",
  "status": "Draft",
  "priority": "High",
  "component": "iOS",
  "parent": "System.2.1"
}
```

### Step 3: Validate the Requirements File

Ensure the requirements file is valid JSON-LD:

```bash
jq empty requirements/requirements.jsonld
```

## Implementing the Function

Next, implement the function that satisfies the requirement.

### Step 1: Identify the Appropriate Module

Determine which module or class should contain the new functionality.

### Step 2: Implement the Function

Add the new function to the appropriate file. Include clear documentation that references the requirement ID.

Example (Swift):

```swift
/// Checks if the device is in offline mode
/// This implements requirement System.2.1.iOS.3 for offline mode support
public func isOfflineMode() -> Bool {
    // Implementation logic
    let reachability = try? Reachability()
    return reachability?.connection == .unavailable
}
```

Example (Kotlin):

```kotlin
/**
 * Checks if the device is in offline mode
 * This implements requirement System.2.1.Android.3 for offline mode support
 */
fun isOfflineMode(): Boolean {
    // Implementation logic
    val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val network = connectivityManager.activeNetwork
    return network == null
}
```

Example (Go):

```go
// IsOfflineMode checks if the IPFS node is in offline mode
// This implements requirement System.2.1.IPFS.6 for offline mode support
func IsOfflineMode() bool {
    // Implementation logic
    peers := ipfs.Swarm().Peers()
    return len(peers) == 0
}
```

## Writing Tests

Once the function is implemented, write tests to verify it meets the requirements.

### Step 1: Create or Locate the Test File

Find the appropriate test file or create a new one if needed.

### Step 2: Implement the Test

Write a test that verifies the functionality. Include comments that reference the requirement ID.

Example (Swift):

```swift
/// Test that the isOfflineMode function correctly detects offline status
/// This test verifies requirement System.2.1.iOS.3
func testOfflineMode() {
    // Given
    let mockNetworkService = MockNetworkService(isConnected: false)
    let service = NetworkManager(service: mockNetworkService)
    
    // When
    let result = service.isOfflineMode()
    
    // Then
    XCTAssertTrue(result, "Should correctly detect offline mode")
}
```

Example (Kotlin):

```kotlin
/**
 * Test that the isOfflineMode function correctly detects offline status
 * This test verifies requirement System.2.1.Android.3
 */
@Test
fun testOfflineMode() {
    // Given
    val mockConnectivityManager = mock(ConnectivityManager::class.java)
    `when`(mockConnectivityManager.activeNetwork).thenReturn(null)
    
    // When
    val result = NetworkManager(mockConnectivityManager).isOfflineMode()
    
    // Then
    assertTrue(result, "Should correctly detect offline mode")
}
```

Example (Go):

```go
// TestOfflineMode verifies the offline mode detection
// This test verifies requirement System.2.1.IPFS.6
func TestOfflineMode(t *testing.T) {
    // Given
    mockIPFS := &MockIPFSService{peerCount: 0}
    
    // When
    result := IsOfflineMode(mockIPFS)
    
    // Then
    if !result {
        t.Errorf("Expected offline mode to be detected when no peers are available")
    }
}
```

## Creating Test Mappings

After writing the tests, create or update test mappings to link them to requirements.

### Step 1: Locate the Test Mappings File

Each component has its own test mappings file:

- iOS: `journaltrove-ios/Tests/test-mappings.jsonld`
- Android: `journaltrove-android/app/src/test/test-mappings.jsonld`
- IPFS: `journaltrove-ipfs/tests/test-mappings.jsonld`

### Step 2: Add the Test Mapping

Add your test to the appropriate test suite in the mappings file:

```json
{
  "@id": "testOfflineMode",
  "@type": "TestCase",
  "name": "testOfflineMode",
  "verifies": "System.2.1.iOS.3",
  "description": "Verifies that the app correctly detects when it's in offline mode"
}
```

### Step 3: Validate the Test Mappings File

Ensure the test mappings file is valid JSON-LD:

```bash
jq empty Tests/test-mappings.jsonld
```

## Running the Orchestrator

Once you've committed and pushed your changes, trigger the orchestrator workflow in GitHub Actions.

### Step 1: Commit and Push Your Changes

```bash
git add .
git commit -m "Implement offline mode support (System.2.1.iOS.3)"
git push origin main
```

### Step 2: Trigger the Orchestrator Workflow

You can trigger the workflow through the GitHub UI or using the GitHub CLI:

```bash
gh workflow run orchestrator.yml --repo journalbrand/journaltrove-system
```

### Step 3: Monitor the Workflow

Monitor the workflow execution either through the GitHub UI or using the CLI:

```bash
gh run list --workflow=orchestrator.yml --repo journalbrand/journaltrove-system
```

## Downloading the Compliance Matrix

After the orchestrator workflow completes successfully, download the generated compliance matrix.

### Step 1: Run the Download Script

```bash
cd journaltrove-system
python3 scripts/download_compliance_matrix.py
```

This will download the compliance matrix to `compliance/dashboard/compliance_matrix.jsonld`.

## Viewing the Compliance Dashboard

After downloading the compliance matrix, you can view it in the compliance dashboard.

### Starting the Dashboard Server

To view the compliance matrix:

1. Navigate to the `journaltrove-system` directory:
   ```bash
   cd journaltrove-system
   ```

2. Start the dashboard server:
   ```bash
   python3 serve_dashboard.py
   ```

3. Open a web browser and go to:
   ```
   http://localhost:8000
   ```

### Interpreting the Dashboard

The compliance dashboard provides a visual representation of the compliance matrix data. Here's how to interpret the information presented:

#### Main Dashboard View

The main dashboard displays:

1. **Top Summary**: Provides an overview of:
   - Total requirements
   - Requirements verified by tests
   - Test coverage percentage
   - Number of passing and failing tests

2. **Requirements Tree**: A hierarchical representation of requirements showing:
   - Requirement ID
   - Requirement name
   - Component (iOS, Android, IPFS)
   - Status (colored indicators):
     - Green: Requirement is verified by passing tests
     - Red: Requirement is verified but tests are failing
     - Yellow: Requirement has no tests yet

3. **Component Filters**: Buttons to filter requirements by component (iOS, Android, IPFS, or All)

4. **Status Filters**: Options to filter by verification status

#### Requirement Details

Clicking on any requirement in the tree will show:

1. **Requirement Details**:
   - Full description
   - Priority
   - Status
   - Component

2. **Test Cases**: Tests that verify this requirement
   - Test name
   - Test result (Pass/Fail)
   - Date last executed

3. **Child Requirements**: If applicable, sub-requirements are listed

#### Test Results View

The Tests tab shows:

1. **Test Summary**: Total tests, passing, and failing
2. **Test List**: All tests with their:
   - Test name
   - Component
   - Requirements verified
   - Result status

### Example Interpretation

For instance, if you see:

- Requirement "System.1.1.iOS.1" is green, it means:
  - This iOS requirement has tests
  - All tests for this requirement are passing

- If "System.1.1.Android.2" is yellow, it means:
  - This Android requirement has no tests yet
  - This is a gap in test coverage that needs addressing

- If a test is failing (red), it indicates:
  - The implementation may not satisfy the requirement
  - There is a regression in functionality
  - The test itself may need updating

Use these indicators to prioritize your development and testing efforts.

## Troubleshooting

### Common Issues and Solutions

#### 1. Invalid JSON-LD Files

If you encounter JSON-LD validation errors:

```bash
# Validate JSON-LD syntax
jq empty requirements/requirements.jsonld

# Validate against schema (if available)
node scripts/validate-jsonld.js schema/requirements-schema.json requirements/requirements.jsonld
```

#### 2. Component Requirements Not Showing in Compliance Matrix

If component requirements aren't appearing in the compliance matrix:

- Verify that the component CI workflows are uploading the requirements files as artifacts
- Check that the compliance-matrix.yml workflow is downloading these artifacts
- Examine the logs of the aggregate_jsonld_compliance.sh script for errors

#### 3. Tests Not Mapping to Requirements

If tests aren't correctly mapped to requirements:

- Ensure the test ID in the test mappings file matches the actual test function name
- Verify that the requirement ID exists in the requirements file
- Check that the test results JSON-LD file is being generated and uploaded correctly

#### 4. Workflow Failures

If the orchestrator workflow fails:

```bash
# Get detailed logs of the failed run
gh run view --log [RUN_ID] --repo journalbrand/journaltrove-system
```

#### 5. Downloading Compliance Matrix Fails

If downloading the compliance matrix fails:

- Ensure you have GitHub CLI installed and authenticated
- Verify that the compliance matrix workflow completed successfully
- Check for errors in the download script output

## Complete Example Workflow

This example demonstrates the complete workflow for adding a background sync feature to the iOS component of JournalTrove.

### Step 1: Add a New Requirement

First, let's add a new requirement to the iOS requirements file.

File: `journaltrove-ios/requirements/requirements.jsonld`

```json
{
  "@context": {
    "@vocab": "http://journaltrove.com/schema/",
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "Requirement": "http://journaltrove.com/schema/Requirement",
    "component": {
      "@type": "@id"
    },
    "parent": {
      "@type": "@id"
    }
  },
  "@graph": [
    {
      "@id": "iOS",
      "@type": "Component",
      "name": "iOS Component"
    },
    {
      "@id": "System.1.1.iOS.1",
      "@type": "Requirement",
      "name": "iOS Echo Service",
      "description": "The iOS app shall provide an echo service that returns the input string",
      "component": "iOS",
      "status": "Draft",
      "priority": "Medium",
      "parent": "System.1.1"
    },
    // Add the new requirement
    {
      "@id": "System.1.1.iOS.2",
      "@type": "Requirement",
      "name": "iOS Background Sync",
      "description": "The iOS app shall support background synchronization of journal entries when the app is not in the foreground",
      "component": "iOS",
      "status": "Draft",
      "priority": "High",
      "parent": "System.1.1"
    }
  ]
}
```

### Step 2: Implement the Functionality

Next, create the implementation that satisfies the requirement.

File: `journaltrove-ios/Sources/Core/SyncService.swift`

```swift
import Foundation
import BackgroundTasks

public class SyncService {
    private let bgTaskIdentifier = "com.journaltrove.sync"
    private let syncInterval: TimeInterval = 3600 // 1 hour
    
    public init() {
        registerBackgroundTask()
    }
    
    /// Registers background synchronization task with the system
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskIdentifier, using: nil) { task in
            self.handleSyncTask(task: task as! BGProcessingTask)
        }
    }
    
    /// Schedule the next background sync
    public func scheduleBackgroundSync() -> Bool {
        let request = BGProcessingTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: syncInterval)
        request.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            return true
        } catch {
            print("Could not schedule background sync: \(error)")
            return false
        }
    }
    
    /// Handle the sync task when executed in background
    private func handleSyncTask(task: BGProcessingTask) {
        // Create a task that will be called when the app is about to be suspended
        let cancelTask = task.expirationHandler = {
            // Cancel the sync operation
            task.setTaskCompleted(success: false)
        }
        
        // Perform synchronization
        synchronizeJournalEntries { success in
            // Schedule the next sync regardless of success
            self.scheduleBackgroundSync()
            task.setTaskCompleted(success: success)
        }
    }
    
    /// Synchronize journal entries with the server
    public func synchronizeJournalEntries(completion: @escaping (Bool) -> Void) {
        // Actual implementation would connect to server and sync entries
        // For this example, we'll simulate a successful sync
        DispatchQueue.global().async {
            // Simulate network operation
            Thread.sleep(forTimeInterval: 2.0)
            
            // Return success
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
}
```

### Step 3: Write Tests

Now, write a test for the new functionality.

File: `journaltrove-ios/Tests/CoreTests/SyncServiceTests.swift`

```swift
import XCTest
@testable import Core
import BackgroundTasks

class SyncServiceTests: XCTestCase {
    var syncService: SyncService!
    
    override func setUp() {
        super.setUp()
        syncService = SyncService()
    }
    
    override func tearDown() {
        syncService = nil
        super.tearDown()
    }
    
    func testBackgroundSyncScheduling() {
        // Given the sync service is initialized
        
        // When we schedule a background sync
        let result = syncService.scheduleBackgroundSync()
        
        // Then the scheduling should succeed
        XCTAssertTrue(result, "Background sync should be successfully scheduled")
    }
    
    func testSynchronizeJournalEntries() {
        // Given the sync service is initialized
        
        // When we perform a sync
        let expectation = self.expectation(description: "Sync completion")
        var syncResult = false
        
        syncService.synchronizeJournalEntries { success in
            syncResult = success
            expectation.fulfill()
        }
        
        // Then the sync should complete successfully
        waitForExpectations(timeout: 5.0, handler: nil)
        XCTAssertTrue(syncResult, "Journal synchronization should succeed")
    }
}
```

### Step 4: Create Test Mappings

Update the test mappings file to link the test to the requirement.

File: `journaltrove-ios/Tests/test-mappings.jsonld`

```json
{
  "@context": {
    "@vocab": "http://journaltrove.com/schema/",
    "TestMapping": "http://journaltrove.com/schema/TestMapping",
    "testCase": {
      "@type": "@id"
    },
    "verifies": {
      "@type": "@id"
    }
  },
  "@graph": [
    {
      "@id": "mapping1",
      "@type": "TestMapping",
      "testCase": "testEcho",
      "verifies": "System.1.1.iOS.1"
    },
    {
      "@id": "mapping2",
      "@type": "TestMapping",
      "testCase": "testBackgroundSyncScheduling",
      "verifies": "System.1.1.iOS.2"
    },
    {
      "@id": "mapping3",
      "@type": "TestMapping",
      "testCase": "testSynchronizeJournalEntries",
      "verifies": "System.1.1.iOS.2"
    }
  ]
}
```

### Step 5: Validate JSON-LD Files

Before committing, validate the JSON-LD files to ensure they conform to the schema:

```bash
cd journaltrove-system
node scripts/validate-jsonld.js ../journaltrove-ios/requirements/requirements.jsonld
node scripts/validate-jsonld.js ../journaltrove-ios/Tests/test-mappings.jsonld
```

Ensure there are no validation errors before proceeding.

### Step 6: Commit and Push Changes

Commit and push your changes to the repository:

```bash
cd journaltrove-ios
git add requirements/requirements.jsonld Sources/Core/SyncService.swift Tests/CoreTests/SyncServiceTests.swift Tests/test-mappings.jsonld
git commit -m "Add iOS background sync feature with tests and requirements"
git push origin main
```

### Step 7: Run the Orchestrator Workflow

Trigger the orchestrator workflow in GitHub Actions:

```bash
cd ../journaltrove-system
gh workflow run orchestrator.yml --repo journalbrand/journaltrove-system
```

Monitor the workflow:

```bash
gh run list --workflow=orchestrator.yml
```

### Step 8: Download and View Compliance Matrix

After the workflow completes, download the compliance matrix:

```bash
cd journaltrove-system
python3 scripts/download_compliance_matrix.py
```

Start the dashboard server:

```bash
python3 serve_dashboard.py
```

Access the dashboard in your browser:
```
http://localhost:8000
```

### Verification and Validation

In the compliance dashboard:

1. Navigate to the iOS component section.
2. Find `System.1.1.iOS.2` (iOS Background Sync).
3. Verify that:
   - The requirement is displayed in green, indicating that it's verified by passing tests.
   - Both test cases (`testBackgroundSyncScheduling` and `testSynchronizeJournalEntries`) are linked to the requirement.
   - All tests are passing.

If there are any issues:
- Review the workflow logs in GitHub Actions
- Check for validation errors in the JSON-LD files
- Ensure that your tests actually pass
- Verify that the test mappings correctly link tests to requirements 