#!/usr/bin/env python3
"""
Download Compliance Matrix JSONLD Utility Script

This script downloads the compliance_matrix.jsonld file from the most recent 
successful run of the Compliance Matrix Generation workflow on GitHub.

Usage:
    python download_compliance_matrix.py [--repo REPOSITORY] [--output OUTPUT_PATH]

Options:
    --repo       GitHub repository in format 'owner/repo' (default: journalbrand/journaltrove-system)
    --output     Output path where the file should be saved (default: compliance/dashboard/compliance_matrix.jsonld)

Requirements:
    - GitHub CLI (gh) must be installed and authenticated
    - Python 3.6+
    - Proper GitHub permissions to access the repository
"""

import argparse
import os
import subprocess
import sys
import json
import tempfile
import shutil
import time
from pathlib import Path


def check_gh_cli_installed():
    """Check if GitHub CLI is installed and authenticated."""
    try:
        # Check if gh is installed
        subprocess.run(["gh", "--version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        
        # Check if authenticated
        result = subprocess.run(["gh", "auth", "status"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if "Logged in to" not in result.stdout and result.returncode != 0:
            print("🔒 GitHub CLI is installed but not authenticated.")
            print("Please run 'gh auth login' to authenticate with GitHub.")
            return False
        
        return True
    except subprocess.CalledProcessError:
        print("❌ GitHub CLI (gh) is not installed.")
        print("Please install it from https://cli.github.com/")
        return False
    except FileNotFoundError:
        print("❌ GitHub CLI (gh) is not installed or not in PATH.")
        print("Please install it from https://cli.github.com/")
        return False


def get_latest_workflow_run(repository, workflow_name="compliance-matrix.yml"):
    """Get the ID of the latest successful run of the specified workflow."""
    print(f"🔍 Finding the latest successful run of '{workflow_name}' in {repository}...")
    
    # Get the most recent completed workflow run
    cmd = ["gh", "run", "list", "--repo", repository, "--workflow", workflow_name, 
           "--status", "completed", "--limit", "5", "--json", "databaseId,conclusion,createdAt,displayTitle"]
    
    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        runs = json.loads(result.stdout)
        
        # Filter for successful runs
        successful_runs = [run for run in runs if run["conclusion"] == "success"]
        
        if not successful_runs:
            print(f"❌ No successful runs found for workflow '{workflow_name}'.")
            return None
        
        # Sort by createdAt (most recent first)
        successful_runs.sort(key=lambda x: x["createdAt"], reverse=True)
        latest_run = successful_runs[0]
        
        print(f"✅ Found workflow run: {latest_run['displayTitle']} (ID: {latest_run['databaseId']})")
        return latest_run["databaseId"]
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Error finding workflow runs: {e}")
        print(f"Error details: {e.stderr}")
        return None
    except json.JSONDecodeError:
        print("❌ Error parsing GitHub CLI output.")
        return None


def download_matrix_artifact(repository, run_id, output_path):
    """Download the compliance matrix artifact from the specified workflow run."""
    print(f"📥 Downloading compliance matrix artifact from run ID: {run_id}...")
    
    # Create temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            # Download the artifact
            artifact_name = "compliance-matrix-jsonld"
            download_cmd = [
                "gh", "run", "download", str(run_id),
                "--repo", repository,
                "--name", artifact_name,
                "--dir", temp_dir
            ]
            
            result = subprocess.run(download_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            print(f"✅ Successfully downloaded artifact to temporary location.")
            
            # Find the downloaded file
            jsonld_files = list(Path(temp_dir).glob("**/*.jsonld"))
            if not jsonld_files:
                print("❌ No JSONLD files found in the downloaded artifact.")
                return False
            
            # Ensure output directory exists
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            
            # Copy the file to the output path
            source_file = str(jsonld_files[0])
            shutil.copy2(source_file, output_path)
            print(f"📋 Compliance matrix saved to: {output_path}")
            
            # Verify the file exists and has content
            if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
                print(f"✅ Verification successful: File exists and contains data.")
                return True
            else:
                print(f"❌ Verification failed: File is empty or does not exist.")
                return False
                
        except subprocess.CalledProcessError as e:
            print(f"❌ Error downloading artifact: {e}")
            print(f"Error details: {e.stderr}")
            return False


def main():
    """Main function that parses arguments and runs the download process."""
    parser = argparse.ArgumentParser(description="Download the latest compliance matrix JSONLD file from GitHub.")
    parser.add_argument("--repo", default="journalbrand/journaltrove-system",
                        help="GitHub repository in format 'owner/repo'")
    parser.add_argument("--output", default="compliance/dashboard/compliance_matrix.jsonld",
                        help="Output path where the file should be saved")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("📊 journaltrove Compliance Matrix Downloader")
    print("=" * 60)
    print(f"Repository: {args.repo}")
    print(f"Output path: {args.output}")
    print()
    
    # Make sure the output path is relative to the script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    output_path = os.path.join(project_root, args.output)
    
    # Check if GitHub CLI is installed
    if not check_gh_cli_installed():
        sys.exit(1)
    
    # Get the latest workflow run ID
    run_id = get_latest_workflow_run(args.repo)
    if not run_id:
        sys.exit(1)
    
    # Download the artifact
    success = download_matrix_artifact(args.repo, run_id, output_path)
    if not success:
        sys.exit(1)
    
    print("\n🎉 Download completed successfully!")
    print(f"The compliance matrix is now available at: {output_path}")
    
    # Report file size
    file_size_kb = os.path.getsize(output_path) / 1024
    print(f"File size: {file_size_kb:.1f} KB")
    print("=" * 60)


if __name__ == "__main__":
    main() 