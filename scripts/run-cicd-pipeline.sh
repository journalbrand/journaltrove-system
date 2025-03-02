#!/bin/bash
# Script to trigger the journaltrove App CI/CD Pipeline Orchestrator

set -e

# Configuration
REPO_NAME="journalbrand/journaltrove-system"
WORKFLOW_NAME="orchestrator.yml"

# Print banner
echo "==============================================="
echo "🚀 journaltrove App CI/CD Pipeline Orchestrator Runner"
echo "==============================================="

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI is not installed"
    echo "Please install it from https://cli.github.com/manual/installation"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not logged in to GitHub"
    echo "Please run 'gh auth login' first"
    exit 1
fi

# Check if we have sufficient permissions
echo "Checking permissions for $REPO_NAME..."
if ! gh repo view "$REPO_NAME" &> /dev/null; then
    echo "❌ Error: Cannot access repository $REPO_NAME"
    echo "Please make sure you have access and are authenticated correctly"
    exit 1
fi

# Trigger the workflow
echo "🚀 Triggering CI/CD Pipeline Orchestrator workflow..."
gh workflow run "$WORKFLOW_NAME" --repo "$REPO_NAME" --ref main

# Wait for the workflow to start
echo "⏱ Waiting for workflow to start running..."
sleep 5

# Get the ID of the most recent workflow run
RUN_ID=$(gh run list --repo "$REPO_NAME" --workflow="$WORKFLOW_NAME" --limit=1 --json databaseId --jq '.[0].databaseId')

echo "✅ Workflow started with run ID: $RUN_ID"
echo "View progress at: https://github.com/$REPO_NAME/actions/runs/$RUN_ID"

# Ask if user wants to monitor the status
read -p "Would you like to monitor the workflow status? (y/n): " MONITOR

if [[ "$MONITOR" == "y" || "$MONITOR" == "Y" ]]; then
    echo "📊 Monitoring workflow status..."
    
    while true; do
        STATUS=$(gh run view "$RUN_ID" --repo "$REPO_NAME" --json status --jq '.status')
        
        if [[ "$STATUS" == "completed" ]]; then
            CONCLUSION=$(gh run view "$RUN_ID" --repo "$REPO_NAME" --json conclusion --jq '.conclusion')
            echo "✅ Workflow completed with status: $CONCLUSION"
            
            if [[ "$CONCLUSION" == "success" ]]; then
                echo "🎉 CI/CD pipeline completed successfully!"
            else
                echo "❌ CI/CD pipeline failed. Check logs for details."
            fi
            
            echo "View details at: https://github.com/$REPO_NAME/actions/runs/$RUN_ID"
            break
        fi
        
        # Show current progress
        echo "⏳ Workflow is still running (status: $STATUS)..."
        sleep 30
    done
else
    echo "📝 You can check the status later at: https://github.com/$REPO_NAME/actions/runs/$RUN_ID"
fi

echo "Done!" 