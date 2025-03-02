const fs = require('fs');
const path = require('path');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const jsonld = require('jsonld');

async function validateJsonLd() {
  try {
    // Read the schema
    const schemaPath = path.join(__dirname, 'schema', 'requirements-schema.json');
    const schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    
    // Read the JSON-LD file
    const jsonldPath = path.join(__dirname, 'requirements', 'requirements.jsonld');
    const jsonldStr = fs.readFileSync(jsonldPath, 'utf8');
    const jsonldDoc = JSON.parse(jsonldStr);
    
    console.log('1. Successfully loaded JSON-LD and schema files');
    
    // Create Ajv instance and add formats
    const ajv = new Ajv({ allErrors: true });
    addFormats(ajv);
    
    console.log('2. Configured AJV with formats');
    
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
    
    console.log('3. Added custom date-time format');
    
    // Try validating against the schema directly first
    const validate = ajv.compile(schema);
    const validDirect = validate(jsonldDoc);
    
    if (validDirect) {
      console.log('Direct validation successful!');
    } else {
      console.log('Direct validation failed with errors:');
      console.log(validate.errors);
      
      // Let's try to diagnose specific issues
      for (const error of validate.errors) {
        console.log(`- Error at ${error.instancePath}: ${error.message}`);
        if (error.instancePath === '') {
          // Check if it's an issue with the root properties
          const missingProps = error.params.missingProperty ? [error.params.missingProperty] : [];
          if (missingProps.length > 0) {
            console.log(`  Missing required properties: ${missingProps.join(', ')}`);
          }
        }
      }
    }
    
    // Now let's try to process the JSON-LD document
    try {
      console.log('\nAttempting to process the JSON-LD document...');
      // Create a local copy of the context to resolve relative references
      const contextPath = path.join(__dirname, 'requirements', 'context', 'requirements-context.jsonld');
      const contextDoc = JSON.parse(fs.readFileSync(contextPath, 'utf8'));
      
      // Replace the relative context reference with the actual context
      const expandedDoc = JSON.parse(JSON.stringify(jsonldDoc));
      expandedDoc['@context'] = contextDoc['@context'];
      
      console.log('4. Successfully replaced relative context with actual context');
      
      // Try validating the expanded document
      const validExpanded = validate(expandedDoc);
      
      if (validExpanded) {
        console.log('Validation with expanded context successful!');
      } else {
        console.log('Validation with expanded context failed with errors:');
        console.log(validate.errors);
      }
      
      // Now try to process with jsonld library
      const expanded = await jsonld.expand(expandedDoc);
      console.log('\n5. Successfully expanded the JSON-LD document');
      
      // Compact it back with the context
      const compacted = await jsonld.compact(expanded, contextDoc['@context']);
      console.log('6. Successfully compacted the JSON-LD document');
      
      // Try validating the processed document
      const validProcessed = validate(compacted);
      
      if (validProcessed) {
        console.log('Validation after JSON-LD processing successful!');
      } else {
        console.log('Validation after JSON-LD processing failed with errors:');
        console.log(validate.errors);
      }
      
    } catch (ldError) {
      console.log('Error processing JSON-LD document:', ldError);
    }
    
  } catch (error) {
    console.error('Error:', error);
  }
}

validateJsonLd().catch(console.error); 