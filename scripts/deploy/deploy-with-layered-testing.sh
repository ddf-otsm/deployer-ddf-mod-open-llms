#!/bin/bash
# DeployerDDF LLM Models - Layered Testing Deployment Script
# Deploys infrastructure and runs progressive testing from Layer 1 to Llama 4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default configuration
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
DEPLOYMENT_TYPE="ecs-fargate"
AUTO_STOP="enabled"
INSTANCE_COUNT=2
DRY_RUN="false"
FORCE="false"
VERBOSE="false"
RUN_TESTS="true"
TEST_LAYER=""
PROGRESSIVE_TESTS="true"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] VERBOSE: $1${NC}"
    fi
}

# Show usage
show_usage() {
    cat << EOF
DeployerDDF LLM Models - Layered Testing Deployment

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --env ENVIRONMENT       Environment (dev|staging|prod) [default: dev]
    -r, --region REGION         AWS region [default: us-east-1]
    -t, --type TYPE            Deployment type (ecs-fargate|ec2-gpu|lambda) [default: ecs-fargate]
    -i, --instances COUNT      Number of instances [default: 2]
    -l, --layer LAYER          Test specific layer only (1-4)
    --auto-stop ENABLED        Auto-stop functionality (enabled|disabled) [default: enabled]
    --no-tests                 Skip layered testing after deployment
    --no-progressive           Run individual layer tests instead of progressive
    --dry-run                  Show what would be deployed without executing
    --force                    Skip confirmation prompts
    --verbose                  Enable verbose logging
    -h, --help                 Show this help message

EXAMPLES:
    # Deploy dev environment with progressive testing
    $0 --env=dev --region=us-east-1

    # Deploy production with specific layer testing
    $0 --env=prod --layer=4 --instances=5

    # Dry run to see deployment plan
    $0 --env=staging --dry-run

    # Deploy without running tests
    $0 --env=dev --no-tests

LAYERED TESTING:
    Layer 1: Basic Assistant (Llama 3.1 8B, Mistral 7B)
    Layer 2: Advanced Assistant (Llama 3.1 70B, CodeLlama 34B)
    Layer 3: Expert Assistant (Future models)
    Layer 4: Enterprise Assistant (Llama 4)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -r|--region)
                AWS_REGION="$2"
                shift 2
                ;;
            -t|--type)
                DEPLOYMENT_TYPE="$2"
                shift 2
                ;;
            -i|--instances)
                INSTANCE_COUNT="$2"
                shift 2
                ;;
            -l|--layer)
                TEST_LAYER="$2"
                PROGRESSIVE_TESTS="false"
                shift 2
                ;;
            --auto-stop)
                AUTO_STOP="$2"
                shift 2
                ;;
            --no-tests)
                RUN_TESTS="false"
                shift
                ;;
            --no-progressive)
                PROGRESSIVE_TESTS="false"
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
            --verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Validate configuration
validate_config() {
    log "Validating configuration..."

    # Check if configuration files exist
    local config_file="$PROJECT_ROOT/../config/llm-models.json"
    if [[ ! -f "$config_file" ]]; then
        error "LLM models configuration not found: $config_file"
        exit 1
    fi

    # Validate JSON schema
    if command -v ajv &> /dev/null; then
        local schema_file="$PROJECT_ROOT/../config/schemas/llm-models-schema.json"
        if [[ -f "$schema_file" ]]; then
            verbose "Validating configuration against JSON schema..."
            if ajv validate -s "$schema_file" -d "$config_file"; then
                success "Configuration validation passed"
            else
                error "Configuration validation failed"
                exit 1
            fi
        else
            warning "JSON schema not found, skipping validation"
        fi
    else
        warning "ajv not installed, skipping JSON schema validation"
    fi

    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod"
        exit 1
    fi

    # Validate layer if specified
    if [[ -n "$TEST_LAYER" ]] && [[ ! "$TEST_LAYER" =~ ^[1-4]$ ]]; then
        error "Invalid layer: $TEST_LAYER. Must be 1, 2, 3, or 4"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured or invalid"
        exit 1
    fi

    success "Configuration validation completed"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    # Check required commands
    local required_commands=("aws" "docker" "node" "npm")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: $cmd"
            exit 1
        fi
    done

    # Check Node.js version
    local node_version=$(node --version | cut -d'v' -f2)
    local required_version="18.0.0"
    if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
        error "Node.js version $node_version is too old. Required: $required_version+"
        exit 1
    fi

    # Check if TypeScript CLI is available
    if ! npm list -g typescript &> /dev/null; then
        warning "TypeScript not installed globally, installing..."
        npm install -g typescript
    fi

    success "Prerequisites check completed"
}

# Deploy AWS infrastructure
deploy_infrastructure() {
    log "Deploying AWS infrastructure..."

    local stack_name="deployer-ddf-llm-models-${ENVIRONMENT}"
    local template_file="$SCRIPT_DIR/templates/master-stack.yml"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN - Would deploy CloudFormation stack:"
        log "  Stack Name: $stack_name"
        log "  Environment: $ENVIRONMENT"
        log "  Type: $DEPLOYMENT_TYPE"
        log "  Region: $AWS_REGION"
        log "  Instances: $INSTANCE_COUNT"
        log "  Auto-Stop: $AUTO_STOP"
        return 0
    fi

    # Confirmation prompt
    if [[ "$FORCE" != "true" ]]; then
        echo
        warning "You are about to deploy DeployerDDF LLM Models infrastructure:"
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

    # Deploy the stack
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
            Project=deployer-ddf-llm-models \
            Environment="$ENVIRONMENT" \
            DeploymentType="$DEPLOYMENT_TYPE" \
            AutoStop="$AUTO_STOP" \
            ManagedBy=layered-testing-deployment

    if [[ $? -eq 0 ]]; then
        success "Infrastructure deployment completed successfully!"
    else
        error "Infrastructure deployment failed"
        exit 1
    fi
}

# Build and deploy testing framework
deploy_testing_framework() {
    log "Building and deploying testing framework..."

    cd "$PROJECT_ROOT"

    # Install dependencies
    if [[ ! -d "node_modules" ]]; then
        log "Installing Node.js dependencies..."
        npm install
    fi

    # Build TypeScript
    log "Building TypeScript code..."
    npx tsc --build

    # Copy configuration files
    log "Copying configuration files..."
    mkdir -p dist/config
    cp -r "$PROJECT_ROOT/../config/"* dist/config/

    success "Testing framework built successfully"
}

# Run layered tests
run_layered_tests() {
    if [[ "$RUN_TESTS" != "true" ]]; then
        log "Skipping layered tests (--no-tests specified)"
        return 0
    fi

    log "Running layered tests..."

    cd "$PROJECT_ROOT"

    # Prepare test command
    local test_cmd="node dist/cli/run-layered-tests.js"
    test_cmd="$test_cmd --environment $ENVIRONMENT"
    test_cmd="$test_cmd --config dist/config/llm-models.json"

    if [[ "$VERBOSE" == "true" ]]; then
        test_cmd="$test_cmd --verbose"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        test_cmd="$test_cmd --dry-run"
    fi

    # Add layer-specific or progressive testing
    if [[ -n "$TEST_LAYER" ]]; then
        test_cmd="$test_cmd --layer $TEST_LAYER"
        log "Running Layer $TEST_LAYER tests..."
    elif [[ "$PROGRESSIVE_TESTS" == "true" ]]; then
        test_cmd="$test_cmd --progressive"
        log "Running progressive tests (Layer 1 → Layer 4)..."
    else
        log "Running all layer tests..."
    fi

    # Add output file
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="test-results-${ENVIRONMENT}-${timestamp}.json"
    test_cmd="$test_cmd --output $output_file"

    # Execute tests
    verbose "Executing: $test_cmd"
    
    if eval "$test_cmd"; then
        success "Layered testing completed successfully!"
        if [[ "$DRY_RUN" != "true" ]]; then
            log "Test results saved to: $output_file"
        fi
    else
        error "Layered testing failed"
        exit 1
    fi
}

# Run health checks
run_health_checks() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN - Would run health checks"
        return 0
    fi

    log "Running post-deployment health checks..."

    # Check CloudFormation stack status
    local stack_name="deployer-ddf-llm-models-${ENVIRONMENT}"
    local stack_status=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "NOT_FOUND")

    if [[ "$stack_status" == "CREATE_COMPLETE" ]] || [[ "$stack_status" == "UPDATE_COMPLETE" ]]; then
        success "CloudFormation stack is healthy: $stack_status"
    else
        warning "CloudFormation stack status: $stack_status"
    fi

    # Additional health checks can be added here
    success "Health checks completed"
}

# Generate deployment summary
generate_summary() {
    log "Generating deployment summary..."

    echo
    echo "🎯 DEPLOYMENT SUMMARY"
    echo "═".repeat(50)
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "Instance Count: $INSTANCE_COUNT"
    echo "Auto-Stop: $AUTO_STOP"
    echo
    
    if [[ "$RUN_TESTS" == "true" ]]; then
        echo "🧪 TESTING SUMMARY"
        echo "─".repeat(30)
        if [[ -n "$TEST_LAYER" ]]; then
            echo "Test Scope: Layer $TEST_LAYER only"
        elif [[ "$PROGRESSIVE_TESTS" == "true" ]]; then
            echo "Test Scope: Progressive (Layer 1 → Layer 4)"
        else
            echo "Test Scope: All layers"
        fi
        echo
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🔍 DRY RUN COMPLETED"
        echo "No actual deployment or testing was performed."
        echo "Run without --dry-run to execute the deployment."
    else
        echo "✅ DEPLOYMENT COMPLETED SUCCESSFULLY"
        echo
        echo "Next steps:"
        echo "1. Monitor CloudWatch logs for application health"
        echo "2. Review test results for model performance"
        echo "3. Scale instances based on workload requirements"
        echo "4. Set up monitoring and alerting"
    fi
    echo
}

# Main execution
main() {
    echo "🚀 DeployerDDF LLM Models - Layered Testing Deployment"
    echo "═".repeat(60)
    echo

    parse_args "$@"
    validate_config
    check_prerequisites
    deploy_infrastructure
    deploy_testing_framework
    run_layered_tests
    run_health_checks
    generate_summary
}

# Error handling
trap 'error "Script failed on line $LINENO"' ERR

# Run main function
main "$@" 