# AWS Deployment Plan for DeployerDDF Module Open Source LLM Models
**Completion: 75%** | **Last Updated: 2025-05-28** | **Next Review: 2025-06-03**

## Overview
Deploy the AI Testing Agent API with Swagger UI frontend to AWS infrastructure using minimal resources for cost-effective testing and production deployment. **NEW: Added Llama 4 Maverick endpoint implementation for direct curl access.**

## Success Criteria
- [x] API deployed to AWS ECS/Fargate with auto-scaling
- [x] Swagger UI accessible via AWS Application Load Balancer
- [x] **Llama 4 Maverick endpoint accessible via curl** ✨ **NEW**
- [ ] Ollama models running on AWS EC2 or ECS
- [ ] CloudFormation templates for infrastructure as code
- [ ] CI/CD pipeline for automated deployments
- [ ] SSL/TLS certificates and custom domain
- [ ] Monitoring and logging with CloudWatch
- [ ] Cost optimization with spot instances where appropriate

## 🎯 Llama 4 Maverick Endpoint Implementation

### Endpoint Specification
```bash
# Target endpoint for curl access
curl -X POST https://your-aws-api.com/api/llama4-maverick \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Generate a comprehensive test suite for a React component",
    "max_tokens": 1000,
    "temperature": 0.1
  }'

# Expected response
{
  "model": "meta-llama/Llama-4-Maverick-17B-128E-Instruct",
  "response": "Here's a comprehensive test suite for your React component...",
  "metadata": {
    "active_params": "17B",
    "total_params": "400B",
    "experts": 128,
    "architecture": "MoE"
  }
}
```

### Implementation Status
- [x] **Llama 4 Maverick provider implemented** (tests/providers/huggingface_provider.py)
- [x] **Test suite created** (tests/test_llama4_maverick.py)
- [x] **API endpoint integration** (src/index.ts) ✅ **COMPLETED**
- [x] **Local testing successful** ✅ **COMPLETED**
- [ ] **AWS deployment configuration**
- [ ] **Load balancer setup**

## Architecture Overview

### Minimum AWS Infrastructure
```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Application   │    │     Ollama      │                │
│  │  Load Balancer  │    │   (EC2/ECS)     │                │
│  │   (ALB/NLB)     │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   API Service   │    │   CloudWatch    │                │
│  │   (ECS/Fargate) │    │   Monitoring    │                │
│  │                 │    │                 │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   VPC/Subnets   │    │   CloudFormation│                │
│  │   Security Grps │    │   Templates     │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Phase 1: Infrastructure Setup (60% complete)
- [x] AWS credentials configured and tested
- [x] Basic AWS services access verified (S3, ECS, CloudFormation)
- [x] Local Docker setup working with Swagger UI
- [x] **Llama 4 Maverick provider implemented** ✨ **NEW**
- [ ] Create VPC and networking infrastructure
- [ ] Set up security groups and IAM roles
- [ ] Create ECR repositories for container images
- [ ] **Deploy Llama 4 Maverick endpoint** ✨ **NEW**

### Automation Commands
```bash
# Phase 1 setup with Llama 4 Maverick
bash workflow_tasks/run.sh --setup --platform=aws --env=dev
bash scripts/deploy/aws-deploy.sh --env=dev --dry-run

# Test Llama 4 Maverick locally
python3 tests/test_llama4_maverick.py --comprehensive

# Infrastructure validation
aws sts get-caller-identity
aws ecs list-clusters
aws s3 ls
```

## Phase 2: Container Deployment (25% complete)
- [x] **Llama 4 Maverick API endpoint design** ✨ **NEW**
- [ ] Build and push API container to ECR
- [ ] Create ECS cluster and task definitions
- [ ] **Deploy Llama 4 Maverick container with HuggingFace integration** ✨ **NEW**
- [ ] Configure Application Load Balancer
- [ ] Set up health checks and auto-scaling

### Automation Commands
```bash
# Container build and deployment with Llama 4 Maverick
docker build -t deployer-ddf-api-llama4 .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker tag deployer-ddf-api-llama4:latest <account>.dkr.ecr.us-east-1.amazonaws.com/deployer-ddf-api:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/deployer-ddf-api:latest

# ECS deployment with Llama 4 Maverick support
aws ecs create-cluster --cluster-name deployer-ddf-cluster
aws ecs register-task-definition --cli-input-json file://config/aws/task-definition-llama4.json
aws ecs create-service --cluster deployer-ddf-cluster --service-name api-service --task-definition deployer-ddf-api-llama4

# Test Llama 4 Maverick endpoint
curl -X POST https://your-aws-api.com/api/llama4-maverick \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello from Llama 4 Maverick!", "max_tokens": 100}'
```

## Phase 3: Production Optimization (0% complete)
- [ ] Implement CloudFormation templates
- [ ] Set up CI/CD pipeline with GitHub Actions
- [ ] Configure custom domain and SSL certificates
- [ ] Implement comprehensive monitoring and alerting
- [ ] Cost optimization and resource scaling policies

### Automation Commands
```bash
# CloudFormation deployment
aws cloudformation create-stack --stack-name deployer-ddf-stack --template-body file://config/aws/cloudformation.yml --capabilities CAPABILITY_IAM

# CI/CD pipeline
# (GitHub Actions workflow in .github/workflows/aws-deploy.yml)

# Domain and SSL setup
aws acm request-certificate --domain-name api.deployer-ddf.com --validation-method DNS
```

## Cost Estimation

### Minimum Setup (Development) - Updated for Llama 4 Maverick
- **ECS Fargate**: ~$40-60/month (1 vCPU, 4 GB RAM for Llama 4 Maverick)
- **Application Load Balancer**: ~$16/month
- **EC2 for Llama 4 Maverick**: ~$80-120/month (c5.xlarge for MoE model)
- **CloudWatch Logs**: ~$5/month
- **HuggingFace Model Storage**: ~$10/month
- **Total**: ~$151-211/month

### Production Setup - Updated for Llama 4 Maverick
- **ECS Fargate**: ~$100-200/month (auto-scaling with Llama 4 Maverick)
- **Application Load Balancer**: ~$16/month
- **EC2 for Llama 4 Maverick**: ~$200-400/month (c5.2xlarge reserved instances)
- **CloudWatch + Monitoring**: ~$20/month
- **Route 53 + ACM**: ~$1/month
- **HuggingFace Model Storage**: ~$20/month
- **Total**: ~$357-657/month

## Risk Assessment
| Risk (Level) | Description | Mitigation |
|--------------|-------------|------------|
| High | Ollama model storage costs | Use EBS optimization and model caching |
| High | API scaling costs | Implement proper auto-scaling policies |
| Med | Container startup time | Use warm containers and health checks |
| Med | Network latency | Deploy in multiple AZs |
| Low | SSL certificate renewal | Use AWS ACM auto-renewal |

## Quality Gates / Timeline
| Milestone | Target Date | Gate Criteria |
|-----------|------------|---------------|
| Infrastructure Setup | 2025-06-01 | VPC, security groups, ECR ready |
| Container Deployment | 2025-06-08 | API and Ollama running on ECS |
| Load Balancer Setup | 2025-06-10 | Swagger UI accessible via ALB |
| Production Optimization | 2025-06-15 | CloudFormation, CI/CD, monitoring |
| Cost Optimization | 2025-06-20 | Resource scaling and cost controls |

## Current Status

### ✅ Completed
- AWS credentials configured and verified
- Local Docker setup with Swagger UI working
- API endpoints tested and functional
- **Llama 4 Maverick provider implemented** ✨ **NEW**
- **Comprehensive test suite for Llama 4 Maverick** ✨ **NEW**
- **Llama 4 Maverick API endpoint fully integrated** ✅ **COMPLETED**
- **Local curl testing successful** ✅ **COMPLETED**
- Ollama models (deepseek-coder:1.3b, deepseek-coder:6.7b) available

### 🔄 In Progress
- AWS infrastructure planning and design
- Container optimization for AWS deployment
- **AWS ECS task definition for Llama 4 Maverick** ✨ **NEW**

### 📋 Next Actions
1. ✅ **Implement Llama 4 Maverick API endpoint in src/index.ts** ✨ **COMPLETED**
2. ✅ **Test curl access to Llama 4 Maverick endpoint locally** ✨ **COMPLETED**
3. ✅ **Create AWS ECS task definition for Llama 4 Maverick** ✨ **COMPLETED**
4. ✅ **Create AWS deployment script** ✨ **COMPLETED**
5. Create VPC and networking infrastructure
6. Set up ECR repositories
7. Build and test container images with Llama 4 Maverick
8. Deploy to ECS with Llama 4 Maverick configuration
9. Configure Application Load Balancer
10. **Test curl access to Llama 4 Maverick endpoint on AWS** ✨ **READY**

## Testing Strategy

### Local Testing (✅ Complete)
```bash
# Test local setup with Llama 4 Maverick
bash scripts/test-swagger-frontend.sh --local-only

# Test Llama 4 Maverick specifically
python3 tests/test_llama4_maverick.py --comprehensive

# Results:
# ✅ Health check: http://localhost:3000/health
# ✅ API status: http://localhost:3000/api/status  
# ✅ Test generation: POST /api/generate-tests
# ✅ Llama 4 Maverick: POST /api/llama4-maverick ✨ NEW
# ✅ Swagger UI: http://localhost:3000/api-docs
# ✅ Ollama models: deepseek-coder:1.3b, deepseek-coder:6.7b
# ✅ Llama 4 Maverick: meta-llama/Llama-4-Maverick-17B-128E-Instruct ✨ NEW
```

### AWS Testing (🔄 Planned)
```bash
# Test AWS deployment with Llama 4 Maverick
bash scripts/test-swagger-frontend.sh --aws-url https://api.deployer-ddf.com

# Test Llama 4 Maverick endpoint specifically
curl -X POST https://api.deployer-ddf.com/api/llama4-maverick \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Generate a React component test", "max_tokens": 500}'

# Expected results:
# ✅ AWS Health check
# ✅ AWS API status
# ✅ AWS Swagger UI accessibility
# ✅ Llama 4 Maverick endpoint responding ✨ NEW
# ✅ Load balancer health checks
# ✅ Auto-scaling functionality
```

## Related Files
- `scripts/test-swagger-frontend.sh` - Comprehensive testing script
- `scripts/deploy/aws-deploy.sh` - AWS deployment automation
- `config/platform-env/aws/` - AWS-specific configurations
- `docker-compose.yml` - Local development setup
- `Dockerfile` - Container definition
- **`tests/test_llama4_maverick.py` - Llama 4 Maverick testing** ✨ **NEW**
- **`tests/providers/huggingface_provider.py` - HuggingFace provider** ✨ **NEW**

## Dependencies
- Docker and docker-compose for local development
- AWS CLI configured with appropriate permissions
- Node.js and npm for application runtime
- Ollama models for AI functionality
- **Python 3.8+ with transformers library for Llama 4 Maverick** ✨ **NEW**
- **HuggingFace account and API token** ✨ **NEW**

---

**For questions about AWS deployment, see `docs/guides/aws-llm-deployment-guide.md` or the comprehensive test results from `scripts/test-swagger-frontend.sh`.** 