#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/health-check.sh
# Service health verification for AI Testing Agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
TIMEOUT="300"
VERBOSE="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Verify health and functionality of deployed AI Testing Agent.

OPTIONS:
    --env=ENV               Environment (dev|staging|prod) [default: dev]
    --region=REGION        AWS region [default: us-east-1]
    --timeout=SECONDS      Health check timeout [default: 300]
    --verbose              Enable verbose output
    --help                 Show this help message

EXAMPLES:
    $0 --env=prod --region=us-west-2
    $0 --env=dev --timeout=600 --verbose
    $0 --env=staging

HEALTH CHECKS:
    - CloudFormation stack status
    - Service endpoint availability
    - LLM model availability
    - Performance benchmarking
    - Distributed testing capability
    - Auto-stop functionality

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

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --region=*)
            AWS_REGION="${1#*=}"
            shift
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE="true"
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
    log "Validating health check parameters..."
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
        exit 1
    fi
    
    # Validate timeout
    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT" -lt 30 ] || [ "$TIMEOUT" -gt 3600 ]; then
        error "Invalid timeout: $TIMEOUT. Must be between 30 and 3600 seconds."
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
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        error "curl is not installed. Please install curl first."
        exit 1
    fi
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install jq first."
        exit 1
    fi
    
    success "All parameters validated successfully"
}

# Check CloudFormation stack status
check_stack_status() {
    log "Checking CloudFormation stack status..."
    
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    verbose "Checking stack: $stack_name in region: $AWS_REGION"
    
    # Check if stack exists
    if ! aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" &> /dev/null; then
        error "CloudFormation stack not found: $stack_name"
        return 1
    fi
    
    # Get stack status
    local stack_status=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text)
    
    verbose "Stack status: $stack_status"
    
    case "$stack_status" in
        "CREATE_COMPLETE"|"UPDATE_COMPLETE")
            success "CloudFormation stack is healthy: $stack_status"
            return 0
            ;;
        "CREATE_IN_PROGRESS"|"UPDATE_IN_PROGRESS")
            warning "CloudFormation stack is updating: $stack_status"
            return 0
            ;;
        *)
            error "CloudFormation stack is in unhealthy state: $stack_status"
            return 1
            ;;
    esac
}

# Get service endpoints
get_service_endpoints() {
    log "Getting service endpoints..."
    
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    # Get service endpoints from stack outputs
    local endpoints=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ServiceEndpoints`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    if [[ -z "$endpoints" ]]; then
        warning "No service endpoints found in stack outputs"
        # Try to get from ECS service
        local cluster_name=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$AWS_REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
            --output text 2>/dev/null || echo "")
        
        if [[ -n "$cluster_name" ]]; then
            verbose "Found cluster: $cluster_name"
            # For now, return a placeholder endpoint
            endpoints="http://localhost:11434"
        fi
    fi
    
    if [[ -z "$endpoints" ]]; then
        error "Could not determine service endpoints"
        return 1
    fi
    
    verbose "Service endpoints: $endpoints"
    echo "$endpoints"
}

# Check service endpoint health
check_endpoint_health() {
    local endpoint="$1"
    
    log "Checking endpoint health: $endpoint"
    
    # Health check endpoint
    local health_url="${endpoint}/health"
    if [[ "$endpoint" == *"localhost:11434"* ]]; then
        health_url="${endpoint}/api/tags"
    fi
    
    verbose "Health check URL: $health_url"
    
    # Try to connect with timeout
    local start_time=$(date +%s)
    local max_time=$((start_time + TIMEOUT))
    
    while [ $(date +%s) -lt $max_time ]; do
        if curl -f -s --max-time 10 "$health_url" > /dev/null 2>&1; then
            local response_time=$(($(date +%s) - start_time))
            success "Health check passed: $endpoint (${response_time}s)"
            return 0
        fi
        
        verbose "Health check failed, retrying in 5 seconds..."
        sleep 5
    done
    
    error "Health check failed: $endpoint (timeout after ${TIMEOUT}s)"
    return 1
}

# Check model availability
check_model_availability() {
    local endpoint="$1"
    
    log "Checking model availability: $endpoint"
    
    local models_url="${endpoint}/api/tags"
    
    verbose "Models URL: $models_url"
    
    # Get available models
    local models_response
    if models_response=$(curl -f -s --max-time 30 "$models_url" 2>/dev/null); then
        verbose "Models response: $models_response"
        
        # Check if we have models
        local model_count
        if model_count=$(echo "$models_response" | jq -r '.models | length' 2>/dev/null); then
            if [[ "$model_count" -gt 0 ]]; then
                success "Models available: $model_count models found"
                
                # List available models if verbose
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "$models_response" | jq -r '.models[].name' | while read -r model; do
                        verbose "Available model: $model"
                    done
                fi
                return 0
            else
                warning "No models available"
                return 1
            fi
        else
            warning "Could not parse models response"
            return 1
        fi
    else
        error "Could not retrieve models list"
        return 1
    fi
}

# Performance benchmark
run_performance_benchmark() {
    local endpoint="$1"
    
    log "Running performance benchmark: $endpoint"
    
    local generate_url="${endpoint}/api/generate"
    
    # Test payload
    local test_payload='{
        "model": "deepseek-coder:1.3b",
        "prompt": "Write a simple test function",
        "stream": false,
        "options": {
            "temperature": 0.1,
            "top_p": 0.9
        }
    }'
    
    verbose "Benchmark URL: $generate_url"
    verbose "Test payload: $test_payload"
    
    # Run benchmark
    local start_time=$(date +%s%3N)
    local response
    
    if response=$(curl -f -s --max-time 60 -X POST "$generate_url" \
        -H "Content-Type: application/json" \
        -d "$test_payload" 2>/dev/null); then
        
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        
        verbose "Benchmark response: ${response:0:100}..."
        
        # Check if response contains expected fields
        if echo "$response" | jq -e '.response' > /dev/null 2>&1; then
            success "Performance benchmark passed: ${duration}ms response time"
            return 0
        else
            warning "Performance benchmark completed but response format unexpected"
            return 1
        fi
    else
        error "Performance benchmark failed"
        return 1
    fi
}

# Test distributed testing capability
test_distributed_execution() {
    log "Testing distributed test execution capability..."
    
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    # Check if SQS queue exists
    local queue_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}-queue"
    local queue_url
    
    if queue_url=$(aws sqs get-queue-url \
        --queue-name "$queue_name" \
        --region "$AWS_REGION" \
        --query 'QueueUrl' \
        --output text 2>/dev/null); then
        
        verbose "Found SQS queue: $queue_url"
        
        # Send test message
        local test_message='{
            "type": "test",
            "code": "function add(a, b) { return a + b; }",
            "language": "javascript",
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }'
        
        if aws sqs send-message \
            --queue-url "$queue_url" \
            --message-body "$test_message" \
            --region "$AWS_REGION" > /dev/null 2>&1; then
            
            success "Distributed test message sent successfully"
            
            # Wait a bit and check for processing
            sleep 10
            
            # Check S3 for results (if bucket exists)
            local bucket_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}-results"
            if aws s3 ls "s3://$bucket_name/" --region "$AWS_REGION" > /dev/null 2>&1; then
                local results_count=$(aws s3 ls "s3://$bucket_name/" --region "$AWS_REGION" | wc -l)
                if [[ $results_count -gt 0 ]]; then
                    success "Distributed test execution verified: $results_count results found"
                else
                    warning "Distributed test queue working but no results found yet"
                fi
            else
                warning "Results bucket not found, but queue is functional"
            fi
            
            return 0
        else
            error "Failed to send test message to queue"
            return 1
        fi
    else
        warning "SQS queue not found: $queue_name"
        warning "Distributed testing may not be configured"
        return 1
    fi
}

# Check auto-stop functionality
check_auto_stop() {
    log "Checking auto-stop functionality..."
    
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    # Check if auto-stop is enabled in stack parameters
    local auto_stop_enabled
    if auto_stop_enabled=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Parameters[?ParameterKey==`AutoStop`].ParameterValue' \
        --output text 2>/dev/null); then
        
        verbose "Auto-stop parameter: $auto_stop_enabled"
        
        if [[ "$auto_stop_enabled" == "enabled" ]]; then
            success "Auto-stop is enabled"
            
            # Check for CloudWatch events or Lambda functions for auto-stop
            local function_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}-auto-stop"
            if aws lambda get-function \
                --function-name "$function_name" \
                --region "$AWS_REGION" > /dev/null 2>&1; then
                success "Auto-stop Lambda function found: $function_name"
            else
                warning "Auto-stop enabled but Lambda function not found"
            fi
            
            return 0
        else
            warning "Auto-stop is disabled"
            return 1
        fi
    else
        warning "Could not determine auto-stop status"
        return 1
    fi
}

# Generate health report
generate_health_report() {
    local total_checks="$1"
    local passed_checks="$2"
    local failed_checks="$3"
    
    log "Generating health report..."
    
    local success_rate=$((passed_checks * 100 / total_checks))
    
    echo
    echo "=================================="
    echo "AI Testing Agent Health Report"
    echo "=================================="
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    echo "Health Check Results:"
    echo "  Total Checks: $total_checks"
    echo "  Passed: $passed_checks"
    echo "  Failed: $failed_checks"
    echo "  Success Rate: ${success_rate}%"
    echo
    
    if [[ $success_rate -ge 80 ]]; then
        success "Overall health status: HEALTHY (${success_rate}%)"
        return 0
    elif [[ $success_rate -ge 60 ]]; then
        warning "Overall health status: DEGRADED (${success_rate}%)"
        return 1
    else
        error "Overall health status: UNHEALTHY (${success_rate}%)"
        return 2
    fi
}

# Main health check function
main() {
    log "Starting AI Testing Agent health checks..."
    
    validate_inputs
    
    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    
    # Run health checks
    echo
    log "Running health checks..."
    
    # Check 1: CloudFormation stack status
    total_checks=$((total_checks + 1))
    if check_stack_status; then
        passed_checks=$((passed_checks + 1))
    else
        failed_checks=$((failed_checks + 1))
    fi
    
    # Get service endpoints
    local endpoints
    if endpoints=$(get_service_endpoints); then
        # Check 2: Endpoint health
        total_checks=$((total_checks + 1))
        if check_endpoint_health "$endpoints"; then
            passed_checks=$((passed_checks + 1))
        else
            failed_checks=$((failed_checks + 1))
        fi
        
        # Check 3: Model availability
        total_checks=$((total_checks + 1))
        if check_model_availability "$endpoints"; then
            passed_checks=$((passed_checks + 1))
        else
            failed_checks=$((failed_checks + 1))
        fi
        
        # Check 4: Performance benchmark
        total_checks=$((total_checks + 1))
        if run_performance_benchmark "$endpoints"; then
            passed_checks=$((passed_checks + 1))
        else
            failed_checks=$((failed_checks + 1))
        fi
    else
        # Skip endpoint-dependent checks
        failed_checks=$((failed_checks + 3))
        total_checks=$((total_checks + 3))
    fi
    
    # Check 5: Distributed testing
    total_checks=$((total_checks + 1))
    if test_distributed_execution; then
        passed_checks=$((passed_checks + 1))
    else
        failed_checks=$((failed_checks + 1))
    fi
    
    # Check 6: Auto-stop functionality
    total_checks=$((total_checks + 1))
    if check_auto_stop; then
        passed_checks=$((passed_checks + 1))
    else
        failed_checks=$((failed_checks + 1))
    fi
    
    # Generate final report
    generate_health_report "$total_checks" "$passed_checks" "$failed_checks"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        success "Health check completed successfully!"
    else
        warning "Health check completed with issues. See report above."
    fi
    
    exit $exit_code
}

# Error handling
trap 'error "Health check failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 