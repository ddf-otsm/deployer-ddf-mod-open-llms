# AWS Deployment Configuration - May 2025

## 📋 Overview

This directory contains AWS resource discovery tools and deployment configurations for the **DeployerDDF Module: Open LLM Models** project.

## 📁 Files

### 🔍 Resource Discovery
- **`aws-resource-discovery.sh`** - Automated script to discover and document AWS resources
- **`discovered-resources-*.yml`** - Generated YAML files with actual AWS resource information
- **`.env.aws-secrets-*`** - Generated environment files with sensitive AWS resource identifiers

### 📋 Configuration Templates
- **`deployment-config-template.yml`** - Template with placeholders for AWS resource IDs
- **`README.md`** - This documentation file

## 🚀 Quick Start

### 1. Discover Existing AWS Resources

Run the discovery script to find all AWS resources related to this project:

```bash
# Make sure you have AWS CLI configured
aws configure list

# Run the discovery script
./config/deployments/may_2025/aws-resource-discovery.sh
```

This will generate:
- `discovered-resources-TIMESTAMP.yml` - Complete resource inventory
- `.env.aws-secrets-TIMESTAMP` - Environment variables with resource identifiers

### 2. Review Discovered Resources

```bash
# View the discovered resources
cat config/deployments/may_2025/discovered-resources-*.yml

# Check the secrets file (contains sensitive information)
cat config/deployments/may_2025/.env.aws-secrets-*
```

### 3. Transfer Secrets Safely

**⚠️ IMPORTANT**: The `.env.aws-secrets-*` file contains sensitive information.

```bash
# Option 1: Transfer to your environment
source config/deployments/may_2025/.env.aws-secrets-*

# Option 2: Add to your .env file (recommended)
cat config/deployments/may_2025/.env.aws-secrets-* >> .env

# Option 3: Use AWS Secrets Manager (production)
# Upload secrets to AWS Secrets Manager and reference them in your application

# After transferring, delete the secrets file
rm config/deployments/may_2025/.env.aws-secrets-*
```

## 🔧 Resource Discovery Script Details

### What It Discovers

The `aws-resource-discovery.sh` script searches for:

1. **CloudFormation Stacks** - Infrastructure stacks with project prefix
2. **ECS Resources** - Clusters, services, and task definitions
3. **S3 Buckets** - Storage buckets for results and artifacts
4. **Load Balancers** - Application Load Balancers and target groups
5. **SQS Queues** - Message queues for job processing
6. **CloudWatch Log Groups** - Logging infrastructure

### Configuration

The script uses these environment variables:

```bash
# AWS Region (default: us-east-1)
export AWS_REGION=us-east-1

# Project prefix for resource filtering
PROJECT_PREFIX="deployer-ddf-llm"
```

### Output Format

#### Resources File (`discovered-resources-*.yml`)
```yaml
discovery:
  timestamp: "20250526_143022"
  region: "us-east-1"
  project_prefix: "deployer-ddf-llm"

resources:
  cloudformation:
    stacks:
      - name: "deployer-ddf-llm-dev"
        status: "CREATE_COMPLETE"
        outputs:
          - key: "VPCId"
            value: "vpc-1234567890abcdef0"
  # ... more resources
```

#### Secrets File (`.env.aws-secrets-*`)
```bash
# AWS Secrets and Sensitive Information
AWS_DISCOVERY_TIMESTAMP=20250526_143022
AWS_REGION=us-east-1
AWS_S3_BUCKET_DEPLOYER_DDF_LLM_RESULTS_DEV=arn:aws:s3:::deployer-ddf-llm-results-dev-123456789012
AWS_ALB_DNS_DEPLOYER_DDF_LLM_ALB_DEV=deployer-ddf-llm-alb-dev-1234567890.us-east-1.elb.amazonaws.com
# ... more secrets
```

## 📊 Using the Configuration Template

The `deployment-config-template.yml` provides a structured template for deployment configurations:

1. **Copy the template** for your environment:
   ```bash
   cp deployment-config-template.yml deployment-config-dev.yml
   ```

2. **Replace placeholders** with actual values from the discovery:
   ```bash
   # Use the discovered resources to populate the template
   sed -i 's/${VPC_ID}/vpc-1234567890abcdef0/g' deployment-config-dev.yml
   ```

3. **Validate the configuration**:
   ```bash
   # Check YAML syntax
   python -c "import yaml; yaml.safe_load(open('deployment-config-dev.yml'))"
   ```

## 🔒 Security Best Practices

### Secrets Management

1. **Never commit secrets** to version control
2. **Use environment variables** for local development
3. **Use AWS Secrets Manager** for production
4. **Rotate credentials** regularly
5. **Apply least privilege** IAM policies

### File Permissions

```bash
# Secure the secrets file
chmod 600 .env.aws-secrets-*

# Make discovery script executable
chmod +x aws-resource-discovery.sh
```

## 🔄 Maintenance

### Regular Updates

Run the discovery script regularly to keep resource information current:

```bash
# Weekly discovery (recommended)
./config/deployments/may_2025/aws-resource-discovery.sh

# Compare with previous discoveries
diff discovered-resources-old.yml discovered-resources-new.yml
```

### Cleanup

Remove old discovery files periodically:

```bash
# Keep only the latest 5 discovery files
ls -t discovered-resources-*.yml | tail -n +6 | xargs rm -f
```

## 🆘 Troubleshooting

### Common Issues

1. **AWS CLI not configured**:
   ```bash
   aws configure
   # or
   export AWS_PROFILE=your-profile
   ```

2. **Insufficient permissions**:
   ```bash
   # Check your AWS identity
   aws sts get-caller-identity
   
   # Required permissions:
   # - cloudformation:ListStacks
   # - cloudformation:DescribeStacks
   # - ecs:ListClusters
   # - ecs:ListServices
   # - s3:ListBuckets
   # - elbv2:DescribeLoadBalancers
   # - sqs:ListQueues
   # - logs:DescribeLogGroups
   ```

3. **No resources found**:
   - Check if resources were actually deployed
   - Verify the correct AWS region
   - Confirm the project prefix matches your resources

### Debug Mode

Run the script with debug output:

```bash
bash -x ./config/deployments/may_2025/aws-resource-discovery.sh
```

## 📞 Support

For issues with this deployment configuration:

1. Check the project's main README
2. Review the CloudFormation templates in `scripts/deploy/templates/`
3. Consult the AWS documentation for specific services
4. Open an issue in the project repository

## 📝 Changelog

- **2025-05-26**: Initial creation of deployment configuration system
- **2025-05-26**: Added automated AWS resource discovery script
- **2025-05-26**: Created configuration templates and documentation 