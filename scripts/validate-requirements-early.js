#!/usr/bin/env node

/**
 * Early Requirements Validation Script
 * 
 * This script validates requirements across repositories before tests run:
 * 1. Validates parent-child relationships (parents must exist)
 * 2. Validates test mappings against actual requirements
 * 3. Ensures consistent ID formatting across components
 * 
 * Usage: node validate-requirements-early.js <system-reqs-file> <component1-reqs-file> [component2-reqs-file...]
 */

const fs = require('fs');
const path = require('path');

// Check arguments
if (process.argv.length < 3) {
  console.error('Usage: node validate-requirements-early.js <system-reqs-file> [component-reqs-files...]');
  process.exit(1);
}

// Load all requirements files
const reqFiles = process.argv.slice(2);
console.log(`Validating ${reqFiles.length} requirements files\n`);

// Store all requirements by ID
const allRequirements = new Map();
const componentRequirements = new Map(); // Organize by component
const testMappings = []; // Store test-to-requirement mappings

// Load all requirements from all files
reqFiles.forEach(filePath => {
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
      
      // Store test mappings (from test mapping files)
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

console.log(`Found ${allRequirements.size} total requirements across all components`);
console.log(`Found ${testMappings.length} test mappings\n`);

// VALIDATION 1: Check parent-child relationships
console.log('🔍 VALIDATING REQUIREMENT HIERARCHY:');
let hierarchyErrors = 0;

allRequirements.forEach((req, id) => {
  const parent = req.parent;
  if (parent && !allRequirements.has(parent)) {
    console.error(`❌ Error: Requirement ${id} references non-existent parent ${parent}`);
    hierarchyErrors++;
  }
});

if (hierarchyErrors === 0) {
  console.log('✅ All requirement parent references are valid\n');
} else {
  console.error(`❌ Found ${hierarchyErrors} invalid parent references\n`);
}

// VALIDATION 2: Check for component prefix consistency
console.log('🔍 VALIDATING COMPONENT ID PREFIXES:');
let prefixErrors = 0;

componentRequirements.forEach((reqs, componentName) => {
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
}

// Final Summary
const totalErrors = hierarchyErrors + prefixErrors + testMapErrors + formatErrors;
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