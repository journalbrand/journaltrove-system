#!/bin/bash

# Navigate to the todo-system directory
cd "$(dirname "$0")"

# Define server port
PORT=8000

# Function to download the latest compliance matrix
download_compliance_matrix() {
    echo "🔄 $(date +"%H:%M:%S") - Refreshing compliance matrix data..."
    
    if ! command -v gh &> /dev/null; then
        echo "⚠️ GitHub CLI not found. Cannot refresh data."
        return 1
    fi
    
    # Create necessary directories
    mkdir -p compliance/dashboard
    mkdir -p compliance/reports
    
    # Download the latest compliance matrix artifact from the most recent successful workflow run
    WORKFLOW_RUN_ID=$(gh run list --workflow=compliance-matrix.yml --status=completed --limit=1 --json databaseId --jq '.[0].databaseId')
    
    if [ -n "$WORKFLOW_RUN_ID" ]; then
        echo "📥 Downloading artifacts from workflow run $WORKFLOW_RUN_ID..."
        
        # Create a temporary directory for downloading
        TEMP_DIR=$(mktemp -d)
        
        # Download the artifact
        gh run download $WORKFLOW_RUN_ID --name=compliance-matrix-jsonld --dir="$TEMP_DIR" > /dev/null 2>&1
        
        if [ -f "$TEMP_DIR/compliance_matrix.jsonld" ]; then
            # Copy to both locations where it might be expected
            cp "$TEMP_DIR/compliance_matrix.jsonld" compliance/dashboard/compliance_matrix.jsonld
            cp "$TEMP_DIR/compliance_matrix.jsonld" compliance/reports/compliance_matrix.jsonld
            echo "✅ Compliance matrix refreshed successfully!"
            
            # Clean up temporary directory
            rm -rf "$TEMP_DIR"
        else
            # Check if it's in a subdirectory
            if [ -d "$TEMP_DIR/compliance-matrix-jsonld" ]; then
                cp "$TEMP_DIR/compliance-matrix-jsonld/compliance_matrix.jsonld" compliance/dashboard/compliance_matrix.jsonld
                cp "$TEMP_DIR/compliance-matrix-jsonld/compliance_matrix.jsonld" compliance/reports/compliance_matrix.jsonld
                echo "✅ Compliance matrix refreshed successfully!"
            else
                echo "⚠️ Could not find compliance_matrix.jsonld in the downloaded artifact!"
            fi
            
            # Clean up temporary directory
            rm -rf "$TEMP_DIR"
        fi
    else
        echo "⚠️ No completed workflow runs found."
    fi
    
    # Ensure the requirements file is accessible to the dashboard
    if [ -f "requirements/requirements.jsonld" ]; then
        # Create a directory for requirements and copy the file
        mkdir -p compliance/requirements/
        cp requirements/requirements.jsonld compliance/requirements/
    fi
}

# Initial check for GitHub CLI
echo "🔍 Checking for GitHub CLI..."
if ! command -v gh &> /dev/null; then
    echo "⚠️ GitHub CLI not found. Please install it to download the latest compliance matrix."
    echo "Visit: https://cli.github.com/"
    echo "Continuing with existing files (if any)..."
else
    echo "✅ GitHub CLI found."
    # Initial download of compliance matrix
    download_compliance_matrix
fi

# Start the auto-refresh process in the background
auto_refresh_compliance_matrix() {
    while true; do
        sleep 60
        download_compliance_matrix
    done
}
auto_refresh_compliance_matrix &
REFRESH_PID=$!

# Trap to kill the background auto-refresh process when the script exits
trap 'echo "Shutting down auto-refresh process..."; kill $REFRESH_PID 2>/dev/null; exit' INT TERM EXIT

echo "⏱️ Auto-refresh is enabled - compliance matrix will update every 60 seconds"
echo "🌐 Starting Compliance Dashboard server on http://localhost:$PORT"
echo "📊 Dashboard will be available at: http://localhost:$PORT/compliance/dashboard/"
echo "⚠️ Press Ctrl+C to stop the server and auto-refresh"

# Open the dashboard in the default browser (after a short delay to let the server start)
(sleep 1 && open "http://localhost:$PORT/compliance/dashboard/") &

# Start a simple HTTP server with Python
# This works with both Python 2 and 3
if command -v python3 &>/dev/null; then
    python3 -m http.server $PORT
elif command -v python &>/dev/null; then
    # Check if it's Python 2 or 3
    if python -c 'import sys; exit(0 if sys.version_info.major == 3 else 1)' &>/dev/null; then
        python -m http.server $PORT
    else
        python -m SimpleHTTPServer $PORT
    fi
else
    echo "❌ Error: Python is not installed. Please install Python to run this server."
    exit 1
fi 