const fs = require('fs');
const path = require('path');

// Read the JSON-LD files
const requirementsPath = path.join(__dirname, 'requirements', 'requirements.jsonld');
const contextPath = path.join(__dirname, 'requirements', 'context', 'requirements-context.jsonld');

try {
  // Parse the JSON-LD files
  const requirements = JSON.parse(fs.readFileSync(requirementsPath, 'utf8'));
  const context = JSON.parse(fs.readFileSync(contextPath, 'utf8'));
  
  // Replace the relative context with the actual context
  requirements['@context'] = context['@context'];
  
  // Write the preprocessed file for AJV CLI
  const outputPath = path.join(__dirname, 'requirements-processed.jsonld');
  fs.writeFileSync(outputPath, JSON.stringify(requirements, null, 2));
  
  console.log(`Successfully created preprocessed file at ${outputPath}`);
} catch (error) {
  console.error('Error:', error);
} 