# AWS Deployment Plan for DeployerDDF Module Open Source LLM Models
**Completion: 15%** | **Last Updated: 2025-05-27** | **Next Review: 2025-06-03**

## Overview
Deploy the AI Testing Agent API with Swagger UI frontend to AWS infrastructure using minimal resources for cost-effective testing and production deployment.

## Success Criteria
- [ ] API deployed to AWS ECS/Fargate with auto-scaling
- [ ] Swagger UI accessible via AWS Application Load Balancer
- [ ] Ollama models running on AWS EC2 or ECS
- [ ] CloudFormation templates for infrastructure as code
- [ ] CI/CD pipeline for automated deployments
- [ ] SSL/TLS certificates and custom domain
- [ ] Monitoring and logging with CloudWatch
- [ ] Cost optimization with spot instances where appropriate

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

## Phase 1: Infrastructure Setup (40% complete)
- [x] AWS credentials configured and tested
- [x] Basic AWS services access verified (S3, ECS, CloudFormation)
- [x] Local Docker setup working with Swagger UI
- [ ] Create VPC and networking infrastructure
- [ ] Set up security groups and IAM roles
- [ ] Create ECR repositories for container images

### Automation Commands
```bash
# Phase 1 setup
bash workflow_tasks/run.sh --setup --platform=aws --env=dev
bash scripts/deploy/aws-deploy.sh --env=dev --dry-run

# Infrastructure validation
aws sts get-caller-identity
aws ecs list-clusters
aws s3 ls
```

## Phase 2: Container Deployment (0% complete)
- [ ] Build and push API container to ECR
- [ ] Create ECS cluster and task definitions
- [ ] Deploy Ollama container with models
- [ ] Configure Application Load Balancer
- [ ] Set up health checks and auto-scaling

### Automation Commands
```bash
# Container build and deployment
docker build -t deployer-ddf-api .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker tag deployer-ddf-api:latest <account>.dkr.ecr.us-east-1.amazonaws.com/deployer-ddf-api:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/deployer-ddf-api:latest

# ECS deployment
aws ecs create-cluster --cluster-name deployer-ddf-cluster
aws ecs register-task-definition --cli-input-json file://config/aws/task-definition.json
aws ecs create-service --cluster deployer-ddf-cluster --service-name api-service --task-definition deployer-ddf-api
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

### Minimum Setup (Development)
- **ECS Fargate**: ~$20-30/month (0.25 vCPU, 0.5 GB RAM)
- **Application Load Balancer**: ~$16/month
- **EC2 for Ollama**: ~$30-50/month (t3.medium spot instance)
- **CloudWatch Logs**: ~$5/month
- **Total**: ~$71-101/month

### Production Setup
- **ECS Fargate**: ~$50-100/month (auto-scaling)
- **Application Load Balancer**: ~$16/month
- **EC2 for Ollama**: ~$100-200/month (c5.large reserved instances)
- **CloudWatch + Monitoring**: ~$20/month
- **Route 53 + ACM**: ~$1/month
- **Total**: ~$187-337/month

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
- Ollama models (deepseek-coder:1.3b, deepseek-coder:6.7b) available
- Comprehensive test script created

### 🔄 In Progress
- AWS infrastructure planning and design
- Container optimization for AWS deployment

### 📋 Next Actions
1. Create VPC and networking infrastructure
2. Set up ECR repositories
3. Build and test container images
4. Deploy to ECS with basic configuration
5. Configure Application Load Balancer

## Testing Strategy

### Local Testing (✅ Complete)
```bash
# Test local setup
bash scripts/test-swagger-frontend.sh --local-only

# Results:
# ✅ Health check: http://localhost:3000/health
# ✅ API status: http://localhost:3000/api/status  
# ✅ Test generation: POST /api/generate-tests
# ✅ Swagger UI: http://localhost:3000/api-docs
# ✅ Ollama models: deepseek-coder:1.3b, deepseek-coder:6.7b
```

### AWS Testing (🔄 Planned)
```bash
# Test AWS deployment
bash scripts/test-swagger-frontend.sh --aws-url https://api.deployer-ddf.com

# Expected results:
# ✅ AWS Health check
# ✅ AWS API status
# ✅ AWS Swagger UI accessibility
# ✅ Load balancer health checks
# ✅ Auto-scaling functionality
```

## Related Files
- `scripts/test-swagger-frontend.sh` - Comprehensive testing script
- `scripts/deploy/aws-deploy.sh` - AWS deployment automation
- `config/platform-env/aws/` - AWS-specific configurations
- `docker-compose.yml` - Local development setup
- `Dockerfile` - Container definition

## Dependencies
- Docker and docker-compose for local development
- AWS CLI configured with appropriate permissions
- Node.js and npm for application runtime
- Ollama models for AI functionality

---

**For questions about AWS deployment, see `docs/guides/aws-llm-deployment-guide.md` or the comprehensive test results from `scripts/test-swagger-frontend.sh`.** 