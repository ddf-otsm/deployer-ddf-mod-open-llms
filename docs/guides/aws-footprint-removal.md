# AWS Footprint Removal Guide

## Overview

This document tracks all AWS resources created by the AI Testing Agent deployment and provides step-by-step instructions for complete removal.

## Created Resources Inventory

### IAM Resources
- **Execution Role**: `deployer-ddf-mod-llm-models-{environment}-execution-role`
  - Purpose: ECS task execution (ECR access, CloudWatch logs)
  - CloudFormation Name: `DeployerDDFModLLMModelsExecutionRole`
- **Task Role**: `deployer-ddf-mod-llm-models-{environment}-task-role`  
  - Purpose: Application permissions (S3, SQS, Bedrock LLM access)
  - CloudFormation Name: `DeployerDDFModLLMModelsTaskRole`
- **Inline Policies**: 
  - `ECRAccess` (execution role)
  - `S3Access` (task role)
  - `SQSAccess` (task role)
  - `BedrockLLMAccess` (task role)
- **Access Keys**: Created for deployment user (if any)

### Compute Resources
- **ECS Cluster**: `deployer-ddf-mod-llm-models-{environment}`
- **ECS Service**: `deployer-ddf-mod-llm-models`
- **ECS Task Definition**: `deployer-ddf-mod-llm-models-{environment}`
- **Load Balancer**: `deployer-ddf-mod-llm-models-{environment}-alb`
- **Target Group**: `deployer-ddf-mod-llm-models-{environment}-tg`

### Networking Resources
- **VPC**: `deployer-ddf-mod-llm-models-{environment}-vpc`
- **Internet Gateway**: `deployer-ddf-mod-llm-models-{environment}-igw`
- **Subnets**: 
  - `deployer-ddf-mod-llm-models-{environment}-public-subnet-1`
  - `deployer-ddf-mod-llm-models-{environment}-public-subnet-2`
  - `deployer-ddf-mod-llm-models-{environment}-private-subnet-1`
  - `deployer-ddf-mod-llm-models-{environment}-private-subnet-2`
- **Route Tables**: `deployer-ddf-mod-llm-models-{environment}-public-routes`
- **Security Groups**:
  - `deployer-ddf-mod-llm-models-{environment}-alb-sg`
  - `deployer-ddf-mod-llm-models-{environment}-ecs-sg`

### Storage Resources
- **S3 Bucket**: Results bucket (name varies by deployment)
- **CloudWatch Log Group**: `/ecs/deployer-ddf-mod-llm-models-{environment}`

### Messaging Resources
- **SQS Queue**: Test queue (name varies by deployment)

### CloudFormation Stack
- **Stack Name**: `deployer-ddf-mod-llm-models-{environment}`

## Automated Removal Script

```bash
#!/bin/bash
# Complete AWS footprint removal for AI Testing Agent

ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"
STACK_NAME="deployer-ddf-mod-llm-models-${ENVIRONMENT}"

echo "🗑️  Removing AWS footprint for environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Stack: $STACK_NAME"

# 1. Delete CloudFormation stack (this removes most resources)
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

# Wait for stack deletion
echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

# 2. Clean up any remaining resources
echo "Cleaning up remaining resources..."

# Remove any orphaned IAM roles
aws iam list-roles --query "Roles[?contains(RoleName, 'deployer-ddf-mod-llm-models')].RoleName" --output text | \
while read role; do
    if [ -n "$role" ]; then
        echo "Removing IAM role: $role"
        # Detach policies first
        aws iam list-attached-role-policies --role-name "$role" --query "AttachedPolicies[].PolicyArn" --output text | \
        while read policy; do
            aws iam detach-role-policy --role-name "$role" --policy-arn "$policy"
        done
        # Delete inline policies
        aws iam list-role-policies --role-name "$role" --query "PolicyNames" --output text | \
        while read policy; do
            aws iam delete-role-policy --role-name "$role" --policy-name "$policy"
        done
        # Delete role
        aws iam delete-role --role-name "$role"
    fi
done

# 3. Remove any remaining S3 buckets
aws s3api list-buckets --query "Buckets[?contains(Name, 'deployer-ddf-mod-llm-models')].Name" --output text | \
while read bucket; do
    if [ -n "$bucket" ]; then
        echo "Removing S3 bucket: $bucket"
        aws s3 rm "s3://$bucket" --recursive
        aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION"
    fi
done

echo "✅ AWS footprint removal completed for environment: $ENVIRONMENT"
```

## Manual Removal Steps

If the automated script fails, follow these manual steps:

### 1. Delete CloudFormation Stack
```bash
aws cloudformation delete-stack \
    --stack-name "deployer-ddf-mod-llm-models-{environment}" \
    --region us-east-1
```

### 2. Verify Resource Deletion
Check that all resources are deleted:
```bash
# Check ECS resources
aws ecs list-clusters --query "clusterArns[?contains(@, 'deployer-ddf-mod-llm-models')]"

# Check Load Balancers
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'deployer-ddf-mod-llm-models')]"

# Check VPCs
aws ec2 describe-vpcs --query "Vpcs[?contains(Tags[?Key=='Name'].Value, 'deployer-ddf-mod-llm-models')]"

# Check IAM roles
aws iam list-roles --query "Roles[?contains(RoleName, 'deployer-ddf-mod-llm-models')]"
```

### 3. Clean Up IAM Resources
```bash
# List and delete IAM roles
ROLE_NAME="deployer-ddf-mod-llm-models-{environment}-execution-role"
aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "ECRAccess"
aws iam delete-role --role-name "$ROLE_NAME"

ROLE_NAME="deployer-ddf-mod-llm-models-{environment}-task-role"
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "S3Access"
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "SQSAccess"
aws iam delete-role --role-name "$ROLE_NAME"
```

### 4. Remove Access Keys (if created)
```bash
# List access keys for deployment user
aws iam list-access-keys --user-name deployer-ddf-mod-llm-models-user

# Delete access keys
aws iam delete-access-key --user-name deployer-ddf-mod-llm-models-user --access-key-id AKIA...
```

## Cost Verification

After removal, verify no charges are incurring:

1. **AWS Cost Explorer**: Check for any remaining charges
2. **AWS Billing Dashboard**: Verify $0 charges for removed services
3. **CloudWatch**: Ensure no log groups are still active

## Emergency Contact

If you encounter issues during removal:
- **Technical Contact**: ti@dadosfera.ai
- **AWS Support**: Use your AWS support plan
- **Documentation**: This file and deployment logs

## Removal Checklist

- [ ] CloudFormation stack deleted
- [ ] ECS cluster removed
- [ ] Load balancer deleted
- [ ] VPC and networking resources removed
- [ ] IAM roles and policies deleted
- [ ] S3 buckets emptied and deleted
- [ ] CloudWatch log groups deleted
- [ ] SQS queues deleted
- [ ] Access keys revoked
- [ ] Cost verification completed
- [ ] No remaining charges in billing

## Notes

- Always run removal in non-production environments first
- Keep deployment logs for troubleshooting
- Document any custom modifications before removal
- Backup any important data before deletion 