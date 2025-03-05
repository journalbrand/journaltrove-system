#!/bin/bash
# Fetch component requirements files for validation
# This script fetches requirements.jsonld files from all component repositories

set -e

# Create directory for component requirements
mkdir -p components/ios/requirements
mkdir -p components/android/requirements
mkdir -p components/ipfs/requirements

# Define repositories to fetch from
repositories=(
  "journalbrand/journaltrove-ios"
  "journalbrand/journaltrove-android"
  "journalbrand/journaltrove-ipfs"
)

# Define requirements file paths for each repo
requirements_paths=(
  "requirements/requirements.jsonld"
  "requirements/requirements.jsonld"
  "requirements/requirements.jsonld"
)

# Ensure we have GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI is not installed"
    exit 1
fi

# Ensure we're authenticated 
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not logged in to GitHub"
    echo "Please run 'gh auth login' first"
    exit 1
fi

# Fetch requirements files from each repository
for i in "${!repositories[@]}"; do
    repo="${repositories[$i]}"
    path="${requirements_paths[$i]}"
    component=$(echo "$repo" | cut -d'/' -f2 | cut -d'-' -f2)
    
    echo "Fetching requirements for $component..."
    
    # Fetch file using GitHub API
    gh api "repos/$repo/contents/$path" --jq '.content' | base64 -d > "components/$component/requirements/requirements.jsonld"
    
    if [ -f "components/$component/requirements/requirements.jsonld" ]; then
        echo "✅ Successfully fetched requirements for $component"
    else
        echo "❌ Failed to fetch requirements for $component"
        exit 1
    fi
done

echo "All component requirements fetched successfully." 