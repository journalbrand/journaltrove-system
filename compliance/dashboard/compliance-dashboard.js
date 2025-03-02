/**
 * Todo App Requirements Dashboard (Simplified)
 * 
 * This script loads and renders the requirements from JSON-LD
 * It's intentionally lean until we have actual code implementation and test results
 */

// Fetch and display requirements data
async function loadRequirements() {
  try {
    const response = await fetch('../requirements/requirements.jsonld');
    const data = await response.json();
    renderRequirements(data);
  } catch (error) {
    document.getElementById('app').innerHTML = 
      `<p>Error loading requirements: ${error.message}</p>`;
  }
}

// Render requirements from JSON-LD data
function renderRequirements(data) {
  const app = document.getElementById('app');
  
  // Extract requirements
  const graph = data['@graph'] || [];
  const requirements = graph.filter(item => item.type === 'Requirement');
  
  // Create header
  const header = document.createElement('header');
  header.innerHTML = `
    <h1>Todo App Requirements</h1>
    <p>Current project state: Requirements definition phase</p>
  `;
  app.appendChild(header);
  
  // Create requirements list
  const reqList = document.createElement('div');
  reqList.className = 'requirements-list';
  
  requirements.forEach(requirement => {
    const reqItem = document.createElement('div');
    reqItem.className = 'requirement-item';
    reqItem.innerHTML = `
      <h3>${requirement.id}: ${requirement.title}</h3>
      <p>${requirement.description}</p>
      <p><strong>Priority:</strong> ${requirement.priority || 'Not specified'}</p>
    `;
    reqList.appendChild(reqItem);
  });
  
  app.appendChild(reqList);
  
  // Add note about future implementation
  const note = document.createElement('div');
  note.className = 'future-note';
  note.innerHTML = `
    <p>Note: Test results and compliance tracking will be added once we have actual code implementation.</p>
  `;
  app.appendChild(note);
}

// Load requirements when the page loads
document.addEventListener('DOMContentLoaded', loadRequirements);

// Add basic CSS for the dashboard
document.head.innerHTML += `
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
  header { margin-bottom: 2rem; }
  .requirements-list { display: grid; gap: 1rem; }
  .requirement-item { border: 1px solid #ddd; padding: 1rem; border-radius: 4px; }
  .future-note { margin-top: 2rem; padding: 1rem; background: #f8f9fa; border-radius: 4px; }
</style>
`; 