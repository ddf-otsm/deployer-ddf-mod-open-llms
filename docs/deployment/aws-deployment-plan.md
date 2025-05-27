# AWS Deployment Plan - AI Testing Agent

**Document Version:** 1.0  
**Created:** 2025-01-22  
**Updated:** 2025-01-22  
**Status:** DRAFT

## 🎯 Executive Summary

This document outlines three deployment strategies for the AI Testing Agent on AWS, with detailed cost estimates, performance characteristics, and implementation timelines. The recommended approach is **ECS Fargate** for most use cases, providing the best balance of cost, performance, and operational simplicity.

## 📊 Deployment Options Comparison

| Criteria | ECS Fargate | EC2 + GPU | Lambda + EFS |
|----------|-------------|-----------|--------------|
| **Monthly Cost** | $50-150 | $200-500 | $20-80 |
| **Setup Complexity** | Medium | High | Low |
| **Performance** | Good | Excellent | Variable |
| **Scalability** | Auto-scale | Manual | Auto-scale |
| **Cold Start** | ~30s | None | ~60-120s |
| **Maintenance** | Low | High | Very Low |
| **GPU Support** | No | Yes | No |
| **Recommended For** | Production | High-volume | Development |

## 🏗️ Option 1: ECS Fargate (Recommended)

### Architecture Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│   ECS Fargate   │───▶│   Test Results  │
│   (Webhook)     │    │   AI Agent      │    │   (S3 Bucket)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   EFS Storage   │
                       │  (Model Cache)  │
                       └─────────────────┘
```

### Infrastructure Components

#### ECS Cluster Configuration
```yaml
# ecs-cluster.yml
Resources:
  AITestingCluster:
    Type: AWS::ECS::Cluster
    Properties:
      ClusterName: deployer-ddf-mod-llm-models
      CapacityProviders:
        - FARGATE
        - FARGATE_SPOT
      DefaultCapacityProviderStrategy:
        - CapacityProvider: FARGATE_SPOT
          Weight: 70
        - CapacityProvider: FARGATE
          Weight: 30
```

#### Task Definition
```yaml
# task-definition.yml
TaskDefinition:
  Family: deployer-ddf-mod-llm-models
  NetworkMode: awsvpc
  RequiresCompatibilities:
    - FARGATE
  Cpu: 4096  # 4 vCPU
  Memory: 16384  # 16 GB
  Containers:
    - Name: ollama-service
      Image: ghcr.io/ollama/ollama:latest
      Memory: 8192
      PortMappings:
        - ContainerPort: 11434
      MountPoints:
        - SourceVolume: model-cache
          ContainerPath: /root/.ollama
    - Name: ai-test-generator
      Image: your-account.dkr.ecr.region.amazonaws.com/deployer-ddf-mod-llm-models:latest
      Memory: 8192
      Environment:
        - Name: OLLAMA_HOST
          Value: localhost:11434
        - Name: AWS_REGION
          Value: !Ref AWS::Region
  Volumes:
    - Name: model-cache
      EFSVolumeConfiguration:
        FileSystemId: !Ref ModelCacheEFS
```

### Cost Breakdown (Monthly)

| Component | Configuration | Cost |
|-----------|---------------|------|
| **ECS Fargate** | 4 vCPU, 16GB RAM, 50% utilization | $85-120 |
| **EFS Storage** | 20GB model cache | $6 |
| **Application Load Balancer** | Standard ALB | $16 |
| **CloudWatch Logs** | 10GB/month | $5 |
| **ECR Repository** | 5GB container images | $0.50 |
| **Data Transfer** | 100GB/month | $9 |
| **NAT Gateway** | Single AZ | $32 |
| **Total** | | **$153.50/month** |

### Performance Characteristics
- **Test Generation Speed**: 15-20 tests/minute
- **Cold Start Time**: ~30 seconds
- **Concurrent Requests**: Up to 10 parallel test generations
- **Model Loading Time**: ~2 minutes (cached after first run)

### Implementation Timeline
- **Week 1**: Infrastructure setup, ECR repository, EFS configuration
- **Week 2**: Container optimization, ECS task definition, ALB setup
- **Week 3**: CI/CD pipeline integration, monitoring setup
- **Week 4**: Testing, optimization, documentation

---

## 🚀 Option 2: EC2 with GPU (High Performance)

### Architecture Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│   EC2 Instance  │───▶│   Test Results  │
│   (Webhook)     │    │   (GPU-enabled) │    │   (S3 Bucket)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   EBS Storage   │
                       │  (Model Cache)  │
                       └─────────────────┘
```

### Infrastructure Components

#### EC2 Instance Configuration
```yaml
# ec2-instance.yml
Resources:
  AITestingInstance:
    Type: AWS::EC2::Instance
    Properties:
      InstanceType: g4dn.xlarge  # 4 vCPU, 16GB RAM, T4 GPU
      ImageId: ami-0abcdef1234567890  # Deep Learning AMI
      SecurityGroupIds:
        - !Ref AITestingSecurityGroup
      IamInstanceProfile: !Ref AITestingInstanceProfile
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          # Install Docker and Ollama
          curl -fsSL https://ollama.ai/install.sh | sh
          systemctl enable ollama
          systemctl start ollama
          
          # Pull required models
          ollama pull deepseek-coder:6.7b
          ollama pull deepseek-coder:1.3b
```

#### Auto Scaling Group
```yaml
AutoScalingGroup:
  Type: AWS::AutoScaling::AutoScalingGroup
  Properties:
    MinSize: 0
    MaxSize: 3
    DesiredCapacity: 1
    LaunchTemplate:
      LaunchTemplateId: !Ref LaunchTemplate
      Version: !GetAtt LaunchTemplate.LatestVersionNumber
    TargetGroupARNs:
      - !Ref TargetGroup
```

### Cost Breakdown (Monthly)

| Component | Configuration | Cost |
|-----------|---------------|------|
| **EC2 g4dn.xlarge** | 50% utilization, On-Demand | $280 |
| **EBS Storage** | 100GB gp3 | $8 |
| **Application Load Balancer** | Standard ALB | $16 |
| **CloudWatch Monitoring** | Detailed monitoring | $10 |
| **Data Transfer** | 200GB/month | $18 |
| **Elastic IP** | Single static IP | $3.65 |
| **Total** | | **$335.65/month** |

### Performance Characteristics
- **Test Generation Speed**: 40-60 tests/minute
- **Cold Start Time**: None (always warm)
- **Concurrent Requests**: Up to 20 parallel test generations
- **Model Loading Time**: ~30 seconds (GPU acceleration)

### Implementation Timeline
- **Week 1**: EC2 setup, GPU drivers, Ollama installation
- **Week 2**: Auto Scaling Group, Load Balancer configuration
- **Week 3**: Monitoring, alerting, backup strategies
- **Week 4**: Performance tuning, cost optimization

---

## ⚡ Option 3: Lambda + EFS (Serverless)

### Architecture Overview
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│  Lambda Function│───▶│   Test Results  │
│   (Webhook)     │    │  (Container)    │    │   (S3 Bucket)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   EFS Storage   │
                       │  (Model Cache)  │
                       └─────────────────┘
```

### Infrastructure Components

#### Lambda Function Configuration
```yaml
# lambda-function.yml
Resources:
  AITestingFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: deployer-ddf-mod-llm-models
      Runtime: provided.al2
      Code:
        ImageUri: your-account.dkr.ecr.region.amazonaws.com/ai-testing-lambda:latest
      PackageType: Image
      MemorySize: 10240  # 10GB
      Timeout: 900  # 15 minutes
      FileSystemConfigs:
        - Arn: !GetAtt ModelCacheAccessPoint.Arn
          LocalMountPath: /mnt/models
      VpcConfig:
        SecurityGroupIds:
          - !Ref LambdaSecurityGroup
        SubnetIds:
          - !Ref PrivateSubnet1
          - !Ref PrivateSubnet2
```

#### EFS Configuration
```yaml
ModelCacheEFS:
  Type: AWS::EFS::FileSystem
  Properties:
    PerformanceMode: generalPurpose
    ThroughputMode: provisioned
    ProvisionedThroughputInMibps: 100
    
ModelCacheAccessPoint:
  Type: AWS::EFS::AccessPoint
  Properties:
    FileSystemId: !Ref ModelCacheEFS
    PosixUser:
      Uid: 1000
      Gid: 1000
    RootDirectory:
      Path: /models
      CreationInfo:
        OwnerUid: 1000
        OwnerGid: 1000
        Permissions: 755
```

### Cost Breakdown (Monthly)

| Component | Configuration | Cost |
|-----------|---------------|------|
| **Lambda Execution** | 1000 invocations, 5min avg | $45 |
| **EFS Storage** | 20GB model cache | $6 |
| **EFS Throughput** | 100 MiB/s provisioned | $60 |
| **VPC NAT Gateway** | Single AZ | $32 |
| **CloudWatch Logs** | 5GB/month | $2.50 |
| **API Gateway** | 1000 requests | $3.50 |
| **Total** | | **$149/month** |

### Performance Characteristics
- **Test Generation Speed**: 10-15 tests/minute (after warm-up)
- **Cold Start Time**: 60-120 seconds
- **Concurrent Requests**: Up to 1000 (with provisioned concurrency)
- **Model Loading Time**: ~3-5 minutes (EFS latency)

### Implementation Timeline
- **Week 1**: Lambda container image, EFS setup
- **Week 2**: VPC configuration, API Gateway integration
- **Week 3**: Provisioned concurrency optimization
- **Week 4**: Cost optimization, monitoring setup

---

## 🔧 Shared Infrastructure Components

### Networking
```yaml
# vpc.yml
VPC:
  Type: AWS::EC2::VPC
  Properties:
    CidrBlock: 10.0.0.0/16
    EnableDnsHostnames: true
    EnableDnsSupport: true

PrivateSubnet1:
  Type: AWS::EC2::Subnet
  Properties:
    VpcId: !Ref VPC
    CidrBlock: 10.0.1.0/24
    AvailabilityZone: !Select [0, !GetAZs '']

PrivateSubnet2:
  Type: AWS::EC2::Subnet
  Properties:
    VpcId: !Ref VPC
    CidrBlock: 10.0.2.0/24
    AvailabilityZone: !Select [1, !GetAZs '']
```

### Security
```yaml
# security.yml
AITestingSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: Security group for AI Testing Agent
    VpcId: !Ref VPC
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 11434
        ToPort: 11434
        SourceSecurityGroupId: !Ref ALBSecurityGroup
      - IpProtocol: tcp
        FromPort: 8080
        ToPort: 8080
        SourceSecurityGroupId: !Ref ALBSecurityGroup
```

### Monitoring & Alerting
```yaml
# monitoring.yml
TestGenerationAlarm:
  Type: AWS::CloudWatch::Alarm
  Properties:
    AlarmName: AI-Testing-High-Error-Rate
    MetricName: ErrorRate
    Namespace: AI/Testing
    Statistic: Average
    Period: 300
    EvaluationPeriods: 2
    Threshold: 10
    ComparisonOperator: GreaterThanThreshold
    AlarmActions:
      - !Ref SNSTopic
```

---

## 💰 Cost Optimization Strategies

### 1. Spot Instances (EC2 Option)
- **Savings**: 50-70% cost reduction
- **Risk**: Potential interruption
- **Mitigation**: Auto Scaling Group with mixed instance types

### 2. Reserved Instances (EC2 Option)
- **Savings**: 30-60% for 1-3 year commitments
- **Best For**: Predictable workloads
- **Recommendation**: Start with On-Demand, convert after usage patterns are established

### 3. Fargate Spot (ECS Option)
- **Savings**: 50-70% cost reduction
- **Risk**: Task interruption
- **Mitigation**: Mixed capacity provider strategy

### 4. Provisioned Concurrency Optimization (Lambda Option)
- **Strategy**: Use scheduled scaling for predictable traffic
- **Savings**: 20-40% on Lambda costs
- **Implementation**: CloudWatch Events + Lambda scaling

---

## 🚀 Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
1. **Infrastructure Setup**
   - VPC and networking configuration
   - Security groups and IAM roles
   - ECR repository for container images

2. **Container Optimization**
   - Multi-stage Docker builds
   - Model caching strategies
   - Health check implementation

### Phase 2: Core Deployment (Week 3-4)
1. **Service Deployment**
   - ECS service or EC2 Auto Scaling Group
   - Load balancer configuration
   - EFS or EBS storage setup

2. **CI/CD Integration**
   - GitHub Actions workflow
   - Automated deployments
   - Rollback strategies

### Phase 3: Optimization (Week 5-6)
1. **Performance Tuning**
   - Model loading optimization
   - Concurrent request handling
   - Memory and CPU optimization

2. **Monitoring & Alerting**
   - CloudWatch dashboards
   - Custom metrics
   - Slack/email notifications

### Phase 4: Production Readiness (Week 7-8)
1. **Security Hardening**
   - Network security review
   - IAM permission audit
   - Secrets management

2. **Documentation & Training**
   - Operational runbooks
   - Troubleshooting guides
   - Team training sessions

---

## 📊 Decision Matrix

| Factor | Weight | ECS Fargate | EC2 + GPU | Lambda + EFS |
|--------|--------|-------------|-----------|--------------|
| **Cost** | 25% | 7/10 | 4/10 | 8/10 |
| **Performance** | 30% | 7/10 | 10/10 | 5/10 |
| **Scalability** | 20% | 9/10 | 6/10 | 10/10 |
| **Maintenance** | 15% | 8/10 | 4/10 | 9/10 |
| **Reliability** | 10% | 8/10 | 7/10 | 6/10 |
| **Total Score** | | **7.4/10** | **6.7/10** | **7.1/10** |

## 🎯 Recommendation

**Primary Choice: ECS Fargate**
- Best balance of cost, performance, and operational simplicity
- Suitable for most production workloads
- Easy to scale and maintain

**Alternative: EC2 + GPU** (for high-volume scenarios)
- Choose when test generation speed is critical
- Suitable for teams with >100 PRs/day
- Requires more operational expertise

**Development/Testing: Lambda + EFS**
- Ideal for proof-of-concept and development environments
- Pay-per-use model for irregular workloads
- Lowest operational overhead

---

## 📋 Next Steps

1. **Immediate Actions**
   - Review and approve deployment strategy
   - Set up AWS account and billing alerts
   - Create initial CloudFormation templates

2. **Week 1 Deliverables**
   - VPC and networking setup
   - ECR repository configuration
   - Initial container builds

3. **Success Metrics**
   - Deployment time < 2 weeks
   - Monthly cost within budget
   - Test generation speed > 15 tests/minute
   - 99.5% uptime SLA

---

**Document Owner:** DevOps Team  
**Review Cycle:** Monthly  
**Last Updated:** 2025-01-22 