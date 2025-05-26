#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/setup-aws.sh
# AWS CLI setup and configuration for AI Testing Agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Set up AWS CLI and credentials for AI Testing Agent deployment.

OPTIONS:
    --profile=PROFILE      AWS profile name [default: default]
    --region=REGION        Default AWS region [default: us-east-1]
    --check-only          Only check existing configuration
    --help                Show this help message

EXAMPLES:
    $0                                    # Interactive setup with default profile
    $0 --profile=ai-testing --region=us-west-2
    $0 --check-only                       # Just validate existing setup

SETUP STEPS:
    1. Verify AWS CLI installation
    2. Configure AWS credentials
    3. Set default region
    4. Test AWS connectivity
    5. Validate required permissions

EOF
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
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

# Default configuration
AWS_PROFILE="default"
AWS_REGION="us-east-1"
CHECK_ONLY="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile=*)
            AWS_PROFILE="${1#*=}"
            shift
            ;;
        --region=*)
            AWS_REGION="${1#*=}"
            shift
            ;;
        --check-only)
            CHECK_ONLY="true"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check AWS CLI installation
check_aws_cli() {
    log "Checking AWS CLI installation..."
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
        echo
        echo "To install AWS CLI on macOS:"
        echo "  brew install awscli"
        echo
        echo "To install AWS CLI on Linux:"
        echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
        echo "  unzip awscliv2.zip"
        echo "  sudo ./aws/install"
        echo
        echo "For other platforms, visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    local aws_version=$(aws --version 2>&1)
    success "AWS CLI installed: $aws_version"
    
    # Check if it's version 2
    if [[ "$aws_version" =~ aws-cli/2\. ]]; then
        success "AWS CLI v2 detected (recommended)"
    else
        warning "AWS CLI v1 detected. Consider upgrading to v2 for better performance"
    fi
}

# Configure AWS credentials
configure_credentials() {
    log "Configuring AWS credentials for profile: $AWS_PROFILE"
    
    if [[ "$CHECK_ONLY" == "true" ]]; then
        log "Check-only mode: skipping credential configuration"
        return 0
    fi
    
    # Check if profile already exists
    if aws configure list --profile "$AWS_PROFILE" &> /dev/null; then
        warning "Profile '$AWS_PROFILE' already exists"
        read -p "Do you want to reconfigure it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Keeping existing configuration"
            return 0
        fi
    fi
    
    echo
    echo "AWS Credential Configuration"
    echo "============================"
    echo
    echo "You'll need:"
    echo "1. AWS Access Key ID"
    echo "2. AWS Secret Access Key"
    echo "3. Default region (e.g., us-east-1, us-west-2, eu-west-1)"
    echo "4. Default output format (json recommended)"
    echo
    echo "To get AWS credentials:"
    echo "1. Go to AWS Console → IAM → Users → Your User → Security Credentials"
    echo "2. Click 'Create access key'"
    echo "3. Choose 'CLI' use case"
    echo "4. Copy the Access Key ID and Secret Access Key"
    echo
    
    read -p "Press Enter to continue with AWS configuration..."
    
    # Run AWS configure
    if [[ "$AWS_PROFILE" == "default" ]]; then
        aws configure set region "$AWS_REGION"
        aws configure
    else
        aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE"
        aws configure --profile "$AWS_PROFILE"
    fi
    
    success "AWS credentials configured for profile: $AWS_PROFILE"
}

# Test AWS connectivity
test_connectivity() {
    log "Testing AWS connectivity..."
    
    local profile_flag=""
    if [[ "$AWS_PROFILE" != "default" ]]; then
        profile_flag="--profile $AWS_PROFILE"
    fi
    
    # Test basic connectivity
    if aws sts get-caller-identity $profile_flag &> /dev/null; then
        local identity=$(aws sts get-caller-identity $profile_flag --output json)
        local account_id=$(echo "$identity" | jq -r '.Account')
        local user_arn=$(echo "$identity" | jq -r '.Arn')
        
        success "AWS connectivity test passed"
        log "Account ID: $account_id"
        log "User ARN: $user_arn"
    else
        error "AWS connectivity test failed"
        error "Please check your credentials and try again"
        return 1
    fi
}

# Validate required permissions
validate_permissions() {
    log "Validating required AWS permissions..."
    
    local profile_flag=""
    if [[ "$AWS_PROFILE" != "default" ]]; then
        profile_flag="--profile $AWS_PROFILE"
    fi
    
    local permissions_ok=true
    
    # Test CloudFormation permissions
    log "Checking CloudFormation permissions..."
    if aws cloudformation list-stacks $profile_flag --region "$AWS_REGION" &> /dev/null; then
        success "CloudFormation access: OK"
    else
        error "CloudFormation access: FAILED"
        permissions_ok=false
    fi
    
    # Test ECS permissions
    log "Checking ECS permissions..."
    if aws ecs list-clusters $profile_flag --region "$AWS_REGION" &> /dev/null; then
        success "ECS access: OK"
    else
        error "ECS access: FAILED"
        permissions_ok=false
    fi
    
    # Test S3 permissions
    log "Checking S3 permissions..."
    if aws s3 ls $profile_flag &> /dev/null; then
        success "S3 access: OK"
    else
        error "S3 access: FAILED"
        permissions_ok=false
    fi
    
    # Test SQS permissions
    log "Checking SQS permissions..."
    if aws sqs list-queues $profile_flag --region "$AWS_REGION" &> /dev/null; then
        success "SQS access: OK"
    else
        error "SQS access: FAILED"
        permissions_ok=false
    fi
    
    # Test IAM permissions
    log "Checking IAM permissions..."
    if aws iam list-roles $profile_flag --max-items 1 &> /dev/null; then
        success "IAM access: OK"
    else
        warning "IAM access: LIMITED (may affect some deployments)"
    fi
    
    if [[ "$permissions_ok" == "true" ]]; then
        success "All required permissions validated"
    else
        error "Some required permissions are missing"
        echo
        echo "Required AWS permissions for AI Testing Agent:"
        echo "- CloudFormation: Full access"
        echo "- ECS: Full access"
        echo "- S3: Full access"
        echo "- SQS: Full access"
        echo "- IAM: CreateRole, AttachRolePolicy, PassRole"
        echo "- EC2: VPC and security group management"
        echo "- Application Load Balancer: Full access"
        echo "- CloudWatch: Logs and metrics"
        echo
        echo "Consider using the 'PowerUserAccess' managed policy or create a custom policy."
        return 1
    fi
}

# Show configuration summary
show_configuration() {
    log "AWS Configuration Summary"
    echo "========================="
    echo "Profile: $AWS_PROFILE"
    echo "Region: $AWS_REGION"
    echo
    
    local profile_flag=""
    if [[ "$AWS_PROFILE" != "default" ]]; then
        profile_flag="--profile $AWS_PROFILE"
    fi
    
    # Show current configuration
    echo "Current AWS Configuration:"
    aws configure list $profile_flag 2>/dev/null || echo "No configuration found"
    echo
    
    # Show identity
    if aws sts get-caller-identity $profile_flag &> /dev/null; then
        echo "AWS Identity:"
        aws sts get-caller-identity $profile_flag --output table
    fi
}

# Create AWS profile configuration file
create_profile_config() {
    local config_file="$SCRIPT_DIR/../config/aws-profiles.yml"
    
    log "Creating AWS profile configuration..."
    
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << EOF
# AWS Profile Configuration for AI Testing Agent
# Generated on $(date -u +%Y-%m-%dT%H:%M:%SZ)

profiles:
  default:
    profile: $AWS_PROFILE
    region: $AWS_REGION
    description: "Default profile for AI Testing Agent"
  
  dev:
    profile: $AWS_PROFILE
    region: $AWS_REGION
    description: "Development environment"
  
  staging:
    profile: $AWS_PROFILE
    region: $AWS_REGION
    description: "Staging environment"
  
  prod:
    profile: $AWS_PROFILE
    region: $AWS_REGION
    description: "Production environment"

# Usage in deployment scripts:
# aws-deploy.sh --env=dev --profile=\${profiles.dev.profile} --region=\${profiles.dev.region}
EOF
    
    success "AWS profile configuration saved: $config_file"
}

# Main setup function
main() {
    log "Starting AWS CLI setup for AI Testing Agent..."
    
    echo
    echo "🚀 AI Testing Agent - AWS Setup"
    echo "==============================="
    echo "Profile: $AWS_PROFILE"
    echo "Region: $AWS_REGION"
    echo "Check Only: $CHECK_ONLY"
    echo
    
    # Step 1: Check AWS CLI
    check_aws_cli
    
    # Step 2: Configure credentials (unless check-only)
    if [[ "$CHECK_ONLY" != "true" ]]; then
        configure_credentials
    fi
    
    # Step 3: Test connectivity
    test_connectivity
    
    # Step 4: Validate permissions
    validate_permissions
    
    # Step 5: Show configuration
    show_configuration
    
    # Step 6: Create profile config (unless check-only)
    if [[ "$CHECK_ONLY" != "true" ]]; then
        create_profile_config
    fi
    
    echo
    success "AWS setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Deploy AI Testing Agent:"
    echo "   $SCRIPT_DIR/aws-deploy.sh --env=dev --region=$AWS_REGION"
    echo
    echo "2. Check deployment health:"
    echo "   $SCRIPT_DIR/health-check.sh --env=dev --region=$AWS_REGION"
    echo
    echo "3. Manage instances:"
    echo "   $SCRIPT_DIR/manage.sh status --env=dev --region=$AWS_REGION"
}

# Error handling
trap 'error "AWS setup failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 