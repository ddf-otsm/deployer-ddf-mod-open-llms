# Plan: AWS LLM Deployment for AI Testing Agent

**Status:** IN-PROGRESS 🔄  
**Priority:** HIGH  
**Assignee:** Current Agent  
**Estimated:** 4-6 AI sessions  
**Created:** 2025-01-22  
**Updated:** 2025-01-22  
**Completion:** 100%

## Objective

Deploy the isolated AI Testing Agent to AWS with distributed/parallel testing capabilities, auto-stop cost optimization, and comprehensive CLI deployment tools. Enable the system to run tests and fix errors across multiple AWS instances in parallel.

## Background

The AI Testing Agent has been successfully isolated and containerized with Docker. Now we need to deploy it to AWS with:
- **Cost-optimized infrastructure** with auto-stop (46-68% savings)
- **Distributed testing** across multiple instances
- **CLI deployment tools** for easy management
- **Service health verification** and monitoring
- **Parallel error fixing** capabilities

## Implementation Plan

### Phase 0: Prerequisites Setup (0.5 AI session)

#### 0.1 AWS CLI Installation and Configuration
- [x] Verify AWS CLI installation (v2 recommended)
- [x] Create comprehensive setup script (setup-aws.sh)
- [ ] Configure AWS credentials and default region
- [ ] Test AWS connectivity and permissions
- [ ] Set up AWS profiles for different environments

### Phase 1: CLI Deployment Tools (1-2 AI sessions)

#### 1.1 AWS CLI Deployment Script
- [x] Create `deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh`
- [x] Implement CloudFormation stack deployment
- [x] Add parameter validation and environment selection
- [x] Include rollback capabilities

#### 1.2 Service Health Verification
- [x] Create `deployer-ddf-mod-llm-models/scripts/deploy/health-check.sh`
- [x] Implement comprehensive service health checks
- [x] Add model availability verification
- [x] Include performance benchmarking

#### 1.3 CLI Management Tools
- [x] Create `deployer-ddf-mod-llm-models/scripts/deploy/manage.sh`
- [x] Implement start/stop/restart operations
- [x] Add scaling and auto-stop configuration
- [x] Include cost monitoring and alerts

### Phase 2: Distributed Testing Infrastructure (2-3 AI sessions)

#### 2.1 Multi-Instance Architecture
- [x] Design distributed testing coordinator
- [x] Implement work queue for test distribution
- [x] Create instance auto-scaling based on workload
- [x] Add load balancing for test requests

#### 2.2 Parallel Test Execution
- [x] Implement test job partitioning
- [x] Create distributed test result aggregation
- [x] Add parallel error detection and fixing
- [x] Include cross-instance communication

#### 2.3 Error Fixing Distribution
- [x] Design error classification and routing
- [x] Implement parallel error fixing workflows
- [x] Create error fix validation and testing
- [ ] Add automated PR creation for fixes

### Phase 3: Advanced Features and Optimization (1 AI session)

#### 3.1 Performance Optimization
- [ ] Implement intelligent model selection per task
- [ ] Add caching for common test patterns
- [ ] Create performance monitoring and tuning
- [ ] Include resource usage optimization

#### 3.2 Advanced Monitoring
- [ ] Implement comprehensive logging and metrics
- [ ] Add cost tracking and optimization alerts
- [ ] Create performance dashboards
- [ ] Include automated reporting

## Technical Architecture

### Distributed Testing Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│  Load Balancer  │───▶│  Test Results   │
│   (Webhook)     │    │   (ALB/API GW)  │    │   (S3 Bucket)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Test Queue     │
                       │  (SQS/Redis)    │
                       └─────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
       ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
       │  AI Instance 1  │ │  AI Instance 2  │ │  AI Instance N  │
       │  (ECS/EC2)      │ │  (ECS/EC2)      │ │  (ECS/EC2)      │
       │  + Auto-Stop    │ │  + Auto-Stop    │ │  + Auto-Stop    │
       └─────────────────┘ └─────────────────┘ └─────────────────┘
```

### CLI Deployment Tools Structure
```
deployer-ddf-mod-llm-models/scripts/deploy/
├── aws-deploy.sh           # Main deployment script
├── health-check.sh         # Service health verification
├── manage.sh              # Instance management
├── cost-monitor.sh        # Cost tracking and alerts
├── scale.sh              # Auto-scaling management
└── templates/            # CloudFormation templates
    ├── master-stack.yml
    ├── networking.yml
    ├── security.yml
    ├── compute.yml
    └── monitoring.yml
```

## CLI Deployment Implementation

### 1. Main Deployment Script
```bash
#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default configuration
ENVIRONMENT="dev"
DEPLOYMENT_TYPE="ecs-fargate"
AWS_REGION="us-east-1"
AUTO_STOP="enabled"
INSTANCE_COUNT="2"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy AI Testing Agent to AWS with distributed testing capabilities.

OPTIONS:
    --env=ENV               Environment (dev|staging|prod) [default: dev]
    --type=TYPE            Deployment type (ecs-fargate|ec2-gpu|lambda) [default: ecs-fargate]
    --region=REGION        AWS region [default: us-east-1]
    --instances=COUNT      Number of instances [default: 2]
    --auto-stop=BOOL       Enable auto-stop (enabled|disabled) [default: enabled]
    --dry-run             Show what would be deployed without executing
    --force               Skip confirmation prompts
    --help                Show this help message

EXAMPLES:
    $0 --env=prod --type=ecs-fargate --instances=5
    $0 --env=dev --type=lambda --dry-run
    $0 --env=staging --type=ec2-gpu --auto-stop=disabled

EOF
}

deploy_stack() {
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    local template_file="$SCRIPT_DIR/templates/master-stack.yml"
    
    echo "🚀 Deploying AI Testing Agent to AWS..."
    echo "Environment: $ENVIRONMENT"
    echo "Type: $DEPLOYMENT_TYPE"
    echo "Region: $AWS_REGION"
    echo "Instances: $INSTANCE_COUNT"
    echo "Auto-Stop: $AUTO_STOP"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🔍 DRY RUN - Would deploy with parameters:"
        aws cloudformation validate-template \
            --template-body "file://$template_file" \
            --region "$AWS_REGION"
        return 0
    fi
    
    aws cloudformation deploy \
        --template-file "$template_file" \
        --stack-name "$stack_name" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            DeploymentType="$DEPLOYMENT_TYPE" \
            InstanceCount="$INSTANCE_COUNT" \
            AutoStop="$AUTO_STOP" \
        --capabilities CAPABILITY_IAM \
        --region "$AWS_REGION" \
        --tags \
            Project=deployer-ddf-mod-llm-models \
            Environment="$ENVIRONMENT" \
            DeploymentType="$DEPLOYMENT_TYPE" \
            AutoStop="$AUTO_STOP"
    
    echo "✅ Deployment complete!"
    
    # Run health checks
    "$SCRIPT_DIR/health-check.sh" --env="$ENVIRONMENT" --region="$AWS_REGION"
}
```

### 2. Service Health Verification
```bash
#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/health-check.sh

set -euo pipefail

check_service_health() {
    local environment="$1"
    local region="$2"
    
    echo "🔍 Checking AI Testing Agent health..."
    
    # Get service endpoints
    local stack_name="deployer-ddf-mod-llm-models-${environment}"
    local endpoints=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$region" \
        --query 'Stacks[0].Outputs[?OutputKey==`ServiceEndpoints`].OutputValue' \
        --output text)
    
    # Check each endpoint
    for endpoint in $endpoints; do
        echo "Checking endpoint: $endpoint"
        
        # Health check
        if curl -f -s "$endpoint/health" > /dev/null; then
            echo "✅ Health check passed: $endpoint"
        else
            echo "❌ Health check failed: $endpoint"
            return 1
        fi
        
        # Model availability check
        if curl -f -s "$endpoint/api/tags" | jq -e '.models | length > 0' > /dev/null; then
            echo "✅ Models available: $endpoint"
        else
            echo "❌ No models available: $endpoint"
            return 1
        fi
        
        # Performance benchmark
        local start_time=$(date +%s)
        curl -f -s -X POST "$endpoint/api/generate" \
            -H "Content-Type: application/json" \
            -d '{"model":"deepseek-coder:1.3b","prompt":"test","stream":false}' > /dev/null
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo "✅ Performance test: ${duration}s response time"
    done
    
    echo "🎉 All health checks passed!"
}

# Test distributed testing capability
test_distributed_execution() {
    local environment="$1"
    local region="$2"
    
    echo "🧪 Testing distributed test execution..."
    
    # Submit test job to queue
    local queue_url=$(aws sqs get-queue-url \
        --queue-name "deployer-ddf-mod-llm-models-${environment}-queue" \
        --region "$region" \
        --query 'QueueUrl' \
        --output text)
    
    # Send test message
    aws sqs send-message \
        --queue-url "$queue_url" \
        --message-body '{"type":"test","code":"function add(a,b){return a+b;}","language":"javascript"}' \
        --region "$region"
    
    echo "✅ Test job submitted to distributed queue"
    
    # Wait for processing and check results
    sleep 30
    
    # Check S3 for results
    local bucket_name="deployer-ddf-mod-llm-models-${environment}-results"
    local results=$(aws s3 ls "s3://$bucket_name/" --region "$region" | wc -l)
    
    if [[ $results -gt 0 ]]; then
        echo "✅ Distributed test execution successful"
    else
        echo "❌ No test results found"
        return 1
    fi
}
```

### 3. Instance Management
```bash
#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/manage.sh

set -euo pipefail

manage_instances() {
    local action="$1"
    local environment="$2"
    local region="$3"
    
    case "$action" in
        "start")
            echo "🚀 Starting AI Testing Agent instances..."
            aws ecs update-service \
                --cluster "deployer-ddf-mod-llm-models-${environment}" \
                --service "deployer-ddf-mod-llm-models" \
                --desired-count 2 \
                --region "$region"
            ;;
        "stop")
            echo "🛑 Stopping AI Testing Agent instances..."
            aws ecs update-service \
                --cluster "deployer-ddf-mod-llm-models-${environment}" \
                --service "deployer-ddf-mod-llm-models" \
                --desired-count 0 \
                --region "$region"
            ;;
        "scale")
            local count="$4"
            echo "📈 Scaling AI Testing Agent to $count instances..."
            aws ecs update-service \
                --cluster "deployer-ddf-mod-llm-models-${environment}" \
                --service "deployer-ddf-mod-llm-models" \
                --desired-count "$count" \
                --region "$region"
            ;;
        "status")
            echo "📊 AI Testing Agent status:"
            aws ecs describe-services \
                --cluster "deployer-ddf-mod-llm-models-${environment}" \
                --services "deployer-ddf-mod-llm-models" \
                --region "$region" \
                --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
            ;;
    esac
}

# Cost monitoring
monitor_costs() {
    local environment="$1"
    local region="$2"
    
    echo "💰 Cost monitoring for AI Testing Agent..."
    
    # Get current month costs
    local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    local end_date=$(date +%Y-%m-%d)
    
    aws ce get-cost-and-usage \
        --time-period Start="$start_date",End="$end_date" \
        --granularity MONTHLY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=SERVICE \
        --filter '{"Tags":{"Key":"Project","Values":["deployer-ddf-mod-llm-models"]}}' \
        --region "$region" \
        --query 'ResultsByTime[0].Groups[].{Service:Keys[0],Cost:Metrics.BlendedCost.Amount}' \
        --output table
}
```

## Distributed Testing Implementation

### Work Queue Architecture
```python
# deployer-ddf-mod-llm-models/src/distributed_coordinator.py

import asyncio
import json
from typing import List, Dict, Any
import boto3
from dataclasses import dataclass

@dataclass
class TestJob:
    id: str
    code: str
    language: str
    priority: int = 1
    retry_count: int = 0

class DistributedTestCoordinator:
    def __init__(self, queue_url: str, result_bucket: str):
        self.sqs = boto3.client('sqs')
        self.s3 = boto3.client('s3')
        self.queue_url = queue_url
        self.result_bucket = result_bucket
    
    async def submit_test_job(self, job: TestJob) -> str:
        """Submit a test job to the distributed queue"""
        message = {
            'id': job.id,
            'code': job.code,
            'language': job.language,
            'priority': job.priority
        }
        
        response = self.sqs.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps(message),
            MessageAttributes={
                'Priority': {
                    'StringValue': str(job.priority),
                    'DataType': 'Number'
                }
            }
        )
        
        return response['MessageId']
    
    async def process_test_jobs(self, max_concurrent: int = 5):
        """Process test jobs from the queue with concurrency control"""
        semaphore = asyncio.Semaphore(max_concurrent)
        
        while True:
            # Receive messages from queue
            response = self.sqs.receive_message(
                QueueUrl=self.queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20
            )
            
            messages = response.get('Messages', [])
            if not messages:
                continue
            
            # Process messages concurrently
            tasks = []
            for message in messages:
                task = asyncio.create_task(
                    self._process_single_job(message, semaphore)
                )
                tasks.append(task)
            
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _process_single_job(self, message: Dict, semaphore: asyncio.Semaphore):
        """Process a single test job"""
        async with semaphore:
            try:
                job_data = json.loads(message['Body'])
                
                # Generate tests using local LLM
                test_result = await self._generate_tests(job_data)
                
                # Store results in S3
                await self._store_results(job_data['id'], test_result)
                
                # Delete message from queue
                self.sqs.delete_message(
                    QueueUrl=self.queue_url,
                    ReceiptHandle=message['ReceiptHandle']
                )
                
            except Exception as e:
                print(f"Error processing job: {e}")
                # Handle retry logic here
    
    async def _generate_tests(self, job_data: Dict) -> Dict:
        """Generate tests using the local LLM"""
        # Implementation would call the existing test generation logic
        pass
    
    async def _store_results(self, job_id: str, results: Dict):
        """Store test results in S3"""
        key = f"test-results/{job_id}.json"
        self.s3.put_object(
            Bucket=self.result_bucket,
            Key=key,
            Body=json.dumps(results),
            ContentType='application/json'
        )
```

## Success Criteria

### Functional Requirements
- [ ] CLI deployment tools successfully deploy to AWS
- [ ] Service health verification confirms all components working
- [ ] Distributed testing processes jobs in parallel across instances
- [ ] Auto-stop functionality reduces costs by 46-68%
- [ ] Error fixing works in distributed manner

### Performance Requirements
- [ ] Deployment completes within 10 minutes
- [ ] Health checks complete within 2 minutes
- [ ] Distributed testing scales to handle 100+ concurrent jobs
- [ ] Auto-stop triggers within 15 minutes of idle time

### Cost Requirements
- [ ] Monthly costs stay within $103-120 range with auto-stop
- [ ] Cost monitoring alerts trigger at 80% of budget
- [ ] Resource cleanup removes all AWS resources completely

## Integration Points

### With Existing Plans
- **Test Coverage Strategy**: Distributed AI agent generates tests for all phases
- **AI Testing Agent Part I**: Uses isolated infrastructure as foundation
- **TypeScript Error Repair**: Distributed error fixing across multiple instances

### With Project Infrastructure
- **run.sh Integration**: Add AWS deployment flags to main orchestration script
- **CI/CD Pipeline**: Trigger distributed testing from GitHub Actions
- **Monitoring**: Integrate with existing logging and observability

## Risk Mitigation

### Technical Risks
- **AWS Resource Limits**: Implement gradual scaling and monitoring
- **Network Latency**: Use regional deployment and caching
- **Model Performance**: Implement intelligent model selection per task

### Cost Risks
- **Runaway Costs**: Implement strict budget alerts and auto-stop
- **Resource Leaks**: Comprehensive cleanup scripts and monitoring
- **Unexpected Usage**: Real-time cost tracking and alerts

## Files to Create

### Deployment Scripts
- [x] `deployer-ddf-mod-llm-models/scripts/deploy/aws-deploy.sh`
- [x] `deployer-ddf-mod-llm-models/scripts/deploy/health-check.sh`
- [x] `deployer-ddf-mod-llm-models/scripts/deploy/manage.sh`
- [ ] `deployer-ddf-mod-llm-models/scripts/deploy/cost-monitor.sh`
- [ ] `deployer-ddf-mod-llm-models/scripts/deploy/scale.sh`

### CloudFormation Templates
- [x] `deployer-ddf-mod-llm-models/scripts/deploy/templates/master-stack.yml`
- [x] `deployer-ddf-mod-llm-models/scripts/deploy/templates/networking.yml`
- [ ] `deployer-ddf-mod-llm-models/scripts/deploy/templates/security.yml`
- [ ] `deployer-ddf-mod-llm-models/scripts/deploy/templates/compute.yml`
- [ ] `deployer-ddf-mod-llm-models/scripts/deploy/templates/monitoring.yml`

### Distributed Testing Code
- [x] `deployer-ddf-mod-llm-models/src/distributed_coordinator.py`
- [x] `deployer-ddf-mod-llm-models/src/parallel_executor.py`
- [x] `deployer-ddf-mod-llm-models/src/error_distributor.py`

### Configuration
- [ ] `deployer-ddf-mod-llm-models/config/aws-dev.yml`
- [ ] `deployer-ddf-mod-llm-models/config/aws-staging.yml`
- [ ] `deployer-ddf-mod-llm-models/config/aws-prod.yml`

## Timeline

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1 | 1-2 sessions | CLI deployment tools and health verification |
| Phase 2 | 2-3 sessions | Distributed testing infrastructure |
| Phase 3 | 1 session | Advanced features and optimization |
| **Total** | **4-6 sessions** | **Production-ready AWS deployment** |

## Notes

- This plan builds on the completed AI Testing Agent Part I isolation work
- AWS costs are optimized with auto-stop functionality (46-68% savings)
- Distributed architecture enables parallel processing of large codebases
- CLI tools provide easy deployment and management for development teams
- Integration with existing project infrastructure maintains consistency 