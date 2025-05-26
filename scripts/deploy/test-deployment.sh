#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh
# CLI Deployment Testing Script for AI Testing Agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"
DEPLOYMENT_TYPE="${3:-local}"
VERBOSE="${VERBOSE:-false}"
TIMEOUT="${TIMEOUT:-300}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [AWS_REGION] [DEPLOYMENT_TYPE]

Test AI Testing Agent deployment and verify service functionality.

ARGUMENTS:
    ENVIRONMENT     Environment to test (dev|staging|prod) [default: dev]
    AWS_REGION      AWS region [default: us-east-1]
    DEPLOYMENT_TYPE Deployment type (local|ecs-fargate|ec2-gpu|lambda) [default: local]

ENVIRONMENT VARIABLES:
    VERBOSE         Enable verbose output (true|false) [default: false]
    TIMEOUT         Test timeout in seconds [default: 300]

EXAMPLES:
    $0                                    # Test local development setup
    $0 dev us-east-1 local               # Test local with explicit params
    $0 staging us-east-1 ecs-fargate     # Test staging ECS deployment
    $0 prod us-east-1 ec2-gpu            # Test production EC2 deployment

TESTS PERFORMED:
    1. Service Health Checks
    2. Model Availability Verification
    3. Test Generation Functionality
    4. Error Fixing Capabilities
    5. Performance Benchmarking
    6. Cost Monitoring (AWS deployments)

EOF
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v curl >/dev/null 2>&1 || missing_tools+=("curl")
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")
    command -v python3 >/dev/null 2>&1 || missing_tools+=("python3")
    
    if [[ "$DEPLOYMENT_TYPE" != "local" ]]; then
        command -v aws >/dev/null 2>&1 || missing_tools+=("aws")
    fi
    
    if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
        command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Get service endpoints based on deployment type
get_service_endpoints() {
    local endpoints=()
    
    case "$DEPLOYMENT_TYPE" in
        "local")
            # Check if local services are running
            if docker ps --format "table {{.Names}}" | grep -q "ai-testing-ollama"; then
                endpoints+=("http://localhost:11434")
            else
                log_warning "Local Ollama service not running. Starting with Docker Compose..."
                cd "$PROJECT_ROOT/docker"
                docker-compose up -d ollama
                sleep 30
                endpoints+=("http://localhost:11434")
            fi
            ;;
        "ecs-fargate"|"ec2-gpu")
            # Get endpoints from AWS CloudFormation
            local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
            local cf_endpoints=$(aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --region "$AWS_REGION" \
                --query 'Stacks[0].Outputs[?OutputKey==`ServiceEndpoints`].OutputValue' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$cf_endpoints" ]]; then
                IFS=',' read -ra endpoint_array <<< "$cf_endpoints"
                endpoints+=("${endpoint_array[@]}")
            else
                log_error "Could not retrieve service endpoints from CloudFormation stack: $stack_name"
                return 1
            fi
            ;;
        "lambda")
            # Get Lambda function URL
            local function_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
            local lambda_url=$(aws lambda get-function-url-config \
                --function-name "$function_name" \
                --region "$AWS_REGION" \
                --query 'FunctionUrl' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$lambda_url" ]]; then
                endpoints+=("$lambda_url")
            else
                log_error "Could not retrieve Lambda function URL for: $function_name"
                return 1
            fi
            ;;
        *)
            log_error "Unknown deployment type: $DEPLOYMENT_TYPE"
            return 1
            ;;
    esac
    
    if [[ ${#endpoints[@]} -eq 0 ]]; then
        log_error "No service endpoints found"
        return 1
    fi
    
    echo "${endpoints[@]}"
}

# Test service health
test_service_health() {
    local endpoint="$1"
    log_info "Testing service health: $endpoint"
    
    local health_url="${endpoint}/health"
    if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
        health_url="${endpoint}/api/tags"  # Ollama health check
    fi
    
    local start_time=$(date +%s)
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s --max-time 10 "$health_url" >/dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "Health check passed in ${duration}s (attempt $attempt)"
            return 0
        fi
        
        log_warning "Health check failed (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Test model availability
test_model_availability() {
    local endpoint="$1"
    log_info "Testing model availability: $endpoint"
    
    local models_url="${endpoint}/api/tags"
    local response=$(curl -f -s --max-time 30 "$models_url" 2>/dev/null || echo "")
    
    if [[ -z "$response" ]]; then
        log_error "Could not retrieve model list"
        return 1
    fi
    
    # Parse model list
    local model_count=$(echo "$response" | jq -r '.models | length' 2>/dev/null || echo "0")
    
    if [[ "$model_count" -gt 0 ]]; then
        log_success "Found $model_count models available"
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$response" | jq -r '.models[].name' | while read -r model; do
                log_info "  - $model"
            done
        fi
        
        # Check for required models
        local required_models=("deepseek-coder:1.3b" "llama3.2:1b")
        for model in "${required_models[@]}"; do
            if echo "$response" | jq -e ".models[] | select(.name == \"$model\")" >/dev/null 2>&1; then
                log_success "Required model available: $model"
            else
                log_warning "Required model missing: $model"
            fi
        done
        
        return 0
    else
        log_error "No models available"
        return 1
    fi
}

# Test test generation functionality
test_generation_functionality() {
    local endpoint="$1"
    log_info "Testing test generation functionality: $endpoint"
    
    # Sample code for test generation
    local test_code='function add(a, b) { return a + b; }'
    local prompt="Generate a comprehensive test for this JavaScript function: $test_code"
    
    local generate_url="${endpoint}/api/generate"
    local request_data=$(jq -n \
        --arg model "deepseek-coder:1.3b" \
        --arg prompt "$prompt" \
        '{model: $model, prompt: $prompt, stream: false}')
    
    log_info "Sending test generation request..."
    local start_time=$(date +%s)
    
    local response=$(curl -f -s --max-time 120 \
        -X POST "$generate_url" \
        -H "Content-Type: application/json" \
        -d "$request_data" 2>/dev/null || echo "")
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ -n "$response" ]]; then
        local generated_text=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "")
        
        if [[ -n "$generated_text" && "$generated_text" != "null" ]]; then
            log_success "Test generation completed in ${duration}s"
            
            # Check if response contains test-like content
            if echo "$generated_text" | grep -qi -E "(test|describe|it|expect|assert)"; then
                log_success "Generated content appears to be a valid test"
            else
                log_warning "Generated content may not be a proper test"
            fi
            
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "Generated test preview:"
                echo "$generated_text" | head -10
                echo "..."
            fi
            
            return 0
        else
            log_error "Empty or invalid response from test generation"
            return 1
        fi
    else
        log_error "Test generation request failed"
        return 1
    fi
}

# Performance benchmark
performance_benchmark() {
    local endpoint="$1"
    log_info "Running performance benchmark: $endpoint"
    
    local test_prompts=(
        "Generate a unit test for a simple function"
        "Create integration tests for an API endpoint"
        "Write E2E tests for a React component"
    )
    
    local total_time=0
    local successful_requests=0
    
    for prompt in "${test_prompts[@]}"; do
        local start_time=$(date +%s)
        
        local request_data=$(jq -n \
            --arg model "deepseek-coder:1.3b" \
            --arg prompt "$prompt" \
            '{model: $model, prompt: $prompt, stream: false}')
        
        if curl -f -s --max-time 60 \
            -X POST "${endpoint}/api/generate" \
            -H "Content-Type: application/json" \
            -d "$request_data" >/dev/null 2>&1; then
            
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            total_time=$((total_time + duration))
            ((successful_requests++))
            
            log_success "Benchmark request completed in ${duration}s"
        else
            log_warning "Benchmark request failed"
        fi
    done
    
    if [[ $successful_requests -gt 0 ]]; then
        local avg_time=$((total_time / successful_requests))
        log_success "Performance benchmark: ${successful_requests}/${#test_prompts[@]} requests successful"
        log_success "Average response time: ${avg_time}s"
        
        # Performance thresholds
        if [[ $avg_time -lt 30 ]]; then
            log_success "Performance: EXCELLENT (< 30s average)"
        elif [[ $avg_time -lt 60 ]]; then
            log_success "Performance: GOOD (< 60s average)"
        elif [[ $avg_time -lt 120 ]]; then
            log_warning "Performance: ACCEPTABLE (< 120s average)"
        else
            log_warning "Performance: SLOW (> 120s average)"
        fi
    else
        log_error "All benchmark requests failed"
        return 1
    fi
}

# Test error fixing capabilities (if available)
test_error_fixing() {
    local endpoint="$1"
    log_info "Testing error fixing capabilities: $endpoint"
    
    # Sample TypeScript error
    local error_code='const x: string = 123;'  # Type error
    local error_prompt="Fix this TypeScript error: $error_code"
    
    local request_data=$(jq -n \
        --arg model "deepseek-coder:1.3b" \
        --arg prompt "$error_prompt" \
        '{model: $model, prompt: $prompt, stream: false}')
    
    local response=$(curl -f -s --max-time 60 \
        -X POST "${endpoint}/api/generate" \
        -H "Content-Type: application/json" \
        -d "$request_data" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        local fixed_code=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "")
        
        if [[ -n "$fixed_code" && "$fixed_code" != "null" ]]; then
            log_success "Error fixing functionality working"
            
            # Check if the fix looks reasonable
            if echo "$fixed_code" | grep -qi -E "(string|number|const|let|var)"; then
                log_success "Generated fix appears to address the type error"
            else
                log_warning "Generated fix may not properly address the error"
            fi
            
            return 0
        else
            log_warning "Error fixing returned empty response"
            return 1
        fi
    else
        log_warning "Error fixing request failed"
        return 1
    fi
}

# Monitor costs (AWS deployments only)
monitor_costs() {
    if [[ "$DEPLOYMENT_TYPE" == "local" ]]; then
        log_info "Skipping cost monitoring for local deployment"
        return 0
    fi
    
    log_info "Monitoring AWS costs for AI Testing Agent..."
    
    # Get current month costs
    local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    local end_date=$(date +%Y-%m-%d)
    
    local cost_data=$(aws ce get-cost-and-usage \
        --time-period Start="$start_date",End="$end_date" \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter "{\"Tags\":{\"Key\":\"Project\",\"Values\":[\"deployer-ddf-mod-llm-models\"]}}" \
        --region "$AWS_REGION" \
        --query 'ResultsByTime[0].Groups' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ "$cost_data" != "[]" ]]; then
        local total_cost=$(echo "$cost_data" | jq -r 'map(.Metrics.BlendedCost.Amount | tonumber) | add')
        log_success "Current month cost: \$${total_cost}"
        
        # Cost thresholds
        if (( $(echo "$total_cost < 50" | bc -l) )); then
            log_success "Cost: EXCELLENT (< \$50/month)"
        elif (( $(echo "$total_cost < 120" | bc -l) )); then
            log_success "Cost: GOOD (< \$120/month)"
        elif (( $(echo "$total_cost < 200" | bc -l) )); then
            log_warning "Cost: ACCEPTABLE (< \$200/month)"
        else
            log_warning "Cost: HIGH (> \$200/month)"
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$cost_data" | jq -r '.[] | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"'
        fi
    else
        log_info "No cost data available (may be too early in the month)"
    fi
}

# Main test execution
main() {
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        usage
        exit 0
    fi
    
    log_info "Starting AI Testing Agent deployment test"
    log_info "Environment: $ENVIRONMENT"
    log_info "AWS Region: $AWS_REGION"
    log_info "Deployment Type: $DEPLOYMENT_TYPE"
    echo
    
    # Check prerequisites
    check_prerequisites
    echo
    
    # Get service endpoints
    log_info "Discovering service endpoints..."
    local endpoints
    if ! endpoints=$(get_service_endpoints); then
        log_error "Failed to discover service endpoints"
        exit 1
    fi
    
    IFS=' ' read -ra endpoint_array <<< "$endpoints"
    log_success "Found ${#endpoint_array[@]} service endpoint(s)"
    echo
    
    # Test each endpoint
    local failed_tests=0
    local total_tests=0
    
    for endpoint in "${endpoint_array[@]}"; do
        log_info "Testing endpoint: $endpoint"
        echo "----------------------------------------"
        
        # Service health test
        ((total_tests++))
        if ! test_service_health "$endpoint"; then
            ((failed_tests++))
            continue
        fi
        
        # Model availability test
        ((total_tests++))
        if ! test_model_availability "$endpoint"; then
            ((failed_tests++))
        fi
        
        # Test generation functionality
        ((total_tests++))
        if ! test_generation_functionality "$endpoint"; then
            ((failed_tests++))
        fi
        
        # Error fixing capabilities
        ((total_tests++))
        if ! test_error_fixing "$endpoint"; then
            ((failed_tests++))
        fi
        
        # Performance benchmark
        ((total_tests++))
        if ! performance_benchmark "$endpoint"; then
            ((failed_tests++))
        fi
        
        echo
    done
    
    # Cost monitoring (AWS only)
    if [[ "$DEPLOYMENT_TYPE" != "local" ]]; then
        ((total_tests++))
        if ! monitor_costs; then
            ((failed_tests++))
        fi
    fi
    
    # Summary
    echo "========================================"
    log_info "Test Summary"
    echo "========================================"
    
    local passed_tests=$((total_tests - failed_tests))
    log_info "Total Tests: $total_tests"
    log_success "Passed: $passed_tests"
    
    if [[ $failed_tests -gt 0 ]]; then
        log_error "Failed: $failed_tests"
        log_error "AI Testing Agent deployment has issues"
        exit 1
    else
        log_success "All tests passed!"
        log_success "AI Testing Agent deployment is working correctly"
        exit 0
    fi
}

# Run main function with all arguments
main "$@" 