#!/bin/bash
# Test AWS availability and credentials for deployer-ddf-mod-open-llms

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🔍 Testing AWS Availability for deployer-ddf-mod-open-llms"
echo "=================================================="

# Test 1: Check if AWS CLI is installed
log "Checking AWS CLI installation..."
if command -v aws >/dev/null 2>&1; then
    AWS_VERSION=$(aws --version 2>&1 | head -n1)
    success "AWS CLI is installed: $AWS_VERSION"
else
    error "AWS CLI is not installed"
    echo "Please install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Test 2: Check AWS credentials
log "Checking AWS credentials..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    CALLER_IDENTITY=$(aws sts get-caller-identity --output json)
    USER_ID=$(echo "$CALLER_IDENTITY" | jq -r '.UserId // "N/A"')
    ACCOUNT=$(echo "$CALLER_IDENTITY" | jq -r '.Account // "N/A"')
    ARN=$(echo "$CALLER_IDENTITY" | jq -r '.Arn // "N/A"')
    
    success "AWS credentials are configured"
    echo "  User ID: $USER_ID"
    echo "  Account: $ACCOUNT"
    echo "  ARN: $ARN"
else
    error "AWS credentials are not configured or invalid"
    echo "Please configure AWS credentials:"
    echo "  aws configure"
    echo "Or set environment variables:"
    echo "  export AWS_ACCESS_KEY_ID=your_access_key"
    echo "  export AWS_SECRET_ACCESS_KEY=your_secret_key"
    exit 1
fi

# Test 3: Check default region
log "Checking AWS region configuration..."
DEFAULT_REGION=$(aws configure get region 2>/dev/null || echo "")
if [[ -n "$DEFAULT_REGION" ]]; then
    success "Default region is set: $DEFAULT_REGION"
else
    warning "No default region configured"
    echo "Consider setting a default region:"
    echo "  aws configure set region us-east-1"
fi

# Test 4: Test basic AWS service access
log "Testing basic AWS service access..."

# Test S3 access
if aws s3 ls >/dev/null 2>&1; then
    success "S3 access: OK"
else
    warning "S3 access: Limited or no access"
fi

# Test ECS access
if aws ecs list-clusters >/dev/null 2>&1; then
    success "ECS access: OK"
else
    warning "ECS access: Limited or no access"
fi

# Test CloudFormation access
if aws cloudformation list-stacks >/dev/null 2>&1; then
    success "CloudFormation access: OK"
else
    warning "CloudFormation access: Limited or no access"
fi

# Test 5: Check for existing deployments
log "Checking for existing deployments..."
STACK_NAME="deployer-ddf-mod-llm-models-dev"
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1; then
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].StackStatus' --output text)
    success "Found existing stack: $STACK_NAME (Status: $STACK_STATUS)"
    
    # Get stack outputs if available
    OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs' --output json 2>/dev/null || echo "[]")
    if [[ "$OUTPUTS" != "[]" ]]; then
        echo "Stack outputs:"
        echo "$OUTPUTS" | jq -r '.[] | "  \(.OutputKey): \(.OutputValue)"'
    fi
else
    log "No existing deployment found for stack: $STACK_NAME"
fi

# Test 6: Check required permissions
log "Testing required AWS permissions..."

# Test IAM permissions
if aws iam get-user >/dev/null 2>&1; then
    success "IAM permissions: OK"
else
    warning "IAM permissions: Limited (this may be normal for some setups)"
fi

# Test EC2 permissions
if aws ec2 describe-regions >/dev/null 2>&1; then
    success "EC2 permissions: OK"
else
    warning "EC2 permissions: Limited or no access"
fi

echo ""
echo "🎯 AWS Availability Summary"
echo "=========================="
success "AWS CLI is properly configured and accessible"
log "You can deploy to AWS using:"
echo "  ./run.sh --env=dev --platform=aws --setup --verbose"
echo ""
log "For a dry-run deployment test:"
echo "  ./run.sh --env=dev --platform=aws --dry-run"
echo ""
log "To check deployment health after deployment:"
echo "  bash scripts/deploy/health-check.sh --env=dev --verbose" 