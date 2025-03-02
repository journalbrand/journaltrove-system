#!/usr/bin/env node

/**
 * JSON-LD Schema Validation Script
 * 
 * This script validates JSON-LD documents against JSON Schema.
 * It handles JSON-LD specific features like @context resolution.
 * 
 * Usage: node validate-jsonld.js <schema-path> <jsonld-path>
 */

const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

// Check arguments
const args = process.argv.slice(2);
if (args.length < 2) {
  console.error('Usage: node validate-jsonld.js <schema-path> <jsonld-path>');
  process.exit(1);
}

const schemaPath = args[0];
const jsonldPath = args[1];

async function validateJsonLd() {
  try {
    // Read the schema
    if (!fs.existsSync(schemaPath)) {
      console.error(`Error: Schema file not found at ${schemaPath}`);
      process.exit(1);
    }
    
    const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    console.log(`✓ Loaded schema from ${schemaPath}`);
    
    // Read the JSON-LD file
    if (!fs.existsSync(jsonldPath)) {
      console.error(`Error: JSON-LD file not found at ${jsonldPath}`);
      process.exit(1);
    }
    
    const jsonldStr = fs.readFileSync(jsonldPath, 'utf8');
    let jsonldDoc;
    
    try {
      jsonldDoc = JSON.parse(jsonldStr);
      console.log(`✓ Loaded JSON-LD from ${jsonldPath}`);
    } catch (parseError) {
      console.error('Error: Invalid JSON syntax');
      console.error(parseError.message);
      process.exit(1);
    }
    
    // Handle @context resolution if it's a reference to another file
    if (typeof jsonldDoc['@context'] === 'string' && jsonldDoc['@context'].startsWith('./')) {
      const contextPath = path.join(path.dirname(jsonldPath), jsonldDoc['@context']);
      
      if (fs.existsSync(contextPath)) {
        try {
          const contextDoc = JSON.parse(fs.readFileSync(contextPath, 'utf8'));
          console.log(`✓ Loaded context from ${contextPath}`);
          
          // Create a copy with the expanded context
          const expandedDoc = JSON.parse(JSON.stringify(jsonldDoc));
          expandedDoc['@context'] = contextDoc['@context'];
          jsonldDoc = expandedDoc;
          
          console.log('✓ Expanded @context references');
        } catch (contextError) {
          console.error(`Error: Failed to process context file at ${contextPath}`);
          console.error(contextError.message);
          // Continue with validation anyway
        }
      } else {
        console.warn(`Warning: Referenced context file not found at ${contextPath}`);
        // Continue with validation anyway
      }
    }
    
    // Configure AJV with formats
    const ajv = new Ajv({ 
      allErrors: true,
      verbose: true,
      strict: false // Allow JSON-LD keywords starting with @
    });
    
    addFormats(ajv);
    
    // Custom format for date-time validation
    ajv.addFormat('date-time', {
      validate: (dateTimeString) => {
        try {
          const date = new Date(dateTimeString);
          return !isNaN(date.getTime());
        } catch (e) {
          return false;
        }
      }
    });
    
    // Run validation
    const validate = ajv.compile(schema);
    const valid = validate(jsonldDoc);
    
    if (valid) {
      console.log('✅ Validation successful! Document conforms to schema.');
      process.exit(0);
    } else {
      console.error('❌ Validation failed with the following errors:');
      
      if (validate.errors) {
        validate.errors.forEach((error, index) => {
          console.error(`\nError ${index + 1}:`);
          console.error(`  Path: ${error.instancePath || 'document root'}`);
          console.error(`  Issue: ${error.message}`);
          
          if (error.params) {
            if (error.params.missingProperty) {
              console.error(`  Missing required property: ${error.params.missingProperty}`);
            }
            if (error.params.additionalProperty) {
              console.error(`  Unknown additional property: ${error.params.additionalProperty}`);
            }
          }
          
          // Try to show the problematic value
          if (error.instancePath) {
            let instance = jsonldDoc;
            const parts = error.instancePath.split('/').filter(p => p);
            try {
              for (const part of parts) {
                instance = instance[part];
              }
              console.error(`  Value: ${JSON.stringify(instance)}`);
            } catch (e) {
              // Skip if we can't access the value
            }
          }
        });
      }
      
      process.exit(1);
    }
    
  } catch (error) {
    console.error('Unexpected error during validation:');
    console.error(error);
    process.exit(1);
  }
}

validateJsonLd().catch(error => {
  console.error('Unhandled promise rejection during validation:');
  console.error(error);
  process.exit(1);
}); 