// === WATCHER HEADER START ===
// File: todo-system/compliance/dashboard/compliance-dashboard.js
// Managed by file watcher
// === WATCHER HEADER END ===
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

// No longer need to add styles here since they're all in theme.css 
