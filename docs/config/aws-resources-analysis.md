# AWS Resources Analysis - Dadosfera Deployment

**Analysis Date:** 2025-05-27  
**Source:** Cursor conversations export + CloudFormation templates  
**Project:** planner-ddf-floor-2 / deployer-ddf-mod-llm-models

## 📋 **EXECUTIVE SUMMARY**

Based on the analysis of exported Cursor conversations and CloudFormation templates, this document provides a comprehensive overview of AWS resources that were created or planned for the Dadosfera LLM deployment infrastructure.

## 🔍 **DISCOVERED RESOURCE IDENTIFIERS**

### **IAM Roles (Confirmed)**
From conversation `20250526_072239_5eb5d1cd`:
- **Execution Role ARN**: `arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-execution-role`
- **Task Role ARN**: `arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-task-role`

### **CloudFormation Stack Names (Planned)**
From conversation `20250526_203302_fccff0de`:
- **Main Stack**: `deployer-ddf-llm-dev`
- **Stack Outputs Pattern**: `${AWS::StackName}-*`

### **ECS Resources (Planned)**
- **Cluster Name**: `deployer-ddf-llm-cluster-${Environment}`
- **Cluster Example**: `deployer-ddf-llm-cluster-dev`

## 🏗️ **COMPLETE INFRASTRUCTURE BLUEPRINT**

### **VPC and Networking**
```yaml
VPC:
  Name: deployer-ddf-llm-vpc-${Environment}
  CIDR: 10.0.0.0/16

Internet Gateway:
  Name: deployer-ddf-llm-igw-${Environment}

Public Subnets:
  - Name: deployer-ddf-llm-public-subnet-1-${Environment}
    CIDR: 10.0.1.0/24
    AZ: us-east-1a
  - Name: deployer-ddf-llm-public-subnet-2-${Environment}
    CIDR: 10.0.2.0/24
    AZ: us-east-1b

Private Subnets:
  - Name: deployer-ddf-llm-private-subnet-1-${Environment}
    CIDR: 10.0.3.0/24
    AZ: us-east-1a
  - Name: deployer-ddf-llm-private-subnet-2-${Environment}
    CIDR: 10.0.4.0/24
    AZ: us-east-1b

Route Tables:
  - Name: deployer-ddf-llm-public-rt-${Environment}
```

### **Security Groups**
```yaml
ALB Security Group:
  Name: deployer-ddf-llm-alb-sg-${Environment}
  Ingress:
    - Port: 80 (HTTP)
    - Port: 443 (HTTPS)
  Source: 0.0.0.0/0

ECS Security Group:
  Name: deployer-ddf-llm-ecs-sg-${Environment}
  Ingress:
    - Port: 3000 (Application)
  Source: ALB Security Group
```

### **Load Balancer Infrastructure**
```yaml
Application Load Balancer:
  Name: deployer-ddf-llm-alb-${Environment}
  Scheme: internet-facing
  Subnets: Public Subnets

Target Group:
  Name: deployer-ddf-llm-tg-${Environment}
  Protocol: HTTP
  Port: 3000
  HealthCheck: /health
```

### **ECS Infrastructure**
```yaml
ECS Cluster:
  Name: deployer-ddf-llm-cluster-${Environment}
  Capacity Providers:
    - FARGATE
    - FARGATE_SPOT

Task Definition:
  Family: deployer-ddf-llm-task-${Environment}
  CPU: 1024
  Memory: 2048
  Network Mode: awsvpc
```

### **IAM Roles and Policies**
```yaml
Task Execution Role:
  Name: deployer-ddf-llm-execution-role-${Environment}
  ARN: arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-execution-role
  Policies:
    - AmazonECSTaskExecutionRolePolicy
    - CloudWatch Logs access

Task Role:
  Name: deployer-ddf-llm-task-role-${Environment}
  ARN: arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-task-role
  Policies:
    - S3 access for results bucket
    - SQS access for job queues

Auto-Stop Lambda Role:
  Name: deployer-ddf-llm-autostop-role-${Environment}
  Policies:
    - ECS task management
    - CloudWatch Events
```

### **Storage and Messaging**
```yaml
S3 Bucket:
  Name: deployer-ddf-llm-results-${Environment}-${AWS::AccountId}
  Example: deployer-ddf-llm-results-dev-123456789012
  Purpose: Test results and model artifacts

SQS Queues:
  Main Queue:
    Name: deployer-ddf-llm-test-jobs-${Environment}
    Visibility Timeout: 300s
  
  Dead Letter Queue:
    Name: deployer-ddf-llm-test-jobs-dlq-${Environment}
    Max Receive Count: 3

CloudWatch Log Group:
  Name: /aws/ecs/deployer-ddf-llm-${Environment}
  Retention: 7 days
```

## 📊 **CLOUDFORMATION STACK OUTPUTS**

The stack exports these values for cross-stack references:
```yaml
Exports:
  VPC-ID: ${AWS::StackName}-VPC-ID
  PUBLIC-SUBNETS: ${AWS::StackName}-PUBLIC-SUBNETS
  PRIVATE-SUBNETS: ${AWS::StackName}-PRIVATE-SUBNETS
  ECS-CLUSTER: ${AWS::StackName}-ECS-CLUSTER
  ALB-DNS: ${AWS::StackName}-ALB-DNS
  S3-BUCKET: ${AWS::StackName}-S3-BUCKET
  TEST-QUEUE: ${AWS::StackName}-TEST-QUEUE
```

## 🔍 **RESOURCE DISCOVERY COMMANDS**

### **1. CloudFormation Stacks**
```bash
# List all stacks
aws cloudformation list-stacks --region us-east-1

# Get specific stack outputs
aws cloudformation describe-stacks \
  --stack-name deployer-ddf-llm-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'

# List stack resources
aws cloudformation list-stack-resources \
  --stack-name deployer-ddf-llm-dev \
  --region us-east-1
```

### **2. ECS Resources**
```bash
# List ECS clusters
aws ecs list-clusters --region us-east-1

# Describe specific cluster
aws ecs describe-clusters \
  --clusters deployer-ddf-llm-cluster-dev \
  --region us-east-1

# List services in cluster
aws ecs list-services \
  --cluster deployer-ddf-llm-cluster-dev \
  --region us-east-1
```

### **3. S3 Buckets**
```bash
# List S3 buckets with deployer-ddf prefix
aws s3 ls | grep deployer-ddf-llm-results

# Get bucket details
aws s3api head-bucket --bucket deployer-ddf-llm-results-dev-ACCOUNT
```

### **4. Load Balancers**
```bash
# List Application Load Balancers
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `deployer-ddf-llm`)]'

# List target groups
aws elbv2 describe-target-groups \
  --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `deployer-ddf-llm`)]'
```

### **5. IAM Roles**
```bash
# List IAM roles with deployer-ddf prefix
aws iam list-roles \
  --query 'Roles[?contains(RoleName, `deployer-ddf-mod-llm-models`)]'

# Get specific role details
aws iam get-role \
  --role-name deployer-ddf-mod-llm-models-dev-execution-role
```

### **6. VPC Resources**
```bash
# List VPCs with deployer-ddf tag
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=deployer-ddf-llm-vpc-*" \
  --region us-east-1

# List security groups
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=deployer-ddf-llm-*" \
  --region us-east-1
```

## 📝 **RESOURCE CLEANUP COMMANDS**

### **Complete Stack Deletion**
```bash
# Delete CloudFormation stack (this will delete all resources)
aws cloudformation delete-stack \
  --stack-name deployer-ddf-llm-dev \
  --region us-east-1

# Monitor deletion progress
aws cloudformation describe-stacks \
  --stack-name deployer-ddf-llm-dev \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

### **Individual Resource Cleanup**
```bash
# Stop ECS services first
aws ecs update-service \
  --cluster deployer-ddf-llm-cluster-dev \
  --service deployer-ddf-llm-service-dev \
  --desired-count 0 \
  --region us-east-1

# Empty S3 bucket before deletion
aws s3 rm s3://deployer-ddf-llm-results-dev-ACCOUNT --recursive

# Delete S3 bucket
aws s3 rb s3://deployer-ddf-llm-results-dev-ACCOUNT
```

## 🚨 **COST OPTIMIZATION NOTES**

Based on the conversations, the following cost optimization features were implemented:
- **Auto-stop functionality** for ECS tasks
- **FARGATE_SPOT** capacity provider for cost savings
- **CloudWatch Events** for scheduled shutdowns
- **7-day log retention** to minimize storage costs

## 📋 **NEXT STEPS**

1. **Run discovery commands** to get actual resource IDs
2. **Document actual ARNs and IDs** in `config/deployments/may_2025/`
3. **Create cleanup scripts** for resource management
4. **Set up monitoring** for cost tracking
5. **Implement backup procedures** for critical data

## 🔗 **RELATED DOCUMENTS**

- CloudFormation Template: `scripts/deploy/templates/master-stack.yml`
- Deployment Logs: `logs/deployer-migration-20250526_181333.log`
- Cursor Conversations: `export/cursor-conversations/`
- Multi-Env Cleanup Plan: `docs/todos/plans/backlog/multi-env-cleanup-plan.md` 