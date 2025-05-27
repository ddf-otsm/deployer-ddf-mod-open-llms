# AWS Authentication & Budget Setup Guide

**Status**: CRITICAL DOCUMENTATION  
**Priority**: HIGH  
**Created**: 2025-05-26  
**Last Updated**: 2025-05-26  

## 🚨 **CRITICAL QUESTION ANSWERED**

**Q: How are we being authorized to make API calls to AWS?**  
**A: We are NOT currently authorized! This is a critical gap that needs immediate attention.**

## 🔐 **Current Authentication Status**

### **❌ MISSING: AWS Authentication Configuration**
- **No AWS credentials configured** in health check scripts
- **No IAM roles defined** for Bedrock access
- **No authentication headers** in API calls
- **Result**: HTTP 403 Forbidden from all AWS endpoints

### **Evidence of Missing Authentication**
```bash
# Current health check attempts (FAILING):
curl -s https://bedrock.us-east-1.amazonaws.com/foundation-models/meta.llama3-1-70b-instruct-v1:0
# Response: HTTP 403 Forbidden
```

## 🎯 **IMMEDIATE ACTION PLAN**

### **Phase 1: AWS Account Setup (TODAY)**

#### **1.1 Create AWS Account & IAM User**
```bash
# Step 1: Create AWS account (if not exists)
# Go to: https://aws.amazon.com/

# Step 2: Create IAM user for LLM models
aws iam create-user --user-name deployer-ddf-llm-models

# Step 3: Create access keys
aws iam create-access-key --user-name deployer-ddf-llm-models
```

#### **1.2 Configure IAM Permissions**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockModelAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:GetFoundationModel",
        "bedrock:ListFoundationModels"
      ],
      "Resource": [
        "arn:aws:bedrock:*:*:foundation-model/meta.llama3-1-70b-instruct-v1:0",
        "arn:aws:bedrock:*:*:foundation-model/meta.codellama-34b-instruct-v1:0"
      ]
    },
    {
      "Sid": "BedrockHealthCheck",
      "Effect": "Allow",
      "Action": [
        "bedrock:GetFoundationModel",
        "bedrock:ListFoundationModels"
      ],
      "Resource": "*"
    }
  ]
}
```

#### **1.3 Set Budget Limits**
```bash
# Create monthly budget for LLM models
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "deployer-ddf-llm-models-budget",
    "BudgetLimit": {
      "Amount": "100",
      "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
      "Service": ["Amazon Bedrock"]
    }
  }' \
  --notifications-with-subscribers '[
    {
      "Notification": {
        "NotificationType": "ACTUAL",
        "ComparisonOperator": "GREATER_THAN",
        "Threshold": 80
      },
      "Subscribers": [
        {
          "SubscriptionType": "EMAIL",
          "Address": "ti@dadosfera.ai"
        }
      ]
    }
  ]'
```

### **Phase 2: Authentication Implementation (TODAY)**

#### **2.1 Update Health Check Script with AWS Authentication**
```bash
# Add AWS authentication to api-endpoint-tester.sh
test_aws_endpoint_with_auth() {
    local url="$1"
    local method="${2:-GET}"
    
    # Use AWS CLI to make authenticated requests
    local aws_response
    if aws_response=$(aws bedrock get-foundation-model \
        --model-identifier "meta.llama3-1-70b-instruct-v1:0" \
        --region us-east-1 \
        --output json 2>/dev/null); then
        
        echo "200|0.5|$aws_response"
        return 0
    else
        echo "403|0.5|Authentication failed"
        return 1
    fi
}
```

#### **2.2 Environment Configuration**
```bash
# Create .env file for AWS credentials (NEVER COMMIT)
cat > deployer-ddf-mod-llm-models/.env << EOF
# AWS Credentials for LLM Models
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_DEFAULT_REGION=us-east-1

# Budget Configuration
AWS_BUDGET_LIMIT=100
AWS_COST_ALERT_THRESHOLD=80
EOF

# Ensure .env is in .gitignore
echo ".env" >> deployer-ddf-mod-llm-models/.gitignore
```

#### **2.3 Update Configuration with Authentication**
```json
{
  "environments": {
    "dev": {
      "endpoints": {
        "local": "http://localhost:11434",
        "aws": "https://bedrock-runtime.us-east-1.amazonaws.com"
      },
      "authentication": {
        "aws": {
          "type": "iam",
          "region": "us-east-1",
          "credentials_source": "environment"
        }
      },
      "budget": {
        "monthly_limit": 50,
        "alert_threshold": 80
      }
    },
    "staging": {
      "budget": {
        "monthly_limit": 100,
        "alert_threshold": 75
      }
    },
    "prod": {
      "budget": {
        "monthly_limit": 200,
        "alert_threshold": 70
      }
    }
  }
}
```

## 💰 **BUDGET MANAGEMENT PLAN**

### **Budget Tiers by Environment**

| Environment | Monthly Limit | Alert Threshold | Use Case |
|-------------|---------------|-----------------|----------|
| **dev** | $50 | 80% ($40) | Development testing |
| **staging** | $100 | 75% ($75) | Pre-production validation |
| **prod** | $200 | 70% ($140) | Production workloads |

### **Cost Monitoring Implementation**
```bash
# Daily cost check script
#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/monitoring/check-aws-costs.sh

check_daily_costs() {
    local environment="$1"
    local budget_limit="$2"
    
    # Get current month costs
    local current_costs=$(aws ce get-cost-and-usage \
        --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter file://cost-filter.json \
        --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
        --output text)
    
    # Calculate percentage of budget used
    local percentage=$(echo "scale=2; $current_costs / $budget_limit * 100" | bc)
    
    echo "Environment: $environment"
    echo "Current costs: \$$current_costs"
    echo "Budget limit: \$$budget_limit"
    echo "Budget used: $percentage%"
    
    # Alert if over threshold
    if (( $(echo "$percentage > 80" | bc -l) )); then
        echo "⚠️  WARNING: Budget threshold exceeded!"
        # Send alert (implement notification system)
    fi
}
```

### **Cost Optimization Strategies**

#### **1. Model Selection by Cost**
```json
{
  "cost_optimization": {
    "model_tiers": {
      "tier_1_local": {
        "cost_per_request": "$0.00",
        "models": ["llama-3.1-8b", "mistral-7b"],
        "use_case": "Development, basic testing"
      },
      "tier_2_aws_small": {
        "cost_per_request": "$0.001-0.005",
        "models": ["llama-3.1-70b"],
        "use_case": "Advanced testing, staging"
      },
      "tier_3_aws_large": {
        "cost_per_request": "$0.01-0.05",
        "models": ["codellama-34b"],
        "use_case": "Production, complex analysis"
      }
    }
  }
}
```

#### **2. Request Optimization**
```bash
# Implement request caching to reduce AWS costs
cache_aws_response() {
    local model="$1"
    local prompt_hash=$(echo "$2" | sha256sum | cut -d' ' -f1)
    local cache_file="cache/aws_${model}_${prompt_hash}.json"
    
    # Check cache first
    if [[ -f "$cache_file" && $(find "$cache_file" -mmin -60) ]]; then
        cat "$cache_file"
        return 0
    fi
    
    # Make AWS request and cache result
    local response=$(aws bedrock invoke-model \
        --model-id "$model" \
        --body "$2" \
        --output json)
    
    echo "$response" > "$cache_file"
    echo "$response"
}
```

#### **3. Auto-Stop for AWS Resources**
```bash
# Auto-stop AWS resources when not in use
auto_stop_aws_resources() {
    local environment="$1"
    
    # Check if any health checks are running
    local active_checks=$(ps aux | grep "api-endpoint-tester" | grep -v grep | wc -l)
    
    if [[ $active_checks -eq 0 ]]; then
        echo "No active health checks, implementing cost-saving measures..."
        
        # Reduce provisioned concurrency for Lambda functions
        aws lambda put-provisioned-concurrency-config \
            --function-name "deployer-ddf-llm-models-$environment" \
            --provisioned-concurrency-config ProvisionedConcurrencyConfig=0
        
        echo "✅ Cost-saving measures activated"
    fi
}
```

## 🔧 **IMPLEMENTATION STEPS**

### **Step 1: Immediate Setup (Next 30 minutes)**
```bash
# 1. Create AWS account and IAM user
# 2. Configure credentials locally
aws configure --profile llm-models

# 3. Test basic AWS access
aws sts get-caller-identity --profile llm-models

# 4. Set up budget
./scripts/setup/create-aws-budget.sh --limit=100 --environment=dev
```

### **Step 2: Update Health Check Script (Next 30 minutes)**
```bash
# 1. Add AWS authentication to health check
# 2. Update configuration with AWS endpoints
# 3. Test AWS model connectivity
./scripts/local/api-endpoint-tester.sh --env=staging --verbose --aws-auth
```

### **Step 3: Budget Monitoring (Next 15 minutes)**
```bash
# 1. Set up daily cost monitoring
# 2. Configure alerts
# 3. Test budget notifications
./scripts/monitoring/setup-cost-alerts.sh --environment=dev
```

## 🚨 **SECURITY CONSIDERATIONS**

### **Credential Management**
```bash
# ✅ SECURE: Use environment variables
export AWS_ACCESS_KEY_ID="your_key"
export AWS_SECRET_ACCESS_KEY="your_secret"

# ✅ SECURE: Use AWS profiles
aws configure --profile llm-models

# ❌ INSECURE: Never hardcode in scripts
# AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"  # DON'T DO THIS
```

### **IAM Best Practices**
1. **Principle of least privilege**: Only Bedrock model access
2. **Resource-specific permissions**: Limit to specific model ARNs
3. **Time-based access**: Consider temporary credentials
4. **Regular rotation**: Rotate access keys monthly

### **Cost Protection**
1. **Budget alerts**: Multiple threshold levels (50%, 75%, 90%)
2. **Automatic shutoff**: Stop services at 95% budget
3. **Daily monitoring**: Check costs every 24 hours
4. **Request limits**: Maximum requests per day/hour

## 📊 **SUCCESS METRICS**

### **Authentication Success**
- ✅ AWS Bedrock API calls return HTTP 200
- ✅ Model health checks pass for AWS endpoints
- ✅ No more HTTP 403 Forbidden errors

### **Budget Compliance**
- ✅ Monthly costs stay within budget limits
- ✅ Cost alerts trigger at defined thresholds
- ✅ Daily cost monitoring operational

### **Security Compliance**
- ✅ No credentials in code or logs
- ✅ IAM permissions follow least privilege
- ✅ Access keys rotated regularly

## 🎯 **NEXT STEPS**

1. **IMMEDIATE**: Set up AWS account and IAM user
2. **TODAY**: Implement AWS authentication in health checks
3. **THIS WEEK**: Deploy budget monitoring and alerts
4. **ONGOING**: Monitor costs and optimize usage

---

**Last Updated**: 2025-05-26 07:20:00 UTC  
**Next Review**: 2025-05-27 07:00:00 UTC  
**Owner**: DevOps Team  
**Budget Owner**: Finance Team 