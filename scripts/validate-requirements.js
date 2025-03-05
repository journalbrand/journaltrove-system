#!/usr/bin/env node

/**
 * Unified Requirements Validation Script
 * 
 * This script provides a unified approach to requirements validation:
 * 1. Early validation mode: Validates requirements structure, hierarchy, and test mappings
 * 2. Test results validation mode: Validates test results against requirement IDs
 * 
 * Usage (Early Validation Mode):
 *   node validate-requirements.js --early <system-reqs-file> <component1-reqs-file> [component2-reqs-file...] [--test-mappings <test-mapping-files>]
 * 
 * Usage (Test Results Validation Mode):
 *   node validate-requirements.js --test-results <test-results-dir> <system-reqs-file> <component1-reqs-file> [component2-reqs-file...]
 */

const fs = require('fs');
const path = require('path');
const glob = require('glob');

// Parse command line arguments
const args = process.argv.slice(2);
const mode = args.includes('--early') ? 'early' : (args.includes('--test-results') ? 'test-results' : null);

if (!mode || args.length < 2) {
  console.error('Usage (Early Validation Mode):');
  console.error('  node validate-requirements.js --early <system-reqs-file> <component1-reqs-file> [component2-reqs-file...] [--test-mappings <test-mapping-files>]');
  console.error('');
  console.error('Usage (Test Results Validation Mode):');
  console.error('  node validate-requirements.js --test-results <test-results-dir> <system-reqs-file> <component1-reqs-file> [component2-reqs-file...]');
  process.exit(1);
}

// Extract appropriate arguments based on mode
let requirementsFiles = [];
let testMappingFiles = [];
let testResultsDir = null;

if (mode === 'early') {
  const modeIndex = args.indexOf('--early');
  const testMappingsIndex = args.indexOf('--test-mappings');
  
  if (testMappingsIndex > -1 && testMappingsIndex + 1 < args.length) {
    // Get test mapping files
    const mappingPattern = args[testMappingsIndex + 1];
    testMappingFiles = glob.sync(mappingPattern);
    console.log(`Found ${testMappingFiles.length} test mapping files`);
    
    // Get requirements files (all args between --early and --test-mappings)
    requirementsFiles = args.slice(modeIndex + 1, testMappingsIndex);
  } else {
    // All remaining args are requirements files
    requirementsFiles = args.slice(modeIndex + 1);
  }
} else if (mode === 'test-results') {
  const modeIndex = args.indexOf('--test-results');
  if (modeIndex + 1 < args.length) {
    testResultsDir = args[modeIndex + 1];
    requirementsFiles = args.slice(modeIndex + 2);
  }
}

// Validate that we have the required files
if (requirementsFiles.length === 0) {
  console.error('Error: No requirements files specified');
  process.exit(1);
}

if (mode === 'test-results' && !testResultsDir) {
  console.error('Error: Test results directory not specified');
  process.exit(1);
}

// Initialize data structures for requirements tracking
const allRequirements = new Map();
const componentRequirements = new Map(); // Organize by component
const testMappings = []; // Store test-to-requirement mappings

// Process requirements files
console.log(`Processing ${requirementsFiles.length} requirements files`);

requirementsFiles.forEach(filePath => {
  try {
    if (!fs.existsSync(filePath)) {
      console.error(`Error: Requirements file not found: ${filePath}`);
      process.exit(1);
    }
    
    const content = fs.readFileSync(filePath, 'utf8');
    let data;
    
    try {
      data = JSON.parse(content);
    } catch (parseError) {
      console.error(`Error parsing ${filePath}: ${parseError.message}`);
      process.exit(1);
    }
    
    // Extract component name from path or content
    let componentName = path.basename(path.dirname(filePath));
    if (componentName === 'requirements') {
      componentName = path.basename(path.dirname(path.dirname(filePath)));
    }
    
    // Handle the special case of system requirements
    if (filePath.includes('journaltrove-system/requirements') || 
        filePath.includes('system/requirements')) {
      componentName = 'System';
    }
    
    console.log(`Processing requirements for component: ${componentName}`);
    
    if (!data['@graph'] || !Array.isArray(data['@graph'])) {
      console.error(`Error: Missing @graph array in ${filePath}`);
      process.exit(1);
    }
    
    // Process each requirement
    data['@graph'].forEach(item => {
      // Store requirements
      if (item.type === 'Requirement' || item['@type'] === 'Requirement') {
        const id = item.id || item['@id'];
        if (!id) {
          console.error(`Error: Requirement missing ID in ${filePath}`);
          return;
        }
        
        // Register this requirement
        allRequirements.set(id, {
          ...item,
          source: filePath,
          component: componentName
        });
        
        // Add to component-specific map
        if (!componentRequirements.has(componentName)) {
          componentRequirements.set(componentName, new Map());
        }
        componentRequirements.get(componentName).set(id, item);
      }
    });
    
  } catch (error) {
    console.error(`Error processing ${filePath}: ${error.message}`);
    process.exit(1);
  }
});

// Process test mapping files if in early mode
if (mode === 'early' && testMappingFiles.length > 0) {
  console.log(`Processing ${testMappingFiles.length} test mapping files`);
  
  testMappingFiles.forEach(filePath => {
    try {
      if (!fs.existsSync(filePath)) {
        console.error(`Error: Test mapping file not found: ${filePath}`);
        process.exit(1);
      }
      
      const content = fs.readFileSync(filePath, 'utf8');
      let data;
      
      try {
        data = JSON.parse(content);
      } catch (parseError) {
        console.error(`Error parsing ${filePath}: ${parseError.message}`);
        process.exit(1);
      }
      
      // Extract component name from path
      let componentName = path.basename(path.dirname(filePath));
      if (componentName === 'test-mappings') {
        componentName = path.basename(path.dirname(path.dirname(filePath)));
      }
      
      console.log(`Processing test mappings for component: ${componentName}`);
      
      if (!data['@graph'] || !Array.isArray(data['@graph'])) {
        console.error(`Error: Missing @graph array in ${filePath}`);
        process.exit(1);
      }
      
      // Extract test mappings
      data['@graph'].forEach(item => {
        if ((item.type === 'TestMappings' || item['@type'] === 'TestMappings') && 
            item.testSuites && Array.isArray(item.testSuites)) {
          
          item.testSuites.forEach(suite => {
            if (suite.testCases && Array.isArray(suite.testCases)) {
              suite.testCases.forEach(testCase => {
                if (testCase.verifies) {
                  testMappings.push({
                    id: testCase['@id'] || testCase.id,
                    name: testCase.name,
                    verifies: testCase.verifies,
                    source: filePath,
                    component: componentName
                  });
                }
              });
            }
          });
        }
      });
    } catch (error) {
      console.error(`Error processing ${filePath}: ${error.message}`);
      process.exit(1);
    }
  });
}

console.log(`Found ${allRequirements.size} total requirements across all components`);
if (mode === 'early') {
  console.log(`Found ${testMappings.length} test mappings\n`);
}

// Early Validation Mode: Run specific validation checks for requirements structure
if (mode === 'early') {
  // Missing parents are now expected when we have component-specific requirements
  // We'll now only validate parent references within a component
  runEarlyValidation(allRequirements, componentRequirements, testMappings);
}

// Test Results Validation Mode: Validate test results against requirements
if (mode === 'test-results') {
  runTestResultsValidation(allRequirements, testResultsDir);
}

/**
 * Run validations specific to early mode (pre-test)
 */
function runEarlyValidation(allRequirements, componentRequirements, testMappings) {
  let totalErrors = 0;
  
  // VALIDATION 1: Check parent-child relationships
  console.log('🔍 VALIDATING REQUIREMENT HIERARCHY:');
  let hierarchyErrors = 0;

  allRequirements.forEach((req, id) => {
    const parent = req.parent;
    
    // Only validate parent if it's a within-component reference or a system-level reference
    if (parent) {
      // Check if parent matches component-specific pattern
      const isComponentSpecificParent = parent.includes(`.${req.component}.`);
      
      // If it's component-specific, parent must exist and be in same component
      // If it's system-level, it must exist in the system requirements
      const expectParentToExist = isComponentSpecificParent || parent.startsWith('System.');
      
      if (expectParentToExist && !allRequirements.has(parent)) {
        console.error(`❌ Error: Requirement ${id} references non-existent parent ${parent}`);
        hierarchyErrors++;
      }
    }
  });

  if (hierarchyErrors === 0) {
    console.log('✅ All requirement parent references are valid\n');
  } else {
    console.error(`❌ Found ${hierarchyErrors} invalid parent references\n`);
    totalErrors += hierarchyErrors;
  }

  // VALIDATION 2: Check for component prefix consistency
  console.log('🔍 VALIDATING COMPONENT ID PREFIXES:');
  let prefixErrors = 0;

  componentRequirements.forEach((reqs, componentName) => {
    if (componentName === 'System') {
      return; // Skip system component
    }
    
    reqs.forEach((req, id) => {
      // Check that component-specific IDs properly contain the component name
      // Example: System.1.1.iOS.1 should be in the iOS component
      if (id.includes(`.${componentName}.`) && req.component !== componentName) {
        console.error(`❌ Error: ID ${id} contains component ${componentName} but is assigned to ${req.component}`);
        prefixErrors++;
      }
    });
  });

  if (prefixErrors === 0) {
    console.log('✅ All component requirement IDs have consistent prefixes\n');
  } else {
    console.error(`❌ Found ${prefixErrors} inconsistent component prefixes\n`);
    totalErrors += prefixErrors;
  }

  // VALIDATION 3: Check test mappings against requirements
  console.log('🔍 VALIDATING TEST MAPPINGS:');
  let testMapErrors = 0;

  testMappings.forEach(mapping => {
    if (!mapping.verifies) {
      console.warn(`⚠️ Warning: Test ${mapping.name} doesn't verify any requirement`);
      return;
    }
    
    if (!allRequirements.has(mapping.verifies)) {
      console.error(`❌ Error: Test ${mapping.name} verifies non-existent requirement ${mapping.verifies}`);
      testMapErrors++;
    }
  });

  if (testMapErrors === 0) {
    console.log('✅ All test mappings reference valid requirements\n');
  } else {
    console.error(`❌ Found ${testMapErrors} invalid test mappings\n`);
    totalErrors += testMapErrors;
  }

  // VALIDATION 4: Check ID format consistency
  console.log('🔍 VALIDATING ID FORMAT CONSISTENCY:');
  let formatErrors = 0;

  const systemFormat = /^System\.\d+(\.\d+)*(\.[A-Za-z]+\.\d+(\.\d+)*)?$/;
  allRequirements.forEach((req, id) => {
    if (!systemFormat.test(id)) {
      console.error(`❌ Error: Requirement ID ${id} doesn't follow the System.X.Y.Component.Z format`);
      formatErrors++;
    }
  });

  if (formatErrors === 0) {
    console.log('✅ All requirement IDs follow the correct format\n');
  } else {
    console.error(`❌ Found ${formatErrors} incorrectly formatted IDs\n`);
    totalErrors += formatErrors;
  }

  // Final Summary
  console.log('==== EARLY VALIDATION SUMMARY ====');
  console.log(`Total Requirements: ${allRequirements.size}`);
  console.log(`Total Test Mappings: ${testMappings.length}`);
  console.log(`Total Components: ${componentRequirements.size}`);
  console.log(`Total Errors: ${totalErrors}`);

  if (totalErrors > 0) {
    console.error('❌ VALIDATION FAILED: Please fix the errors above before proceeding.');
    process.exit(1);
  } else {
    console.log('✅ VALIDATION SUCCESSFUL: All requirements and test mappings are valid.');
    process.exit(0);
  }
}

/**
 * Run validations for test results mode
 */
function runTestResultsValidation(allRequirements, testResultsDir) {
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
        
        if (!allRequirements.has(reqId)) {
          console.error(`Error: Test case references '${reqId}' which doesn't exist in requirements`);
          errors++;
        } else {
          const req = allRequirements.get(reqId);
          console.log(`✅ Valid reference: ${reqId} (from ${req.component || 'unknown'})`);
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
}

/**
 * Find all JSON-LD test result files in the given directory
 */
function findTestResultFiles(directory) {
  const results = [];
  
  try {
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
  } catch (error) {
    console.error(`Error reading directory ${directory}: ${error.message}`);
  }
  
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