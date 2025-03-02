#!/bin/bash

# Navigate to the todo-system directory
cd "$(dirname "$0")"

# Define server port
PORT=8000

echo "🔍 Checking for GitHub CLI..."
if ! command -v gh &> /dev/null; then
    echo "⚠️ GitHub CLI not found. Please install it to download the latest compliance matrix."
    echo "Visit: https://cli.github.com/"
    echo "Continuing with existing files (if any)..."
else
    echo "✅ GitHub CLI found. Downloading latest compliance matrix..."
    
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
        gh run download $WORKFLOW_RUN_ID --name=compliance-matrix-jsonld --dir="$TEMP_DIR"
        
        if [ -f "$TEMP_DIR/compliance_matrix.jsonld" ]; then
            # Copy to both locations where it might be expected
            cp "$TEMP_DIR/compliance_matrix.jsonld" compliance/dashboard/compliance_matrix.jsonld
            cp "$TEMP_DIR/compliance_matrix.jsonld" compliance/reports/compliance_matrix.jsonld
            echo "✅ Compliance matrix downloaded and installed successfully!"
            
            # Clean up temp directory
            rm -rf "$TEMP_DIR"
        else
            echo "⚠️ Could not find compliance_matrix.jsonld in the downloaded artifact!"
            # List the contents of the temp dir to debug
            echo "Contents of downloaded artifact:"
            ls -la "$TEMP_DIR"
            
            # Check if it's in a subdirectory
            if [ -d "$TEMP_DIR/compliance-matrix-jsonld" ]; then
                echo "Found subdirectory, copying files..."
                cp "$TEMP_DIR/compliance-matrix-jsonld/compliance_matrix.jsonld" compliance/dashboard/compliance_matrix.jsonld
                cp "$TEMP_DIR/compliance-matrix-jsonld/compliance_matrix.jsonld" compliance/reports/compliance_matrix.jsonld
                echo "✅ Compliance matrix installed from subdirectory!"
            fi
            
            # Clean up temp directory
            rm -rf "$TEMP_DIR"
        fi
    else
        echo "⚠️ No completed workflow runs found."
    fi
fi

# Ensure the requirements file is accessible to the dashboard
echo "🔄 Setting up requirements file for dashboard..."
if [ -f "requirements/requirements.jsonld" ]; then
    # Create a symbolic link to the requirements file in the dashboard directory
    mkdir -p compliance/requirements/
    cp requirements/requirements.jsonld compliance/requirements/
    echo "✅ Requirements file linked for dashboard access"
else
    echo "⚠️ Requirements file not found at requirements/requirements.jsonld"
fi

echo "🌐 Starting Compliance Dashboard server on http://localhost:$PORT"
echo "📊 Dashboard will be available at: http://localhost:$PORT/compliance/dashboard/"
echo "⚠️ Press Ctrl+C to stop the server"

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