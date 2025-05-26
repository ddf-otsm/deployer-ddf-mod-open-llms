#!/bin/bash
# Local AI Testing Agent - Development Script
# Tests the AI agent locally using Docker Ollama

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_CONTAINER="ddf-ai-testing-ollama-local"
OLLAMA_PORT="11434"
MODEL_NAME="deepseek-coder:6b"
TIMEOUT=300

echo -e "${BLUE}🤖 Local AI Testing Agent${NC}"
echo "=================================="

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Function to start Ollama container
start_ollama() {
    echo -e "${YELLOW}🐳 Starting Ollama container...${NC}"
    
    # Stop existing container if running
    docker stop $OLLAMA_CONTAINER 2>/dev/null || true
    docker rm $OLLAMA_CONTAINER 2>/dev/null || true
    
    # Start new container
    docker run -d \
        --name $OLLAMA_CONTAINER \
        -p $OLLAMA_PORT:11434 \
        -v ollama_data:/root/.ollama \
        ollama/ollama:latest
    
    echo -e "${GREEN}✅ Ollama container started${NC}"
}

# Function to wait for Ollama to be ready
wait_for_ollama() {
    echo -e "${YELLOW}⏳ Waiting for Ollama to be ready...${NC}"
    
    local count=0
    while [ $count -lt $TIMEOUT ]; do
        if curl -s http://localhost:$OLLAMA_PORT/api/tags >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Ollama is ready!${NC}"
            return 0
        fi
        sleep 2
        count=$((count + 2))
        echo -n "."
    done
    
    echo -e "${RED}❌ Timeout waiting for Ollama${NC}"
    exit 1
}

# Function to pull the model
pull_model() {
    echo -e "${YELLOW}🧠 Pulling $MODEL_NAME model...${NC}"
    echo "This may take several minutes for the first run..."
    
    curl -X POST http://localhost:$OLLAMA_PORT/api/pull \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$MODEL_NAME\"}" \
        --max-time 600 \
        --silent --show-error
    
    echo -e "${GREEN}✅ Model pulled successfully!${NC}"
}

# Function to test the model
test_model() {
    echo -e "${YELLOW}🧪 Testing model with simple prompt...${NC}"
    
    local test_response=$(curl -s -X POST http://localhost:$OLLAMA_PORT/api/generate \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'$MODEL_NAME'",
            "prompt": "Write a simple React test using Vitest. Just return: describe(\"test\", () => { it(\"works\", () => { expect(true).toBe(true); }); });",
            "stream": false,
            "options": {
                "temperature": 0.1,
                "num_predict": 100
            }
        }')
    
    if echo "$test_response" | grep -q "describe"; then
        echo -e "${GREEN}✅ Model is responding correctly${NC}"
    else
        echo -e "${RED}❌ Model test failed${NC}"
        echo "Response: $test_response"
        exit 1
    fi
}

# Function to run AI test generation
run_ai_tests() {
    echo -e "${YELLOW}🚀 Running AI test generation...${NC}"
    
    # Check if Python script exists
    if [ ! -f "deployer-ddf-mod-llm-models/tests/local_llm_testgen.py" ]; then
        echo -e "${RED}❌ Test generation script not found${NC}"
        exit 1
    fi
    
    # Install Python dependencies if needed
    if ! python3 -c "import requests" 2>/dev/null; then
        echo -e "${YELLOW}📦 Installing Python dependencies...${NC}"
        pip3 install requests
    fi
    
    # Run the test generator
    echo -e "${BLUE}🎯 Analyzing changed files...${NC}"
            python3 deployer-ddf-mod-llm-models/tests/local_llm_testgen.py client/src --changed-only
    
    # If no changed files, analyze a sample component
    if [ ! -d "tests/ai_generated" ] || [ -z "$(ls -A tests/ai_generated 2>/dev/null)" ]; then
        echo -e "${YELLOW}📝 No changed files found, testing with sample component...${NC}"
        
        # Find a sample component to test
        sample_file=$(find client/src/components -name "*.tsx" -not -name "*.test.tsx" | head -1)
        if [ -n "$sample_file" ]; then
            echo -e "${BLUE}🔍 Testing with: $sample_file${NC}"
            python3 deployer-ddf-mod-llm-models/tests/local_llm_testgen.py client/src
        fi
    fi
}

# Function to run generated tests
run_generated_tests() {
    if [ -d "tests/ai_generated" ] && [ "$(ls -A tests/ai_generated 2>/dev/null)" ]; then
        echo -e "${YELLOW}🧪 Running AI-generated tests...${NC}"
        npm run test tests/ai_generated
        echo -e "${GREEN}✅ AI-generated tests completed${NC}"
    else
        echo -e "${YELLOW}📝 No AI-generated tests to run${NC}"
    fi
}

# Function to cleanup
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    docker stop $OLLAMA_CONTAINER 2>/dev/null || true
    docker rm $OLLAMA_CONTAINER 2>/dev/null || true
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     - Start Ollama and pull model"
    echo "  test      - Run AI test generation"
    echo "  stop      - Stop and cleanup Ollama container"
    echo "  full      - Run complete pipeline (start + test + stop)"
    echo "  status    - Check Ollama status"
    echo ""
    echo "Examples:"
    echo "  $0 full          # Complete AI testing pipeline"
    echo "  $0 start         # Just start Ollama service"
    echo "  $0 test          # Generate tests (requires Ollama running)"
}

# Main execution
case "${1:-full}" in
    "start")
        check_docker
        start_ollama
        wait_for_ollama
        pull_model
        test_model
        echo -e "${GREEN}🎉 AI Testing Agent is ready!${NC}"
        echo -e "${BLUE}💡 Run '$0 test' to generate tests${NC}"
        ;;
    
    "test")
        if ! curl -s http://localhost:$OLLAMA_PORT/api/tags >/dev/null 2>&1; then
            echo -e "${RED}❌ Ollama is not running. Run '$0 start' first.${NC}"
            exit 1
        fi
        run_ai_tests
        run_generated_tests
        ;;
    
    "stop")
        cleanup
        ;;
    
    "full")
        check_docker
        start_ollama
        wait_for_ollama
        pull_model
        test_model
        run_ai_tests
        run_generated_tests
        cleanup
        echo -e "${GREEN}🎉 AI Testing Pipeline completed!${NC}"
        ;;
    
    "status")
        if curl -s http://localhost:$OLLAMA_PORT/api/tags >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Ollama is running on port $OLLAMA_PORT${NC}"
            
            # Check if model is available
            if curl -s http://localhost:$OLLAMA_PORT/api/tags | grep -q "$MODEL_NAME"; then
                echo -e "${GREEN}✅ Model $MODEL_NAME is available${NC}"
            else
                echo -e "${YELLOW}⚠️  Model $MODEL_NAME not found${NC}"
            fi
        else
            echo -e "${RED}❌ Ollama is not running${NC}"
        fi
        ;;
    
    "help"|"-h"|"--help")
        show_usage
        ;;
    
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_usage
        exit 1
        ;;
esac 