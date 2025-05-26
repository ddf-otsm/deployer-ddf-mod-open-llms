#!/bin/bash
# AI Testing Agent - Secure Deployment Wrapper
# Professional deployment script with secure credential handling

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Securely deploy AI Testing Agent to AWS with proper credential handling.

OPTIONS:
    --env=ENV               Environment (dev|staging|prod) [default: dev]
    --type=TYPE            Deployment type (ecs-fargate|ec2-gpu|lambda) [default: ecs-fargate]
    --region=REGION        AWS region [default: us-east-1]
    --instances=COUNT      Number of instances [default: 2]
    --auto-stop=BOOL       Enable auto-stop (enabled|disabled) [default: enabled]
    --env-file=FILE        Path to environment file [default: .env]
    --dry-run             Show what would be deployed without executing
    --force               Skip confirmation prompts
    --help                Show this help message

SECURITY FEATURES:
    ✅ Credentials loaded from .env file (never exposed in command line)
    ✅ Temporary credential files are automatically cleaned up
    ✅ Credential masking in all log outputs
    ✅ No credential exposure in process lists

EXAMPLES:
    $0 --env=dev                         # Deploy to development
    $0 --env=prod --instances=5          # Deploy to production with 5 instances
    $0 --env=staging --dry-run           # Preview staging deployment
    $0 --env-file=.env.prod --env=prod   # Use specific environment file

ENVIRONMENT FILE FORMAT (.env):
    AWS_ACCESS_KEY_ID=AKIA...
    AWS_SECRET_ACCESS_KEY=...
    AWS_DEFAULT_REGION=us-east-1

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

# Default values
ENVIRONMENT="dev"
DEPLOYMENT_TYPE="ecs-fargate"
AWS_REGION="us-east-1"
AUTO_STOP="enabled"
INSTANCE_COUNT="2"
ENV_FILE="${PROJECT_ROOT}/.env"
DRY_RUN="false"
FORCE="false"

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
        --env-file=*)
            ENV_FILE="${1#*=}"
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

# Validate environment file exists
if [[ ! -f "$ENV_FILE" ]]; then
    error "Environment file not found: $ENV_FILE"
    error "Please create the file with your AWS credentials:"
    echo ""
    echo "AWS_ACCESS_KEY_ID=your_access_key"
    echo "AWS_SECRET_ACCESS_KEY=your_secret_key"
    echo "AWS_DEFAULT_REGION=us-east-1"
    exit 1
fi

log "🚀 AI Testing Agent - Secure AWS Deployment"
log "Environment: $ENVIRONMENT"
log "Deployment Type: $DEPLOYMENT_TYPE"
log "Region: $AWS_REGION"
log "Instances: $INSTANCE_COUNT"
log "Auto-Stop: $AUTO_STOP"
log "Credentials: $ENV_FILE"

# Set up AWS environment securely
log "Setting up AWS environment securely..."
if [[ -f "$SCRIPT_DIR/setup-env.sh" ]]; then
    ENV_TEMP_FILE=$("$SCRIPT_DIR/setup-env.sh" --env-file="$ENV_FILE" --region="$AWS_REGION")
    if [[ -n "$ENV_TEMP_FILE" && -f "$ENV_TEMP_FILE" ]]; then
        source "$ENV_TEMP_FILE"
        success "AWS environment loaded securely"
        
        # Clean up temp file immediately after sourcing
        rm -f "$ENV_TEMP_FILE" 2>/dev/null || true
    else
        error "Failed to set up AWS environment"
        exit 1
    fi
else
    error "setup-env.sh not found. Please ensure the deployment scripts are complete."
    exit 1
fi

# Confirmation prompt (unless --force is used)
if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
    echo ""
    warning "You are about to deploy to AWS with the following configuration:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Type: $DEPLOYMENT_TYPE"
    echo "  Region: $AWS_REGION"
    echo "  Instances: $INSTANCE_COUNT"
    echo "  Auto-Stop: $AUTO_STOP"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
fi

# Build deployment arguments
DEPLOY_ARGS=(
    "--env=$ENVIRONMENT"
    "--type=$DEPLOYMENT_TYPE"
    "--region=$AWS_REGION"
    "--instances=$INSTANCE_COUNT"
    "--auto-stop=$AUTO_STOP"
)

if [[ "$DRY_RUN" == "true" ]]; then
    DEPLOY_ARGS+=("--dry-run")
fi

if [[ "$FORCE" == "true" ]]; then
    DEPLOY_ARGS+=("--force")
fi

# Execute the actual deployment script
log "Executing deployment with secure credentials..."
if [[ -f "$SCRIPT_DIR/aws-deploy.sh" ]]; then
    exec "$SCRIPT_DIR/aws-deploy.sh" "${DEPLOY_ARGS[@]}"
else
    error "aws-deploy.sh not found. Please ensure the deployment scripts are complete."
    exit 1
fi 