#!/bin/bash
# DeployerDDF LLM Models - Local Deployment Verification Script
# Verifies configuration, endpoints, and API connectivity without AWS access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
ENVIRONMENT="dev"
CONFIG_FILE="$PROJECT_ROOT/config/llm-models.json"
SCHEMA_FILE="$PROJECT_ROOT/config/schemas/llm-models-schema.json"
VERBOSE="false"
CHECK_ENDPOINTS="true"
VALIDATE_CONFIG="true"
TEST_LOCAL_MODELS="true"

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
DeployerDDF LLM Models - Local Deployment Verification

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -e, --env ENVIRONMENT       Environment to verify (dev|staging|prod) [default: dev]
    -c, --config PATH          Path to configuration file [default: ../config/llm-models.json]
    --no-endpoints             Skip endpoint connectivity checks
    --no-config                Skip configuration validation
    --no-local                 Skip local model testing
    --verbose                  Enable verbose logging
    -h, --help                 Show this help message

EXAMPLES:
    # Basic verification
    $0

    # Verify specific environment with verbose output
    $0 --env=staging --verbose

    # Skip endpoint checks (useful for offline verification)
    $0 --no-endpoints

    # Verify configuration only
    $0 --no-endpoints --no-local

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
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --no-endpoints)
                CHECK_ENDPOINTS="false"
                shift
                ;;
            --no-config)
                VALIDATE_CONFIG="false"
                shift
                ;;
            --no-local)
                TEST_LOCAL_MODELS="false"
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
    local required_commands=("node" "npm" "curl" "jq")
    
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

    # Check Node.js version
    local node_version=$(node --version | cut -d'v' -f2)
    local required_version="18.0.0"
    if ! printf '%s\n%s\n' "$required_version" "$node_version" | sort -V -C; then
        error "Node.js version $node_version is too old. Required: $required_version+"
        exit 1
    fi

    success "Prerequisites check completed"
}

# Validate configuration files
validate_configuration() {
    if [[ "$VALIDATE_CONFIG" != "true" ]]; then
        log "Skipping configuration validation (--no-config specified)"
        return 0
    fi

    log "Validating configuration files..."

    # Check if configuration file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Validate JSON syntax
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        error "Invalid JSON syntax in configuration file: $CONFIG_FILE"
        exit 1
    fi

    success "Configuration file syntax is valid"

    # Validate against schema if available
    if [[ -f "$SCHEMA_FILE" ]]; then
        if command -v ajv &> /dev/null; then
            verbose "Validating configuration against JSON schema..."
            if ajv validate -s "$SCHEMA_FILE" -d "$CONFIG_FILE" 2>/dev/null; then
                success "Configuration validation against schema passed"
            else
                warning "Configuration validation against schema failed"
                verbose "Run 'ajv validate -s $SCHEMA_FILE -d $CONFIG_FILE' for details"
            fi
        else
            warning "ajv not installed, skipping JSON schema validation"
            echo "Install with: npm install -g ajv-cli"
        fi
    else
        warning "JSON schema not found: $SCHEMA_FILE"
    fi

    # Validate environment configuration
    local env_config=$(jq -r ".environments.${ENVIRONMENT}" "$CONFIG_FILE")
    if [[ "$env_config" == "null" ]]; then
        error "Environment '$ENVIRONMENT' not found in configuration"
        exit 1
    fi

    success "Environment '$ENVIRONMENT' configuration is valid"
}

# Check TypeScript build
check_typescript_build() {
    log "Checking TypeScript build..."

    cd "$PROJECT_ROOT"

    # Check if dist directory exists
    if [[ ! -d "dist" ]]; then
        warning "TypeScript build not found, building now..."
        if npm run build 2>/dev/null || npx tsc --build; then
            success "TypeScript build completed"
        else
            error "TypeScript build failed"
            exit 1
        fi
    else
        success "TypeScript build found"
    fi

    # Check if CLI is built
    if [[ ! -f "dist/cli/run-layered-tests.js" ]]; then
        error "CLI not found in build output"
        exit 1
    fi

    success "CLI build verified"
}

# Test configuration loading
test_configuration_loading() {
    log "Testing configuration loading..."

    cd "$PROJECT_ROOT"

    # Test dry run to verify configuration loading
    local test_output
    if test_output=$(node dist/cli/run-layered-tests.js --dry-run --environment "$ENVIRONMENT" --config "$CONFIG_FILE" 2>&1); then
        success "Configuration loading test passed"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$test_output"
        fi
    else
        error "Configuration loading test failed"
        echo "$test_output"
        exit 1
    fi
}

# Check local model endpoints
check_local_endpoints() {
    if [[ "$CHECK_ENDPOINTS" != "true" ]]; then
        log "Skipping endpoint checks (--no-endpoints specified)"
        return 0
    fi

    log "Checking local model endpoints..."

    # Common local endpoints for LLM models
    local endpoints=(
        "http://localhost:11434/api/tags"      # Ollama
        "http://localhost:8080/health"         # Generic health endpoint
        "http://localhost:5000/health"         # Alternative health endpoint
        "http://localhost:3000/api/health"     # Express.js style
    )

    local working_endpoints=()
    local failed_endpoints=()

    for endpoint in "${endpoints[@]}"; do
        verbose "Testing endpoint: $endpoint"
        if curl -s --connect-timeout 5 --max-time 10 "$endpoint" >/dev/null 2>&1; then
            working_endpoints+=("$endpoint")
            success "Endpoint responding: $endpoint"
        else
            failed_endpoints+=("$endpoint")
            verbose "Endpoint not responding: $endpoint"
        fi
    done

    if [[ ${#working_endpoints[@]} -gt 0 ]]; then
        success "Found ${#working_endpoints[@]} working endpoint(s)"
        for endpoint in "${working_endpoints[@]}"; do
            echo "  ✅ $endpoint"
        done
    else
        warning "No local endpoints are responding"
        echo "This is normal if no local models are currently running."
        echo "To start local models, you can use:"
        echo "  - Ollama: ollama serve"
        echo "  - Docker: docker run -p 11434:11434 ollama/ollama"
    fi

    if [[ ${#failed_endpoints[@]} -gt 0 && "$VERBOSE" == "true" ]]; then
        echo "Non-responding endpoints:"
        for endpoint in "${failed_endpoints[@]}"; do
            echo "  ❌ $endpoint"
        done
    fi
}

# Test local model inference (if available)
test_local_model_inference() {
    if [[ "$TEST_LOCAL_MODELS" != "true" ]]; then
        log "Skipping local model testing (--no-local specified)"
        return 0
    fi

    log "Testing local model inference..."

    # Test Ollama if available
    if curl -s --connect-timeout 5 "http://localhost:11434/api/tags" >/dev/null 2>&1; then
        log "Testing Ollama inference..."
        
        # Get available models
        local models
        if models=$(curl -s "http://localhost:11434/api/tags" | jq -r '.models[]?.name' 2>/dev/null); then
            if [[ -n "$models" ]]; then
                local first_model=$(echo "$models" | head -n1)
                success "Found Ollama models: $(echo "$models" | tr '\n' ' ')"
                
                # Test simple inference
                local test_prompt="What is 2+2?"
                local response
                if response=$(curl -s -X POST "http://localhost:11434/api/generate" \
                    -H "Content-Type: application/json" \
                    -d "{\"model\":\"$first_model\",\"prompt\":\"$test_prompt\",\"stream\":false}" \
                    --connect-timeout 10 --max-time 30 2>/dev/null); then
                    
                    if echo "$response" | jq -e '.response' >/dev/null 2>&1; then
                        success "Local model inference test passed with model: $first_model"
                        if [[ "$VERBOSE" == "true" ]]; then
                            echo "Response: $(echo "$response" | jq -r '.response' | head -c 100)..."
                        fi
                    else
                        warning "Local model responded but format unexpected"
                        if [[ "$VERBOSE" == "true" ]]; then
                            echo "Response: $response"
                        fi
                    fi
                else
                    warning "Local model inference test failed"
                fi
            else
                warning "No models found in Ollama"
                echo "Install a model with: ollama pull llama3.1:8b"
            fi
        else
            warning "Could not parse Ollama models list"
        fi
    else
        log "Ollama not available, skipping local inference test"
        echo "To test local inference, install and start Ollama:"
        echo "  1. Install: https://ollama.ai/"
        echo "  2. Start: ollama serve"
        echo "  3. Pull model: ollama pull llama3.1:8b"
    fi
}

# Generate verification report
generate_verification_report() {
    log "Generating verification report..."

    echo
    echo "🎯 DEPLOYMENT VERIFICATION REPORT"
    echo "══════════════════════════════════════════════════"
    echo "Environment: $ENVIRONMENT"
    echo "Configuration: $CONFIG_FILE"
    echo "Timestamp: $(date)"
    echo

    # Configuration status
    echo "📋 CONFIGURATION STATUS"
    echo "──────────────────────────────"
    if [[ "$VALIDATE_CONFIG" == "true" ]]; then
        echo "✅ Configuration file syntax: Valid"
        echo "✅ Environment configuration: Valid"
        if [[ -f "$SCHEMA_FILE" ]] && command -v ajv &> /dev/null; then
            echo "✅ Schema validation: Available"
        else
            echo "⚠️  Schema validation: Not available"
        fi
    else
        echo "⏭️  Configuration validation: Skipped"
    fi
    echo

    # Build status
    echo "🔨 BUILD STATUS"
    echo "──────────────────────────────"
    if [[ -d "$PROJECT_ROOT/dist" ]]; then
        echo "✅ TypeScript build: Available"
        echo "✅ CLI interface: Available"
    else
        echo "❌ TypeScript build: Missing"
    fi
    echo

    # Endpoint status
    echo "🌐 ENDPOINT STATUS"
    echo "──────────────────────────────"
    if [[ "$CHECK_ENDPOINTS" == "true" ]]; then
        echo "✅ Endpoint checks: Completed"
        echo "ℹ️  See endpoint results above"
    else
        echo "⏭️  Endpoint checks: Skipped"
    fi
    echo

    # Local testing status
    echo "🧪 LOCAL TESTING STATUS"
    echo "──────────────────────────────"
    if [[ "$TEST_LOCAL_MODELS" == "true" ]]; then
        echo "✅ Local model tests: Completed"
        echo "ℹ️  See test results above"
    else
        echo "⏭️  Local model tests: Skipped"
    fi
    echo

    # Next steps
    echo "🚀 NEXT STEPS"
    echo "──────────────────────────────"
    echo "1. Start local models for testing:"
    echo "   ollama serve && ollama pull llama3.1:8b"
    echo
    echo "2. Run layered tests:"
    echo "   cd deployer-ddf-mod-llm-models"
    echo "   node dist/cli/run-layered-tests.js --dry-run --environment $ENVIRONMENT"
    echo
    echo "3. Deploy to cloud (when ready):"
    echo "   ./scripts/deploy/deploy-with-layered-testing.sh --env=$ENVIRONMENT --dry-run"
    echo
    echo "4. Monitor and validate deployment:"
    echo "   Check CloudWatch logs and metrics (requires AWS access)"
    echo

    success "Verification completed successfully!"
}

# Main execution
main() {
    echo "🔍 DeployerDDF LLM Models - Local Deployment Verification"
    echo "════════════════════════════════════════════════════════════"
    echo

    parse_args "$@"
    check_prerequisites
    validate_configuration
    check_typescript_build
    test_configuration_loading
    check_local_endpoints
    test_local_model_inference
    generate_verification_report
}

# Error handling
trap 'error "Script failed on line $LINENO"' ERR

# Run main function
main "$@" 