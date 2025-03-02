#!/bin/bash

# Define the output log file
LOGFILE="dashboard.log"

# Determine the base directory
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$BASE_DIR" || { echo "Error: Could not change to base directory"; exit 1; }

# Define server port
PORT=8000

# Define PID file for tracking auto-refresh background processes
PID_FILE=".dashboard_refresh.pid"

# Function to log messages to both console and log file
log() {
    echo "$@"
    echo "$(date "+%T") - $@" >> "$LOGFILE"
}

# Function to clean up all child processes on exit
cleanup() {
    log "Shutting down auto-refresh process..."
    if [[ -f "$PID_FILE" ]]; then
        # Kill the auto-refresh process if it exists
        if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            kill $(cat "$PID_FILE") 2>/dev/null
        fi
        rm -f "$PID_FILE"
    fi
    
    # Get all child processes and kill them
    pkill -P $$ 2>/dev/null
    
    # Exit the script
    exit 0
}

# Set up trap to catch termination signals
trap cleanup SIGINT SIGTERM EXIT

# Initialize log file with a header
echo "journaltrove App Dashboard Server - Started $(date)" > "$LOGFILE"

# Function to download compliance matrix from GitHub workflow
download_compliance_matrix() {
    log "🔍 Checking for GitHub CLI..."
    if ! command -v gh &>/dev/null; then
        log "❌ GitHub CLI not found. Cannot download compliance matrix artifact."
        log "Please install GitHub CLI or manually copy the compliance matrix to compliance/dashboard/compliance_matrix.jsonld"
        return 1
    fi
    
    log "✅ GitHub CLI found."
    log "🔄 Refreshing compliance matrix data..."
    
    # Create necessary directories
    mkdir -p "compliance/dashboard" "compliance/reports" "compliance/results"
    
    # Download test results from component workflows
    log "📥 Downloading test results from component workflows..."
    
    # Create directories for each component's test results
    mkdir -p "compliance/results/ios" "compliance/results/android" "compliance/results/ipfs"
    
    # Download iOS test results
    log "📱 iOS: Downloading test results from latest workflow run..."
    # Get the latest run ID for iOS workflow
    IOS_RUN_ID=$(gh run list --repo journalbrand/journaltrove-ios --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)
    if [[ -n "$IOS_RUN_ID" ]]; then
        log "📱 iOS: Downloading test results from run $IOS_RUN_ID..."
        gh run download $IOS_RUN_ID --repo journalbrand/journaltrove-ios --name ios-test-results-jsonld --dir compliance/results/ios 2>/dev/null
        
        # Check if the file exists directly or in a subdirectory
        if [[ -f "compliance/results/ios/test-results.jsonld" ]]; then
            log "✅ iOS test results downloaded."
        elif [[ -d "compliance/results/ios" ]]; then
            # Look for the file in any subdirectory
            FOUND_FILE=$(find "compliance/results/ios" -name "test-results.jsonld" -type f | head -n 1)
            if [[ -n "$FOUND_FILE" ]]; then
                # Move the file to the expected location
                cp "$FOUND_FILE" "compliance/results/ios/test-results.jsonld"
                log "✅ iOS test results downloaded."
            else
                log "⚠️ iOS test results not found in the downloaded artifact."
            fi
        else
            log "⚠️ iOS test results download failed."
        fi
    else
        log "⚠️ No iOS workflow runs found."
    fi
    
    # Download Android test results
    log "🤖 Android: Downloading test results from latest workflow run..."
    # Get the latest run ID for Android workflow
    ANDROID_RUN_ID=$(gh run list --repo journalbrand/journaltrove-android --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)
    if [[ -n "$ANDROID_RUN_ID" ]]; then
        log "🤖 Android: Downloading test results from run $ANDROID_RUN_ID..."
        gh run download $ANDROID_RUN_ID --repo journalbrand/journaltrove-android --name android-test-results-jsonld --dir compliance/results/android 2>/dev/null
        
        # Check if the file exists directly or in a subdirectory
        if [[ -f "compliance/results/android/test-results.jsonld" ]]; then
            log "✅ Android test results downloaded."
        elif [[ -d "compliance/results/android" ]]; then
            # Look for the file in any subdirectory
            FOUND_FILE=$(find "compliance/results/android" -name "test-results.jsonld" -type f | head -n 1)
            if [[ -n "$FOUND_FILE" ]]; then
                # Move the file to the expected location
                cp "$FOUND_FILE" "compliance/results/android/test-results.jsonld"
                log "✅ Android test results downloaded."
            else
                log "⚠️ Android test results not found in the downloaded artifact."
            fi
        else
            log "⚠️ Android test results download failed."
        fi
    else
        log "⚠️ No Android workflow runs found."
    fi
    
    # Download IPFS test results
    log "📦 IPFS: Downloading test results from latest workflow run..."
    # Get the latest run ID for IPFS workflow
    IPFS_RUN_ID=$(gh run list --repo journalbrand/journaltrove-ipfs --workflow ci.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)
    if [[ -n "$IPFS_RUN_ID" ]]; then
        log "📦 IPFS: Downloading test results from run $IPFS_RUN_ID..."
        gh run download $IPFS_RUN_ID --repo journalbrand/journaltrove-ipfs --name ipfs-test-results-jsonld --dir compliance/results/ipfs 2>/dev/null
        
        # Check if the file exists directly or in a subdirectory
        if [[ -f "compliance/results/ipfs/test-results.jsonld" ]]; then
            log "✅ IPFS test results downloaded."
        elif [[ -d "compliance/results/ipfs" ]]; then
            # Look for the file in any subdirectory
            FOUND_FILE=$(find "compliance/results/ipfs" -name "test-results.jsonld" -type f | head -n 1)
            if [[ -n "$FOUND_FILE" ]]; then
                # Move the file to the expected location
                cp "$FOUND_FILE" "compliance/results/ipfs/test-results.jsonld"
                log "✅ IPFS test results downloaded."
            else
                log "⚠️ IPFS test results not found in the downloaded artifact."
            fi
        else
            log "⚠️ IPFS test results download failed."
        fi
    else
        log "⚠️ No IPFS workflow runs found."
    fi
    
    # Generate fresh compliance matrix from test results
    log "🔄 Generating fresh compliance matrix from test results..."
    # Check if at least one test result file exists
    TEST_RESULTS_COUNT=$(find "compliance/results" -name "test-results.jsonld" -type f | wc -l)
    if [[ "$TEST_RESULTS_COUNT" -gt 0 ]]; then
        # Run the aggregation script
        ./compliance/scripts/aggregate_jsonld_compliance.sh compliance/results compliance/dashboard >> "$LOGFILE" 2>&1
        if [[ $? -eq 0 ]]; then
            log "✅ Fresh compliance matrix generated from test results."
            return 0
        else
            log "⚠️ Error generating compliance matrix from test results."
        fi
    else
        log "⚠️ No test result files found. Will download pre-built compliance matrix."
    fi
    
    # If we couldn't generate a fresh matrix, try to download a pre-built one
    log "📥 Downloading latest compliance matrix artifact..."
    # Get the latest run ID for compliance matrix workflow
    RUN_ID=$(gh run list --workflow=compliance-matrix.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null)
    if [[ -n "$RUN_ID" ]]; then
        log "📥 Downloading compliance matrix from run $RUN_ID..."
        gh run download $RUN_ID --name compliance-matrix-jsonld --dir compliance/dashboard 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log "✅ Downloaded compliance matrix successfully."
            return 0
        else
            log "⚠️ Failed to download compliance matrix."
        fi
    else
        log "⚠️ No compliance matrix workflow runs found."
    fi
    
    # If downloaded matrix exists, copy to dashboard directory
    if [[ -f "compliance/reports/compliance_matrix.jsonld" ]]; then
        cp "compliance/reports/compliance_matrix.jsonld" "compliance/dashboard/compliance_matrix.jsonld"
        log "✅ Using existing compliance matrix."
        return 0
    fi
    
    # If requirements.json exists, create a minimal dashboard
    if [[ -f "requirements/requirements.jsonld" ]]; then
        log "ℹ️ Creating minimal dashboard from requirements only."
        cp "requirements/requirements.jsonld" "compliance/dashboard/requirements.jsonld"
        return 0
    fi
    
    log "❌ Could not obtain compliance matrix or requirements."
    return 1
}

# Download compliance matrix initially
download_compliance_matrix

# Start auto-refresh in the background
(
    while true; do
        sleep 60
        log "🔄 Auto-refreshing compliance matrix data..."
        download_compliance_matrix
    done
) &

# Save the PID of the background process
echo $! > "$PID_FILE"

log "⏱️ Auto-refresh is enabled - compliance matrix will update every 60 seconds"
log "🌐 Starting Compliance Dashboard server on http://localhost:$PORT"
log "📊 Dashboard will be available at: http://localhost:$PORT/compliance/dashboard/"
log "⚠️ Press Ctrl+C to stop the server and auto-refresh"

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
    log "❌ Error: Python is not installed. Please install Python to run this server."
    exit 1
fi 