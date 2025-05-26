#!/bin/bash
# DeployerDDF LLM Models - API Endpoint Testing Script
# Tests LLM inference endpoints and validates API responses

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
ENVIRONMENT="dev"
CONFIG_FILE="$PROJECT_ROOT/config/llm-models.json"
TIMEOUT=30
MAX_RETRIES=3
VERBOSE="false"
OUTPUT_FILE=""
TEST_INFERENCE="true"
TEST_HEALTH="true"
SAVE_RESPONSES="false"

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
        echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] VERBOSE: $1${NC}" >&2
    fi
}

# Show usage
show_usage() {
    cat << EOF
DeployerDDF LLM Models - API Endpoint Testing

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --env ENVIRONMENT       Environment to test (dev|staging|prod) [default: dev]
    -c, --config PATH          Path to configuration file [default: ../config/llm-models.json]
    -t, --timeout SECONDS     Request timeout in seconds [default: 30]
    -r, --retries COUNT        Maximum retry attempts [default: 3]
    -o, --output FILE          Save test results to file
    --no-inference             Skip inference endpoint testing
    --no-health                Skip health endpoint testing
    --save-responses           Save API responses to files
    --verbose                  Enable verbose logging
    -h, --help                 Show this help message

EXAMPLES:
    # Basic API testing
    $0

    # Test specific environment with verbose output
    $0 --env=staging --verbose

    # Test with custom timeout and save results
    $0 --timeout=60 --output=api-test-results.json

    # Test health endpoints only
    $0 --no-inference

    # Test inference endpoints only
    $0 --no-health

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
            --env=*)
                ENVIRONMENT="${1#*=}"
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --config=*)
                CONFIG_FILE="${1#*=}"
                shift
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --timeout=*)
                TIMEOUT="${1#*=}"
                shift
                ;;
            -r|--retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --retries=*)
                MAX_RETRIES="${1#*=}"
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --output=*)
                OUTPUT_FILE="${1#*=}"
                shift
                ;;
            --no-inference)
                TEST_INFERENCE="false"
                shift
                ;;
            --no-health)
                TEST_HEALTH="false"
                shift
                ;;
            --save-responses)
                SAVE_RESPONSES="true"
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    local missing_commands=()
    local required_commands=("curl" "jq")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_commands[*]}"
        echo "Please install the missing commands and try again."
        exit 1
    fi

    success "Prerequisites check completed"
}

# Load configuration
load_configuration() {
    log "Loading configuration..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        error "Invalid JSON syntax in configuration file: $CONFIG_FILE"
        exit 1
    fi

    success "Configuration loaded successfully"
}

# Get enabled models for environment
get_enabled_models() {
    local env="$1"
    jq -r ".environments.${env}.enabled_models[]?" "$CONFIG_FILE" 2>/dev/null || echo ""
}

# Get model configuration
get_model_config() {
    local model_id="$1"
    jq -r ".models.\"${model_id}\"" "$CONFIG_FILE" 2>/dev/null
}

# Test endpoint with retries
test_endpoint_with_retries() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local content_type="${4:-application/json}"
    
    local attempt=1
    local max_attempts=$((MAX_RETRIES + 1))
    
    while [[ $attempt -le $max_attempts ]]; do
        verbose "Attempt $attempt/$max_attempts for $url"
        
        local curl_cmd="curl -s --connect-timeout 10 --max-time $TIMEOUT"
        curl_cmd="$curl_cmd -X $method"
        curl_cmd="$curl_cmd -H 'Content-Type: $content_type'"
        curl_cmd="$curl_cmd -w '%{http_code}|%{time_total}'"
        
        if [[ -n "$data" ]]; then
            curl_cmd="$curl_cmd -d '$data'"
        fi
        
        curl_cmd="$curl_cmd '$url'"
        
        local response
        if response=$(eval "$curl_cmd" 2>/dev/null); then
            # Extract the last part after the last occurrence of the pattern
            local status_info=$(echo "$response" | grep -o '[0-9][0-9][0-9]|[0-9.]*$')
            local http_code=$(echo "$status_info" | cut -d'|' -f1)
            local time_total=$(echo "$status_info" | cut -d'|' -f2)
            local body=$(echo "$response" | sed 's/[0-9][0-9][0-9]|[0-9.]*$//')
            
            verbose "Response: HTTP $http_code, Time: ${time_total}s, Body length: ${#body}"
            
            if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
                echo "$http_code|$time_total|$body"
                return 0
            else
                verbose "HTTP $http_code received, attempt $attempt/$max_attempts"
            fi
        else
            verbose "Connection failed, attempt $attempt/$max_attempts"
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            sleep $((attempt * 2))
        fi
        
        ((attempt++))
    done
    
    return 1
}

# Test health endpoints
test_health_endpoints() {
    if [[ "$TEST_HEALTH" != "true" ]]; then
        log "Skipping health endpoint testing (--no-health specified)"
        return 0
    fi

    log "Testing health endpoints..."

    local enabled_models
    enabled_models=$(get_enabled_models "$ENVIRONMENT")
    
    if [[ -z "$enabled_models" ]]; then
        warning "No enabled models found for environment: $ENVIRONMENT"
        return 0
    fi

    local health_results=()
    
    while IFS= read -r model_id; do
        [[ -z "$model_id" ]] && continue
        
        log "Testing health endpoint for model: $model_id"
        
        local model_config
        model_config=$(get_model_config "$model_id")
        
        if [[ "$model_config" == "null" ]]; then
            warning "Model configuration not found: $model_id"
            continue
        fi
        
        # Get environment-specific endpoints and provider priority
        local env_config
        env_config=$(jq -r ".environments.${ENVIRONMENT}" "$CONFIG_FILE")
        
        local provider_priority
        provider_priority=$(echo "$env_config" | jq -r '.provider_priority[]?' 2>/dev/null || echo "local")
        
        local endpoints_to_test=()
        
        # Build endpoints based on provider priority and model configuration
        while IFS= read -r provider; do
            [[ -z "$provider" ]] && continue
            
            case "$provider" in
                "local")
                    local local_base
                    local_base=$(echo "$env_config" | jq -r '.endpoints.local // "http://localhost:11434"')
                    local local_health
                    local_health=$(echo "$model_config" | jq -r '.endpoints.local.health // "/api/tags"')
                    endpoints_to_test+=("${local_base}${local_health}|local")
                    ;;
                "aws")
                    local aws_health
                    aws_health=$(echo "$model_config" | jq -r '.endpoints.aws.health // ""')
                    if [[ -n "$aws_health" && "$aws_health" != "null" ]]; then
                        endpoints_to_test+=("${aws_health}|aws")
                    fi
                    ;;
            esac
        done <<< "$provider_priority"
        
        # Fallback to common local endpoints if no configuration found
        if [[ ${#endpoints_to_test[@]} -eq 0 ]]; then
            local fallback_health
            fallback_health=$(echo "$model_config" | jq -r '.endpoints.health // "/api/tags"')
            endpoints_to_test=(
                "http://localhost:11434${fallback_health}|local"
                "http://localhost:8080${fallback_health}|local"
                "http://localhost:5000${fallback_health}|local"
                "http://localhost:3000${fallback_health}|local"
            )
        fi
        
        local endpoint_found=false
        
        for endpoint_info in "${endpoints_to_test[@]}"; do
            local full_url=$(echo "$endpoint_info" | cut -d'|' -f1)
            local provider=$(echo "$endpoint_info" | cut -d'|' -f2)
            
            verbose "Testing health endpoint: $full_url (provider: $provider)"
            
            local result
            if result=$(test_endpoint_with_retries "$full_url"); then
                local http_code=$(echo "$result" | cut -d'|' -f1)
                local time_total=$(echo "$result" | cut -d'|' -f2)
                local body=$(echo "$result" | cut -d'|' -f3)
                
                success "Health endpoint responding: $full_url (${http_code}, ${time_total}s, provider: $provider)"
                
                health_results+=("{\"model\":\"$model_id\",\"endpoint\":\"$full_url\",\"provider\":\"$provider\",\"status\":\"healthy\",\"http_code\":$http_code,\"response_time\":$time_total}")
                endpoint_found=true
                
                if [[ "$SAVE_RESPONSES" == "true" ]]; then
                    echo "$body" > "logs/health_response_${model_id}_${provider}.json"
                    verbose "Health response saved to: logs/health_response_${model_id}_${provider}.json"
                fi
                
                break
            else
                verbose "Health endpoint not responding: $full_url (provider: $provider)"
            fi
        done
        
        if [[ "$endpoint_found" == "false" ]]; then
            warning "No health endpoints responding for model: $model_id"
            health_results+=("{\"model\":\"$model_id\",\"endpoint\":\"none\",\"status\":\"unhealthy\",\"http_code\":0,\"response_time\":0}")
        fi
        
    done <<< "$enabled_models"
    
    # Save health results
    if [[ ${#health_results[@]} -gt 0 ]]; then
        local health_json="[$(IFS=,; echo "${health_results[*]}")]"
        echo "$health_json" > "logs/health_test_results.json"
        success "Health test results saved to: logs/health_test_results.json"
    fi
}

# Test inference endpoints
test_inference_endpoints() {
    if [[ "$TEST_INFERENCE" != "true" ]]; then
        log "Skipping inference endpoint testing (--no-inference specified)"
        return 0
    fi

    log "Testing inference endpoints..."

    local enabled_models
    enabled_models=$(get_enabled_models "$ENVIRONMENT")
    
    if [[ -z "$enabled_models" ]]; then
        warning "No enabled models found for environment: $ENVIRONMENT"
        return 0
    fi

    local inference_results=()
    
    while IFS= read -r model_id; do
        [[ -z "$model_id" ]] && continue
        
        log "Testing inference endpoint for model: $model_id"
        
        local model_config
        model_config=$(get_model_config "$model_id")
        
        if [[ "$model_config" == "null" ]]; then
            warning "Model configuration not found: $model_id"
            continue
        fi
        
        local inference_endpoint
        inference_endpoint=$(echo "$model_config" | jq -r '.endpoints.inference // "/api/generate"')
        
        local test_questions
        test_questions=$(echo "$model_config" | jq -r '.testing.standard_questions[]?' 2>/dev/null)
        
        if [[ -z "$test_questions" ]]; then
            test_questions="What is artificial intelligence?"
        fi
        
        local first_question
        first_question=$(echo "$test_questions" | head -n1)
        
        # Test common local endpoints
        local base_urls=(
            "http://localhost:11434"
            "http://localhost:8080"
            "http://localhost:5000"
            "http://localhost:3000"
        )
        
        local endpoint_found=false
        
        for base_url in "${base_urls[@]}"; do
            local full_url="${base_url}${inference_endpoint}"
            verbose "Testing inference endpoint: $full_url"
            
            # Prepare test data for different API formats
            local test_data_ollama="{\"model\":\"$model_id\",\"prompt\":\"$first_question\",\"stream\":false}"
            local test_data_openai="{\"model\":\"$model_id\",\"messages\":[{\"role\":\"user\",\"content\":\"$first_question\"}],\"max_tokens\":100}"
            
            # Try Ollama format first
            local result
            if result=$(test_endpoint_with_retries "$full_url" "POST" "$test_data_ollama"); then
                local http_code=$(echo "$result" | cut -d'|' -f1)
                local time_total=$(echo "$result" | cut -d'|' -f2)
                local body=$(echo "$result" | cut -d'|' -f3)
                
                # Validate response format
                if echo "$body" | jq -e '.response' >/dev/null 2>&1; then
                    local response_text
                    response_text=$(echo "$body" | jq -r '.response' | head -c 100)
                    
                    success "Inference endpoint working: $full_url (${http_code}, ${time_total}s)"
                    verbose "Response preview: $response_text..."
                    
                    inference_results+=("{\"model\":\"$model_id\",\"endpoint\":\"$full_url\",\"status\":\"working\",\"http_code\":$http_code,\"response_time\":$time_total,\"format\":\"ollama\"}")
                    endpoint_found=true
                    
                    if [[ "$SAVE_RESPONSES" == "true" ]]; then
                        echo "$body" > "logs/inference_response_${model_id}.json"
                        verbose "Inference response saved to: logs/inference_response_${model_id}.json"
                    fi
                    
                    break
                else
                    verbose "Response format not recognized (Ollama), trying OpenAI format..."
                    
                    # Try OpenAI format
                    if result=$(test_endpoint_with_retries "$full_url" "POST" "$test_data_openai"); then
                        http_code=$(echo "$result" | cut -d'|' -f1)
                        time_total=$(echo "$result" | cut -d'|' -f2)
                        body=$(echo "$result" | cut -d'|' -f3)
                        
                        if echo "$body" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
                            response_text=$(echo "$body" | jq -r '.choices[0].message.content' | head -c 100)
                            
                            success "Inference endpoint working: $full_url (${http_code}, ${time_total}s)"
                            verbose "Response preview: $response_text..."
                            
                            inference_results+=("{\"model\":\"$model_id\",\"endpoint\":\"$full_url\",\"status\":\"working\",\"http_code\":$http_code,\"response_time\":$time_total,\"format\":\"openai\"}")
                            endpoint_found=true
                            
                            if [[ "$SAVE_RESPONSES" == "true" ]]; then
                                echo "$body" > "logs/inference_response_${model_id}.json"
                                verbose "Inference response saved to: logs/inference_response_${model_id}.json"
                            fi
                            
                            break
                        fi
                    fi
                fi
            else
                verbose "Inference endpoint not responding: $full_url"
            fi
        done
        
        if [[ "$endpoint_found" == "false" ]]; then
            warning "No inference endpoints working for model: $model_id"
            inference_results+=("{\"model\":\"$model_id\",\"endpoint\":\"none\",\"status\":\"not_working\",\"http_code\":0,\"response_time\":0,\"format\":\"unknown\"}")
        fi
        
    done <<< "$enabled_models"
    
    # Save inference results
    if [[ ${#inference_results[@]} -gt 0 ]]; then
        local inference_json="[$(IFS=,; echo "${inference_results[*]}")]"
        echo "$inference_json" > "logs/inference_test_results.json"
        success "Inference test results saved to: logs/inference_test_results.json"
    fi
}

# Generate comprehensive test report
generate_test_report() {
    log "Generating API test report..."

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Combine results
    local combined_results="{\"timestamp\":\"$timestamp\",\"environment\":\"$ENVIRONMENT\",\"test_config\":{\"timeout\":$TIMEOUT,\"max_retries\":$MAX_RETRIES,\"test_inference\":$TEST_INFERENCE,\"test_health\":$TEST_HEALTH}}"
    
    if [[ -f "logs/health_test_results.json" ]]; then
        local health_data
        health_data=$(cat "logs/health_test_results.json")
        combined_results=$(echo "$combined_results" | jq ".health_tests = $health_data")
    fi
    
    if [[ -f "logs/inference_test_results.json" ]]; then
        local inference_data
        inference_data=$(cat "logs/inference_test_results.json")
        combined_results=$(echo "$combined_results" | jq ".inference_tests = $inference_data")
    fi
    
    # Save combined results
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$combined_results" | jq '.' > "$OUTPUT_FILE"
        success "Complete test results saved to: $OUTPUT_FILE"
    else
        local results_file="logs/api_test_results_$(date +%Y%m%d_%H%M%S).json"
        echo "$combined_results" | jq '.' > "$results_file"
        success "Complete test results saved to: $results_file"
    fi
    
    # Generate summary
    echo
    echo "🎯 API ENDPOINT TEST REPORT"
    echo "══════════════════════════════════════════════════"
    echo "Environment: $ENVIRONMENT"
    echo "Timestamp: $timestamp"
    echo "Configuration: $CONFIG_FILE"
    echo
    
    if [[ "$TEST_HEALTH" == "true" && -f "logs/health_test_results.json" ]]; then
        echo "🏥 HEALTH ENDPOINT RESULTS"
        echo "──────────────────────────────"
        local healthy_count
        healthy_count=$(jq '[.[] | select(.status == "healthy")] | length' "logs/health_test_results.json")
        local total_health
        total_health=$(jq 'length' "logs/health_test_results.json")
        echo "Healthy endpoints: $healthy_count/$total_health"
        
        jq -r '.[] | "  \(.status == "healthy" | if . then "✅" else "❌" end) \(.model): \(.endpoint)"' "logs/health_test_results.json"
        echo
    fi
    
    if [[ "$TEST_INFERENCE" == "true" && -f "logs/inference_test_results.json" ]]; then
        echo "🧠 INFERENCE ENDPOINT RESULTS"
        echo "──────────────────────────────"
        local working_count
        working_count=$(jq '[.[] | select(.status == "working")] | length' "logs/inference_test_results.json")
        local total_inference
        total_inference=$(jq 'length' "logs/inference_test_results.json")
        echo "Working endpoints: $working_count/$total_inference"
        
        jq -r '.[] | "  \(.status == "working" | if . then "✅" else "❌" end) \(.model): \(.endpoint) (\(.format))"' "logs/inference_test_results.json"
        echo
    fi
    
    echo "📊 SUMMARY"
    echo "──────────────────────────────"
    echo "Test completed successfully"
    echo "Results saved in JSON format"
    if [[ "$SAVE_RESPONSES" == "true" ]]; then
        echo "API responses saved to individual files"
    fi
    echo
    
    echo "🚀 NEXT STEPS"
    echo "──────────────────────────────"
    echo "1. If no endpoints are working, start local models:"
    echo "   cd deployer-ddf-mod-llm-models"
    echo "   docker-compose -f docker/docker-compose.yml up -d"
    echo "   # Wait for models to download and start"
    echo
    echo "2. For AWS models, set up authentication first:"
    echo "   See: docs/guides/aws-authentication-setup.md"
    echo "   aws configure --profile llm-models"
    echo
    echo "3. Run the layered testing framework:"
    echo "   cd deployer-ddf-mod-llm-models"
    echo "   ./scripts/local/api-endpoint-tester.sh --env=dev --verbose"
    echo
    echo "4. For cloud deployment testing:"
    echo "   Use cloud-specific health check endpoints"
    echo "   Configure load balancer health checks"
    echo

    success "API endpoint testing completed!"
}

# Main execution
main() {
    echo "🔌 DeployerDDF LLM Models - API Endpoint Testing"
    echo "════════════════════════════════════════════════════════════"
    echo

    parse_args "$@"
    check_prerequisites
    load_configuration
    test_health_endpoints
    test_inference_endpoints
    generate_test_report
}

# Error handling
trap 'error "Script failed on line $LINENO"' ERR

# Run main function
main "$@" 