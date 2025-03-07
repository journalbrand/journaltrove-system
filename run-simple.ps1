# Simple script to run the orchestrator

$RepoName = "journalbrand/journaltrove-system"
$WorkflowName = "orchestrator.yml"

Write-Host "Starting workflow..."
gh workflow run $WorkflowName --repo $RepoName --ref main

Start-Sleep -Seconds 5

$RunID = gh run list --repo $RepoName --workflow=$WorkflowName --limit=1 --json databaseId --jq ".[0].databaseId"

Write-Host "Workflow started with ID: $RunID"
Write-Host "View at: https://github.com/$RepoName/actions/runs/$RunID"
