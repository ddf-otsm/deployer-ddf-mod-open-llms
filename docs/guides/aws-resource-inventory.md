# AWS Resource Inventory - deployer-ddf-mod-llm-models

**Project**: AI Testing Agent - LLM Models  
**Last Updated**: 2025-05-25  
**Contact**: ti@dadosfera.ai  
**AWS Account Type**: Development  

## 📋 Complete Resource Inventory

### 🔐 IAM Resources

#### IAM Roles
| CloudFormation Name | Physical Name | Purpose | Environment |
|---------------------|---------------|---------|-------------|
| `DeployerDDFModLLMModelsExecutionRole` | `deployer-ddf-mod-llm-models-{env}-execution-role` | ECS task execution (ECR, CloudWatch) | dev/staging/prod |
| `DeployerDDFModLLMModelsTaskRole` | `deployer-ddf-mod-llm-models-{env}-task-role` | Application permissions (S3, SQS, Bedrock) | dev/staging/prod |
| `AutoStopRole` | `deployer-ddf-mod-llm-models-{env}-auto-stop-role` | Lambda auto-stop functionality | dev/staging/prod |

#### IAM Policies (Inline)
| Policy Name | Attached To | Permissions |
|-------------|-------------|-------------|
| `ECRAccess` | ExecutionRole | ECR image pulling |
| `S3Access` | TaskRole | S3 bucket operations |
| `SQSAccess` | TaskRole | SQS queue operations |
| `BedrockLLMAccess` | TaskRole | Bedrock model invocation |
| `ECSAccess` | AutoStopRole | ECS service management |

### 💻 Compute Resources

#### ECS Resources
| Resource Type | CloudFormation Name | Physical Name | Purpose |
|---------------|---------------------|---------------|---------|
| ECS Cluster | `ECSCluster` | `deployer-ddf-mod-llm-models-{env}` | Container orchestration |
| ECS Service | `ECSService` | `deployer-ddf-mod-llm-models` | Service management |
| Task Definition | `TaskDefinition` | `deployer-ddf-mod-llm-models-{env}` | Container specification |

#### Lambda Functions
| Function Name | Purpose | Runtime | Trigger |
|---------------|---------|---------|---------|
| `deployer-ddf-mod-llm-models-{env}-auto-stop` | Cost optimization | Python 3.9 | CloudWatch Events |

### 🌐 Networking Resources

#### VPC Infrastructure
| Resource Type | CloudFormation Name | Physical Name | CIDR/Details |
|---------------|---------------------|---------------|--------------|
| VPC | `VPC` | `deployer-ddf-mod-llm-models-{env}-vpc` | 10.0.0.0/16 |
| Internet Gateway | `InternetGateway` | `deployer-ddf-mod-llm-models-{env}-igw` | - |
| Public Subnet 1 | `PublicSubnet1` | `deployer-ddf-mod-llm-models-{env}-public-subnet-1` | 10.0.1.0/24 |
| Public Subnet 2 | `PublicSubnet2` | `deployer-ddf-mod-llm-models-{env}-public-subnet-2` | 10.0.2.0/24 |
| Private Subnet 1 | `PrivateSubnet1` | `deployer-ddf-mod-llm-models-{env}-private-subnet-1` | 10.0.3.0/24 |
| Private Subnet 2 | `PrivateSubnet2` | `deployer-ddf-mod-llm-models-{env}-private-subnet-2` | 10.0.4.0/24 |
| Route Table | `PublicRouteTable` | `deployer-ddf-mod-llm-models-{env}-public-routes` | Public routing |

#### Security Groups
| CloudFormation Name | Physical Name | Purpose | Ports |
|---------------------|---------------|---------|-------|
| `LoadBalancerSecurityGroup` | `deployer-ddf-mod-llm-models-{env}-alb-sg` | ALB access | 80, 443 |
| `ECSSecurityGroup` | `deployer-ddf-mod-llm-models-{env}-ecs-sg` | ECS tasks | 11434 |

#### Load Balancer
| Resource Type | CloudFormation Name | Physical Name | Type |
|---------------|---------------------|---------------|------|
| Application Load Balancer | `LoadBalancer` | `deployer-ddf-mod-llm-models-{env}-alb` | internet-facing |
| Target Group | `TargetGroup` | `deployer-ddf-mod-llm-models-{env}-tg` | HTTP health checks |
| Listener | `LoadBalancerListener` | - | HTTP:80 → HTTP:11434 |

### 💾 Storage Resources

#### S3 Buckets
| CloudFormation Name | Physical Name | Purpose | Lifecycle |
|---------------------|---------------|---------|-----------|
| `ResultsBucket` | `deployer-ddf-mod-llm-models-{env}-results-{account-id}` | Test results storage | 30 days |
| `LogsBucket` | `deployer-ddf-mod-llm-models-{env}-logs-{account-id}` | Log archival | 90 days |

#### SQS Queues
| CloudFormation Name | Physical Name | Purpose | Visibility Timeout |
|---------------------|---------------|---------|-------------------|
| `TestQueue` | `deployer-ddf-mod-llm-models-{env}-queue` | Distributed testing | 300 seconds |

### 📊 Monitoring Resources

#### CloudWatch
| Resource Type | CloudFormation Name | Physical Name | Retention |
|---------------|---------------------|---------------|-----------|
| Log Group | `LogGroup` | `/ecs/deployer-ddf-mod-llm-models-{env}` | 7 days (dev), 30 days (prod) |
| Event Rule | `AutoStopSchedule` | `deployer-ddf-mod-llm-models-{env}-auto-stop-schedule` | 15 minutes |

## 🏷️ Resource Tagging Strategy

### Standard Tags Applied to All Resources
```yaml
Tags:
  - Key: Project
    Value: deployer-ddf-mod-llm-models
  - Key: Environment
    Value: !Ref Environment  # dev/staging/prod
  - Key: Owner
    Value: ti@dadosfera.ai
  - Key: CostCenter
    Value: ai-testing
  - Key: CreatedBy
    Value: cloudformation
  - Key: AutoStop
    Value: enabled  # For dev environment
  - Key: BackupRequired
    Value: false    # For dev environment
  - Key: MonitoringLevel
    Value: basic    # For dev environment
```

### Environment-Specific Tags
```yaml
# Development Environment
Development:
  - Key: Environment
    Value: development
  - Key: AutoStop
    Value: enabled
  - Key: CostOptimization
    Value: aggressive

# Staging Environment  
Staging:
  - Key: Environment
    Value: staging
  - Key: AutoStop
    Value: disabled
  - Key: CostOptimization
    Value: moderate

# Production Environment
Production:
  - Key: Environment
    Value: production
  - Key: AutoStop
    Value: disabled
  - Key: CostOptimization
    Value: conservative
```

## 📍 Resource Locations and References

### CloudFormation Templates
```
deployer-ddf-mod-llm-models/scripts/deploy/templates/
├── master-stack.yml              # Main infrastructure template
├── networking.yml                # VPC, subnets, security groups
├── compute.yml                   # ECS cluster, services, tasks
├── storage.yml                   # S3 buckets, SQS queues
├── monitoring.yml                # CloudWatch logs, alarms
└── security.yml                  # IAM roles, policies
```

### Configuration Files
```
deployer-ddf-mod-llm-models/config/
├── auth/
│   ├── auth-config-deployment.yml               # Authentication configuration
│   └── keycloak-integration-deployment.yml     # Identity provider integration
├── deployments/
│   └── aws/
│       └── aws-dev-account-deployment.yml      # AWS DEV account specific settings
└── docker/
    ├── docker-compose-deployment.yml           # Docker deployment configuration
    └── Dockerfile                              # Container build configuration
```

### Documentation References
```
deployer-ddf-mod-llm-models/docs/guides/
├── aws-resource-inventory.md     # This document
├── iam-roles-reference.md        # Detailed IAM documentation
├── aws-footprint-removal.md      # Resource cleanup guide
├── secrets-management.md         # Security and secrets guide
└── aws-authentication-setup.md   # Authentication setup guide
```

## 🔍 Resource Discovery Commands

### List All Resources by Tag
```bash
# Find all resources for this project
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=deployer-ddf-mod-llm-models \
    --region us-east-1

# Find resources by environment
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=deployer-ddf-mod-llm-models Key=Environment,Values=dev \
    --region us-east-1
```

### Environment-Specific Resource Queries
```bash
# Development Environment Resources
ENVIRONMENT="dev"

# ECS Resources
aws ecs list-clusters --query "clusterArns[?contains(@, 'deployer-ddf-mod-llm-models-${ENVIRONMENT}')]"
aws ecs list-services --cluster "deployer-ddf-mod-llm-models-${ENVIRONMENT}"

# IAM Roles
aws iam list-roles --query "Roles[?contains(RoleName, 'deployer-ddf-mod-llm-models-${ENVIRONMENT}')]"

# S3 Buckets
aws s3api list-buckets --query "Buckets[?contains(Name, 'deployer-ddf-mod-llm-models-${ENVIRONMENT}')]"

# Load Balancers
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, 'deployer-ddf-mod-llm-models-${ENVIRONMENT}')]"

# VPCs
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=deployer-ddf-mod-llm-models-${ENVIRONMENT}-vpc"

# CloudWatch Log Groups
aws logs describe-log-groups --log-group-name-prefix "/ecs/deployer-ddf-mod-llm-models-${ENVIRONMENT}"
```

## 💰 Cost Tracking

### Resource Cost Categories
| Category | Resources | Estimated Monthly Cost (Dev) |
|----------|-----------|------------------------------|
| **Compute** | ECS Fargate (1 vCPU, 2GB) | $15-25 |
| **Networking** | ALB, NAT Gateway | $20-30 |
| **Storage** | S3 buckets, CloudWatch logs | $5-10 |
| **Monitoring** | CloudWatch metrics, alarms | $5-10 |
| **Total** | All resources | **$45-75** |

### Cost Optimization Features
- **Auto-stop**: Scales ECS service to 0 during idle periods
- **Spot instances**: Uses Fargate Spot for cost savings
- **Log retention**: Short retention periods for dev (7 days)
- **Minimal monitoring**: Basic CloudWatch metrics only

## 🚨 Resource Cleanup

### Quick Cleanup Commands
```bash
# Delete entire CloudFormation stack
aws cloudformation delete-stack \
    --stack-name "deployer-ddf-mod-llm-models-dev" \
    --region us-east-1

# Monitor deletion progress
aws cloudformation wait stack-delete-complete \
    --stack-name "deployer-ddf-mod-llm-models-dev" \
    --region us-east-1

# Verify all resources are deleted
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=deployer-ddf-mod-llm-models \
    --region us-east-1
```

### Manual Cleanup (if CloudFormation fails)
```bash
# Run the comprehensive cleanup script
bash deployer-ddf-mod-llm-models/scripts/cleanup-aws-resources.sh dev

# Or use the documented removal guide
# See: docs/guides/aws-footprint-removal.md
```

## 📋 Resource Validation

### Validation Script
```bash
#!/bin/bash
# scripts/validate-aws-resources.sh

ENVIRONMENT="${1:-dev}"

echo "🔍 Validating AWS resources for environment: $ENVIRONMENT"

# Check IAM roles
echo "Checking IAM roles..."
aws iam get-role --role-name "deployer-ddf-mod-llm-models-${ENVIRONMENT}-execution-role" >/dev/null 2>&1 && echo "✅ Execution role exists" || echo "❌ Execution role missing"
aws iam get-role --role-name "deployer-ddf-mod-llm-models-${ENVIRONMENT}-task-role" >/dev/null 2>&1 && echo "✅ Task role exists" || echo "❌ Task role missing"

# Check ECS resources
echo "Checking ECS resources..."
aws ecs describe-clusters --clusters "deployer-ddf-mod-llm-models-${ENVIRONMENT}" >/dev/null 2>&1 && echo "✅ ECS cluster exists" || echo "❌ ECS cluster missing"

# Check VPC
echo "Checking VPC..."
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=deployer-ddf-mod-llm-models-${ENVIRONMENT}-vpc" --query "Vpcs[0].VpcId" --output text | grep -q "vpc-" && echo "✅ VPC exists" || echo "❌ VPC missing"

# Check S3 buckets
echo "Checking S3 buckets..."
aws s3api head-bucket --bucket "deployer-ddf-mod-llm-models-${ENVIRONMENT}-results-$(aws sts get-caller-identity --query Account --output text)" >/dev/null 2>&1 && echo "✅ Results bucket exists" || echo "❌ Results bucket missing"

echo "🎯 Resource validation completed"
```

---

**Resource Inventory Maintained By**: DevOps Team  
**Update Frequency**: After each deployment  
**Last Validation**: 2025-05-25  
**Next Review**: Weekly 