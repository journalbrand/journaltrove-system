#!/usr/bin/env python3
"""
Cross-platform dashboard server for the journaltrove App System.
Replaces serve-dashboard.sh and aggregate_jsonld_compliance.sh with a Python implementation
that works on both Windows and macOS/Linux.
"""

import os
import sys
import json
import time
import signal
import logging
import datetime
import subprocess
import threading
import http.server
import socketserver
import webbrowser
from pathlib import Path
from typing import List, Dict, Any, Optional
import platform
import glob
import shutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("dashboard.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("dashboard")

# Configuration
BASE_DIR = Path(__file__).parent.absolute()
PORT = 8000
PID_FILE = "dashboard.pid"
REFRESH_INTERVAL = 60  # seconds

# Directories
RESULTS_DIR = BASE_DIR / "compliance" / "results"
DASHBOARD_DIR = BASE_DIR / "compliance" / "dashboard"
REPORTS_DIR = BASE_DIR / "compliance" / "reports"
REQUIREMENTS_DIR = BASE_DIR / "requirements"


def log(message: str) -> None:
    """Log a message to both console and log file."""
    # Use ASCII emoticons instead of Unicode emojis for Windows compatibility
    message = (message
              .replace("🔍", "[SEARCH]")
              .replace("⚠️", "[WARNING]")
              .replace("❌", "[ERROR]")
              .replace("✅", "[SUCCESS]")
              .replace("🔄", "[REFRESH]")
              .replace("📥", "[DOWNLOAD]")
              .replace("📊", "[DASHBOARD]")
              .replace("🌐", "[SERVER]")
              .replace("⏱️", "[TIMER]")
              .replace("ℹ️", "[INFO]")
              .replace("✗", "[X]")
              .replace("✓", "[OK]"))
    logger.info(message)


def ensure_dirs_exist() -> None:
    """Create necessary directories if they don't exist."""
    for directory in [RESULTS_DIR, DASHBOARD_DIR, REPORTS_DIR, 
                     RESULTS_DIR / "ios", RESULTS_DIR / "android", RESULTS_DIR / "ipfs"]:
        directory.mkdir(parents=True, exist_ok=True)


def clear_cache() -> None:
    """
    Clear cached JSON-LD files to ensure fresh data.
    
    This removes:
    1. All test-results.jsonld files in the results directory
    2. The compliance_matrix.jsonld file in the dashboard and reports directories
    
    It does NOT remove the requirements.jsonld file which is a source file.
    """
    log("[REFRESH] Clearing JSON-LD cache files...")
    
    # Create the directories if they don't exist
    ensure_dirs_exist()
    
    # Clear test results
    for component in ["ios", "android", "ipfs"]:
        result_file = RESULTS_DIR / component / "test-results.jsonld"
        if result_file.exists():
            try:
                result_file.unlink()
                log(f"[SUCCESS] Deleted {result_file}")
            except Exception as e:
                log(f"[WARNING] Could not delete {result_file}: {e}")
    
    # Clear any other test results files
    for jsonld_file in RESULTS_DIR.glob("**/*.jsonld"):
        try:
            jsonld_file.unlink()
            log(f"[SUCCESS] Deleted {jsonld_file}")
        except Exception as e:
            log(f"[WARNING] Could not delete {jsonld_file}: {e}")
    
    # Clear compliance matrix files
    for matrix_path in [DASHBOARD_DIR / "compliance_matrix.jsonld", REPORTS_DIR / "compliance_matrix.jsonld"]:
        if matrix_path.exists():
            try:
                matrix_path.unlink()
                log(f"[SUCCESS] Deleted {matrix_path}")
            except Exception as e:
                log(f"[WARNING] Could not delete {matrix_path}: {e}")
    
    log("[SUCCESS] Cache cleared successfully")


def run_cmd(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    try:
        result = subprocess.run(
            cmd, 
            check=check, 
            capture_output=True, 
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        log(f"[WARNING] Command failed: {' '.join(cmd)}")
        log(f"Error: {e}")
        log(f"Output: {e.stdout}")
        log(f"Error output: {e.stderr}")
        if check:
            raise
        return e


def gh_cli_exists() -> bool:
    """Check if GitHub CLI is installed."""
    try:
        subprocess.run(
            ["gh", "--version"], 
            check=True, 
            capture_output=True, 
            text=True
        )
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
        return False


def get_latest_workflow_run_id(repo: str, workflow: str) -> Optional[str]:
    """Get the latest run ID for a workflow."""
    if not gh_cli_exists():
        return None
    
    try:
        result = run_cmd(
            ["gh", "run", "list", "--repo", repo, "--workflow", workflow, "--limit", "1", "--json", "databaseId"], 
            check=False
        )
        if result.returncode != 0:
            return None
        
        data = json.loads(result.stdout)
        if data and len(data) > 0:
            return str(data[0]["databaseId"])
        return None
    except (subprocess.SubprocessError, json.JSONDecodeError) as e:
        log(f"[WARNING] Error getting latest workflow run ID: {e}")
        return None


def download_artifact(repo: str, run_id: str, name: str, output_dir: Path) -> bool:
    """Download an artifact from a workflow run."""
    if not gh_cli_exists() or not run_id:
        return False
    
    try:
        result = run_cmd(
            ["gh", "run", "download", run_id, "--repo", repo, "--name", name, "--dir", str(output_dir)],
            check=False
        )
        return result.returncode == 0
    except subprocess.SubprocessError:
        return False


def find_and_move_file(search_dir: Path, filename: str, dest_path: Path) -> bool:
    """Find a file in a directory (including subdirectories) and move it to the destination."""
    # Look for the file directly
    if (search_dir / filename).exists():
        with open(search_dir / filename, 'rb') as src_file:
            with open(dest_path, 'wb') as dest_file:
                dest_file.write(src_file.read())
        return True
    
    # Look in subdirectories
    for found_file in search_dir.glob(f"**/{filename}"):
        with open(found_file, 'rb') as src_file:
            with open(dest_path, 'wb') as dest_file:
                dest_file.write(src_file.read())
        return True
    
    return False


def download_component_test_results() -> None:
    """Download test results from component workflows."""
    components = {
        "ios": {
            "repo": "journalbrand/journaltrove-ios",
            "workflow": "ci.yml",
            "artifact": "ios-test-results-jsonld",
            "dir": RESULTS_DIR / "ios",
            "dest": RESULTS_DIR / "ios" / "test-results.jsonld"
        },
        "android": {
            "repo": "journalbrand/journaltrove-android",
            "workflow": "ci.yml",
            "artifact": "android-test-results-jsonld",
            "dir": RESULTS_DIR / "android",
            "dest": RESULTS_DIR / "android" / "test-results.jsonld"
        },
        "ipfs": {
            "repo": "journalbrand/journaltrove-ipfs",
            "workflow": "ci.yml",
            "artifact": "ipfs-test-results-jsonld",
            "dir": RESULTS_DIR / "ipfs",
            "dest": RESULTS_DIR / "ipfs" / "test-results.jsonld"
        }
    }
    
    for name, component in components.items():
        log(f"[DOWNLOAD] {name.upper()}: Downloading test results from latest workflow run...")
        run_id = get_latest_workflow_run_id(component["repo"], component["workflow"])
        
        if run_id:
            log(f"[DOWNLOAD] {name.upper()}: Downloading test results from run {run_id}...")
            if download_artifact(component["repo"], run_id, component["artifact"], component["dir"]):
                if find_and_move_file(component["dir"], "test-results.jsonld", component["dest"]):
                    log(f"[SUCCESS] {name.upper()} test results downloaded.")
                else:
                    log(f"[WARNING] {name.upper()} test results not found in the downloaded artifact.")
            else:
                log(f"[WARNING] {name.upper()} test results download failed.")
        else:
            log(f"[WARNING] No {name.upper()} workflow runs found.")


def aggregate_compliance_matrix() -> bool:
    """Generate a compliance matrix from test results."""
    output_file = DASHBOARD_DIR / "compliance_matrix.jsonld"
    
    # Check if system requirements exist
    system_req = REQUIREMENTS_DIR / "requirements.jsonld"
    if not system_req.exists():
        log(f"[X] Error: System requirements not found at {system_req}")
        return False
    
    # Initialize the compliance matrix
    compliance_matrix = {
        "@context": "../requirements/context/requirements-context.jsonld",
        "@graph": [
            {
                "@id": "compliance-matrix",
                "@type": "ComplianceMatrix",
                "name": "journaltrove App Compliance Matrix",
                "description": "Generated compliance matrix aggregating test results from all components",
                "timestamp": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
                "components": [],
                "testCases": []
            }
        ]
    }
    
    # Write initial structure
    with open(output_file, 'w') as f:
        json.dump(compliance_matrix, f, indent=2)
    
    log("[OK] Created initial compliance matrix structure")
    
    # Process component test results
    results_files = list(RESULTS_DIR.glob("**/*.jsonld"))
    if not results_files:
        log("[WARNING] No test result files found.")
        return False
    
    for result_file in results_files:
        log(f"Processing {result_file}...")
        
        # Extract component name from the file path
        component = result_file.parent.name
        log(f"Component: {component}")
        
        # Validate JSON-LD format
        try:
            with open(result_file, 'r') as f:
                result_data = json.load(f)
        except json.JSONDecodeError:
            log(f"[X] Error: Invalid JSON-LD in {result_file}")
            continue
        
        # Read the current compliance matrix
        with open(output_file, 'r') as f:
            compliance_data = json.load(f)
        
        # Add component to the compliance matrix if not already present
        if component not in compliance_data["@graph"][0]["components"]:
            compliance_data["@graph"][0]["components"].append(component)
        
        # Extract test cases and add them to the compliance matrix
        test_cases = []
        try:
            for test_suite in result_data["@graph"][0]["testSuites"]:
                for test_case in test_suite["testCases"]:
                    test_cases.append({
                        "@id": test_case["@id"],
                        "@type": "TestCase",
                        "component": component,
                        "name": test_case["name"],
                        "verifies": test_case["verifies"],
                        "result": test_case["result"]
                    })
        except (KeyError, IndexError) as e:
            log(f"[X] Error extracting test cases: {e}")
            continue
        
        # Add test cases to the compliance matrix
        compliance_data["@graph"][0]["testCases"].extend(test_cases)
        
        # Write updated compliance matrix
        with open(output_file, 'w') as f:
            json.dump(compliance_data, f, indent=2)
    
    # Generate statistics
    log("Generating statistics...")
    
    # Read requirements
    with open(system_req, 'r') as f:
        req_data = json.load(f)
    
    # Count requirements
    total_reqs = sum(1 for item in req_data["@graph"] 
                    if item.get("type") == "Requirement" or item.get("@type") == "Requirement")
    
    # Read compliance matrix
    with open(output_file, 'r') as f:
        compliance_data = json.load(f)
    
    # Calculate statistics
    test_cases = compliance_data["@graph"][0]["testCases"]
    total_tests = len(test_cases)
    passed_tests = sum(1 for tc in test_cases if tc.get("result") in ("Pass", "Passed"))
    failed_tests = sum(1 for tc in test_cases if tc.get("result") in ("Fail", "Failed"))
    components_count = len(compliance_data["@graph"][0]["components"])
    
    # Add statistics to compliance matrix
    compliance_data["@graph"][0]["statistics"] = {
        "totalRequirements": total_reqs,
        "totalTests": total_tests,
        "passingTests": passed_tests,
        "failingTests": failed_tests,
        "components": components_count
    }
    
    # Write updated compliance matrix
    with open(output_file, 'w') as f:
        json.dump(compliance_data, f, indent=2)
    
    # Copy requirements to dashboard directory
    with open(system_req, 'rb') as src_file:
        with open(DASHBOARD_DIR / "requirements.jsonld", 'wb') as dest_file:
            dest_file.write(src_file.read())
    
    log(f"Compliance matrix generated: {output_file}")
    log("Dashboard updated with compliance matrix")
    log(f"Statistics:")
    log(f"- Total requirements: {total_reqs}")
    log(f"- Total tests: {total_tests}")
    log(f"- Passed tests: {passed_tests}")
    log(f"- Failed tests: {failed_tests}")
    log(f"- Components: {components_count}")
    
    return True


def download_compliance_matrix() -> bool:
    """Download or generate compliance matrix."""
    log("[SEARCH] Checking for GitHub CLI...")
    if not gh_cli_exists():
        log("[ERROR] GitHub CLI not found. Cannot download compliance matrix artifact.")
        log("Please install GitHub CLI or manually copy the compliance matrix to compliance/dashboard/compliance_matrix.jsonld")
        return False
    
    log("[SUCCESS] GitHub CLI found.")
    log("[REFRESH] Refreshing compliance matrix data...")
    
    # Create necessary directories
    ensure_dirs_exist()
    
    # Download test results from component workflows
    download_component_test_results()
    
    # Generate fresh compliance matrix from test results
    test_results_count = len(list(RESULTS_DIR.glob("**/test-results.jsonld")))
    if test_results_count > 0:
        log("[REFRESH] Generating fresh compliance matrix from test results...")
        if aggregate_compliance_matrix():
            log("[SUCCESS] Fresh compliance matrix generated from test results.")
            return True
        else:
            log("[WARNING] Error generating compliance matrix from test results.")
    else:
        log("[WARNING] No test result files found. Will download pre-built compliance matrix.")
    
    # If we couldn't generate a fresh matrix, try to download a pre-built one
    log("[DOWNLOAD] Downloading latest compliance matrix artifact...")
    run_id = get_latest_workflow_run_id("journalbrand/journaltrove-system", "compliance-matrix.yml")
    
    if run_id:
        log(f"[DOWNLOAD] Downloading compliance matrix from run {run_id}...")
        if download_artifact("journalbrand/journaltrove-system", run_id, "compliance-matrix-jsonld", DASHBOARD_DIR):
            log("[SUCCESS] Downloaded compliance matrix successfully.")
            return True
        else:
            log("[WARNING] Failed to download compliance matrix.")
    else:
        log("[WARNING] No compliance matrix workflow runs found.")
    
    # If downloaded matrix exists, copy to dashboard directory
    if (REPORTS_DIR / "compliance_matrix.jsonld").exists():
        with open(REPORTS_DIR / "compliance_matrix.jsonld", 'rb') as src_file:
            with open(DASHBOARD_DIR / "compliance_matrix.jsonld", 'wb') as dest_file:
                dest_file.write(src_file.read())
        log("[SUCCESS] Using existing compliance matrix.")
        return True
    
    # If requirements.json exists, create a minimal dashboard
    if (REQUIREMENTS_DIR / "requirements.jsonld").exists():
        log("[INFO] Creating minimal dashboard from requirements only.")
        with open(REQUIREMENTS_DIR / "requirements.jsonld", 'rb') as src_file:
            with open(DASHBOARD_DIR / "requirements.jsonld", 'wb') as dest_file:
                dest_file.write(src_file.read())
        return True
    
    log("[ERROR] Could not obtain compliance matrix or requirements.")
    return False


def auto_refresh_thread() -> None:
    """Background thread that refreshes the compliance matrix periodically."""
    while True:
        time.sleep(REFRESH_INTERVAL)
        log("[REFRESH] Auto-refreshing compliance matrix data...")
        download_compliance_matrix()


def start_http_server() -> None:
    """Start a simple HTTP server to serve the dashboard."""
    class CustomHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(BASE_DIR), **kwargs)
        
        def log_message(self, format, *args):
            # Suppress server logs to keep the console clean
            pass
    
    try:
        with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
            log(f"[SERVER] Starting Compliance Dashboard server on http://localhost:{PORT}")
            log(f"[DASHBOARD] Dashboard will be available at: http://localhost:{PORT}/compliance/dashboard/")
            log(f"[WARNING] Press Ctrl+C to stop the server and auto-refresh")
            httpd.serve_forever()
    except KeyboardInterrupt:
        log("Server stopped.")
    except OSError as e:
        if e.errno == 98:  # Address already in use
            log(f"[ERROR] Error: Port {PORT} is already in use. Try stopping any running servers.")
        else:
            log(f"[ERROR] Error starting server: {e}")


def main() -> None:
    """Main function."""
    # Print header
    log("journaltrove App Dashboard Server - Started " + datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
    
    # Clear cache first to ensure fresh data
    clear_cache()
    
    # Download compliance matrix initially
    download_compliance_matrix()
    
    # Start auto-refresh in a background thread
    refresh_thread = threading.Thread(target=auto_refresh_thread, daemon=True)
    refresh_thread.start()
    
    # Save the main process PID
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))
    
    # Open browser after a short delay
    def open_browser():
        time.sleep(1)
        webbrowser.open(f"http://localhost:{PORT}/compliance/dashboard/")
    
    browser_thread = threading.Thread(target=open_browser, daemon=True)
    browser_thread.start()
    
    # Start the HTTP server (this will block until interrupted)
    start_http_server()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Shutting down...")
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
        sys.exit(0) 