#!/bin/bash

# AWS Resource Discovery Script
# DeployerDDF Module: Open LLM Models
# Date: May 26, 2025

set -e

# Configuration
REGION="${AWS_REGION:-us-east-1}"
PROJECT_PREFIX="deployer-ddf-llm"
OUTPUT_DIR="config/deployments/may_2025"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "🔍 AWS Resource Discovery for DeployerDDF LLM Module"
echo "📅 Timestamp: $TIMESTAMP"
echo "🌍 Region: $REGION"
echo "📁 Output Directory: $OUTPUT_DIR"
echo ""

# Create output files
RESOURCES_FILE="$OUTPUT_DIR/discovered-resources-$TIMESTAMP.yml"
SECRETS_FILE="$OUTPUT_DIR/.env.aws-secrets-$TIMESTAMP"

# Initialize YAML file
cat > "$RESOURCES_FILE" << EOF
# AWS Resources Discovery Report
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Region: $REGION
# Project: deployer-ddf-mod-open-llms

discovery:
  timestamp: "$TIMESTAMP"
  region: "$REGION"
  project_prefix: "$PROJECT_PREFIX"

resources:
EOF

# Initialize secrets file
cat > "$SECRETS_FILE" << EOF
# AWS Secrets and Sensitive Information
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# IMPORTANT: Do not commit this file to version control
# Transfer these values to your environment variables or secrets manager

# Discovery timestamp
AWS_DISCOVERY_TIMESTAMP=$TIMESTAMP
AWS_REGION=$REGION

EOF

echo "📋 Discovering CloudFormation Stacks..."
if aws cloudformation list-stacks --region "$REGION" --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName, '$PROJECT_PREFIX')]" > /tmp/cf_stacks.json 2>/dev/null; then
    if [ -s /tmp/cf_stacks.json ] && [ "$(cat /tmp/cf_stacks.json)" != "[]" ]; then
        echo "  cloudformation:" >> "$RESOURCES_FILE"
        echo "    stacks:" >> "$RESOURCES_FILE"
        
        # Parse stack names and get details
        aws cloudformation list-stacks --region "$REGION" --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?contains(StackName, '$PROJECT_PREFIX')].StackName" --output text | while read -r stack_name; do
            if [ -n "$stack_name" ]; then
                echo "      - name: \"$stack_name\"" >> "$RESOURCES_FILE"
                echo "        status: \"$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$stack_name" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo 'UNKNOWN')\"" >> "$RESOURCES_FILE"
                
                # Get stack outputs
                if aws cloudformation describe-stacks --region "$REGION" --stack-name "$stack_name" --query 'Stacks[0].Outputs' > /tmp/stack_outputs.json 2>/dev/null; then
                    if [ -s /tmp/stack_outputs.json ] && [ "$(cat /tmp/stack_outputs.json)" != "null" ]; then
                        echo "        outputs:" >> "$RESOURCES_FILE"
                        jq -r '.[] | "          - key: \"" + .OutputKey + "\"\n            value: \"" + .OutputValue + "\"\n            description: \"" + (.Description // "No description") + "\""' /tmp/stack_outputs.json >> "$RESOURCES_FILE"
                    fi
                fi
            fi
        done
        
        echo "✅ Found CloudFormation stacks"
    else
        echo "    stacks: []" >> "$RESOURCES_FILE"
        echo "⚠️  No CloudFormation stacks found"
    fi
else
    echo "    stacks: []" >> "$RESOURCES_FILE"
    echo "❌ Error checking CloudFormation stacks"
fi

echo ""
echo "🖥️  Discovering ECS Resources..."
if aws ecs list-clusters --region "$REGION" --query "clusterArns[?contains(@, '$PROJECT_PREFIX')]" > /tmp/ecs_clusters.json 2>/dev/null; then
    if [ -s /tmp/ecs_clusters.json ] && [ "$(cat /tmp/ecs_clusters.json)" != "[]" ]; then
        echo "  ecs:" >> "$RESOURCES_FILE"
        echo "    clusters:" >> "$RESOURCES_FILE"
        
        jq -r '.[]' /tmp/ecs_clusters.json | while read -r cluster_arn; do
            cluster_name=$(basename "$cluster_arn")
            echo "      - name: \"$cluster_name\"" >> "$RESOURCES_FILE"
            echo "        arn: \"$cluster_arn\"" >> "$RESOURCES_FILE"
            
            # Get services in cluster
            if aws ecs list-services --region "$REGION" --cluster "$cluster_name" --query 'serviceArns' > /tmp/ecs_services.json 2>/dev/null; then
                if [ -s /tmp/ecs_services.json ] && [ "$(cat /tmp/ecs_services.json)" != "[]" ]; then
                    echo "        services:" >> "$RESOURCES_FILE"
                    jq -r '.[]' /tmp/ecs_services.json | while read -r service_arn; do
                        service_name=$(basename "$service_arn")
                        echo "          - name: \"$service_name\"" >> "$RESOURCES_FILE"
                        echo "            arn: \"$service_arn\"" >> "$RESOURCES_FILE"
                    done
                fi
            fi
        done
        
        echo "✅ Found ECS clusters"
    else
        echo "  ecs:" >> "$RESOURCES_FILE"
        echo "    clusters: []" >> "$RESOURCES_FILE"
        echo "⚠️  No ECS clusters found"
    fi
else
    echo "  ecs:" >> "$RESOURCES_FILE"
    echo "    clusters: []" >> "$RESOURCES_FILE"
    echo "❌ Error checking ECS clusters"
fi

echo ""
echo "🪣 Discovering S3 Buckets..."
if aws s3api list-buckets --query "Buckets[?contains(Name, '$PROJECT_PREFIX')]" > /tmp/s3_buckets.json 2>/dev/null; then
    if [ -s /tmp/s3_buckets.json ] && [ "$(cat /tmp/s3_buckets.json)" != "[]" ]; then
        echo "  s3:" >> "$RESOURCES_FILE"
        echo "    buckets:" >> "$RESOURCES_FILE"
        
        jq -r '.[] | .Name' /tmp/s3_buckets.json | while read -r bucket_name; do
            echo "      - name: \"$bucket_name\"" >> "$RESOURCES_FILE"
            echo "        region: \"$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text 2>/dev/null || echo 'us-east-1')\"" >> "$RESOURCES_FILE"
            
            # Add bucket ARN to secrets file
            echo "AWS_S3_BUCKET_$(echo "$bucket_name" | tr '[:lower:]-' '[:upper:]_')=arn:aws:s3:::$bucket_name" >> "$SECRETS_FILE"
        done
        
        echo "✅ Found S3 buckets"
    else
        echo "  s3:" >> "$RESOURCES_FILE"
        echo "    buckets: []" >> "$RESOURCES_FILE"
        echo "⚠️  No S3 buckets found"
    fi
else
    echo "  s3:" >> "$RESOURCES_FILE"
    echo "    buckets: []" >> "$RESOURCES_FILE"
    echo "❌ Error checking S3 buckets"
fi

echo ""
echo "⚖️  Discovering Load Balancers..."
if aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_PREFIX')]" > /tmp/alb_list.json 2>/dev/null; then
    if [ -s /tmp/alb_list.json ] && [ "$(cat /tmp/alb_list.json)" != "[]" ]; then
        echo "  load_balancers:" >> "$RESOURCES_FILE"
        echo "    application:" >> "$RESOURCES_FILE"
        
        jq -r '.[] | .LoadBalancerName + "|" + .DNSName + "|" + .LoadBalancerArn' /tmp/alb_list.json | while IFS='|' read -r lb_name dns_name lb_arn; do
            echo "      - name: \"$lb_name\"" >> "$RESOURCES_FILE"
            echo "        dns_name: \"$dns_name\"" >> "$RESOURCES_FILE"
            echo "        arn: \"$lb_arn\"" >> "$RESOURCES_FILE"
            
            # Add ALB DNS to secrets file
            echo "AWS_ALB_DNS_$(echo "$lb_name" | tr '[:lower:]-' '[:upper:]_')=$dns_name" >> "$SECRETS_FILE"
        done
        
        echo "✅ Found Load Balancers"
    else
        echo "  load_balancers:" >> "$RESOURCES_FILE"
        echo "    application: []" >> "$RESOURCES_FILE"
        echo "⚠️  No Load Balancers found"
    fi
else
    echo "  load_balancers:" >> "$RESOURCES_FILE"
    echo "    application: []" >> "$RESOURCES_FILE"
    echo "❌ Error checking Load Balancers"
fi

echo ""
echo "📬 Discovering SQS Queues..."
if aws sqs list-queues --region "$REGION" --queue-name-prefix "$PROJECT_PREFIX" > /tmp/sqs_queues.json 2>/dev/null; then
    if [ -s /tmp/sqs_queues.json ] && [ "$(jq '.QueueUrls' /tmp/sqs_queues.json)" != "null" ]; then
        echo "  sqs:" >> "$RESOURCES_FILE"
        echo "    queues:" >> "$RESOURCES_FILE"
        
        jq -r '.QueueUrls[]' /tmp/sqs_queues.json | while read -r queue_url; do
            queue_name=$(basename "$queue_url")
            echo "      - name: \"$queue_name\"" >> "$RESOURCES_FILE"
            echo "        url: \"$queue_url\"" >> "$RESOURCES_FILE"
            
            # Add queue URL to secrets file
            echo "AWS_SQS_QUEUE_$(echo "$queue_name" | tr '[:lower:]-' '[:upper:]_')=$queue_url" >> "$SECRETS_FILE"
        done
        
        echo "✅ Found SQS queues"
    else
        echo "  sqs:" >> "$RESOURCES_FILE"
        echo "    queues: []" >> "$RESOURCES_FILE"
        echo "⚠️  No SQS queues found"
    fi
else
    echo "  sqs:" >> "$RESOURCES_FILE"
    echo "    queues: []" >> "$RESOURCES_FILE"
    echo "❌ Error checking SQS queues"
fi

echo ""
echo "📊 Discovering CloudWatch Log Groups..."
if aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "/aws/ecs/$PROJECT_PREFIX" > /tmp/cw_logs.json 2>/dev/null; then
    if [ -s /tmp/cw_logs.json ] && [ "$(jq '.logGroups' /tmp/cw_logs.json)" != "[]" ]; then
        echo "  cloudwatch:" >> "$RESOURCES_FILE"
        echo "    log_groups:" >> "$RESOURCES_FILE"
        
        jq -r '.logGroups[] | .logGroupName + "|" + (.retentionInDays // "Never expires" | tostring)' /tmp/cw_logs.json | while IFS='|' read -r log_group retention; do
            echo "      - name: \"$log_group\"" >> "$RESOURCES_FILE"
            echo "        retention_days: \"$retention\"" >> "$RESOURCES_FILE"
        done
        
        echo "✅ Found CloudWatch log groups"
    else
        echo "  cloudwatch:" >> "$RESOURCES_FILE"
        echo "    log_groups: []" >> "$RESOURCES_FILE"
        echo "⚠️  No CloudWatch log groups found"
    fi
else
    echo "  cloudwatch:" >> "$RESOURCES_FILE"
    echo "    log_groups: []" >> "$RESOURCES_FILE"
    echo "❌ Error checking CloudWatch log groups"
fi

# Add summary to YAML
echo "" >> "$RESOURCES_FILE"
echo "summary:" >> "$RESOURCES_FILE"
echo "  discovery_completed: true" >> "$RESOURCES_FILE"
echo "  total_resource_types_checked: 6" >> "$RESOURCES_FILE"
echo "  generated_files:" >> "$RESOURCES_FILE"
echo "    - \"$RESOURCES_FILE\"" >> "$RESOURCES_FILE"
echo "    - \"$SECRETS_FILE\"" >> "$RESOURCES_FILE"

# Add final notes to secrets file
echo "" >> "$SECRETS_FILE"
echo "# Usage Instructions:" >> "$SECRETS_FILE"
echo "# 1. Review all values above" >> "$SECRETS_FILE"
echo "# 2. Transfer to your environment variables or AWS Secrets Manager" >> "$SECRETS_FILE"
echo "# 3. Update your application configuration" >> "$SECRETS_FILE"
echo "# 4. Delete this file after transferring secrets" >> "$SECRETS_FILE"

# Cleanup temp files
rm -f /tmp/cf_stacks.json /tmp/stack_outputs.json /tmp/ecs_clusters.json /tmp/ecs_services.json /tmp/s3_buckets.json /tmp/alb_list.json /tmp/sqs_queues.json /tmp/cw_logs.json

echo ""
echo "✅ AWS Resource Discovery Complete!"
echo ""
echo "📄 Generated Files:"
echo "   📋 Resources: $RESOURCES_FILE"
echo "   🔐 Secrets:   $SECRETS_FILE"
echo ""
echo "🔒 IMPORTANT: The secrets file contains sensitive information."
echo "   Transfer the values to your environment or secrets manager, then delete the file."
echo ""
echo "📖 Next Steps:"
echo "   1. Review the discovered resources in $RESOURCES_FILE"
echo "   2. Transfer secrets from $SECRETS_FILE to your environment"
echo "   3. Update your application configuration as needed"
echo "   4. Run: rm $SECRETS_FILE" 