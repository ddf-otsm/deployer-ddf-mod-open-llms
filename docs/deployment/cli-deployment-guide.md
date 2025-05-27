# CLI Deployment Guide - AI Testing Agent

**Document Version:** 1.0  
**Created:** 2025-01-22  
**Updated:** 2025-01-22

## Overview

This guide provides step-by-step instructions for deploying and testing the AI Testing Agent using CLI tools. The deployment testing script verifies that all components are working correctly across different deployment types.

## Quick Start

### Test Local Development Setup
```bash
# Test local Docker setup (default)
./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh

# Test with verbose output
VERBOSE=true ./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh
```

### Test AWS Deployments
```bash
# Test staging ECS Fargate deployment
./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh staging us-east-1 ecs-fargate

# Test production EC2 GPU deployment
./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh prod us-east-1 ec2-gpu

# Test Lambda deployment
./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh dev us-west-2 lambda
```

## Prerequisites

### Required Tools
- **curl**: HTTP client for API testing
- **jq**: JSON processor for parsing responses
- **python3**: Python runtime for scripts
- **docker**: Container runtime (for local testing)
- **aws**: AWS CLI (for cloud deployments)
- **bc**: Basic calculator (for cost calculations)

### Installation Commands
```bash
# macOS (using Homebrew)
brew install curl jq python3 docker awscli bc

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install curl jq python3 docker.io awscli bc

# CentOS/RHEL
sudo yum install curl jq python3 docker aws-cli bc
```

### AWS Configuration (for cloud testing)
```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

## Deployment Types

### 1. Local Development (`local`)
- **Purpose**: Test local Docker setup
- **Requirements**: Docker, Docker Compose
- **Endpoint**: `http://localhost:11434`
- **Auto-start**: Script automatically starts Ollama if not running

### 2. ECS Fargate (`ecs-fargate`)
- **Purpose**: Test containerized deployment on AWS
- **Requirements**: AWS CLI, CloudFormation stack deployed
- **Endpoint**: Retrieved from CloudFormation outputs
- **Features**: Auto-scaling, cost optimization

### 3. EC2 GPU (`ec2-gpu`)
- **Purpose**: Test high-performance GPU deployment
- **Requirements**: AWS CLI, EC2 instances running
- **Endpoint**: Retrieved from CloudFormation outputs
- **Features**: GPU acceleration, auto-stop

### 4. Lambda (`lambda`)
- **Purpose**: Test serverless deployment
- **Requirements**: AWS CLI, Lambda function deployed
- **Endpoint**: Lambda function URL
- **Features**: Pay-per-use, automatic scaling

## Test Categories

### 1. Service Health Checks
- **Purpose**: Verify service is running and responsive
- **Method**: HTTP GET to health endpoint
- **Success Criteria**: 200 OK response within 10 seconds
- **Retry Logic**: Up to 10 attempts with 5-second intervals

### 2. Model Availability Verification
- **Purpose**: Confirm AI models are loaded and accessible
- **Method**: GET `/api/tags` endpoint
- **Success Criteria**: At least one model available
- **Required Models**: `deepseek-coder:1.3b`, `llama3.2:1b`

### 3. Test Generation Functionality
- **Purpose**: Verify AI can generate test code
- **Method**: POST to `/api/generate` with sample code
- **Success Criteria**: Valid test code returned within 120 seconds
- **Validation**: Response contains test keywords (test, describe, it, expect)

### 4. Error Fixing Capabilities
- **Purpose**: Test AI's ability to fix code errors
- **Method**: POST with TypeScript error sample
- **Success Criteria**: Fix suggestion returned within 60 seconds
- **Validation**: Response addresses the error type

### 5. Performance Benchmarking
- **Purpose**: Measure response times and throughput
- **Method**: Multiple test generation requests
- **Metrics**: Average response time, success rate
- **Thresholds**: 
  - Excellent: < 30s average
  - Good: < 60s average
  - Acceptable: < 120s average

### 6. Cost Monitoring (AWS only)
- **Purpose**: Track AWS resource costs
- **Method**: AWS Cost Explorer API
- **Metrics**: Current month spending by service
- **Thresholds**:
  - Excellent: < $50/month
  - Good: < $120/month
  - Acceptable: < $200/month

## Usage Examples

### Basic Testing
```bash
# Test local setup
./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh

# Expected output:
# [INFO] Starting AI Testing Agent deployment test
# [INFO] Environment: dev
# [INFO] Deployment Type: local
# [SUCCESS] All prerequisites satisfied
# [SUCCESS] Found 1 service endpoint(s)
# [SUCCESS] Health check passed in 2s
# [SUCCESS] Found 3 models available
# [SUCCESS] Test generation completed in 45s
# [SUCCESS] All tests passed!
```

### Verbose Testing
```bash
# Enable detailed output
VERBOSE=true ./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh

# Shows additional information:
# - Available model names
# - Generated test code preview
# - Detailed cost breakdown
# - Performance metrics per request
```

### AWS Testing with Custom Timeout
```bash
# Test with extended timeout for slow networks
TIMEOUT=600 ./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh staging us-east-1 ecs-fargate

# Useful for:
# - Slow network connections
# - Large model downloads
# - Cold start scenarios
```

### Automated Testing in CI/CD
```bash
#!/bin/bash
# ci-test-deployment.sh

set -e

# Test multiple environments
environments=("dev" "staging" "prod")
deployment_types=("ecs-fargate" "lambda")

for env in "${environments[@]}"; do
    for type in "${deployment_types[@]}"; do
        echo "Testing $env environment with $type deployment..."
        
        if ./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh "$env" us-east-1 "$type"; then
            echo "✅ $env/$type: PASSED"
        else
            echo "❌ $env/$type: FAILED"
            exit 1
        fi
    done
done

echo "🎉 All deployment tests passed!"
```

## Troubleshooting

### Common Issues

#### 1. Local Docker Not Running
```bash
# Error: Cannot connect to the Docker daemon
# Solution: Start Docker service
sudo systemctl start docker  # Linux
open -a Docker              # macOS
```

#### 2. AWS Credentials Not Configured
```bash
# Error: Unable to locate credentials
# Solution: Configure AWS CLI
aws configure
# Enter: Access Key ID, Secret Access Key, Region, Output format
```

#### 3. CloudFormation Stack Not Found
```bash
# Error: Stack does not exist
# Solution: Deploy the stack first
./deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh --env=dev --type=ecs-fargate
```

#### 4. Models Not Available
```bash
# Error: No models available
# Solution: Download models manually
docker exec ai-testing-ollama ollama pull deepseek-coder:1.3b
docker exec ai-testing-ollama ollama pull llama3.2:1b
```

#### 5. Slow Response Times
```bash
# Warning: Performance: SLOW (> 120s average)
# Solutions:
# 1. Use smaller models (1.3b instead of 6.7b)
# 2. Increase instance size
# 3. Use GPU instances for better performance
```

### Debug Mode
```bash
# Enable debug output
set -x
./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh

# Shows:
# - All curl commands executed
# - Response headers and status codes
# - Variable values at each step
```

### Manual Testing
```bash
# Test individual components manually

# 1. Health check
curl -f http://localhost:11434/api/tags

# 2. Model list
curl -s http://localhost:11434/api/tags | jq '.models[].name'

# 3. Test generation
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-coder:1.3b",
    "prompt": "Generate a test for function add(a,b){return a+b;}",
    "stream": false
  }'
```

## Performance Optimization

### Local Development
```bash
# Use smaller models for faster responses
export OLLAMA_MODEL="deepseek-coder:1.3b"

# Increase Docker memory allocation
# Docker Desktop > Settings > Resources > Memory: 8GB+
```

### AWS Deployments
```bash
# Use appropriate instance types
# ECS Fargate: 4 vCPU, 16GB RAM
# EC2 GPU: g4dn.xlarge or larger
# Lambda: 10GB memory allocation
```

### Network Optimization
```bash
# Use regional endpoints
export AWS_REGION="us-east-1"  # Closest to your location

# Enable compression
export CURL_OPTS="--compressed"
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Test AI Testing Agent Deployment

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-deployment:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Test Local Deployment
      run: |
        ./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh dev us-east-1 local
    
    - name: Test AWS Deployment
      run: |
        ./deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh dev us-east-1 ecs-fargate
```

### Jenkins Pipeline Example
```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        VERBOSE = 'true'
    }
    
    stages {
        stage('Test Deployments') {
            parallel {
                stage('Local') {
                    steps {
                        sh './deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh dev us-east-1 local'
                    }
                }
                stage('ECS Fargate') {
                    steps {
                        sh './deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh dev us-east-1 ecs-fargate'
                    }
                }
                stage('Lambda') {
                    steps {
                        sh './deployer-ddf-mod-llm-models/scripts/deploy/test-deployment.sh dev us-east-1 lambda'
                    }
                }
            }
        }
    }
    
    post {
        always {
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'test-results',
                reportFiles: 'deployment-test-report.html',
                reportName: 'Deployment Test Report'
            ])
        }
    }
}
```

## Monitoring and Alerting

### Cost Alerts
```bash
# Set up cost monitoring
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "deployer-ddf-mod-llm-models-budget",
    "BudgetLimit": {
      "Amount": "120",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'
```

### Performance Monitoring
```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "deployer-ddf-mod-llm-models-performance" \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "deployer-ddf-mod-llm-models"],
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "deployer-ddf-mod-llm-models"]
          ],
          "period": 300,
          "stat": "Average",
          "region": "us-east-1",
          "title": "AI Testing Agent Performance"
        }
      }
    ]
  }'
```

## Security Considerations

### Network Security
- All endpoints use HTTPS in production
- API access restricted to authorized sources
- No sensitive data in logs or responses

### Credential Management
- AWS credentials stored securely (IAM roles preferred)
- No hardcoded secrets in scripts
- Least privilege access principles

### Data Privacy
- No code or test data stored permanently
- All processing happens in isolated containers
- Automatic cleanup of temporary files

---

**Document Owner:** DevOps Team  
**Review Cycle:** Monthly  
**Last Updated:** 2025-01-22  
**Related Documents:**
- [AWS Deployment Plan Enhanced](aws-deployment-plan-enhanced.md)
- [Project Analysis Summary](../project-analysis-summary.md) 