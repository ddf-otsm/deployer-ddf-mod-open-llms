#!/bin/bash
# Quick test script for deployer-ddf-mod-open-llms
# Tests all endpoints and validates functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:3000"
TIMEOUT=10

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test counter
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_status="${3:-200}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "Running: $test_name"
    
    if eval "$test_command"; then
        success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        error "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if service is running
check_service() {
    log "Checking if service is running on $BASE_URL..."
    
    if curl -s --connect-timeout $TIMEOUT "$BASE_URL/health" >/dev/null 2>&1; then
        success "Service is running"
        return 0
    else
        error "Service is not running or not accessible"
        echo "Please start the service first:"
        echo "  NODE_ENV=development AUTH_DISABLED=true ./run.sh --env=dev --platform=cursor --fast"
        exit 1
    fi
}

# Test health endpoint
test_health() {
    local response=$(curl -s -w "%{http_code}" --connect-timeout $TIMEOUT "$BASE_URL/health" 2>/dev/null)
    local status_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$status_code" == "200" ]]; then
        # Validate JSON response
        if echo "$body" | jq -e '.status == "healthy"' >/dev/null 2>&1; then
            return 0
        else
            echo "Invalid health response format"
            return 1
        fi
    else
        echo "HTTP $status_code"
        return 1
    fi
}

# Test API status endpoint
test_api_status() {
    local response=$(curl -s -w "%{http_code}" --connect-timeout $TIMEOUT "$BASE_URL/api/status" 2>/dev/null)
    local status_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$status_code" == "200" ]]; then
        # Validate JSON response
        if echo "$body" | jq -e '.service == "AI Testing Agent"' >/dev/null 2>&1; then
            return 0
        else
            echo "Invalid API status response format"
            return 1
        fi
    else
        echo "HTTP $status_code"
        return 1
    fi
}

# Test generate tests endpoint
test_generate_tests() {
    local test_payload='{"code":"function add(a, b) { return a + b; }", "language":"javascript"}'
    local response=$(curl -s -w "%{http_code}" --connect-timeout $TIMEOUT \
        -X POST "$BASE_URL/api/generate-tests" \
        -H "Content-Type: application/json" \
        -d "$test_payload" 2>/dev/null)
    local status_code="${response: -3}"
    local body="${response%???}"
    
    if [[ "$status_code" == "200" ]]; then
        # Validate JSON response
        if echo "$body" | jq -e '.success == true' >/dev/null 2>&1; then
            return 0
        else
            echo "Invalid generate tests response format"
            return 1
        fi
    else
        echo "HTTP $status_code"
        return 1
    fi
}

# Test authentication bypass
test_auth_bypass() {
    # Test without any authentication headers
    local response=$(curl -s -w "%{http_code}" --connect-timeout $TIMEOUT \
        -X POST "$BASE_URL/api/generate-tests" \
        -H "Content-Type: application/json" \
        -d '{"code":"test", "language":"javascript"}' 2>/dev/null)
    local status_code="${response: -3}"
    
    if [[ "$status_code" == "200" ]]; then
        return 0
    else
        echo "Authentication bypass failed - HTTP $status_code"
        return 1
    fi
}

# Test error handling
test_error_handling() {
    # Test with invalid JSON
    local response=$(curl -s -w "%{http_code}" --connect-timeout $TIMEOUT \
        -X POST "$BASE_URL/api/generate-tests" \
        -H "Content-Type: application/json" \
        -d '{"invalid": json}' 2>/dev/null)
    local status_code="${response: -3}"
    
    if [[ "$status_code" == "400" ]]; then
        return 0
    else
        echo "Expected 400 for invalid JSON, got HTTP $status_code"
        return 1
    fi
}

# Test 404 handling
test_404_handling() {
    local response=$(curl -s -w "%{http_code}" --connect-timeout $TIMEOUT \
        "$BASE_URL/nonexistent-endpoint" 2>/dev/null)
    local status_code="${response: -3}"
    
    if [[ "$status_code" == "404" ]]; then
        return 0
    else
        echo "Expected 404 for nonexistent endpoint, got HTTP $status_code"
        return 1
    fi
}

# Performance test
test_performance() {
    log "Running performance test (10 concurrent requests)..."
    
    local start_time=$(date +%s.%N)
    
    # Run 10 concurrent health checks
    for i in {1..10}; do
        curl -s "$BASE_URL/health" >/dev/null 2>&1 &
    done
    
    # Wait for all background jobs to complete
    wait
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Check if duration is reasonable (less than 5 seconds)
    if (( $(echo "$duration < 5.0" | bc -l 2>/dev/null || echo "1") )); then
        echo "Performance test completed in ${duration}s"
        return 0
    else
        echo "Performance test took too long: ${duration}s"
        return 1
    fi
}

echo "🧪 Quick Test Suite for deployer-ddf-mod-open-llms"
echo "================================================="

# Check prerequisites
if ! command -v curl >/dev/null 2>&1; then
    error "curl is required but not installed"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    warning "jq is not installed - JSON validation will be limited"
fi

# Check if service is running
check_service

echo ""
log "Running endpoint tests..."

# Run all tests
run_test "Health endpoint" "test_health"
run_test "API status endpoint" "test_api_status"
run_test "Generate tests endpoint" "test_generate_tests"
run_test "Authentication bypass" "test_auth_bypass"
run_test "Error handling (400)" "test_error_handling"
run_test "404 handling" "test_404_handling"

# Performance test (optional)
if command -v bc >/dev/null 2>&1; then
    run_test "Performance test" "test_performance"
else
    warning "bc not available - skipping performance test"
fi

echo ""
echo "📊 Test Results Summary"
echo "======================"
echo "Total tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
    success "All tests passed! 🎉"
    echo ""
    echo "✅ The service is working correctly"
    echo "✅ All endpoints are accessible"
    echo "✅ Authentication bypass is working"
    echo "✅ Error handling is proper"
    exit 0
else
    error "Some tests failed"
    echo ""
    echo "❌ $TESTS_FAILED out of $TESTS_TOTAL tests failed"
    echo "Please check the service configuration and try again"
    exit 1
fi 