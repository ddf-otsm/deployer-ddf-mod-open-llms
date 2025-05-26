#!/bin/bash

# Lightweight AI Testing Script
# Resource-aware testing with smallest models first

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Resource monitoring
RESOURCE_MONITOR="$SCRIPT_DIR/resource-monitor.sh"

# AI Models (ordered by resource usage - lightest first)
MODELS=(
    "deepseek-coder:1.3b"    # Lightest - 1.3B parameters
    "llama3.2:1b"            # Light - 1B parameters  
    "deepseek-coder:6.7b"    # Medium - 6.7B parameters
)

# Test generation targets (prioritized by importance)
TARGETS=(
    "ui-components"          # Highest priority - UI components
    "utilities"              # High priority - Utility functions
    "hooks"                  # Medium priority - React hooks
    "integration"            # Lower priority - Integration tests
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if Ollama is running
check_ollama() {
    log "Checking Ollama service..."
    
    if ! pgrep -f "ollama" > /dev/null; then
        warn "Ollama is not running. Starting Ollama..."
        ollama serve &
        sleep 5
        
        if ! pgrep -f "ollama" > /dev/null; then
            error "Failed to start Ollama service"
            return 1
        fi
    fi
    
    success "Ollama service is running"
    return 0
}

# Check if model is available
check_model() {
    local model=$1
    log "Checking if model $model is available..."
    
    if ollama list | grep -q "$model"; then
        success "Model $model is available"
        return 0
    else
        warn "Model $model not found. Pulling model..."
        
        # Check resources before pulling
        if ! "$RESOURCE_MONITOR" check; then
            error "System resources too high to pull model. Skipping $model"
            return 1
        fi
        
        ollama pull "$model"
        if [ $? -eq 0 ]; then
            success "Model $model pulled successfully"
            return 0
        else
            error "Failed to pull model $model"
            return 1
        fi
    fi
}

# Generate tests for UI components
generate_ui_tests() {
    local model=$1
    log "Generating UI component tests with $model..."
    
    # Create output directory
    mkdir -p tests/unit/ai-generated
    
    # Find UI components
    local components=($(find client/src/components/ui -name "*.tsx" | head -5))  # Limit to 5 for resource management
    
    for component in "${components[@]}"; do
        local component_name=$(basename "$component" .tsx)
        local test_file="tests/unit/ai-generated/${component_name}.test.tsx"
        
        if [ -f "$test_file" ]; then
            log "Test already exists for $component_name, skipping..."
            continue
        fi
        
        log "Generating test for $component_name..."
        
        # Check resources before each generation
        if ! "$RESOURCE_MONITOR" check; then
            warn "Resources high, pausing test generation..."
            sleep 30
            continue
        fi
        
        # Generate test using Ollama
        local prompt="Generate a comprehensive Vitest test for the React component in $component. 
Use @testing-library/react and @testing-library/jest-dom.
Include tests for:
- Basic rendering
- Props handling
- User interactions
- Edge cases
- Accessibility

The test should be TypeScript compatible and follow these patterns:
- Use describe/it blocks
- Use proper assertions with expect()
- Mock any external dependencies
- Test component behavior, not implementation

Component file: $component"

        # Generate test with timeout and resource monitoring
        timeout 60s ollama generate "$model" "$prompt" > "$test_file.tmp" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -s "$test_file.tmp" ]; then
            # Basic validation - check if it looks like a test file
            if grep -q "describe\|it\|test\|expect" "$test_file.tmp"; then
                mv "$test_file.tmp" "$test_file"
                success "Generated test for $component_name"
            else
                warn "Generated content doesn't look like a test file for $component_name"
                rm -f "$test_file.tmp"
            fi
        else
            warn "Failed to generate test for $component_name"
            rm -f "$test_file.tmp"
        fi
        
        # Small delay to prevent overwhelming the system
        sleep 2
    done
}

# Generate utility function tests
generate_utility_tests() {
    local model=$1
    log "Generating utility function tests with $model..."
    
    # Create output directory
    mkdir -p tests/unit/ai-generated
    
    # Find utility files
    local utils=($(find client/src/lib -name "*.ts" -o -name "*.tsx" | head -3))  # Limit to 3
    
    for util in "${utils[@]}"; do
        local util_name=$(basename "$util" | sed 's/\.[^.]*$//')
        local test_file="tests/unit/ai-generated/${util_name}.test.ts"
        
        if [ -f "$test_file" ]; then
            log "Test already exists for $util_name, skipping..."
            continue
        fi
        
        log "Generating test for $util_name..."
        
        # Check resources
        if ! "$RESOURCE_MONITOR" check; then
            warn "Resources high, pausing test generation..."
            sleep 30
            continue
        fi
        
        # Generate test
        local prompt="Generate comprehensive Vitest unit tests for the utility functions in $util.
Include tests for:
- All exported functions
- Edge cases and error conditions
- Input validation
- Return value verification

Use TypeScript and follow these patterns:
- Use describe/it blocks
- Use proper type assertions
- Test all code paths
- Mock external dependencies if needed

Utility file: $util"

        timeout 60s ollama generate "$model" "$prompt" > "$test_file.tmp" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -s "$test_file.tmp" ]; then
            if grep -q "describe\|it\|test\|expect" "$test_file.tmp"; then
                mv "$test_file.tmp" "$test_file"
                success "Generated test for $util_name"
            else
                warn "Generated content doesn't look like a test file for $util_name"
                rm -f "$test_file.tmp"
            fi
        else
            warn "Failed to generate test for $util_name"
            rm -f "$test_file.tmp"
        fi
        
        sleep 2
    done
}

# Run generated tests
run_tests() {
    log "Running generated tests..."
    
    # Check if any tests were generated
    if [ ! -d "tests/unit/ai-generated" ] || [ -z "$(ls -A tests/unit/ai-generated)" ]; then
        warn "No AI-generated tests found"
        return 1
    fi
    
    # Run tests with timeout
    log "Executing test suite..."
    timeout 300s npm test -- tests/unit/ai-generated/ 2>&1 | tee logs/ai-test-results.log
    
    local test_result=$?
    
    if [ $test_result -eq 0 ]; then
        success "All AI-generated tests passed!"
    else
        warn "Some tests failed or timed out. Check logs/ai-test-results.log"
    fi
    
    return $test_result
}

# Main execution
main() {
    log "🚀 Starting Lightweight AI Testing"
    log "📊 Monitoring system resources..."
    
    # Initial resource check
    if ! "$RESOURCE_MONITOR" check; then
        error "System resources too high to start AI testing"
        echo "Current system status:"
        "$RESOURCE_MONITOR" check
        echo ""
        echo "Please close some applications and try again, or use:"
        echo "  $0 --force    # Force execution despite high resources"
        exit 1
    fi
    
    # Check Ollama
    if ! check_ollama; then
        error "Cannot start without Ollama service"
        exit 1
    fi
    
    # Try models in order of resource usage (lightest first)
    local model_used=""
    for model in "${MODELS[@]}"; do
        log "Attempting to use model: $model"
        
        if check_model "$model"; then
            model_used="$model"
            break
        else
            warn "Model $model not available, trying next..."
        fi
    done
    
    if [ -z "$model_used" ]; then
        error "No AI models available for testing"
        exit 1
    fi
    
    success "Using model: $model_used"
    
    # Generate tests with resource monitoring
    log "🧪 Starting test generation..."
    
    # Start resource monitoring in background
    "$RESOURCE_MONITOR" check &
    local monitor_pid=$!
    
    # Generate UI tests first (highest priority)
    generate_ui_tests "$model_used"
    
    # Check resources before continuing
    if "$RESOURCE_MONITOR" check; then
        generate_utility_tests "$model_used"
    else
        warn "Resources high, skipping utility tests"
    fi
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    
    # Run the generated tests
    run_tests
    
    # Final resource check
    log "📊 Final resource status:"
    "$RESOURCE_MONITOR" check
    
    success "🎉 Lightweight AI testing completed!"
    log "📋 Check logs/ai-test-results.log for detailed results"
}

# Handle command line arguments
case "${1:-}" in
    "--force")
        log "⚠️  Force mode enabled - skipping resource checks"
        RESOURCE_MONITOR="echo"  # Disable resource monitoring
        main
        ;;
    "--help"|"-h")
        echo "Lightweight AI Testing Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --force    Force execution despite high system resources"
        echo "  --help     Show this help message"
        echo ""
        echo "This script generates tests using AI models while monitoring system resources."
        echo "It will automatically use the lightest available model and pause if resources are high."
        ;;
    "")
        main
        ;;
    *)
        error "Unknown option: $1"
        echo "Use $0 --help for usage information"
        exit 1
        ;;
esac 