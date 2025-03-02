/**
 * Todo App Compliance Dashboard
 * 
 * This script loads and renders the compliance matrix from JSON-LD
 * providing a clear visualization of requirements, test coverage, and results
 */

// Configuration
const CONFIG = {
  complianceMatrixPath: './compliance_matrix.jsonld',
  requirementsPath: '../requirements/requirements.jsonld',
  refreshInterval: 60000 // Auto-refresh every minute
};

// Main function to load data and initialize dashboard
async function initDashboard() {
  try {
    // Load both the compliance matrix and requirements data
    const [complianceData, requirementsData] = await Promise.all([
      fetchJSON(CONFIG.complianceMatrixPath),
      fetchJSON(CONFIG.requirementsPath)
    ]);
    
    renderDashboard(complianceData, requirementsData);
    
    // Set up auto-refresh
    setInterval(() => {
      fetchJSON(CONFIG.complianceMatrixPath)
        .then(updatedData => renderDashboard(updatedData, requirementsData))
        .catch(error => console.error('Auto-refresh error:', error));
    }, CONFIG.refreshInterval);
  } catch (error) {
    renderError('Error initializing dashboard', error);
  }
}

// Fetch JSON data from a URL
async function fetchJSON(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    throw new Error(`Failed to load data from ${url}: ${error.message}`);
  }
}

// Render the main dashboard
function renderDashboard(complianceData, requirementsData) {
  const app = document.getElementById('app');
  
  // Clear previous content
  app.innerHTML = '';
  
  // Add header
  const header = document.createElement('header');
  header.innerHTML = `
    <h1>Todo App Compliance Dashboard</h1>
    <p class="updated">Last updated: ${new Date().toLocaleString()}</p>
  `;
  app.appendChild(header);
  
  // Extract data
  const matrix = complianceData['@graph'].find(item => item['@type'] === 'ComplianceMatrix');
  const requirements = requirementsData['@graph'].filter(item => item.type === 'Requirement');
  
  // Add statistics summary
  renderStatistics(app, matrix);
  
  // Render requirements and test cases
  renderRequirementsMatrix(app, requirements, matrix);
  
  // Add component test summary
  renderComponentSummary(app, matrix);
}

// Render statistics cards
function renderStatistics(container, matrix) {
  const stats = matrix.statistics || {
    totalRequirements: 0,
    totalTests: 0,
    passingTests: 0,
    failingTests: 0,
    components: 0
  };
  
  const statsContainer = document.createElement('div');
  statsContainer.className = 'statistics';
  
  // Calculate pass percentage
  const passPercentage = stats.totalTests > 0
    ? Math.round((stats.passingTests / stats.totalTests) * 100)
    : 0;
  
  statsContainer.innerHTML = `
    <div class="stat-card">
      <h3>Requirements</h3>
      <div class="value">${stats.totalRequirements}</div>
    </div>
    <div class="stat-card">
      <h3>Test Cases</h3>
      <div class="value">${stats.totalTests}</div>
    </div>
    <div class="stat-card">
      <h3>Pass Rate</h3>
      <div class="value ${passPercentage === 100 ? 'passing' : 'warning'}">${passPercentage}%</div>
    </div>
    <div class="stat-card">
      <h3>Components</h3>
      <div class="value">${stats.components}</div>
    </div>
    <div class="stat-card wide">
      <h3>Status</h3>
      <div class="value ${stats.failingTests === 0 ? 'passing' : 'failing'}">
        ${stats.failingTests === 0 ? '✓ All Tests Passing' : `⚠ ${stats.failingTests} Failing Tests`}
      </div>
    </div>
  `;
  
  container.appendChild(statsContainer);
}

// Render the requirements matrix with test coverage
function renderRequirementsMatrix(container, requirements, matrix) {
  const matrixContainer = document.createElement('div');
  matrixContainer.className = 'requirements-matrix';
  
  const testCases = matrix.testCases || [];
  
  // Group test cases by requirement
  const testsByRequirement = testCases.reduce((acc, test) => {
    if (!acc[test.verifies]) {
      acc[test.verifies] = [];
    }
    acc[test.verifies].push(test);
    return acc;
  }, {});
  
  // Create header
  matrixContainer.innerHTML = `
    <h2>Requirements Traceability Matrix</h2>
  `;
  
  // Create requirements table
  const table = document.createElement('table');
  table.className = 'matrix-table';
  
  // Table header
  table.innerHTML = `
    <thead>
      <tr>
        <th>Requirement ID</th>
        <th>Description</th>
        <th>Test Coverage</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody></tbody>
  `;
  
  const tbody = table.querySelector('tbody');
  
  // Add rows for each requirement
  requirements.forEach(req => {
    const reqTests = testsByRequirement[req.id] || [];
    const isVerified = reqTests.length > 0;
    const allPassing = reqTests.every(test => test.result === 'Pass');
    
    const row = document.createElement('tr');
    row.className = isVerified ? (allPassing ? 'passing' : 'failing') : 'no-coverage';
    
    row.innerHTML = `
      <td>${req.id}</td>
      <td>${req.title || req.description || 'No description'}</td>
      <td>${isVerified ? `${reqTests.length} tests` : 'No tests'}</td>
      <td>
        <span class="status-dot ${isVerified ? (allPassing ? 'passing' : 'failing') : 'no-coverage'}"></span>
        ${isVerified ? (allPassing ? 'Passing' : 'Failing') : 'No Coverage'}
      </td>
    `;
    
    tbody.appendChild(row);
    
    // Add test details if there are tests
    if (reqTests.length > 0) {
      const testRow = document.createElement('tr');
      testRow.className = 'test-details';
      
      const testDetails = reqTests.map(test => `
        <div class="test-case ${test.result === 'Pass' ? 'passing' : 'failing'}">
          <span class="test-name">${test.name}</span>
          <span class="component-badge">${test.component}</span>
          <span class="status-badge ${test.result === 'Pass' ? 'passing' : 'failing'}">${test.result}</span>
        </div>
      `).join('');
      
      testRow.innerHTML = `
        <td colspan="4">
          <div class="test-list">
            ${testDetails}
          </div>
        </td>
      `;
      
      tbody.appendChild(testRow);
    }
  });
  
  matrixContainer.appendChild(table);
  container.appendChild(matrixContainer);
}

// Render component test summary
function renderComponentSummary(container, matrix) {
  const components = matrix.components || [];
  const testCases = matrix.testCases || [];
  
  if (components.length === 0) {
    return;
  }
  
  const summaryContainer = document.createElement('div');
  summaryContainer.className = 'component-summary';
  
  summaryContainer.innerHTML = `
    <h2>Component Test Summary</h2>
  `;
  
  // Group test cases by component
  const testsByComponent = testCases.reduce((acc, test) => {
    if (!acc[test.component]) {
      acc[test.component] = {
        total: 0,
        passing: 0,
        failing: 0
      };
    }
    
    acc[test.component].total++;
    if (test.result === 'Pass') {
      acc[test.component].passing++;
    } else {
      acc[test.component].failing++;
    }
    
    return acc;
  }, {});
  
  // Create component cards
  const cardsContainer = document.createElement('div');
  cardsContainer.className = 'component-cards';
  
  components.forEach(component => {
    const stats = testsByComponent[component] || { total: 0, passing: 0, failing: 0 };
    const passPercentage = stats.total > 0
      ? Math.round((stats.passing / stats.total) * 100)
      : 0;
    
    const card = document.createElement('div');
    card.className = `component-card ${stats.failing === 0 ? 'passing' : 'failing'}`;
    
    card.innerHTML = `
      <h3>${component}</h3>
      <div class="component-stats">
        <div class="stat">
          <div class="value">${stats.total}</div>
          <div class="label">Tests</div>
        </div>
        <div class="stat">
          <div class="value ${stats.failing === 0 ? 'passing' : 'failing'}">${passPercentage}%</div>
          <div class="label">Pass Rate</div>
        </div>
      </div>
      <div class="status-bar">
        <div class="bar-passing" style="width: ${passPercentage}%"></div>
        <div class="bar-failing" style="width: ${100 - passPercentage}%"></div>
      </div>
    `;
    
    cardsContainer.appendChild(card);
  });
  
  summaryContainer.appendChild(cardsContainer);
  container.appendChild(summaryContainer);
}

// Render error message
function renderError(message, error) {
  const app = document.getElementById('app');
  app.innerHTML = `
    <div class="error-message">
      <h2>${message}</h2>
      <p>${error.message}</p>
      <button onclick="initDashboard()">Retry</button>
    </div>
  `;
  console.error(error);
}

// Initialize dashboard when the page loads
document.addEventListener('DOMContentLoaded', initDashboard);

// Add dashboard styles
document.head.innerHTML += `
<style>
  :root {
    --primary-color: #0366d6;
    --success-color: #28a745;
    --warning-color: #f9a825;
    --danger-color: #d73a49;
    --light-gray: #f6f8fa;
    --border-color: #e1e4e8;
  }

  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
    line-height: 1.6;
    color: #24292e;
    margin: 0;
    padding: 0;
    background-color: #fff;
  }

  #app {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
  }

  header {
    margin-bottom: 2rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 1rem;
  }

  header h1 {
    margin-bottom: 0.25rem;
  }

  .updated {
    color: #6a737d;
    font-size: 0.9rem;
    margin: 0;
  }

  h2 {
    margin-top: 2rem;
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--border-color);
  }

  /* Statistics Cards */
  .statistics {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .stat-card {
    border: 1px solid var(--border-color);
    border-radius: 6px;
    padding: 1rem;
    text-align: center;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }

  .stat-card.wide {
    grid-column: 1 / -1;
  }

  .stat-card h3 {
    margin: 0;
    font-size: 0.9rem;
    font-weight: 600;
    color: #6a737d;
    text-transform: uppercase;
  }

  .stat-card .value {
    font-size: 2rem;
    font-weight: 600;
    margin: 0.75rem 0;
  }

  .value.passing {
    color: var(--success-color);
  }

  .value.warning {
    color: var(--warning-color);
  }

  .value.failing {
    color: var(--danger-color);
  }

  /* Requirements Matrix Table */
  .matrix-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 1rem;
    font-size: 0.9rem;
  }

  .matrix-table th,
  .matrix-table td {
    padding: 0.75rem;
    border: 1px solid var(--border-color);
  }

  .matrix-table th {
    background-color: var(--light-gray);
    text-align: left;
    font-weight: 600;
  }

  .matrix-table tr.passing {
    background-color: rgba(40, 167, 69, 0.05);
  }

  .matrix-table tr.failing {
    background-color: rgba(215, 58, 73, 0.05);
  }

  .matrix-table tr.no-coverage {
    background-color: rgba(249, 168, 37, 0.05);
  }

  .status-dot {
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 6px;
  }

  .status-dot.passing {
    background-color: var(--success-color);
  }

  .status-dot.failing {
    background-color: var(--danger-color);
  }

  .status-dot.no-coverage {
    background-color: var(--warning-color);
  }

  /* Test details */
  .test-details td {
    padding: 0;
  }

  .test-list {
    padding: 0.5rem;
    background-color: var(--light-gray);
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .test-case {
    border-radius: 4px;
    padding: 0.5rem;
    font-size: 0.85rem;
    display: flex;
    align-items: center;
    background: white;
    border: 1px solid var(--border-color);
  }

  .test-case.passing {
    border-left: 4px solid var(--success-color);
  }

  .test-case.failing {
    border-left: 4px solid var(--danger-color);
  }

  .test-name {
    font-weight: 600;
    margin-right: 0.5rem;
  }

  .component-badge {
    background-color: var(--light-gray);
    border-radius: 12px;
    padding: 0.15rem 0.5rem;
    font-size: 0.75rem;
    margin-right: 0.5rem;
  }

  .status-badge {
    border-radius: 12px;
    padding: 0.15rem 0.5rem;
    font-size: 0.75rem;
    font-weight: 600;
  }

  .status-badge.passing {
    background-color: rgba(40, 167, 69, 0.15);
    color: var(--success-color);
  }

  .status-badge.failing {
    background-color: rgba(215, 58, 73, 0.15);
    color: var(--danger-color);
  }

  /* Component summary */
  .component-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
  }

  .component-card {
    border: 1px solid var(--border-color);
    border-radius: 6px;
    padding: 1.25rem;
    background: white;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }

  .component-card.passing {
    border-top: 4px solid var(--success-color);
  }

  .component-card.failing {
    border-top: 4px solid var(--danger-color);
  }

  .component-card h3 {
    margin-top: 0;
    margin-bottom: 1rem;
    font-size: 1.1rem;
  }

  .component-stats {
    display: flex;
    justify-content: space-between;
    margin-bottom: 1rem;
  }

  .stat .value {
    font-size: 1.5rem;
    font-weight: 600;
    margin-bottom: 0.25rem;
  }

  .stat .label {
    font-size: 0.8rem;
    color: #6a737d;
  }

  .status-bar {
    height: 6px;
    border-radius: 3px;
    overflow: hidden;
    background-color: #eee;
    display: flex;
  }

  .bar-passing {
    height: 100%;
    background-color: var(--success-color);
  }

  .bar-failing {
    height: 100%;
    background-color: var(--danger-color);
  }

  /* Error message */
  .error-message {
    text-align: center;
    padding: 2rem;
    background-color: #f6f8fa;
    border-radius: 6px;
    margin: 2rem auto;
    max-width: 500px;
  }

  .error-message button {
    background-color: var(--primary-color);
    color: white;
    border: none;
    padding: 0.5rem 1.5rem;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
    margin-top: 1rem;
  }

  .error-message button:hover {
    background-color: #0051b3;
  }
</style>
`; 