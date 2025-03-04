# PowerShell script to trigger the journaltrove App CI/CD Pipeline Orchestrator

# Configuration
$RepoName = "journalbrand/journaltrove-system"
$WorkflowName = "orchestrator.yml"

# Print banner
Write-Host "=========================================="
Write-Host "journaltrove App CI/CD Pipeline Orchestrator"
Write-Host "=========================================="

# Check if GitHub CLI is installed
try {
    $null = Get-Command gh -ErrorAction Stop
}
catch {
    Write-Host "Error: GitHub CLI is not installed"
    Write-Host "Please install it from https://cli.github.com/manual/installation"
    exit 1
}

# Check if logged in to GitHub
try {
    $null = gh auth status
    Write-Host "GitHub authentication confirmed."
}
catch {
    Write-Host "Error: Not logged in to GitHub"
    Write-Host "Please run 'gh auth login' first"
    exit 1
}

# Check if we have sufficient permissions
Write-Host "Checking permissions for $RepoName..."
try {
    $null = gh repo view $RepoName
}
catch {
    Write-Host "Error: Cannot access repository $RepoName"
    Write-Host "Please make sure you have access and are authenticated correctly"
    exit 1
}

# Trigger the workflow
Write-Host "Triggering CI/CD Pipeline Orchestrator workflow..."
gh workflow run $WorkflowName --repo $RepoName --ref main

# Wait for the workflow to start
Write-Host "Waiting for workflow to start running..."
Start-Sleep -Seconds 5

# Get the ID of the most recent workflow run
$RunID = gh run list --repo $RepoName --workflow=$WorkflowName --limit=1 --json databaseId --jq ".[0].databaseId"

Write-Host "Workflow started with run ID: $RunID"
Write-Host "View progress at: https://github.com/$RepoName/actions/runs/$RunID"

# Automatically monitor the workflow status
Write-Host "Monitoring workflow status automatically..."

while ($true) {
    $Status = gh run view $RunID --repo $RepoName --json status --jq ".status"
    
    if ($Status -eq "completed") {
        $Conclusion = gh run view $RunID --repo $RepoName --json conclusion --jq ".conclusion"
        Write-Host "Workflow completed with status: $Conclusion"
        
        if ($Conclusion -eq "success") {
            Write-Host "CI/CD pipeline completed successfully!"
        }
        else {
            Write-Host "CI/CD pipeline failed. Check logs for details."
        }
        
        Write-Host "View details at: https://github.com/$RepoName/actions/runs/$RunID"
        break
    }
    
    # Show current progress
    Write-Host "Workflow is still running (status: $Status)..."
    Start-Sleep -Seconds 30
} 