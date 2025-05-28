#!/bin/bash

# Smoke test script for DeployerDDF Module: Open Source LLM Models
# Tests all key endpoints and ports

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base URL (default to localhost:3000)
BASE_URL="http://localhost:3000"

# Function to log results
echo_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}[PASS]${NC} $2"
  else
    echo -e "${RED}[FAIL]${NC} $2"
  fi
}

# Test endpoints
echo "Starting smoke tests for $BASE_URL..."

# Test /health endpoint
curl -s -f "$BASE_URL/health" > /dev/null
RESULT=$?
echo_result $RESULT "/health endpoint"

# Test /api/status endpoint
curl -s -f "$BASE_URL/api/status" > /dev/null
RESULT=$?
echo_result $RESULT "/api/status endpoint"

# Test /api-docs endpoint
curl -s -f "$BASE_URL/api-docs/" > /dev/null
RESULT=$?
echo_result $RESULT "/api-docs endpoint"

# Test /api-docs.json endpoint
curl -s -f "$BASE_URL/api-docs.json" > /dev/null
RESULT=$?
echo_result $RESULT "/api-docs.json endpoint"

# Test /chat endpoint
curl -s -f "$BASE_URL/chat" > /dev/null
RESULT=$?
echo_result $RESULT "/chat endpoint"

# Test POST endpoints with minimal payload
# /api/generate-tests
curl -s -f -X POST "$BASE_URL/api/generate-tests" -H "Content-Type: application/json" -d '{"code": "function test(){}", "language": "javascript"}' > /dev/null
RESULT=$?
echo_result $RESULT "/api/generate-tests POST endpoint"

# /api/chat
curl -s -f -X POST "$BASE_URL/api/chat" -H "Content-Type: application/json" -d '{"message": "Hello", "model": "deepseek-coder:1.3b"}' > /dev/null
RESULT=$?
echo_result $RESULT "/api/chat POST endpoint"

# /api/llama4-maverick
curl -s -f -X POST "$BASE_URL/api/llama4-maverick" -H "Content-Type: application/json" -d '{"prompt": "Test prompt"}' > /dev/null
RESULT=$?
echo_result $RESULT "/api/llama4-maverick POST endpoint"

echo "Smoke tests completed." 