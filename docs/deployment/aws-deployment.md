# AWS Deployment Guide

Deploy the AI Testing Agent on Amazon Web Services using ECS Fargate with auto-scaling and cost optimization.

## 🎯 Overview

This guide covers deploying the AI Testing Agent on AWS using:
- **ECS Fargate**: Serverless container platform
- **Application Load Balancer**: Traffic distribution and health checks
- **Auto-scaling**: Dynamic instance scaling based on workload
- **Cost Optimization**: Auto-stop functionality for 46-68% savings
- **CloudFormation**: Infrastructure as Code

## 📋 Prerequisites

### 1. AWS Account Setup
- AWS account with appropriate permissions
- AWS CLI v2.x installed and configured
- Docker installed and running

### 2. Required AWS Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "ecs:*",
        "ec2:*",
        "elasticloadbalancing:*",
        "iam:*",
        "s3:*",
        "sqs:*",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🚀 Quick Deployment

### 1. Configure AWS Credentials

**🔒 Secure Method (Recommended):**
```bash
# Create .env file with your credentials (never commit this file!)
cat > .env << EOF
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=us-east-1
EOF

# Ensure .env is in .gitignore
echo ".env" >> .gitignore
```

**Alternative Methods:**
```bash
# Option 1: Using AWS CLI
aws configure

# Option 2: Using AWS profiles
aws configure --profile ai-testing
export AWS_PROFILE=ai-testing
```

### 2. Deploy the Stack

**🔒 Secure Deployment (Recommended):**
```bash
# Navigate to the AI Testing Agent directory
cd deployer-ddf-mod-llm-models

# Use the secure deployment script (loads credentials from .env)
./scripts/deploy/deploy-secure.sh --env=dev --region=us-east-1

# For production deployment
./scripts/deploy/deploy-secure.sh --env=prod --region=us-east-1 --instances=5

# Preview deployment without executing
./scripts/deploy/deploy-secure.sh --env=prod --dry-run
```

**Alternative (Direct Script):**
```bash
# Direct deployment (ensure AWS credentials are in environment)
./scripts/deploy/aws-deploy.sh --env=dev --region=us-east-1
```

### 3. Verify Deployment
```bash
# Check deployment health
./scripts/deploy/health-check.sh --env=dev --region=us-east-1

# Check service status
./scripts/deploy/manage.sh status --env=dev --region=us-east-1
```

## ⚙️ Configuration Options

### Deployment Parameters
```bash
./scripts/deploy/aws-deploy.sh \
  --env=prod \                    # Environment: dev|staging|prod
  --type=ecs-fargate \           # Deployment type: ecs-fargate|ec2-gpu|lambda
  --region=us-east-1 \           # AWS region
  --instances=3 \                # Number of instances
  --auto-stop=enabled \          # Auto-stop for cost savings
  --dry-run                      # Preview changes without deploying
```

### Environment-Specific Configurations

#### Development Environment
```yaml
# config/aws-dev.yml
environment: dev
instance_count: 1
instance_type: t3.small
auto_stop: enabled
cost_budget: 50  # USD per month
```

#### Production Environment
```yaml
# config/aws-prod.yml
environment: prod
instance_count: 3
instance_type: t3.medium
auto_stop: disabled
cost_budget: 200  # USD per month
high_availability: true
```

## 🏗️ Infrastructure Components

### 1. Networking
- **VPC**: Isolated network environment
- **Subnets**: Public and private subnets across 2 AZs
- **Security Groups**: Least-privilege access controls
- **Load Balancer**: Application Load Balancer with health checks

### 2. Compute
- **ECS Cluster**: Managed container orchestration
- **Task Definitions**: Container specifications
- **Services**: Auto-scaling and health management
- **Auto-scaling**: CPU and memory-based scaling

### 3. Storage & Queuing
- **S3 Bucket**: Test results and logs storage
- **SQS Queue**: Distributed test job processing
- **CloudWatch Logs**: Centralized logging

### 4. Security
- **IAM Roles**: Least-privilege service roles
- **Security Groups**: Network-level security
- **Encryption**: Data encryption at rest and in transit

## 💰 Cost Optimization

### Auto-Stop Configuration
```bash
# Enable auto-stop (default)
./scripts/deploy/aws-deploy.sh --auto-stop=enabled

# Configure auto-stop schedule
./scripts/deploy/manage.sh schedule \
  --start="09:00" \
  --stop="18:00" \
  --timezone="UTC" \
  --weekdays-only
```

### Cost Monitoring
```bash
# Monitor current costs
./scripts/deploy/manage.sh costs --env=prod

# Set up cost alerts
./scripts/deploy/manage.sh alert \
  --budget=150 \
  --threshold=80 \
      --email=ti@dadosfera.ai
```

### Expected Costs
| Configuration | Monthly Cost | Auto-Stop Savings |
|---------------|--------------|-------------------|
| Dev (1 instance) | $30-50 | 60% |
| Staging (2 instances) | $80-120 | 50% |
| Production (3-5 instances) | $150-250 | 30% |

## 📊 Monitoring & Observability

### Health Checks
```bash
# Comprehensive health check
./scripts/deploy/health-check.sh --env=prod

# Specific health checks
curl https://your-alb-url/health
curl https://your-alb-url/api/status
```

### CloudWatch Metrics
- **Container Metrics**: CPU, memory, network usage
- **Application Metrics**: Request rate, response time, error rate
- **Custom Metrics**: Test generation rate, model performance

### Logging
```bash
# View application logs
aws logs tail /aws/ecs/deployer-ddf-mod-llm-models-prod --follow

# View specific container logs
./scripts/deploy/manage.sh logs --env=prod --container=ai-agent
```

## 🔧 Management Operations

### Scaling
```bash
# Scale up instances
./scripts/deploy/manage.sh scale --instances=5 --env=prod

# Auto-scaling configuration
./scripts/deploy/manage.sh autoscale \
  --min=2 \
  --max=10 \
  --target-cpu=70 \
  --env=prod
```

### Updates & Rollbacks
```bash
# Deploy new version
./scripts/deploy/aws-deploy.sh --env=prod --image-tag=v2.0.0

# Rollback to previous version
./scripts/deploy/manage.sh rollback --env=prod

# Blue-green deployment
./scripts/deploy/aws-deploy.sh --env=prod --strategy=blue-green
```

### Maintenance
```bash
# Stop all instances
./scripts/deploy/manage.sh stop --env=prod

# Start instances
./scripts/deploy/manage.sh start --env=prod

# Restart with zero downtime
./scripts/deploy/manage.sh restart --env=prod --rolling
```

## 🔒 Security Best Practices

### 1. Network Security
- Use private subnets for ECS tasks
- Restrict security group rules to minimum required
- Enable VPC Flow Logs for network monitoring

### 2. Access Control
- Use IAM roles instead of access keys
- Implement least-privilege access policies
- Enable CloudTrail for audit logging

### 3. Data Protection
- Enable encryption at rest for S3 and EBS
- Use HTTPS/TLS for all communications
- Implement secrets management with AWS Secrets Manager

## 🚨 Troubleshooting

### Common Issues

#### Deployment Failures
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name deployer-ddf-mod-llm-models-dev

# Validate template
aws cloudformation validate-template --template-body file://templates/master-stack.yml
```

#### Service Health Issues
```bash
# Check ECS service status
aws ecs describe-services --cluster deployer-ddf-mod-llm-models-dev --services deployer-ddf-mod-llm-models

# Check task logs
aws logs get-log-events --log-group-name /aws/ecs/deployer-ddf-mod-llm-models
```

#### Performance Issues
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=deployer-ddf-mod-llm-models

# Scale up if needed
./scripts/deploy/manage.sh scale --instances=5
```

## 📚 Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [CloudFormation Templates](../templates/)
- [Cost Optimization Guide](../guides/cost-optimization.md)
- [Security Best Practices](../architecture/security.md)

## 🆘 Support

If you encounter issues:
1. Check the [troubleshooting guide](../operations/troubleshooting.md)
2. Review CloudWatch logs and metrics
3. Open an issue on [GitHub](https://github.com/dadosfera/deployerddf/issues)
4. Contact enterprise support: enterprise@dadosfera.com

---

**Next Steps**: [Configure monitoring and alerting](../operations/monitoring.md) 