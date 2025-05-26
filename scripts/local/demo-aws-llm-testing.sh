#!/bin/bash
# Demo script for AWS LLM Model Testing
# This demonstrates the testing capabilities that are already implemented

set -euo pipefail

echo "🚀 AWS LLM Model Testing Demonstration"
echo "======================================"
echo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test configuration
OLLAMA_URL="http://localhost:11434"
MODELS=("deepseek-coder:1.3b" "llama3.2:1b" "deepseek-coder:6.7b")

# Function to test model availability
test_model_availability() {
    echo -e "${YELLOW}📋 Testing model availability...${NC}"
    
    local response=$(curl -s "$OLLAMA_URL/api/tags" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        echo -e "${GREEN}✅ Ollama service is running${NC}"
        echo "Available models:"
        echo "$response" | jq -r '.models[].name' | while read -r model; do
            echo "  - $model"
        done
        echo
        return 0
    else
        echo -e "${RED}❌ Ollama service not available${NC}"
        return 1
    fi
}

# Function to test code generation
test_code_generation() {
    local model="$1"
    echo -e "${YELLOW}🧪 Testing code generation with $model...${NC}"
    
    local prompt="Write a TypeScript function to calculate the factorial of a number"
    local request_data="{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}"
    
    local start_time=$(date +%s)
    local response=$(curl -s -X POST "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$request_data" 2>/dev/null || echo "")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ -n "$response" ]] && echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        local generated_code=$(echo "$response" | jq -r '.response')
        echo -e "${GREEN}✅ Code generation successful (${duration}s)${NC}"
        echo "Generated code preview:"
        echo "$generated_code" | head -n 5
        echo "..."
        echo
        return 0
    else
        echo -e "${RED}❌ Code generation failed${NC}"
        return 1
    fi
}

# Function to test error fixing
test_error_fixing() {
    local model="$1"
    echo -e "${YELLOW}🔧 Testing error fixing with $model...${NC}"
    
    local error_code="const x: string = 123; // TypeScript error"
    local prompt="Fix this TypeScript error: $error_code"
    local request_data="{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}"
    
    local start_time=$(date +%s)
    local response=$(curl -s -X POST "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$request_data" 2>/dev/null || echo "")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ -n "$response" ]] && echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        local fixed_code=$(echo "$response" | jq -r '.response')
        echo -e "${GREEN}✅ Error fixing successful (${duration}s)${NC}"
        echo "Fixed code preview:"
        echo "$fixed_code" | head -n 3
        echo "..."
        echo
        return 0
    else
        echo -e "${RED}❌ Error fixing failed${NC}"
        return 1
    fi
}

# Function to test code review
test_code_review() {
    local model="$1"
    echo -e "${YELLOW}👀 Testing code review with $model...${NC}"
    
    local code_sample='function calculateTotal(items) {
        let total = 0;
        for (let i = 0; i < items.length; i++) {
            total += items[i].price * items[i].quantity;
        }
        return total;
    }'
    
    local prompt="Review this JavaScript code and suggest improvements: $code_sample"
    local request_data="{\"model\":\"$model\",\"prompt\":\"$prompt\",\"stream\":false}"
    
    local start_time=$(date +%s)
    local response=$(curl -s -X POST "$OLLAMA_URL/api/generate" \
        -H "Content-Type: application/json" \
        -d "$request_data" 2>/dev/null || echo "")
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ -n "$response" ]] && echo "$response" | jq -e '.response' >/dev/null 2>&1; then
        local review_text=$(echo "$response" | jq -r '.response')
        echo -e "${GREEN}✅ Code review successful (${duration}s)${NC}"
        echo "Review preview:"
        echo "$review_text" | head -n 3
        echo "..."
        echo
        return 0
    else
        echo -e "${RED}❌ Code review failed${NC}"
        return 1
    fi
}

# Function to run performance benchmark
run_performance_benchmark() {
    local model="$1"
    local iterations=3
    echo -e "${YELLOW}📊 Running performance benchmark for $model ($iterations iterations)...${NC}"
    
    local total_time=0
    local successful_requests=0
    
    for ((i=1; i<=iterations; i++)); do
        echo "  Iteration $i/$iterations"
        
        local start_time=$(date +%s%3N)
        if curl -s -X POST "$OLLAMA_URL/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$model\",\"prompt\":\"Write a simple function\",\"stream\":false}" \
            >/dev/null 2>&1; then
            
            local end_time=$(date +%s%3N)
            local duration=$((end_time - start_time))
            total_time=$((total_time + duration))
            ((successful_requests++))
        fi
    done
    
    if [[ $successful_requests -gt 0 ]]; then
        local avg_time=$((total_time / successful_requests))
        echo -e "${GREEN}✅ Performance benchmark completed${NC}"
        echo "  Average response time: ${avg_time}ms"
        echo "  Success rate: $successful_requests/$iterations"
        echo
    else
        echo -e "${RED}❌ Performance benchmark failed${NC}"
        echo
    fi
}

# Main execution
main() {
    echo "This demonstration shows the AWS LLM model testing capabilities"
    echo "that are already implemented in the deployer-ddf-mod-llm-models project."
    echo
    
    # Test model availability
    if ! test_model_availability; then
        echo -e "${RED}❌ Cannot proceed without Ollama service${NC}"
        echo "Please start Ollama with: ollama serve"
        exit 1
    fi
    
    # Test each available model
    for model in "${MODELS[@]}"; do
        echo -e "${YELLOW}🔍 Testing model: $model${NC}"
        echo "----------------------------------------"
        
        # Check if model is available
        if curl -s "$OLLAMA_URL/api/tags" | jq -e ".models[] | select(.name == \"$model\")" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Model $model is available${NC}"
            
            # Run comprehensive tests
            test_code_generation "$model"
            test_error_fixing "$model"
            test_code_review "$model"
            run_performance_benchmark "$model"
            
        else
            echo -e "${YELLOW}⚠️  Model $model not available locally${NC}"
            echo "You can pull it with: ollama pull $model"
        fi
        
        echo
    done
    
    echo -e "${GREEN}🎉 AWS LLM Model Testing Demonstration Complete!${NC}"
    echo
    echo "📋 Summary of Capabilities Demonstrated:"
    echo "  ✅ Model availability checking"
    echo "  ✅ Code generation testing"
    echo "  ✅ Error fixing validation"
    echo "  ✅ Code review capabilities"
    echo "  ✅ Performance benchmarking"
    echo
    echo "🚀 Next Steps:"
    echo "  1. Deploy to AWS using: ./scripts/deploy/aws-deploy.sh"
    echo "  2. Run AWS health checks: ./scripts/deploy/health-check.sh"
    echo "  3. Test distributed execution: ./scripts/deploy/test-deployment.sh"
    echo
    echo "📖 Related Plans:"
    echo "  - AWS LLM Deployment Plan (in-progress)"
    echo "  - AWS LLM Model Testing Calls (backlog)"
    echo "  - Variable-Based Project Naming (backlog)"
    echo "  - Constants Review and Consolidation (backlog)"
}

# Run the demonstration
main "$@" 