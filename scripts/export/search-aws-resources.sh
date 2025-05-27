#!/bin/bash

# AWS Resources Search Script
# Searches exported Cursor conversations for AWS resource information
# Usage: bash scripts/export/search-aws-resources.sh [search_term]

set -euo pipefail

CONVERSATIONS_DIR="./export/cursor-conversations/conversations"
SEARCH_TERM="${1:-}"

if [[ ! -d "$CONVERSATIONS_DIR" ]]; then
    echo "❌ Conversations directory not found: $CONVERSATIONS_DIR"
    echo "💡 Run the export first: bash scripts/export/cursor-conversations-export-safe.sh"
    exit 1
fi

echo "🔍 Searching AWS Resources in Cursor Conversations"
echo "📁 Directory: $CONVERSATIONS_DIR"
echo ""

# Function to search and display results
search_and_display() {
    local pattern="$1"
    local description="$2"
    
    echo "🔍 Searching for: $description"
    echo "Pattern: $pattern"
    
    local results=$(grep -r "$pattern" "$CONVERSATIONS_DIR" 2>/dev/null || true)
    
    if [[ -n "$results" ]]; then
        echo "✅ Found matches:"
        echo "$results" | head -5 | while IFS= read -r line; do
            local file=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)
            local basename=$(basename "$file")
            echo "  📄 $basename: ${content:0:100}..."
        done
        
        local count=$(echo "$results" | wc -l)
        if [[ $count -gt 5 ]]; then
            echo "  ... and $((count - 5)) more matches"
        fi
    else
        echo "❌ No matches found"
    fi
    echo ""
}

# If specific search term provided, search for it
if [[ -n "$SEARCH_TERM" ]]; then
    search_and_display "$SEARCH_TERM" "Custom search: $SEARCH_TERM"
    exit 0
fi

# Default searches for AWS resources
echo "🚀 Running comprehensive AWS resource search..."
echo ""

# ARNs and Resource IDs
search_and_display "arn:aws" "AWS ARNs"
search_and_display "i-[0-9a-f]" "EC2 Instance IDs"
search_and_display "sg-[0-9a-f]" "Security Group IDs"
search_and_display "vpc-[0-9a-f]" "VPC IDs"
search_and_display "subnet-[0-9a-f]" "Subnet IDs"

# Stack and Resource Names
search_and_display "deployer-ddf-llm" "Deployer DDF LLM Resources"
search_and_display "stack-name\|StackName" "CloudFormation Stack Names"
search_and_display "ClusterName\|cluster-name" "ECS Cluster Names"

# Specific AWS Services
search_and_display "ECS\|Fargate" "ECS/Fargate Resources"
search_and_display "RDS\|PostgreSQL" "Database Resources"
search_and_display "S3.*bucket" "S3 Buckets"
search_and_display "CloudFormation" "CloudFormation References"
search_and_display "LoadBalancer\|ALB" "Load Balancer Resources"

# Deployment and Configuration
search_and_display "aws cloudformation\|aws ecs\|aws s3" "AWS CLI Commands"
search_and_display "execution-role\|task-role" "IAM Roles"

echo "✅ Search complete!"
echo ""
echo "💡 Usage tips:"
echo "  - Search for specific terms: $0 'your-search-term'"
echo "  - View full conversations: ls $CONVERSATIONS_DIR/*.md"
echo "  - Check summary: cat ./export/cursor-conversations/summary/export_summary.md" 