# IAM Roles Reference - deployer-ddf-mod-llm-models

**Project**: AI Testing Agent - LLM Models  
**Last Updated**: 2025-05-25  
**Contact**: ti@dadosfera.ai

## Overview

This document provides a comprehensive reference for all IAM roles used in the `deployer-ddf-mod-llm-models` project, their purposes, permissions, and relationships.

## Role Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ECS Task Execution                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │        DeployerDDFModLLMModelsExecutionRole         │   │
│  │                                                     │   │
│  │  • Pull container images from ECR                  │   │
│  │  • Create CloudWatch log streams                   │   │
│  │  • Write logs to CloudWatch                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Application Runtime                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │          DeployerDDFModLLMModelsTaskRole            │   │
│  │                                                     │   │
│  │  • Access S3 buckets for test results              │   │
│  │  • Send/receive SQS messages                       │   │
│  │  • Invoke Bedrock LLM models                       │   │
│  │  • Access foundation models for AI testing         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Role Definitions

### 1. DeployerDDFModLLMModelsExecutionRole

**Purpose**: ECS task execution and infrastructure management  
**CloudFormation Resource**: `DeployerDDFModLLMModelsExecutionRole`  
**Physical Name**: `deployer-ddf-mod-llm-models-{environment}-execution-role`

#### Trust Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### Attached Policies
- **AWS Managed**: `arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy`

#### Inline Policies

##### ECRAccess Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Environment-Specific Names
- **Development**: `deployer-ddf-mod-llm-models-dev-execution-role`
- **Staging**: `deployer-ddf-mod-llm-models-staging-execution-role`
- **Production**: `deployer-ddf-mod-llm-models-prod-execution-role`

### 2. DeployerDDFModLLMModelsTaskRole

**Purpose**: Application-level permissions for LLM testing and data access  
**CloudFormation Resource**: `DeployerDDFModLLMModelsTaskRole`  
**Physical Name**: `deployer-ddf-mod-llm-models-{environment}-task-role`

#### Trust Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### Inline Policies

##### S3Access Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::deployer-ddf-mod-llm-models-{environment}-results/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::deployer-ddf-mod-llm-models-{environment}-results"
    }
  ]
}
```

##### SQSAccess Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:SendMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:{region}:{account}:deployer-ddf-mod-llm-models-{environment}-queue"
    }
  ]
}
```

##### BedrockLLMAccess Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:GetFoundationModel",
        "bedrock:ListFoundationModels"
      ],
      "Resource": [
        "arn:aws:bedrock:{region}:{account}:foundation-model/meta.llama3-1-70b-instruct-v1:0",
        "arn:aws:bedrock:{region}:{account}:foundation-model/meta.codellama-34b-instruct-v1:0",
        "arn:aws:bedrock:{region}:{account}:foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      ]
    }
  ]
}
```

#### Environment-Specific Names
- **Development**: `deployer-ddf-mod-llm-models-dev-task-role`
- **Staging**: `deployer-ddf-mod-llm-models-staging-task-role`
- **Production**: `deployer-ddf-mod-llm-models-prod-task-role`

## Configuration Integration

### auth-config.yml Reference
```yaml
authentication:
  iam_role:
    enabled: true
    # Execution role for ECS tasks (pulls images, writes logs)
    execution_role_arn: "arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-execution-role"
    # Task role for application permissions (S3, SQS, Bedrock access)
    task_role_arn: "arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-task-role"
    session_duration: 3600
    
    # Permissions for the task role
    task_permissions:
      - "s3:GetObject"
      - "s3:PutObject" 
      - "s3:DeleteObject"
      - "s3:ListBucket"
      - "sqs:ReceiveMessage"
      - "sqs:SendMessage"
      - "sqs:DeleteMessage"
      - "sqs:GetQueueAttributes"
      - "bedrock:InvokeModel"
      - "bedrock:InvokeModelWithResponseStream"
      - "bedrock:GetFoundationModel"
      - "bedrock:ListFoundationModels"
    
    # Permissions for the execution role  
    execution_permissions:
      - "ecr:GetAuthorizationToken"
      - "ecr:BatchCheckLayerAvailability"
      - "ecr:GetDownloadUrlForLayer"
      - "ecr:BatchGetImage"
      - "logs:CreateLogStream"
      - "logs:PutLogEvents"
```

## Resource Relationships

### CloudFormation Template References
```yaml
# In master-stack.yml
TaskDefinition:
  Type: AWS::ECS::TaskDefinition
  Properties:
    ExecutionRoleArn: !GetAtt DeployerDDFModLLMModelsExecutionRole.Arn
    TaskRoleArn: !GetAtt DeployerDDFModLLMModelsTaskRole.Arn
```

### Environment Variables
```bash
# Set in ECS task definition
AWS_REGION=${AWS::Region}
SQS_QUEUE_URL=${TestQueue}
S3_BUCKET=${ResultsBucket}
```

## Security Best Practices

### 1. Principle of Least Privilege
- **Execution Role**: Only infrastructure permissions needed for ECS
- **Task Role**: Only application permissions needed for LLM testing
- **Resource-Specific**: Permissions scoped to specific S3 buckets and SQS queues

### 2. Environment Isolation
- Separate roles per environment (dev, staging, prod)
- Environment-specific resource access
- No cross-environment permissions

### 3. Model Access Control
- Specific Bedrock model ARNs (not wildcard)
- Limited to approved LLM models
- No access to other AWS AI services

## Monitoring and Auditing

### CloudTrail Events to Monitor
```json
{
  "eventNames": [
    "AssumeRole",
    "InvokeModel",
    "GetObject",
    "PutObject",
    "SendMessage",
    "ReceiveMessage"
  ],
  "resources": [
    "arn:aws:iam::*:role/deployer-ddf-mod-llm-models-*"
  ]
}
```

### CloudWatch Metrics
- Role assumption frequency
- Bedrock API call volume
- S3 access patterns
- SQS message processing

## Troubleshooting

### Common Issues

#### 1. Access Denied Errors
```bash
# Check role permissions
aws iam get-role --role-name deployer-ddf-mod-llm-models-prod-task-role
aws iam list-role-policies --role-name deployer-ddf-mod-llm-models-prod-task-role
```

#### 2. Bedrock Model Access
```bash
# Test Bedrock access
aws bedrock list-foundation-models --region us-east-1
aws bedrock get-foundation-model --model-identifier meta.llama3-1-70b-instruct-v1:0
```

#### 3. S3 Bucket Access
```bash
# Test S3 access
aws s3 ls s3://deployer-ddf-mod-llm-models-prod-results/
```

### Role Validation Script
```bash
#!/bin/bash
# scripts/validate-iam-roles.sh

ENVIRONMENT="${1:-dev}"

echo "Validating IAM roles for environment: $ENVIRONMENT"

# Check execution role
EXEC_ROLE="deployer-ddf-mod-llm-models-${ENVIRONMENT}-execution-role"
if aws iam get-role --role-name "$EXEC_ROLE" >/dev/null 2>&1; then
    echo "✅ Execution role exists: $EXEC_ROLE"
else
    echo "❌ Execution role missing: $EXEC_ROLE"
fi

# Check task role
TASK_ROLE="deployer-ddf-mod-llm-models-${ENVIRONMENT}-task-role"
if aws iam get-role --role-name "$TASK_ROLE" >/dev/null 2>&1; then
    echo "✅ Task role exists: $TASK_ROLE"
else
    echo "❌ Task role missing: $TASK_ROLE"
fi
```

## Cleanup and Removal

### Manual Role Deletion
```bash
# Delete task role
TASK_ROLE="deployer-ddf-mod-llm-models-${ENVIRONMENT}-task-role"
aws iam delete-role-policy --role-name "$TASK_ROLE" --policy-name "S3Access"
aws iam delete-role-policy --role-name "$TASK_ROLE" --policy-name "SQSAccess"
aws iam delete-role-policy --role-name "$TASK_ROLE" --policy-name "BedrockLLMAccess"
aws iam delete-role --role-name "$TASK_ROLE"

# Delete execution role
EXEC_ROLE="deployer-ddf-mod-llm-models-${ENVIRONMENT}-execution-role"
aws iam detach-role-policy --role-name "$EXEC_ROLE" --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
aws iam delete-role-policy --role-name "$EXEC_ROLE" --policy-name "ECRAccess"
aws iam delete-role --role-name "$EXEC_ROLE"
```

## Related Documentation

- [AWS Authentication Setup Guide](./aws-authentication-setup.md)
- [AWS Footprint Removal Guide](./aws-footprint-removal.md)
- [CloudFormation Template](../scripts/deploy/templates/master-stack.yml)
- [Authentication Configuration](../../config/auth-config.yml)

---

**Maintained by**: DevOps Team  
**Review Schedule**: Monthly  
**Last Security Review**: 2025-05-25 