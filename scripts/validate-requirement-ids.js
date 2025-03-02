#!/usr/bin/env node

/**
 * Validate Requirement IDs in Test Results
 * This script validates that requirement IDs referenced in test results
 * match the format of the actual requirement IDs in the requirements file.
 */

const fs = require('fs');
const path = require('path');

// Check arguments
if (process.argv.length < 4) {
  console.error('Usage: node validate-requirement-ids.js <requirements-file> <test-results-directory>');
  process.exit(1);
}

const requirementsFilePath = process.argv[2];
const testResultsDir = process.argv[3];

// Validate file existence
if (!fs.existsSync(requirementsFilePath)) {
  console.error(`Error: Requirements file not found: ${requirementsFilePath}`);
  process.exit(1);
}

if (!fs.existsSync(testResultsDir)) {
  console.error(`Error: Test results directory not found: ${testResultsDir}`);
  process.exit(1);
}

// Load requirements
let requirements;
try {
  const requirementsContent = fs.readFileSync(requirementsFilePath, 'utf8');
  requirements = JSON.parse(requirementsContent);
} catch (error) {
  console.error(`Error parsing requirements file: ${error.message}`);
  process.exit(1);
}

// Extract valid requirement IDs
const validRequirementIds = new Set();
if (requirements['@graph'] && Array.isArray(requirements['@graph'])) {
  requirements['@graph'].forEach(item => {
    if (item['@type'] === 'Requirement' || item.type === 'Requirement') {
      if (item.id || item['@id']) {
        validRequirementIds.add(item.id || item['@id']);
      }
    }
  });
}

console.log(`Found ${validRequirementIds.size} valid requirement IDs in requirements file`);

// Process test result files
const testFiles = findTestResultFiles(testResultsDir);
console.log(`Found ${testFiles.length} test result files to validate`);

let errors = 0;
let warnings = 0;
let correct = 0;

testFiles.forEach(testFile => {
  try {
    const testContent = fs.readFileSync(testFile, 'utf8');
    const testResults = JSON.parse(testContent);
    
    // Extract test cases and their requirement references
    const testCases = extractTestCases(testResults);
    
    testCases.forEach(testCase => {
      const reqId = testCase.verifies;
      
      if (!reqId) {
        console.warn(`Warning: Test case ${testCase['@id'] || testCase.name || 'unknown'} has no requirement reference`);
        warnings++;
        return;
      }
      
      // Check if this is in the format Req.*.* but missing Sys
      if (reqId.match(/^Req\.(?!Sys\.)/) && !validRequirementIds.has(reqId)) {
        // See if adding Sys would make it valid
        const correctedId = reqId.replace(/^Req\./, 'Req.Sys.');
        if (validRequirementIds.has(correctedId)) {
          console.error(`Error: Test case references '${reqId}' but should be '${correctedId}'`);
          errors++;
        } else {
          console.error(`Error: Test case references '${reqId}' which doesn't exist in requirements`);
          errors++;
        }
      } else if (!validRequirementIds.has(reqId)) {
        console.error(`Error: Test case references '${reqId}' which doesn't exist in requirements`);
        errors++;
      } else {
        correct++;
      }
    });
  } catch (error) {
    console.error(`Error processing test file ${testFile}: ${error.message}`);
    errors++;
  }
});

console.log(`\nValidation summary:`);
console.log(`- ${correct} correct requirement references`);
console.log(`- ${warnings} warnings`);
console.log(`- ${errors} errors`);

// Exit with error code if any errors were found
process.exit(errors > 0 ? 1 : 0);

/**
 * Find all JSON-LD test result files in the given directory
 */
function findTestResultFiles(directory) {
  const results = [];
  
  const files = fs.readdirSync(directory, { withFileTypes: true });
  
  files.forEach(file => {
    const fullPath = path.join(directory, file.name);
    
    if (file.isDirectory()) {
      // Recursively search subdirectories
      results.push(...findTestResultFiles(fullPath));
    } else if (file.name.endsWith('.jsonld') || file.name.endsWith('.json')) {
      results.push(fullPath);
    }
  });
  
  return results;
}

/**
 * Extract test cases from test results
 */
function extractTestCases(testResults) {
  const testCases = [];
  
  if (testResults['@graph'] && Array.isArray(testResults['@graph'])) {
    testResults['@graph'].forEach(item => {
      if (item.testSuites && Array.isArray(item.testSuites)) {
        item.testSuites.forEach(suite => {
          if (suite.testCases && Array.isArray(suite.testCases)) {
            testCases.push(...suite.testCases);
          }
        });
      }
      
      if (item.testCases && Array.isArray(item.testCases)) {
        testCases.push(...item.testCases);
      }
    });
  }
  
  return testCases;
} 