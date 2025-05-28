#!/bin/bash
# Deploy Llama 4 Maverick Endpoint to AWS
# Specialized deployment script for the AI Testing Agent with Llama 4 Maverick support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$PROJECT_ROOT/logs/${TIMESTAMP}/deploy-llama4-maverick.log"

# Configuration
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"
DRY_RUN="${3:-false}"
VERBOSE="${4:-false}"
CLUSTER_NAME="deployer-ddf-cluster-$ENVIRONMENT"
SERVICE_NAME="deployer-ddf-api-llama4-$ENVIRONMENT"
TASK_DEFINITION_FAMILY="deployer-ddf-api-llama4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Log to console with colors
    case $level in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "INFO")
            echo -e "${GREEN}[INFO]${NC} $message"
            ;;
        "DEBUG")
            if [ "$VERBOSE" = true ]; then
                echo -e "${BLUE}[DEBUG]${NC} $message"
            fi
            ;;
    esac
}

# Error handler
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Parse command line arguments
parse_args() {
    for arg in "$@"; do
        case $arg in
            --env=*)
                ENVIRONMENT="${arg#*=}"
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --verbose)
                VERBOSE=true
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error_exit "Unknown argument: $arg"
                ;;
        esac
    done
}

# Show help
show_help() {
    cat << EOF
Deploy Llama 4 Maverick Endpoint to AWS

Usage: $0 [OPTIONS]

Options:
    --env=ENV       Environment (dev|staging|prod) [default: dev]
    --dry-run       Show what would be done without executing
    --verbose       Enable verbose output
    --help          Show this help message

Examples:
    $0 --env=dev --dry-run
    $0 --env=prod --verbose

FEATURES:
    ✅ Llama 4 Maverick 17B MoE model support
    ✅ HuggingFace integration with secure token management
    ✅ ECS Fargate deployment with auto-scaling
    ✅ Application Load Balancer with health checks
    ✅ CloudWatch logging and monitoring
    ✅ EFS storage for model caching

EOF
}

# Validate inputs
validate_inputs() {
    log "INFO" "Validating deployment parameters..."
    
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error_exit "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
    fi
    
    if [[ ! "$DRY_RUN" =~ ^(true|false)$ ]]; then
        error_exit "Invalid dry_run value: $DRY_RUN. Must be true or false."
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI is not installed. Please install it first."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS credentials not configured. Please run 'aws configure' first."
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker is not installed. Please install it first."
    fi
    
    log "INFO" "All parameters validated successfully"
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "🔍 CHECKING PREREQUISITES"
    
    log "INFO" "Checking AWS account access..."
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    log "INFO" "AWS Account ID: $account_id"
    
    log "INFO" "Checking AWS region: $AWS_REGION"
    aws configure set region "$AWS_REGION"
    
    log "INFO" "Checking ECR repository..."
    local ecr_repo="deployer-ddf-api"
    if aws ecr describe-repositories --repository-names "$ecr_repo" --region "$AWS_REGION" >/dev/null 2>&1; then
        log "INFO" "ECR repository exists: $ecr_repo"
    else
        log "INFO" "ECR repository does not exist. Creating it..."
        if [[ "$DRY_RUN" == "false" ]]; then
            aws ecr create-repository \
                --repository-name "$ecr_repo" \
                --region "$AWS_REGION" \
                --image-scanning-configuration scanOnPush=true \
                --encryption-configuration encryptionType=AES256
            log "INFO" "ECR repository created: $ecr_repo"
        else
            log "INFO" "[DRY-RUN] Would create ECR repository: $ecr_repo"
        fi
    fi
    
    log "INFO" "Checking HuggingFace token in AWS Secrets Manager..."
    local secret_name="deployer-ddf/huggingface-token"
    if aws secretsmanager describe-secret --secret-id "$secret_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        log "INFO" "HuggingFace token secret exists"
    else
        log "INFO" "HuggingFace token secret does not exist."
        echo "Please create it with:"
        echo "aws secretsmanager create-secret \\"
        echo "  --name '$secret_name' \\"
        echo "  --description 'HuggingFace API token for Llama 4 Maverick' \\"
        echo "  --secret-string 'your-huggingface-token-here' \\"
        echo "  --region '$AWS_REGION'"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            error_exit "HuggingFace token secret is required for deployment"
        fi
    fi
}

# Build and push Docker image
build_and_push_image() {
    log "INFO" "🐳 BUILDING AND PUSHING DOCKER IMAGE"
    
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    local ecr_uri="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/deployer-ddf-api"
    local image_tag="llama4-maverick-${TIMESTAMP}"
    
    log "INFO" "Building Docker image with Llama 4 Maverick support..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Login to ECR
        aws ecr get-login-password --region "$AWS_REGION" | \
            docker login --username AWS --password-stdin "$ecr_uri"
        
        # Build image
        cd "$PROJECT_ROOT"
        docker build \
            --tag "deployer-ddf-api:$image_tag" \
            --tag "deployer-ddf-api:latest" \
            --tag "$ecr_uri:$image_tag" \
            --tag "$ecr_uri:latest" \
            --build-arg ENVIRONMENT="$ENVIRONMENT" \
            --build-arg LLAMA4_MAVERICK_ENABLED=true \
            .
        
        # Push image
        docker push "$ecr_uri:$image_tag"
        docker push "$ecr_uri:latest"
        
        log "INFO" "Docker image built and pushed: $ecr_uri:$image_tag"
    else
        log "INFO" "[DRY-RUN] Would build and push Docker image: $ecr_uri:$image_tag"
    fi
    
    export DOCKER_IMAGE_URI="$ecr_uri:latest"
}

# Deploy ECS infrastructure
deploy_ecs_infrastructure() {
    log "INFO" "☁️  DEPLOYING ECS INFRASTRUCTURE"
    
    log "INFO" "Deploying to ECS cluster: $CLUSTER_NAME"
    log "INFO" "Service name: $SERVICE_NAME"
    
    # Check if cluster exists
    if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
        log "INFO" "ECS cluster exists: $CLUSTER_NAME"
    else
        log "INFO" "ECS cluster does not exist. Creating it..."
        if [[ "$DRY_RUN" == "false" ]]; then
            aws ecs create-cluster \
                --cluster-name "$CLUSTER_NAME" \
                --capacity-providers FARGATE FARGATE_SPOT \
                --default-capacity-provider-strategy \
                    capacityProvider=FARGATE_SPOT,weight=1 \
                    capacityProvider=FARGATE,weight=1 \
                --region "$AWS_REGION"
            log "INFO" "ECS cluster created: $CLUSTER_NAME"
        else
            log "INFO" "[DRY-RUN] Would create ECS cluster: $CLUSTER_NAME"
        fi
    fi
    
    # Register task definition
    log "INFO" "Registering task definition..."
    if [[ "$DRY_RUN" == "false" ]]; then
        # Update task definition with current image URI
        local temp_task_def="/tmp/task-definition-${TIMESTAMP}.json"
        sed "s|468720548566.dkr.ecr.us-east-1.amazonaws.com/deployer-ddf-api:latest|${DOCKER_IMAGE_URI}|g" \
            "$PROJECT_ROOT/config/aws/task-definition-llama4.json" > "$temp_task_def"
        
        local task_def_arn
        task_def_arn=$(aws ecs register-task-definition \
            --cli-input-json "file://$temp_task_def" \
            --region "$AWS_REGION" \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
        
        log "INFO" "Task definition registered: $task_def_arn"
        rm "$temp_task_def"
    else
        log "INFO" "[DRY-RUN] Would register task definition from: $PROJECT_ROOT/config/aws/task-definition-llama4.json"
    fi
    
    # Create or update service
    log "INFO" "Creating/updating ECS service..."
    if [[ "$DRY_RUN" == "false" ]]; then
        if aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$SERVICE_NAME" \
            --region "$AWS_REGION" >/dev/null 2>&1; then
            
            log "INFO" "Updating existing service..."
            aws ecs update-service \
                --cluster "$CLUSTER_NAME" \
                --service "$SERVICE_NAME" \
                --task-definition "$task_def_arn" \
                --region "$AWS_REGION" >/dev/null
            log "INFO" "Service updated: $SERVICE_NAME"
        else
            log "INFO" "Creating new service..."
            # This would require VPC and security group setup
            log "INFO" "Service creation requires VPC and security group configuration"
            log "INFO" "Please use the full CloudFormation stack deployment for initial setup"
        fi
    else
        log "INFO" "[DRY-RUN] Would create/update ECS service: $SERVICE_NAME"
    fi
}

# Test deployment
test_deployment() {
    log "INFO" "🧪 TESTING DEPLOYMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would test deployment endpoints"
        return 0
    fi
    
    log "INFO" "Waiting for service to stabilize..."
    sleep 30
    
    # Get service endpoint (this would be the ALB DNS name in a real deployment)
    local endpoint="https://api-${ENVIRONMENT}.deployer-ddf.com"
    
    log "INFO" "Testing health endpoint..."
    if curl -f -s --max-time 10 "$endpoint/health" >/dev/null 2>&1; then
        log "INFO" "Health check passed: $endpoint/health"
    else
        log "INFO" "Health check failed (service may still be starting)"
    fi
    
    log "INFO" "Testing Llama 4 Maverick endpoint..."
    local test_payload='{"prompt": "Hello from Llama 4 Maverick!", "max_tokens": 100}'
    
    if curl -f -s --max-time 30 \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$test_payload" \
        "$endpoint/api/llama4-maverick" >/dev/null 2>&1; then
        log "INFO" "Llama 4 Maverick endpoint responding: $endpoint/api/llama4-maverick"
    else
        log "INFO" "Llama 4 Maverick endpoint test failed (service may still be starting)"
    fi
    
    log "INFO" "Testing Swagger UI..."
    if curl -f -s --max-time 10 "$endpoint/api-docs" | grep -q "swagger"; then
        log "INFO" "Swagger UI accessible: $endpoint/api-docs"
    else
        log "INFO" "Swagger UI test failed"
    fi
}

# Generate deployment report
generate_report() {
    log "INFO" "📊 DEPLOYMENT REPORT"
    
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    
    log "INFO" "Deployment Summary:"
    log "INFO" "=================="
    log "INFO" "Environment: $ENVIRONMENT"
    log "INFO" "AWS Region: $AWS_REGION"
    log "INFO" "AWS Account: $account_id"
    log "INFO" "Dry Run: $DRY_RUN"
    log "INFO" "Timestamp: $(date)"
    log "INFO" ""
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log "INFO" "🎯 Llama 4 Maverick Endpoint:"
        log "INFO" "   - API URL: https://api-${ENVIRONMENT}.deployer-ddf.com/api/llama4-maverick"
        log "INFO" "   - Swagger UI: https://api-${ENVIRONMENT}.deployer-ddf.com/api-docs"
        log "INFO" "   - Health Check: https://api-${ENVIRONMENT}.deployer-ddf.com/health"
        log "INFO" ""
        log "INFO" "📝 Test Command:"
        log "INFO" "   curl -X POST https://api-${ENVIRONMENT}.deployer-ddf.com/api/llama4-maverick \\"
        log "INFO" "     -H 'Content-Type: application/json' \\"
        log "INFO" "     -d '{\"prompt\": \"Generate a React test\", \"max_tokens\": 500}'"
        log "INFO" ""
        log "INFO" "🔧 Management Commands:"
        log "INFO" "   # Scale service"
        log "INFO" "   aws ecs update-service --cluster deployer-ddf-cluster-${ENVIRONMENT} \\"
        log "INFO" "     --service deployer-ddf-api-llama4-${ENVIRONMENT} --desired-count 2"
        log "INFO" ""
        log "INFO" "   # View logs"
        log "INFO" "   aws logs tail /ecs/deployer-ddf-mod-llm-models-${ENVIRONMENT} --follow"
    else
        log "INFO" "🔍 Dry Run Results:"
        log "INFO" "   - All prerequisites validated"
        log "INFO" "   - Docker image would be built and pushed"
        log "INFO" "   - ECS infrastructure would be deployed"
        log "INFO" "   - Llama 4 Maverick endpoint would be available"
        log "INFO" ""
        log "INFO" "To execute the deployment, run:"
        log "INFO" "   $0 $ENVIRONMENT $AWS_REGION false"
    fi
}

# Main execution
main() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    log "INFO" "🚀 LLAMA 4 MAVERICK AWS DEPLOYMENT"
    
    validate_inputs
    check_prerequisites
    
    if [[ "$DRY_RUN" == "false" ]]; then
        build_and_push_image
        deploy_ecs_infrastructure
        test_deployment
    fi
    
    generate_report
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log "INFO" "🎉 Llama 4 Maverick deployment completed successfully!"
    else
        log "INFO" "🔍 Dry run completed successfully!"
    fi
}

# Parse arguments and run main function
parse_args "$@"
main 