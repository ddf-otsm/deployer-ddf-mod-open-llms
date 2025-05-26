#!/bin/bash
# Quick setup for development environment
# Run this script to set up your local development secrets

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Quick setup for development environment"

# Check if AWS CLI is available
if ! command -v aws >/dev/null 2>&1; then
    echo "❌ AWS CLI not found. Please install it first:"
    echo "   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if OpenSSL is available
if ! command -v openssl >/dev/null 2>&1; then
    echo "❌ OpenSSL not found. Please install it first."
    exit 1
fi

echo "📝 Setting up AWS credentials for development..."
echo "Please enter your AWS credentials:"

read -p "AWS Access Key ID: " aws_access_key_id
read -s -p "AWS Secret Access Key: " aws_secret_access_key
echo ""

# Validate AWS credentials format
if [[ ! "$aws_access_key_id" =~ ^AKIA[0-9A-Z]{16}$ ]]; then
    echo "⚠️  Warning: AWS Access Key ID format looks unusual"
fi

# Save AWS credentials
echo "$aws_access_key_id" > "$PROJECT_ROOT/aws-credentials/dev/access_key_id"
echo "$aws_secret_access_key" > "$PROJECT_ROOT/aws-credentials/dev/secret_access_key"

# Set secure permissions
chmod 600 "$PROJECT_ROOT/aws-credentials/dev/access_key_id"
chmod 600 "$PROJECT_ROOT/aws-credentials/dev/secret_access_key"

echo "✅ AWS credentials saved securely"

# Generate API tokens
echo "🔑 Generating API tokens..."
openssl rand -hex 16 > "$PROJECT_ROOT/api-tokens/dev/client_api_token"
openssl rand -hex 16 > "$PROJECT_ROOT/api-tokens/dev/admin_api_token"

# Set secure permissions
chmod 600 "$PROJECT_ROOT/api-tokens/dev/client_api_token"
chmod 600 "$PROJECT_ROOT/api-tokens/dev/admin_api_token"

echo "✅ API tokens generated"

# Test the setup
echo "🧪 Testing secrets loading..."
if source "$PROJECT_ROOT/scripts/load-secrets.sh" dev; then
    echo "🎯 Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Test AWS access: aws sts get-caller-identity"
    echo "2. Run the application: bash run.sh --env=dev --platform=cursor --fast"
    echo "3. Deploy to AWS: bash run.sh --env=dev --platform=aws --setup"
else
    echo "❌ Setup failed. Please check the error messages above."
    exit 1
fi
