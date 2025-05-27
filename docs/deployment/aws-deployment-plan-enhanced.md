# AWS Deployment Plan - AI Testing Agent (Enhanced)

**Document Version:** 2.0  
**Created:** 2025-01-22  
**Updated:** 2025-01-22  
**Status:** DRAFT

## 🎯 Executive Summary

This enhanced deployment plan includes **auto-stop functionality**, **granular cost breakdowns** (hourly/daily/monthly), **comprehensive tagging strategy**, **security best practices**, and **isolated resource groups** for the AI Testing Agent on AWS.

## 📊 Enhanced Deployment Options Comparison

| Criteria | ECS Fargate + Auto-Stop | EC2 + GPU + Auto-Stop | Lambda + EFS |
|----------|-------------------------|------------------------|--------------|
| **Hourly Cost** | $0.21-0.31 | $0.46-0.69 | $0.03-0.11 |
| **Daily Cost** | $5.04-7.44 | $11.04-16.56 | $0.72-2.64 |
| **Monthly Cost** | $50-150 | $200-500 | $20-80 |
| **Auto-Stop Savings** | 60-80% | 70-85% | N/A (serverless) |
| **Setup Complexity** | Medium | High | Low |
| **Security Level** | High | High | Very High |
| **Resource Isolation** | Complete | Complete | Complete |

---

## 🏗️ Option 1: ECS Fargate with Auto-Stop (Recommended)

### Enhanced Architecture with Auto-Stop
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│   ECS Fargate   │───▶│   Test Results  │
│   (Webhook)     │    │   + Auto-Stop   │    │   (S3 Bucket)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  CloudWatch     │
                       │  Auto-Stop      │
                       │  (15min idle)   │
                       └─────────────────┘
```

### Auto-Stop Implementation
```yaml
# auto-stop-lambda.yml
Resources:
  AutoStopFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${ResourcePrefix}-auto-stop"
      Runtime: python3.9
      Handler: index.lambda_handler
      Code:
        ZipFile: |
          import boto3
          import json
          from datetime import datetime, timedelta
          
          def lambda_handler(event, context):
              ecs = boto3.client('ecs')
              cloudwatch = boto3.client('cloudwatch')
              
              # Check CPU utilization for last 15 minutes
              response = cloudwatch.get_metric_statistics(
                  Namespace='AWS/ECS',
                  MetricName='CPUUtilization',
                  Dimensions=[
                      {'Name': 'ServiceName', 'Value': 'deployer-ddf-mod-llm-models'},
                      {'Name': 'ClusterName', 'Value': 'ai-testing-cluster'}
                  ],
                  StartTime=datetime.utcnow() - timedelta(minutes=15),
                  EndTime=datetime.utcnow(),
                  Period=300,
                  Statistics=['Average']
              )
              
              # If average CPU < 5% for 15 minutes, scale down to 0
              if len(response['Datapoints']) > 0:
                  avg_cpu = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
                  if avg_cpu < 5.0:
                      ecs.update_service(
                          cluster='ai-testing-cluster',
                          service='deployer-ddf-mod-llm-models',
                          desiredCount=0
                      )
                      print(f"Scaled down service due to low CPU: {avg_cpu}%")
              
              return {'statusCode': 200}
      Tags:
        - Key: Project
          Value: !Ref ResourcePrefix
        - Key: Environment
          Value: !Ref Environment
        - Key: Component
          Value: auto-stop
        - Key: CostCenter
          Value: ai-testing
        - Key: Owner
          Value: devops-team

  AutoStopSchedule:
    Type: AWS::Events::Rule
    Properties:
      Description: "Trigger auto-stop check every 5 minutes"
      ScheduleExpression: "rate(5 minutes)"
      State: ENABLED
      Targets:
        - Arn: !GetAtt AutoStopFunction.Arn
          Id: "AutoStopTarget"
```

### Enhanced Cost Breakdown with Auto-Stop

#### Without Auto-Stop (24/7 Operation)
| Component | Hourly | Daily | Monthly | Configuration |
|-----------|--------|-------|---------|---------------|
| **ECS Fargate** | $0.17-0.24 | $4.08-5.76 | $123-173 | 4 vCPU, 16GB RAM |
| **EFS Storage** | $0.008 | $0.20 | $6 | 20GB model cache |
| **ALB** | $0.022 | $0.53 | $16 | Standard ALB |
| **CloudWatch** | $0.007 | $0.17 | $5 | 10GB logs/month |
| **NAT Gateway** | $0.045 | $1.08 | $32 | Single AZ |
| **Data Transfer** | $0.012 | $0.30 | $9 | 100GB/month |
| **ECR** | $0.0007 | $0.017 | $0.50 | 5GB images |
| **Total 24/7** | **$0.27-0.34** | **$6.42-8.13** | **$191.50-241.50** |

#### With Auto-Stop (8 hours/day active)
| Component | Hourly | Daily | Monthly | Savings |
|-----------|--------|-------|---------|---------|
| **ECS Fargate** | $0.17-0.24 | $1.36-1.92 | $41-58 | 67% |
| **EFS Storage** | $0.008 | $0.20 | $6 | 0% |
| **ALB** | $0.022 | $0.53 | $16 | 0% |
| **CloudWatch** | $0.007 | $0.17 | $5 | 0% |
| **NAT Gateway** | $0.045 | $1.08 | $32 | 0% |
| **Data Transfer** | $0.004 | $0.10 | $3 | 67% |
| **ECR** | $0.0007 | $0.017 | $0.50 | 0% |
| **Auto-Stop Lambda** | $0.0001 | $0.002 | $0.06 | New cost |
| **Total Auto-Stop** | **$0.09-0.11** | **$2.16-2.64** | **$103.56-120.56** |
| **Monthly Savings** | | | **$87.94-120.94** | **46-50%** |

### Resource Tagging Strategy
```yaml
# Standard tags for all resources
StandardTags:
  Project: "deployer-ddf-mod-llm-models"
  Environment: !Ref Environment  # dev/staging/prod
  Component: !Ref ComponentName  # ecs/lambda/storage
  CostCenter: "ai-testing"
  Owner: "devops-team"
  CreatedBy: "cloudformation"
  AutoStop: "enabled"
  BackupRequired: "false"
  DataClassification: "internal"
  Compliance: "none"
  
# Resource-specific tags
ECSSpecificTags:
  ServiceType: "container"
  ScalingPolicy: "auto-stop"
  MonitoringLevel: "detailed"
  
StorageSpecificTags:
  StorageType: "efs"
  BackupRetention: "7days"
  EncryptionEnabled: "true"
```

---

## 🚀 Option 2: EC2 with GPU and Auto-Stop (High Performance)

### Enhanced Architecture with Auto-Stop
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│   EC2 Instance  │───▶│   Test Results  │
│   (Webhook)     │    │   + Auto-Stop   │    │   (S3 Bucket)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  CloudWatch     │
                       │  Auto-Stop      │
                       │  (10min idle)   │
                       └─────────────────┘
```

### Auto-Stop Implementation for EC2
```yaml
# ec2-auto-stop.yml
Resources:
  EC2AutoStopFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${ResourcePrefix}-ec2-auto-stop"
      Runtime: python3.9
      Handler: index.lambda_handler
      Code:
        ZipFile: |
          import boto3
          import json
          from datetime import datetime, timedelta
          
          def lambda_handler(event, context):
              ec2 = boto3.client('ec2')
              cloudwatch = boto3.client('cloudwatch')
              
              # Get instances with auto-stop tag
              instances = ec2.describe_instances(
                  Filters=[
                      {'Name': 'tag:AutoStop', 'Values': ['enabled']},
                      {'Name': 'instance-state-name', 'Values': ['running']}
                  ]
              )
              
              for reservation in instances['Reservations']:
                  for instance in reservation['Instances']:
                      instance_id = instance['InstanceId']
                      
                      # Check CPU utilization for last 10 minutes
                      response = cloudwatch.get_metric_statistics(
                          Namespace='AWS/EC2',
                          MetricName='CPUUtilization',
                          Dimensions=[{'Name': 'InstanceId', 'Value': instance_id}],
                          StartTime=datetime.utcnow() - timedelta(minutes=10),
                          EndTime=datetime.utcnow(),
                          Period=300,
                          Statistics=['Average']
                      )
                      
                      # If average CPU < 3% for 10 minutes, stop instance
                      if len(response['Datapoints']) > 0:
                          avg_cpu = sum(dp['Average'] for dp in response['Datapoints']) / len(response['Datapoints'])
                          if avg_cpu < 3.0:
                              ec2.stop_instances(InstanceIds=[instance_id])
                              print(f"Stopped instance {instance_id} due to low CPU: {avg_cpu}%")
              
              return {'statusCode': 200}
      Tags:
        - Key: Project
          Value: !Ref ResourcePrefix
        - Key: AutoStop
          Value: enabled

  AutoStartWebhook:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: !Sub "${ResourcePrefix}-ec2-auto-start"
      Runtime: python3.9
      Handler: index.lambda_handler
      Code:
        ZipFile: |
          import boto3
          import json
          
          def lambda_handler(event, context):
              ec2 = boto3.client('ec2')
              
              # Start instances with auto-stop tag when webhook received
              instances = ec2.describe_instances(
                  Filters=[
                      {'Name': 'tag:AutoStop', 'Values': ['enabled']},
                      {'Name': 'instance-state-name', 'Values': ['stopped']}
                  ]
              )
              
              instance_ids = []
              for reservation in instances['Reservations']:
                  for instance in reservation['Instances']:
                      instance_ids.append(instance['InstanceId'])
              
              if instance_ids:
                  ec2.start_instances(InstanceIds=instance_ids)
                  print(f"Started instances: {instance_ids}")
              
              return {
                  'statusCode': 200,
                  'body': json.dumps({'started_instances': instance_ids})
              }
```

### Enhanced Cost Breakdown with Auto-Stop

#### Without Auto-Stop (24/7 Operation)
| Component | Hourly | Daily | Monthly | Configuration |
|-----------|--------|-------|---------|---------------|
| **EC2 g4dn.xlarge** | $0.526 | $12.62 | $379 | 4 vCPU, 16GB, T4 GPU |
| **EBS Storage** | $0.011 | $0.27 | $8 | 100GB gp3 |
| **ALB** | $0.022 | $0.53 | $16 | Standard ALB |
| **CloudWatch** | $0.014 | $0.33 | $10 | Detailed monitoring |
| **Data Transfer** | $0.025 | $0.60 | $18 | 200GB/month |
| **Elastic IP** | $0.005 | $0.12 | $3.65 | Static IP |
| **Total 24/7** | **$0.603** | **$14.47** | **$434.65** |

#### With Auto-Stop (6 hours/day active)
| Component | Hourly | Daily | Monthly | Savings |
|-----------|--------|-------|---------|---------|
| **EC2 g4dn.xlarge** | $0.526 | $3.16 | $95 | 75% |
| **EBS Storage** | $0.011 | $0.27 | $8 | 0% |
| **ALB** | $0.022 | $0.53 | $16 | 0% |
| **CloudWatch** | $0.014 | $0.33 | $10 | 0% |
| **Data Transfer** | $0.006 | $0.15 | $4.50 | 75% |
| **Elastic IP** | $0.005 | $0.12 | $3.65 | 0% |
| **Auto-Stop Lambda** | $0.0002 | $0.005 | $0.15 | New cost |
| **Total Auto-Stop** | **$0.132** | **$3.17** | **$137.30** |
| **Monthly Savings** | | | **$297.35** | **68%** |

---

## ⚡ Option 3: Lambda + EFS (Serverless - No Auto-Stop Needed)

### Cost Breakdown (Pay-per-Use)
| Component | Per Invocation | Daily (10 runs) | Monthly (300 runs) |
|-----------|----------------|-----------------|-------------------|
| **Lambda Execution** | $0.15 | $1.50 | $45 |
| **EFS Storage** | $0.008/hour | $0.20 | $6 |
| **EFS Throughput** | $0.083/hour | $2.00 | $60 |
| **VPC NAT Gateway** | $0.045/hour | $1.08 | $32 |
| **CloudWatch Logs** | $0.008/day | $0.08 | $2.50 |
| **API Gateway** | $0.0035/request | $0.035 | $1.05 |
| **Total** | **$0.15** | **$4.89** | **$146.55** |

---

## 🔒 Security Best Practices

### Network Security
```yaml
# security-groups.yml
AITestingSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: !Sub "${ResourcePrefix} AI Testing Agent Security Group"
    VpcId: !Ref VPC
    SecurityGroupIngress:
      # Only allow traffic from ALB
      - IpProtocol: tcp
        FromPort: 11434
        ToPort: 11434
        SourceSecurityGroupId: !Ref ALBSecurityGroup
        Description: "Ollama API from ALB only"
      # No direct internet access
    SecurityGroupEgress:
      # Allow HTTPS for model downloads (during setup only)
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 0.0.0.0/0
        Description: "HTTPS for model downloads"
      # Allow EFS access
      - IpProtocol: tcp
        FromPort: 2049
        ToPort: 2049
        DestinationSecurityGroupId: !Ref EFSSecurityGroup
        Description: "EFS access"
    Tags:
      - Key: Name
        Value: !Sub "${ResourcePrefix}-ai-testing-sg"
      - Key: Project
        Value: !Ref ResourcePrefix
```

### IAM Roles with Least Privilege
```yaml
# iam-roles.yml
AITestingTaskRole:
  Type: AWS::IAM::Role
  Properties:
    RoleName: !Sub "${ResourcePrefix}-task-role"
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            Service: ecs-tasks.amazonaws.com
          Action: sts:AssumeRole
    ManagedPolicyArns:
      - arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    Policies:
      - PolicyName: S3TestResultsAccess
        PolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Action:
                - s3:PutObject
                - s3:PutObjectAcl
              Resource: !Sub "${TestResultsBucket}/*"
            - Effect: Allow
              Action:
                - s3:ListBucket
              Resource: !Ref TestResultsBucket
    Tags:
      - Key: Project
        Value: !Ref ResourcePrefix
```

---

## 🏷️ Resource Grouping and Management

### CloudFormation Stack Structure
```yaml
# master-stack.yml
Parameters:
  ResourcePrefix:
    Type: String
    Default: "deployer-ddf-mod-llm-models"
    Description: "Prefix for all resources"
  
  Environment:
    Type: String
    Default: "dev"
    AllowedValues: [dev, staging, prod]
    Description: "Environment name"
  
  ProjectCode:
    Type: String
    Default: "AIT001"
    Description: "Project code for billing"

Resources:
  # Nested stacks for better organization
  NetworkingStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub "https://${TemplatesBucket}.s3.amazonaws.com/networking.yml"
      Parameters:
        ResourcePrefix: !Ref ResourcePrefix
        Environment: !Ref Environment
      Tags:
        - Key: StackType
          Value: networking

  SecurityStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub "https://${TemplatesBucket}.s3.amazonaws.com/security.yml"
      Parameters:
        ResourcePrefix: !Ref ResourcePrefix
        VPCId: !GetAtt NetworkingStack.Outputs.VPCId
      Tags:
        - Key: StackType
          Value: security

  ComputeStack:
    Type: AWS::CloudFormation::Stack
    Properties:
      TemplateURL: !Sub "https://${TemplatesBucket}.s3.amazonaws.com/compute.yml"
      Parameters:
        ResourcePrefix: !Ref ResourcePrefix
        SecurityGroupId: !GetAtt SecurityStack.Outputs.SecurityGroupId
      Tags:
        - Key: StackType
          Value: compute

# Global tags applied to all resources
Tags:
  - Key: Project
    Value: !Ref ResourcePrefix
  - Key: Environment
    Value: !Ref Environment
  - Key: ProjectCode
    Value: !Ref ProjectCode
  - Key: CostCenter
    Value: "ai-testing"
  - Key: Owner
    Value: "devops-team"
  - Key: CreatedBy
    Value: "cloudformation"
  - Key: DeletionPolicy
    Value: "safe-to-delete"
  - Key: BackupRequired
    Value: "false"
  - Key: MonitoringLevel
    Value: "standard"
```

### Resource Group Definition
```yaml
# resource-group.yml
AITestingResourceGroup:
  Type: AWS::ResourceGroups::Group
  Properties:
    Name: !Sub "${ResourcePrefix}-${Environment}"
    Description: !Sub "All resources for AI Testing Agent in ${Environment}"
    ResourceQuery:
      Type: TAG_FILTERS_1_0
      Query:
        ResourceTypeFilters:
          - AWS::AllSupported
        TagFilters:
          - Key: Project
            Values: [!Ref ResourcePrefix]
          - Key: Environment
            Values: [!Ref Environment]
    Tags:
      - Key: Project
        Value: !Ref ResourcePrefix
      - Key: Environment
        Value: !Ref Environment
```

---

## 🗑️ Clean Deletion Strategy

### Deletion Script
```bash
#!/bin/bash
# delete-deployer-ddf-mod-llm-models.sh

set -euo pipefail

RESOURCE_PREFIX="deployer-ddf-mod-llm-models"
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"

echo "🗑️  Deleting AI Testing Agent resources for environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Resource Prefix: $RESOURCE_PREFIX"

# Confirm deletion
read -p "Are you sure you want to delete ALL resources? (type 'DELETE' to confirm): " confirm
if [ "$confirm" != "DELETE" ]; then
    echo "Deletion cancelled"
    exit 1
fi

# Delete CloudFormation stacks in reverse order
echo "Deleting CloudFormation stacks..."
aws cloudformation delete-stack \
    --stack-name "${RESOURCE_PREFIX}-compute-${ENVIRONMENT}" \
    --region "$AWS_REGION"

aws cloudformation delete-stack \
    --stack-name "${RESOURCE_PREFIX}-security-${ENVIRONMENT}" \
    --region "$AWS_REGION"

aws cloudformation delete-stack \
    --stack-name "${RESOURCE_PREFIX}-networking-${ENVIRONMENT}" \
    --region "$AWS_REGION"

aws cloudformation delete-stack \
    --stack-name "${RESOURCE_PREFIX}-master-${ENVIRONMENT}" \
    --region "$AWS_REGION"

# Wait for deletion to complete
echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "${RESOURCE_PREFIX}-master-${ENVIRONMENT}" \
    --region "$AWS_REGION"

# Clean up any remaining resources by tags
echo "Cleaning up any remaining tagged resources..."

# Delete S3 buckets (empty them first)
aws s3api list-buckets --query "Buckets[?contains(Name, '${RESOURCE_PREFIX}')]" --output text | \
while read -r bucket; do
    if [ -n "$bucket" ]; then
        echo "Emptying and deleting S3 bucket: $bucket"
        aws s3 rm "s3://$bucket" --recursive
        aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION"
    fi
done

# Delete ECR repositories
aws ecr describe-repositories --query "repositories[?contains(repositoryName, '${RESOURCE_PREFIX}')]" --output text | \
while read -r repo; do
    if [ -n "$repo" ]; then
        echo "Deleting ECR repository: $repo"
        aws ecr delete-repository --repository-name "$repo" --force --region "$AWS_REGION"
    fi
done

echo "✅ Deletion complete!"
echo "Verify no resources remain:"
echo "aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=${RESOURCE_PREFIX}"
```

---

## 📊 Cost Monitoring and Alerts

### Cost Monitoring Setup
```yaml
# cost-monitoring.yml
Resources:
  CostBudget:
    Type: AWS::Budgets::Budget
    Properties:
      Budget:
        BudgetName: !Sub "${ResourcePrefix}-monthly-budget"
        BudgetLimit:
          Amount: 200
          Unit: USD
        TimeUnit: MONTHLY
        BudgetType: COST
        CostFilters:
          TagKey:
            - Project
          TagValue:
            - !Ref ResourcePrefix
      NotificationsWithSubscribers:
        - Notification:
            NotificationType: ACTUAL
            ComparisonOperator: GREATER_THAN
            Threshold: 80
          Subscribers:
            - SubscriptionType: EMAIL
              Address: devops@company.com
        - Notification:
            NotificationType: FORECASTED
            ComparisonOperator: GREATER_THAN
            Threshold: 100
          Subscribers:
            - SubscriptionType: EMAIL
              Address: devops@company.com

  DailyCostReport:
    Type: AWS::Events::Rule
    Properties:
      Description: "Daily cost report for AI Testing Agent"
      ScheduleExpression: "cron(0 9 * * ? *)"  # 9 AM daily
      State: ENABLED
      Targets:
        - Arn: !GetAtt CostReportFunction.Arn
          Id: "DailyCostReportTarget"
```

---

## 🎯 Final Recommendations

### Cost-Optimized Deployment Strategy

1. **Development Environment**: Lambda + EFS
   - **Cost**: $20-80/month
   - **Use Case**: Testing, proof-of-concept
   - **Auto-scaling**: Built-in serverless scaling

2. **Production Environment**: ECS Fargate + Auto-Stop
   - **Cost**: $103-120/month (with auto-stop)
   - **Use Case**: Regular CI/CD integration
   - **Savings**: 46-50% with auto-stop

3. **High-Volume Environment**: EC2 + GPU + Auto-Stop
   - **Cost**: $137/month (with auto-stop)
   - **Use Case**: >100 PRs/day, intensive testing
   - **Savings**: 68% with auto-stop

### Implementation Priority
1. **Week 1**: Deploy Lambda version for immediate testing
2. **Week 2**: Implement ECS Fargate with auto-stop
3. **Week 3**: Add comprehensive monitoring and cost alerts
4. **Week 4**: Optimize and document operational procedures

---

**Document Owner:** DevOps Team  
**Review Cycle:** Monthly  
**Cost Review:** Weekly  
**Last Updated:** 2025-01-22 