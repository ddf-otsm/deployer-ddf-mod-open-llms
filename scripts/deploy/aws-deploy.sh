#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh
# Main AWS deployment script for AI Testing Agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load AWS environment securely (no credentials in command line)
if [ -f "$SCRIPT_DIR/setup-env.sh" ]; then
    source "$SCRIPT_DIR/setup-env.sh" --env-file="$PROJECT_ROOT/.env"
else
    echo "Warning: setup-env.sh not found. Ensure AWS credentials are set in environment."
fi

# Load authentication configuration
load_auth_config() {
    local auth_config="$PROJECT_ROOT/config/auth-config.yml"
    
    if [ ! -f "$auth_config" ]; then
        error "Authentication configuration not found: $auth_config"
        exit 1
    fi
    
    log "Loading authentication configuration from: $auth_config"
    
    # Extract auth method for current environment
    AUTH_METHOD=$(yq eval ".environments.${ENVIRONMENT}.authentication.method // .authentication.method" "$auth_config" 2>/dev/null || echo "api_token")
    
    log "Authentication method for $ENVIRONMENT: $AUTH_METHOD"
    
    # Validate auth method is supported
    case "$AUTH_METHOD" in
        "api_token"|"iam_role"|"mtls"|"none")
            log "✅ Authentication method '$AUTH_METHOD' is supported"
            ;;
        *)
            error "Unsupported authentication method: $AUTH_METHOD"
            exit 1
            ;;
    esac
    
    export AUTH_METHOD
}

# Default configuration
ENVIRONMENT="dev"
DEPLOYMENT_TYPE="ecs-fargate"
AWS_REGION="us-east-1"
AUTO_STOP="enabled"
INSTANCE_COUNT="2"
DRY_RUN="false"
FORCE="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy AI Testing Agent to AWS with distributed testing capabilities.

OPTIONS:
    --env=ENV               Environment (dev|staging|prod) [default: dev]
    --type=TYPE            Deployment type (ecs-fargate|ec2-gpu|lambda) [default: ecs-fargate]
    --region=REGION        AWS region [default: us-east-1]
    --instances=COUNT      Number of instances [default: 2]
    --auto-stop=BOOL       Enable auto-stop (enabled|disabled) [default: enabled]
    --dry-run             Show what would be deployed without executing
    --force               Skip confirmation prompts
    --help                Show this help message

EXAMPLES:
    $0 --env=prod --type=ecs-fargate --instances=5
    $0 --env=dev --type=lambda --dry-run
    $0 --env=staging --type=ec2-gpu --auto-stop=disabled

DEPLOYMENT TYPES:
    ecs-fargate           Serverless containers (recommended for cost optimization)
    ec2-gpu              GPU instances for intensive AI workloads
    lambda               Serverless functions for lightweight testing

ENVIRONMENTS:
    dev                  Development environment with minimal resources
    staging              Staging environment for testing
    prod                 Production environment with full resources

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

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --type=*)
            DEPLOYMENT_TYPE="${1#*=}"
            shift
            ;;
        --region=*)
            AWS_REGION="${1#*=}"
            shift
            ;;
        --instances=*)
            INSTANCE_COUNT="${1#*=}"
            shift
            ;;
        --auto-stop=*)
            AUTO_STOP="${1#*=}"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
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

# Validate inputs
validate_inputs() {
    log "Validating deployment parameters..."
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
        exit 1
    fi
    
    # Validate deployment type
    if [[ ! "$DEPLOYMENT_TYPE" =~ ^(ecs-fargate|ec2-gpu|lambda)$ ]]; then
        error "Invalid deployment type: $DEPLOYMENT_TYPE. Must be ecs-fargate, ec2-gpu, or lambda."
        exit 1
    fi
    
    # Validate instance count
    if ! [[ "$INSTANCE_COUNT" =~ ^[0-9]+$ ]] || [ "$INSTANCE_COUNT" -lt 1 ] || [ "$INSTANCE_COUNT" -gt 20 ]; then
        error "Invalid instance count: $INSTANCE_COUNT. Must be between 1 and 20."
        exit 1
    fi
    
    # Validate auto-stop
    if [[ ! "$AUTO_STOP" =~ ^(enabled|disabled)$ ]]; then
        error "Invalid auto-stop value: $AUTO_STOP. Must be enabled or disabled."
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    success "All parameters validated successfully"
}

# Check prerequisites
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed. Please install Node.js first."
        exit 1
    fi
    
    # Check if AI Testing Agent is built
    if [ ! -f "$PROJECT_ROOT/package.json" ]; then
        error "AI Testing Agent package.json not found. Please ensure you're in the correct directory."
        exit 1
    fi
    
    success "All prerequisites satisfied"
}

# Build Docker image
build_docker_image() {
    log "Building Docker image for AI Testing Agent..."
    
    local image_tag="deployer-ddf-mod-llm-models:${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN - Would build Docker image: $image_tag"
        return 0
    fi
    
    cd "$PROJECT_ROOT"
    
    # Build the image
    if docker build -t "$image_tag" -f docker/Dockerfile.prod .; then
        success "Docker image built successfully: $image_tag"
        echo "$image_tag" > "$SCRIPT_DIR/.last-image-tag"
    else
        error "Failed to build Docker image"
        exit 1
    fi
}

# Deploy CloudFormation stack
deploy_stack() {
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    local template_file="$SCRIPT_DIR/templates/master-stack.yml"
    
    log "Deploying AI Testing Agent to AWS..."
    log "Environment: $ENVIRONMENT"
    log "Type: $DEPLOYMENT_TYPE"
    log "Region: $AWS_REGION"
    log "Instances: $INSTANCE_COUNT"
    log "Auto-Stop: $AUTO_STOP"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN - Would deploy CloudFormation stack with parameters:"
        log "  Stack Name: $stack_name"
        log "  Template: $template_file"
        log "  Environment: $ENVIRONMENT"
        log "  DeploymentType: $DEPLOYMENT_TYPE"
        log "  InstanceCount: $INSTANCE_COUNT"
        log "  AutoStop: $AUTO_STOP"
        
        # Validate template
        if [ -f "$template_file" ]; then
            aws cloudformation validate-template \
                --template-body "file://$template_file" \
                --region "$AWS_REGION"
            success "CloudFormation template validation passed"
        else
            warning "CloudFormation template not found: $template_file"
        fi
        return 0
    fi
    
    # Confirmation prompt
    if [[ "$FORCE" != "true" ]]; then
        echo
        warning "You are about to deploy AI Testing Agent to AWS with the following configuration:"
        echo "  Environment: $ENVIRONMENT"
        echo "  Deployment Type: $DEPLOYMENT_TYPE"
        echo "  Region: $AWS_REGION"
        echo "  Instance Count: $INSTANCE_COUNT"
        echo "  Auto-Stop: $AUTO_STOP"
        echo
        read -p "Do you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled by user"
            exit 0
        fi
    fi
    
    # Check if template exists
    if [ ! -f "$template_file" ]; then
        error "CloudFormation template not found: $template_file"
        error "Please create the template first or run with --dry-run to see what would be deployed"
        exit 1
    fi
    
    # Deploy the stack
    log "Deploying CloudFormation stack: $stack_name"
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            DeploymentType="$DEPLOYMENT_TYPE" \
            InstanceCount="$INSTANCE_COUNT" \
            AutoStop="$AUTO_STOP" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region "$AWS_REGION" \
        --tags \
            Project=deployer-ddf-mod-llm-models \
            Environment="$ENVIRONMENT" \
            DeploymentType="$DEPLOYMENT_TYPE" \
            AutoStop="$AUTO_STOP" \
            ManagedBy=aws-deploy-script
    
    if [ $? -eq 0 ]; then
        success "CloudFormation stack deployed successfully!"
    else
        error "CloudFormation deployment failed"
        exit 1
    fi
}

# Run health checks
run_health_checks() {
    log "Running post-deployment health checks..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN - Would run health checks after deployment"
        return 0
    fi
    
    # Run health check script
    if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
        "$SCRIPT_DIR/health-check.sh" --env="$ENVIRONMENT" --region="$AWS_REGION"
    else
        warning "Health check script not found: $SCRIPT_DIR/health-check.sh"
        warning "Skipping health checks"
    fi
}

# Display deployment summary
show_deployment_summary() {
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    log "Deployment Summary"
    echo "=================="
    echo "Stack Name: $stack_name"
    echo "Environment: $ENVIRONMENT"
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "Region: $AWS_REGION"
    echo "Instance Count: $INSTANCE_COUNT"
    echo "Auto-Stop: $AUTO_STOP"
    echo
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log "Getting stack outputs..."
        
        # Get stack outputs
        local outputs=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs' \
            --output table 2>/dev/null || echo "No outputs available")
        
        echo "Stack Outputs:"
        echo "$outputs"
        echo
        
        success "AI Testing Agent deployed successfully!"
        log "You can manage the deployment using:"
        log "  $SCRIPT_DIR/manage.sh --env=$ENVIRONMENT --region=$AWS_REGION"
        log "  $SCRIPT_DIR/health-check.sh --env=$ENVIRONMENT --region=$AWS_REGION"
    else
        success "Dry run completed successfully!"
        log "To deploy for real, run the same command without --dry-run"
    fi
}

# Main deployment function
main() {
    log "Starting AI Testing Agent AWS deployment..."
    
    validate_inputs
    check_prerequisites
    load_auth_config
    build_docker_image
    deploy_stack
    run_health_checks
    show_deployment_summary
    
    success "Deployment process completed!"
}

# Error handling
trap 'error "Deployment failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 