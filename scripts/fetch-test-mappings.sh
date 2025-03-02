#!/bin/bash
# Fetch test mapping files from all components for early validation

set -e

# Create temporary directory for test mappings
mkdir -p tmp/test-mappings

# Define repositories to fetch from
repositories=(
  "journalbrand/todo-ios"
  "journalbrand/todo-android"
  "journalbrand/todo-ipfs"
)

# Define mapping file paths for each repo
mapping_paths=(
  "Tests/test-mappings.jsonld"
  "app/src/test/test-mappings.jsonld"
  "tests/test-mappings.jsonld"
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

# Fetch test mapping files from each repository
for i in "${!repositories[@]}"; do
    repo="${repositories[$i]}"
    path="${mapping_paths[$i]}"
    component=$(echo "$repo" | cut -d'/' -f2 | cut -d'-' -f2)
    
    echo "Fetching test mappings for $component..."
    
    # Create directory for component
    mkdir -p "tmp/test-mappings/$component"
    
    # Fetch file using GitHub API
    gh api "repos/$repo/contents/$path" --jq '.content' | base64 -d > "tmp/test-mappings/$component/test-mappings.jsonld"
    
    if [ -f "tmp/test-mappings/$component/test-mappings.jsonld" ]; then
        echo "✅ Successfully fetched test mappings for $component"
    else
        echo "❌ Failed to fetch test mappings for $component"
    fi
done

echo "All test mappings fetched successfully." 