#!/bin/bash
# Swagger Frontend Testing Script
# Tests the API using local Docker and minimum AWS infrastructure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOCAL_API_URL="http://localhost:3000"
AWS_API_URL="${AWS_API_URL:-http://localhost:3000}"  # Will be set for AWS testing
TEST_TIMEOUT=30
VERBOSE=false

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

# Show usage
show_usage() {
    cat << EOF
Swagger Frontend Testing Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --local-only           Test only local Docker setup
    --aws-only            Test only AWS infrastructure  
    --aws-url URL         AWS API endpoint URL
    --timeout SECONDS     Request timeout [default: 30]
    --verbose             Enable verbose logging
    -h, --help            Show this help message

EXAMPLES:
    # Test both local and AWS
    $0

    # Test only local Docker
    $0 --local-only

    # Test AWS with custom endpoint
    $0 --aws-only --aws-url https://api.example.com

EOF
}

# Parse command line arguments
parse_args() {
    local test_local=true
    local test_aws=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --local-only)
                test_aws=false
                shift
                ;;
            --aws-only)
                test_local=false
                shift
                ;;
            --aws-url)
                AWS_API_URL="$2"
                shift 2
                ;;
            --aws-url=*)
                AWS_API_URL="${1#*=}"
                shift
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            --timeout=*)
                TEST_TIMEOUT="${1#*=}"
                shift
                ;;
            --verbose)
                VERBOSE=true
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
    
    export TEST_LOCAL="$test_local"
    export TEST_AWS="$test_aws"
}

# Test API endpoint
test_endpoint() {
    local url="$1"
    local endpoint="$2"
    local method="${3:-GET}"
    local data="${4:-}"
    local description="$5"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "Testing: $method $url$endpoint"
    fi
    
    local curl_cmd="curl -s --max-time $TEST_TIMEOUT"
    
    if [[ "$method" == "POST" ]]; then
        curl_cmd="$curl_cmd -X POST -H 'Content-Type: application/json'"
        if [[ -n "$data" ]]; then
            curl_cmd="$curl_cmd -d '$data'"
        fi
    fi
    
    local response
    if response=$(eval "$curl_cmd '$url$endpoint'" 2>/dev/null); then
        if echo "$response" | jq . >/dev/null 2>&1; then
            success "$description"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "$response" | jq . | head -10
            fi
            return 0
        else
            warning "$description - Invalid JSON response"
            return 1
        fi
    else
        error "$description - Connection failed"
        return 1
    fi
}

# Test Swagger UI accessibility
test_swagger_ui() {
    local url="$1"
    local description="$2"
    
    log "Testing Swagger UI accessibility..."
    
    if curl -s --max-time $TEST_TIMEOUT "$url/api-docs/" | grep -q "swagger-ui"; then
        success "$description - Swagger UI accessible"
        echo "   📚 Access at: $url/api-docs"
        return 0
    else
        error "$description - Swagger UI not accessible"
        return 1
    fi
}

# Test local Docker setup
test_local_docker() {
    header "🐳 TESTING LOCAL DOCKER SETUP"
    
    local api_url="$LOCAL_API_URL"
    local failed_tests=0
    
    # Check if Ollama is running
    log "Checking Ollama Docker container..."
    if docker ps | grep -q ollama; then
        success "Ollama container is running"
    else
        warning "Ollama container not found - starting it..."
        docker-compose up -d ollama || {
            error "Failed to start Ollama container"
            return 1
        }
        sleep 5
    fi
    
    # Check if API is running
    log "Checking if local API is running..."
    if ! curl -s --max-time 5 "$api_url/health" >/dev/null 2>&1; then
        warning "Local API not running - starting it..."
        cd "$PROJECT_ROOT"
        npm run dev &
        sleep 10
        
        if ! curl -s --max-time 5 "$api_url/health" >/dev/null 2>&1; then
            error "Failed to start local API"
            return 1
        fi
    fi
    
    # Test API endpoints
    log "Testing local API endpoints..."
    
    test_endpoint "$api_url" "/health" "GET" "" "Health check" || ((failed_tests++))
    test_endpoint "$api_url" "/api/status" "GET" "" "API status" || ((failed_tests++))
    test_endpoint "$api_url" "/api/generate-tests" "POST" '{"code": "function test() { return true; }", "language": "javascript"}' "Test generation" || ((failed_tests++))
    
    # Test Swagger UI
    test_swagger_ui "$api_url" "Local Docker" || ((failed_tests++))
    
    # Test Ollama models
    log "Testing Ollama models..."
    if curl -s http://localhost:11434/api/tags | jq -r '.models[].name' | grep -q "deepseek-coder"; then
        success "Ollama models available"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Available models:"
            curl -s http://localhost:11434/api/tags | jq -r '.models[].name' | sed 's/^/   - /'
        fi
    else
        warning "No Ollama models found"
        ((failed_tests++))
    fi
    
    echo
    if [[ $failed_tests -eq 0 ]]; then
        success "🎉 Local Docker testing completed successfully!"
        echo "   🌐 Swagger UI: $api_url/api-docs"
        echo "   🔗 API Status: $api_url/api/status"
        echo "   🏥 Health Check: $api_url/health"
    else
        error "Local Docker testing failed ($failed_tests errors)"
        return 1
    fi
}

# Test AWS infrastructure
test_aws_infrastructure() {
    header "☁️  TESTING AWS INFRASTRUCTURE"
    
    local api_url="$AWS_API_URL"
    local failed_tests=0
    
    # Check AWS credentials
    log "Checking AWS credentials..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        success "AWS credentials valid"
        if [[ "$VERBOSE" == "true" ]]; then
            aws sts get-caller-identity | jq .
        fi
    else
        error "AWS credentials not configured"
        return 1
    fi
    
    # Test AWS services availability
    log "Testing AWS services..."
    
    local aws_services=("s3" "ecs" "cloudformation")
    for service in "${aws_services[@]}"; do
        case $service in
            s3)
                if aws s3 ls >/dev/null 2>&1; then
                    success "S3 access verified"
                else
                    warning "S3 access limited"
                    ((failed_tests++))
                fi
                ;;
            ecs)
                if aws ecs list-clusters >/dev/null 2>&1; then
                    success "ECS access verified"
                else
                    warning "ECS access limited"
                    ((failed_tests++))
                fi
                ;;
            cloudformation)
                if aws cloudformation list-stacks >/dev/null 2>&1; then
                    success "CloudFormation access verified"
                else
                    warning "CloudFormation access limited"
                    ((failed_tests++))
                fi
                ;;
        esac
    done
    
    # Test API endpoints (if AWS API is deployed)
    if [[ "$api_url" != "$LOCAL_API_URL" ]]; then
        log "Testing AWS API endpoints..."
        
        test_endpoint "$api_url" "/health" "GET" "" "AWS Health check" || ((failed_tests++))
        test_endpoint "$api_url" "/api/status" "GET" "" "AWS API status" || ((failed_tests++))
        
        # Test Swagger UI on AWS
        test_swagger_ui "$api_url" "AWS" || ((failed_tests++))
    else
        warning "AWS API URL not configured - using local URL for demo"
        log "To test real AWS deployment, use: --aws-url https://your-aws-api.com"
    fi
    
    echo
    if [[ $failed_tests -eq 0 ]]; then
        success "🎉 AWS infrastructure testing completed successfully!"
        if [[ "$api_url" != "$LOCAL_API_URL" ]]; then
            echo "   🌐 AWS Swagger UI: $api_url/api-docs"
            echo "   🔗 AWS API Status: $api_url/api/status"
        fi
        echo "   ☁️  AWS Services: All accessible"
    else
        warning "AWS infrastructure testing completed with warnings ($failed_tests issues)"
        return 1
    fi
}

# Generate test report
generate_report() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    header "📊 TEST REPORT"
    
    echo "Test Duration: ${duration}s"
    echo "Timestamp: $(date)"
    echo
    
    if [[ "$TEST_LOCAL" == "true" ]]; then
        echo "🐳 Local Docker Setup:"
        echo "   - API URL: $LOCAL_API_URL"
        echo "   - Swagger UI: $LOCAL_API_URL/api-docs"
        echo "   - Ollama: http://localhost:11434"
    fi
    
    if [[ "$TEST_AWS" == "true" ]]; then
        echo "☁️  AWS Infrastructure:"
        echo "   - API URL: $AWS_API_URL"
        echo "   - AWS Account: $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'Not configured')"
        echo "   - AWS Region: $(aws configure get region 2>/dev/null || echo 'Not configured')"
    fi
    
    echo
    echo "🎯 Next Steps:"
    echo "   1. Open Swagger UI in browser: $LOCAL_API_URL/api-docs"
    echo "   2. Test API endpoints using the interactive interface"
    echo "   3. Try the /api/generate-tests endpoint with your code"
    echo "   4. Monitor Ollama models: docker exec ollama-server ollama list"
    
    if [[ "$TEST_AWS" == "true" && "$AWS_API_URL" == "$LOCAL_API_URL" ]]; then
        echo "   5. Deploy to AWS and test with: $0 --aws-url https://your-aws-api.com"
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    header "🧪 SWAGGER FRONTEND API TESTING"
    
    echo "Configuration:"
    echo "  Local Testing: $TEST_LOCAL"
    echo "  AWS Testing: $TEST_AWS"
    echo "  Timeout: ${TEST_TIMEOUT}s"
    echo "  Verbose: $VERBOSE"
    echo
    
    local exit_code=0
    
    if [[ "$TEST_LOCAL" == "true" ]]; then
        if ! test_local_docker; then
            exit_code=1
        fi
        echo
    fi
    
    if [[ "$TEST_AWS" == "true" ]]; then
        if ! test_aws_infrastructure; then
            exit_code=1
        fi
        echo
    fi
    
    generate_report "$start_time"
    
    exit $exit_code
}

# Parse arguments and run
parse_args "$@"
main 