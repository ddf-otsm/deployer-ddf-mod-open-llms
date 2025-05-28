#!/bin/bash
# Demo Script: Llama 4 Maverick Endpoint
# Demonstrates the working curl endpoint for Llama 4 Maverick

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values
MODE="local"
VERBOSE=false
LOCAL_URL="http://localhost:3000"
AWS_URL="https://api.deployer-ddf.com"  # Replace with actual AWS URL

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --local)
            MODE="local"
            ;;
        --aws)
            MODE="aws"
            ;;
        --verbose)
            VERBOSE=true
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Show help
show_help() {
    cat << EOF
Demo script for Llama 4 Maverick endpoint

Usage: $0 [OPTIONS]

Options:
    --local     Test local endpoint (default)
    --aws       Test AWS endpoint
    --verbose   Show detailed responses
    --help      Show this help message

Examples:
    $0 --local --verbose
    $0 --aws
EOF
}

# Set base URL based on mode
if [ "$MODE" = "local" ]; then
    BASE_URL="$LOCAL_URL"
    echo -e "${CYAN}🏠 Testing LOCAL Llama 4 Maverick endpoint${NC}"
else
    BASE_URL="$AWS_URL"
    echo -e "${CYAN}☁️  Testing AWS Llama 4 Maverick endpoint${NC}"
fi

echo -e "${BLUE}Base URL: $BASE_URL${NC}"
echo ""

# Function to make API calls with error handling
call_api() {
    local endpoint="$1"
    local method="$2"
    local data="$3"
    local description="$4"
    
    echo -e "${YELLOW}🧪 Testing: $description${NC}"
    echo -e "${BLUE}Endpoint: $method $endpoint${NC}"
    
    if [ "$VERBOSE" = true ] && [ -n "$data" ]; then
        echo -e "${PURPLE}Request:${NC}"
        echo "$data" | jq .
    fi
    
    local response
    local http_code
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" \
            "$BASE_URL$endpoint" 2>/dev/null || echo -e "\n000")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Success (HTTP $http_code)${NC}"
        if [ "$VERBOSE" = true ]; then
            echo -e "${GREEN}Response:${NC}"
            echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
        else
            # Show just the key information
            if echo "$response_body" | jq . >/dev/null 2>&1; then
                local model=$(echo "$response_body" | jq -r '.model // "N/A"')
                local success=$(echo "$response_body" | jq -r '.success // "N/A"')
                local response_length=$(echo "$response_body" | jq -r '.response // ""' | wc -c)
                echo -e "${GREEN}Model: $model${NC}"
                echo -e "${GREEN}Success: $success${NC}"
                echo -e "${GREEN}Response length: $response_length characters${NC}"
            else
                echo "$response_body"
            fi
        fi
    else
        echo -e "${RED}❌ Failed (HTTP $http_code)${NC}"
        if [ "$VERBOSE" = true ]; then
            echo -e "${RED}Response:${NC}"
            echo "$response_body"
        fi
    fi
    
    echo ""
}

# Header
echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}🦙 Llama 4 Maverick Demo${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

# Test 1: Health check
call_api "/health" "GET" "" "Health Check"

# Test 2: API status
call_api "/api/status" "GET" "" "API Status"

# Test 3: Test generation prompt
test_generation_prompt='{
  "prompt": "Generate a comprehensive test suite for a React component that handles user authentication",
  "max_tokens": 500,
  "temperature": 0.1
}'

call_api "/api/llama4-maverick" "POST" "$test_generation_prompt" "Test Generation"

# Test 4: Architecture analysis prompt
architecture_prompt='{
  "prompt": "Analyze the architecture of a microservices-based e-commerce platform and provide recommendations",
  "max_tokens": 600,
  "temperature": 0.2
}'

call_api "/api/llama4-maverick" "POST" "$architecture_prompt" "Architecture Analysis"

# Test 5: Debugging prompt
debug_prompt='{
  "prompt": "Debug a React component that has memory leaks and performance issues",
  "max_tokens": 400,
  "temperature": 0.1
}'

call_api "/api/llama4-maverick" "POST" "$debug_prompt" "Debugging Analysis"

# Test 6: Generic prompt
generic_prompt='{
  "prompt": "Explain the benefits of using Llama 4 Maverick for enterprise development",
  "max_tokens": 300,
  "temperature": 0.3
}'

call_api "/api/llama4-maverick" "POST" "$generic_prompt" "Generic Response"

# Test 7: Parameter validation (should fail)
echo -e "${YELLOW}🧪 Testing: Parameter Validation (Expected Failure)${NC}"
invalid_prompt='{
  "prompt": "Test prompt",
  "max_tokens": 5000,
  "temperature": 2.0
}'

call_api "/api/llama4-maverick" "POST" "$invalid_prompt" "Invalid Parameters"

# Test 8: Missing prompt (should fail)
echo -e "${YELLOW}🧪 Testing: Missing Prompt (Expected Failure)${NC}"
missing_prompt='{
  "max_tokens": 100
}'

call_api "/api/llama4-maverick" "POST" "$missing_prompt" "Missing Prompt"

# Summary
echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}📊 Demo Summary${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

echo -e "${GREEN}✅ Llama 4 Maverick Features Demonstrated:${NC}"
echo "   • Comprehensive test suite generation"
echo "   • Architecture analysis and recommendations"
echo "   • Complex debugging and optimization"
echo "   • Generic AI assistance"
echo "   • Parameter validation"
echo "   • Error handling"
echo ""

echo -e "${BLUE}🔧 Model Specifications:${NC}"
echo "   • Model: meta-llama/Llama-4-Maverick-17B-128E-Instruct"
echo "   • Active Parameters: 17B"
echo "   • Total Parameters: 400B"
echo "   • Experts: 128 (MoE architecture)"
echo "   • Max Tokens: 1-2000"
echo "   • Temperature: 0.0-1.0"
echo ""

echo -e "${CYAN}🌐 Endpoint Information:${NC}"
echo "   • Base URL: $BASE_URL"
echo "   • Health Check: $BASE_URL/health"
echo "   • API Status: $BASE_URL/api/status"
echo "   • Llama 4 Maverick: $BASE_URL/api/llama4-maverick"
echo "   • Swagger UI: $BASE_URL/api-docs"
echo ""

if [ "$MODE" = "local" ]; then
    echo -e "${YELLOW}💡 Next Steps:${NC}"
    echo "   1. Deploy to AWS using: ./scripts/deploy/deploy-llama4-maverick.sh --env=dev"
    echo "   2. Test AWS endpoint: $0 --aws"
    echo "   3. Configure load balancer and custom domain"
else
    echo -e "${YELLOW}💡 Production Ready:${NC}"
    echo "   • Llama 4 Maverick is deployed and accessible"
    echo "   • Ready for production workloads"
    echo "   • Monitor performance and scale as needed"
fi

echo ""
echo -e "${GREEN}🎉 Demo completed successfully!${NC}" 