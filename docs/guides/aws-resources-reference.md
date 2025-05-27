# AWS Resources Reference Guide

## 📋 **DeployerDDF Module: Open LLM Models - AWS Resources**

This document contains all AWS resource names, identifiers, and configurations created by the deployment infrastructure.

### **🏗️ INFRASTRUCTURE RESOURCES**

#### **VPC and Networking**
- **VPC Name**: `deployer-ddf-llm-vpc-${Environment}`
  - Example: `deployer-ddf-llm-vpc-dev`
  - CIDR Block: `10.0.0.0/16`
- **Internet Gateway**: `deployer-ddf-llm-igw-${Environment}`
- **Public Subnets**:
  - `deployer-ddf-llm-public-subnet-1-${Environment}` (CIDR: 10.0.1.0/24, AZ: us-east-1a)
  - `deployer-ddf-llm-public-subnet-2-${Environment}` (CIDR: 10.0.2.0/24, AZ: us-east-1b)
- **Private Subnets**:
  - `deployer-ddf-llm-private-subnet-1-${Environment}` (CIDR: 10.0.3.0/24, AZ: us-east-1a)
  - `deployer-ddf-llm-private-subnet-2-${Environment}` (CIDR: 10.0.4.0/24, AZ: us-east-1b)
- **Route Table**: `deployer-ddf-llm-public-rt-${Environment}`

#### **Security Groups**
- **ALB Security Group**: `deployer-ddf-llm-alb-sg-${Environment}`
  - Ports: 80, 443 (HTTP/HTTPS)
- **ECS Security Group**: `deployer-ddf-llm-ecs-sg-${Environment}`
  - Ports: 3000-8000 (Application ports)

#### **Load Balancer**
- **Application Load Balancer**: `deployer-ddf-llm-alb-${Environment}`
- **Target Group**: `deployer-ddf-llm-tg-${Environment}`
  - Protocol: HTTP
  - Port: 5001 (or configured port)
  - Health Check Path: `/health`

### **🚀 COMPUTE RESOURCES**

#### **ECS Infrastructure**
- **ECS Cluster**: `deployer-ddf-llm-cluster-${Environment}`
- **Capacity Providers**: FARGATE, FARGATE_SPOT
- **Service Name**: `deployer-ddf-llm-service-${Environment}`
- **Task Definition**: `deployer-ddf-llm-task-${Environment}`

#### **IAM Roles**
- **Task Execution Role**: `deployer-ddf-llm-execution-role-${Environment}`
  - Policies: AmazonECSTaskExecutionRolePolicy
- **Task Role**: `deployer-ddf-llm-task-role-${Environment}`
  - Custom policies for S3, SQS access
- **Auto-Stop Lambda Role**: `deployer-ddf-llm-autostop-role-${Environment}`

### **💾 STORAGE AND MESSAGING**

#### **S3 Bucket**
- **Bucket Name**: `deployer-ddf-llm-results-${Environment}-${AWS::AccountId}`
  - Example: `deployer-ddf-llm-results-dev-123456789012`
  - Versioning: Enabled
  - Encryption: AES256

#### **SQS Queues**
- **Main Queue**: `deployer-ddf-llm-test-jobs-${Environment}`
  - Visibility Timeout: 300 seconds
  - Message Retention: 14 days
- **Dead Letter Queue**: `deployer-ddf-llm-test-jobs-dlq-${Environment}`
  - Max Receive Count: 3

#### **CloudWatch**
- **Log Group**: `/aws/ecs/deployer-ddf-llm-${Environment}`
  - Retention: 30 days

### **📊 CLOUDFORMATION STACK OUTPUTS**

The stack exports these values for cross-stack references:
- **VPC ID**: `${AWS::StackName}-VPC-ID`
- **Public Subnets**: `${AWS::StackName}-PUBLIC-SUBNETS`
- **Private Subnets**: `${AWS::StackName}-PRIVATE-SUBNETS`
- **ECS Cluster**: `${AWS::StackName}-ECS-CLUSTER`
- **ALB DNS**: `${AWS::StackName}-ALB-DNS`
- **S3 Bucket**: `${AWS::StackName}-S3-BUCKET`
- **Test Queue**: `${AWS::StackName}-TEST-QUEUE`

### **🔍 RESOURCE DISCOVERY COMMANDS**

#### **Check CloudFormation Stack**
```bash
# List CloudFormation stacks
aws cloudformation list-stacks --region us-east-1

# Get stack outputs (replace with actual stack name)
aws cloudformation describe-stacks \
  --stack-name deployer-ddf-llm-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs'
```

#### **Check ECS Resources**
```bash
# List ECS clusters
aws ecs list-clusters --region us-east-1

# Describe specific cluster
aws ecs describe-clusters \
  --clusters deployer-ddf-llm-cluster-dev \
  --region us-east-1
```

#### **Check S3 Buckets**
```bash
# List S3 buckets with deployer-ddf prefix
aws s3 ls | grep deployer-ddf-llm-results
```

#### **Check Load Balancers**
```bash
# List Application Load Balancers
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `deployer-ddf-llm`)]'
```

### **🏷️ RESOURCE TAGGING STRATEGY**

All resources are tagged with:
- **Project**: `deployer-ddf-mod-open-llms`
- **Environment**: `${Environment}` (dev, staging, prod)
- **Component**: Specific component name
- **ManagedBy**: `CloudFormation`
- **CostCenter**: `AI-Testing-Agent`

### **📝 NOTES**

- Replace `${Environment}` with actual environment (dev, staging, prod)
- Replace `${AWS::AccountId}` with your actual AWS Account ID
- All resources are created in `us-east-1` region by default
- Resource names follow the pattern: `deployer-ddf-llm-{resource-type}-{environment}`

### **🔄 LAST UPDATED**

- **Date**: May 26, 2025
- **Version**: 1.0.0
- **Updated By**: AI Assistant 