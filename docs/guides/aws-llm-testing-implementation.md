# AWS LLM Model Testing Calls Implementation Plan

**Status:** Backlog  
**Priority:** High  
**Estimated Effort:** 1-2 days  
**Created:** 2025-01-22  
**Parent Plan:** [AWS LLM Deployment Plan](../in-progress/aws-llm-deployment-plan.md)

## Overview

Implement comprehensive testing of AWS-deployed LLM models through API calls, building on the existing AWS deployment infrastructure. This plan focuses on the actual testing execution and validation of deployed models.

## Current Status

### ✅ Already Implemented (from AWS LLM Deployment Plan)
- AWS deployment scripts (`aws-deploy.sh`)
- Health check infrastructure (`health-check.sh`)
- Service endpoint discovery
- Basic model availability testing
- CloudFormation templates for AWS resources

### 🔄 In Progress
- Distributed testing infrastructure
- Parallel test execution framework

### ❌ Missing (This Plan's Scope)
- Comprehensive model testing suite
- Performance benchmarking
- Error fixing validation
- Test result aggregation and reporting

## Implementation Tasks

### Phase 1: Enhanced Model Testing Framework
- [ ] **Extend existing health-check.sh script**
  - [ ] Add comprehensive model testing beyond basic availability
  - [ ] Implement layered testing (Tier 1-4 models)
  - [ ] Add role-based testing (assistant, code_reviewer, etc.)
  - [ ] Include performance benchmarking with detailed metrics

- [ ] **Create dedicated AWS model testing script**
  - [ ] `deployer-ddf-mod-llm-models/scripts/deploy/test-aws-models.sh`
  - [ ] Support for multiple AWS regions
  - [ ] Parallel testing across multiple endpoints
  - [ ] Comprehensive error handling and retry logic

### Phase 2: Test Execution and Validation
- [ ] **Implement test scenarios from config/llm-models.json**
  - [ ] Execute standard questions for each model tier
  - [ ] Validate response quality and format
  - [ ] Test role-specific capabilities
  - [ ] Measure response times and accuracy

- [ ] **Error fixing and code generation testing**
  - [ ] Test TypeScript error fixing capabilities
  - [ ] Validate JavaScript code generation
  - [ ] Test React component generation
  - [ ] Verify test generation functionality

### Phase 3: Performance and Monitoring
- [ ] **Performance benchmarking**
  - [ ] Response time measurements
  - [ ] Throughput testing under load
  - [ ] Memory and CPU usage monitoring
  - [ ] Cost per request calculations

- [ ] **Automated reporting**
  - [ ] Generate test reports in JSON/HTML format
  - [ ] Create performance dashboards
  - [ ] Set up alerting for test failures
  - [ ] Integration with CI/CD pipelines

## Technical Implementation

### 1. Enhanced AWS Model Testing Script

```bash
#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/test-aws-models.sh

set -euo pipefail

# Configuration
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"
TEST_SUITE="${3:-comprehensive}"
PARALLEL_TESTS="${4:-true}"

# Test comprehensive model capabilities
test_model_comprehensive() {
    local endpoint="$1"
    local model_config="$2"
    
    echo "🧪 Running comprehensive tests for model: $(echo "$model_config" | jq -r '.name')"
    
    # Get test questions from config
    local questions
    questions=$(echo "$model_config" | jq -r '.testing.standard_questions[]')
    
    local test_results=()
    
    while IFS= read -r question; do
        echo "Testing question: $question"
        
        local start_time=$(date +%s%3N)
        local response=$(curl -f -s --max-time 60 \
            -X POST "${endpoint}/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$(echo "$model_config" | jq -r '.name')\",\"prompt\":\"$question\",\"stream\":false}")
        local end_time=$(date +%s%3N)
        
        local duration=$((end_time - start_time))
        local response_text=$(echo "$response" | jq -r '.response')
        local response_length=${#response_text}
        
        # Validate response quality
        local quality_score=$(validate_response_quality "$response_text" "$question")
        
        test_results+=("{\"question\":\"$question\",\"duration\":$duration,\"length\":$response_length,\"quality\":$quality_score}")
        
    done <<< "$questions"
    
    # Test role-specific capabilities
    local roles
    roles=$(echo "$model_config" | jq -r '.testing.role_tests[]?')
    
    while IFS= read -r role; do
        test_role_capability "$endpoint" "$model_config" "$role"
    done <<< "$roles"
    
    echo "✅ Comprehensive testing completed"
}

# Test specific role capabilities
test_role_capability() {
    local endpoint="$1"
    local model_config="$2"
    local role="$3"
    
    echo "🎭 Testing role capability: $role"
    
    case "$role" in
        "code_reviewer")
            test_code_review_capability "$endpoint" "$model_config"
            ;;
        "test_writer")
            test_test_generation_capability "$endpoint" "$model_config"
            ;;
        "error_fixer")
            test_error_fixing_capability "$endpoint" "$model_config"
            ;;
        "assistant")
            test_general_assistance_capability "$endpoint" "$model_config"
            ;;
        *)
            echo "Unknown role: $role"
            ;;
    esac
}

# Test code review capabilities
test_code_review_capability() {
    local endpoint="$1"
    local model_config="$2"
    
    local code_sample='function calculateTotal(items) {
        let total = 0;
        for (let i = 0; i < items.length; i++) {
            total += items[i].price * items[i].quantity;
        }
        return total;
    }'
    
    local prompt="Review this JavaScript code and suggest improvements: $code_sample"
    
    local response=$(curl -f -s --max-time 60 \
        -X POST "${endpoint}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$(echo "$model_config" | jq -r '.name')\",\"prompt\":\"$prompt\",\"stream\":false}")
    
    local review_text=$(echo "$response" | jq -r '.response')
    
    # Validate review quality (check for common review elements)
    if echo "$review_text" | grep -qi -E "(improve|suggest|consider|recommend|error|bug|optimization)"; then
        echo "✅ Code review capability: PASSED"
    else
        echo "❌ Code review capability: FAILED"
    fi
}

# Test error fixing capabilities
test_error_fixing_capability() {
    local endpoint="$1"
    local model_config="$2"
    
    local error_code='const x: string = 123; // TypeScript error'
    local prompt="Fix this TypeScript error: $error_code"
    
    local response=$(curl -f -s --max-time 60 \
        -X POST "${endpoint}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$(echo "$model_config" | jq -r '.name')\",\"prompt\":\"$prompt\",\"stream\":false}")
    
    local fixed_code=$(echo "$response" | jq -r '.response')
    
    # Validate fix (should mention type conversion or proper typing)
    if echo "$fixed_code" | grep -qi -E "(number|string|const.*=.*'|const.*=.*\"|\\.toString\(\)|Number\(|String\()"; then
        echo "✅ Error fixing capability: PASSED"
    else
        echo "❌ Error fixing capability: FAILED"
    fi
}

# Performance benchmarking
run_performance_benchmark() {
    local endpoint="$1"
    local model_name="$2"
    local iterations="${3:-10}"
    
    echo "📊 Running performance benchmark ($iterations iterations)"
    
    local total_time=0
    local successful_requests=0
    local failed_requests=0
    
    for ((i=1; i<=iterations; i++)); do
        echo "Benchmark iteration $i/$iterations"
        
        local start_time=$(date +%s%3N)
        if curl -f -s --max-time 30 \
            -X POST "${endpoint}/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$model_name\",\"prompt\":\"Write a simple function\",\"stream\":false}" \
            >/dev/null 2>&1; then
            
            local end_time=$(date +%s%3N)
            local duration=$((end_time - start_time))
            total_time=$((total_time + duration))
            ((successful_requests++))
        else
            ((failed_requests++))
        fi
    done
    
    if [[ $successful_requests -gt 0 ]]; then
        local avg_time=$((total_time / successful_requests))
        echo "✅ Performance benchmark results:"
        echo "   Average response time: ${avg_time}ms"
        echo "   Success rate: $successful_requests/$iterations"
        echo "   Failed requests: $failed_requests"
    else
        echo "❌ Performance benchmark failed: no successful requests"
    fi
}
```

### 2. Integration with Existing Infrastructure

The testing will integrate with existing components:

```bash
# Use existing AWS deployment infrastructure
./deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh --env=dev --type=ecs-fargate

# Run comprehensive model testing
./deployer-ddf-mod-llm-models/scripts/deploy/test-aws-models.sh dev us-east-1 comprehensive

# Use existing health check for basic validation
./deployer-ddf-mod-llm-models/scripts/deploy/health-check.sh --env=dev --region=us-east-1
```

### 3. Test Configuration from llm-models.json

The testing will use the existing model configuration:

```json
{
  "models": {
    "llama-3.1-8b": {
      "testing": {
        "layer": 1,
        "standard_questions": [
          "What is artificial intelligence?",
          "Explain machine learning in simple terms",
          "Write a Python function to calculate fibonacci numbers"
        ],
        "role_tests": [
          "assistant",
          "code_reviewer",
          "technical_writer"
        ]
      }
    }
  }
}
```

## Success Criteria

1. **Comprehensive Testing**: All deployed models tested with their configured test questions
2. **Role Validation**: All role-specific capabilities validated
3. **Performance Metrics**: Response times, success rates, and quality scores measured
4. **Error Handling**: Robust error handling and retry logic implemented
5. **Reporting**: Detailed test reports generated in JSON/HTML format
6. **Integration**: Seamless integration with existing AWS deployment infrastructure

## Dependencies

- ✅ AWS deployment infrastructure (already implemented)
- ✅ CloudFormation templates (already implemented)
- ✅ Service endpoint discovery (already implemented)
- ✅ Basic health checks (already implemented)
- 🔄 Model configuration in `config/llm-models.json` (exists but may need updates)

## Execution Commands

```bash
# Deploy AWS infrastructure (if not already deployed)
./deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh --env=dev --type=ecs-fargate

# Run comprehensive model testing
./deployer-ddf-mod-llm-models/scripts/deploy/test-aws-models.sh dev us-east-1 comprehensive

# Run performance benchmarking
./deployer-ddf-mod-llm-models/scripts/deploy/test-aws-models.sh dev us-east-1 performance

# Generate test reports
./deployer-ddf-mod-llm-models/scripts/deploy/test-aws-models.sh dev us-east-1 report
```

## Next Steps

1. **Immediate**: Extend existing `health-check.sh` script with comprehensive testing
2. **Short-term**: Create dedicated `test-aws-models.sh` script
3. **Medium-term**: Implement performance benchmarking and reporting
4. **Long-term**: Integrate with CI/CD pipelines for automated testing

This plan builds directly on the existing AWS deployment infrastructure and focuses specifically on the testing execution and validation aspects. 