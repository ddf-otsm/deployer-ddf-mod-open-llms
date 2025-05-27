# Security Plan for AWS Deployment
## Deployer DDF Mod LLM Models

**Version:** 1.0  
**Last Updated:** 2025-01-26  
**Owner:** Dadosfera Security Team

---

## 1. Executive Summary

This document outlines the security plan for the `deployer-ddf-mod-llm-models` AWS deployment, addressing:
- AWS resource security and internet exposure
- Secrets and credentials management
- Network security architecture
- Access control and authentication
- Monitoring and incident response

### Security Status Overview

| Component | Security Level | Internet Exposed | Risk Level |
|-----------|---------------|------------------|------------|
| Load Balancer | ✅ Secured | ⚠️ Yes (HTTPS only) | Medium |
| ECS Tasks | ✅ Private | ❌ No | Low |
| S3 Buckets | ✅ Private | ❌ No | Low |
| RDS/Database | ✅ Private | ❌ No | Low |
| API Gateway | ✅ Secured | ⚠️ Yes (Auth required) | Medium |

---

## 2. AWS Resource Security Analysis

### 2.1 Internet-Facing Resources

#### Application Load Balancer (ALB)
- **Status:** Internet-facing (required for API access)
- **Security Measures:**
  - HTTPS only (port 443)
  - SSL/TLS termination with valid certificates
  - Security groups restrict access to specific ports
  - WAF (Web Application Firewall) enabled
  - Rate limiting configured

#### API Gateway (if used)
- **Status:** Internet-facing (required for API access)
- **Security Measures:**
  - Authentication required (Keycloak/JWT)
  - API key validation
  - Rate limiting per client
  - Request/response logging

### 2.2 Private Resources

#### ECS Tasks/Containers
- **Status:** Private subnet only
- **Access:** Only through load balancer
- **Security:** No direct internet access

#### S3 Buckets
- **Status:** Private
- **Access:** IAM roles only
- **Encryption:** AES-256 or KMS

#### Database (RDS/Aurora)
- **Status:** Private subnet
- **Access:** VPC internal only
- **Encryption:** At rest and in transit

---

## 3. Network Security Architecture

### 3.1 VPC Configuration

```
Internet Gateway
       |
   Public Subnet (ALB only)
       |
   Private Subnet (ECS, RDS)
       |
   NAT Gateway (outbound only)
```

### 3.2 Security Groups

#### ALB Security Group
```yaml
Inbound:
  - Port 443 (HTTPS): 0.0.0.0/0
  - Port 80 (HTTP): 0.0.0.0/0 (redirect to HTTPS)
Outbound:
  - All traffic to ECS security group
```

#### ECS Security Group
```yaml
Inbound:
  - Port 8080: ALB security group only
Outbound:
  - Port 443: 0.0.0.0/0 (for external API calls)
  - Port 5432: RDS security group (if using PostgreSQL)
```

#### RDS Security Group
```yaml
Inbound:
  - Port 5432: ECS security group only
Outbound:
  - None
```

---

## 4. Secrets Management

### 4.1 Directory Structure

```
deployer-ddf-mod-llm-models/
├── secrets/                    # Git-ignored, never committed
│   ├── certificates/
│   ├── private_keys/
│   └── service_accounts/
├── api-tokens/                 # Git-ignored, never committed
│   ├── dev/
│   ├── staging/
│   └── prod/
├── aws-credentials/            # Git-ignored, never committed
│   ├── dev/
│   ├── staging/
│   └── prod/
└── config/
    ├── *.template.yml          # Templates with placeholders
    └── *.yml                   # Actual configs (git-ignored)
```

### 4.2 Secret Types and Storage

| Secret Type | Storage Method | Access Method |
|-------------|---------------|---------------|
| AWS Credentials | AWS IAM Roles | Instance profiles |
| API Keys | AWS Secrets Manager | Environment variables |
| Database Passwords | AWS Secrets Manager | Connection strings |
| SSL Certificates | AWS Certificate Manager | ALB configuration |
| JWT Signing Keys | AWS Secrets Manager | Application config |

### 4.3 Secret Rotation

- **API Keys:** 30-day rotation
- **Database Passwords:** 90-day rotation
- **JWT Signing Keys:** 180-day rotation
- **SSL Certificates:** Auto-renewal via ACM

---

## 5. Authentication and Authorization

### 5.1 Authentication Methods

#### Primary: Keycloak Integration
- **Server:** External Keycloak instance
- **Protocol:** OAuth 2.0 / OpenID Connect
- **Token Type:** JWT
- **Validation:** Signature, audience, issuer verification

#### Fallback: API Key Authentication
- **Format:** 32-character hex string
- **Header:** `X-API-Key`
- **Validation:** SHA-256 hash comparison

### 5.2 Authorization Model

#### Role-Based Access Control (RBAC)

```yaml
Roles:
  admin:
    permissions: ["llm:*", "config:*", "users:*", "monitoring:*"]
  user:
    permissions: ["llm:query", "llm:status", "monitoring:read"]
  readonly:
    permissions: ["llm:status", "monitoring:read"]
```

### 5.3 Session Management

- **Storage:** Redis (encrypted)
- **Timeout:** 1 hour (production), 2 hours (development)
- **Refresh:** Automatic with 5-minute threshold
- **Concurrent Sessions:** Maximum 5 per user

---

## 6. Data Protection

### 6.1 Encryption

#### Data at Rest
- **S3 Buckets:** AES-256 encryption
- **EBS Volumes:** Encrypted with AWS KMS
- **RDS:** Encryption enabled
- **Logs:** CloudWatch Logs encryption

#### Data in Transit
- **External:** TLS 1.2+ for all connections
- **Internal:** TLS for database connections
- **API:** HTTPS only, no HTTP allowed

### 6.2 Data Classification

| Data Type | Classification | Retention | Backup |
|-----------|---------------|-----------|---------|
| API Logs | Internal | 90 days | Yes |
| User Data | Confidential | 1 year | Yes |
| Model Outputs | Internal | 30 days | No |
| System Logs | Internal | 30 days | No |

---

## 7. Monitoring and Alerting

### 7.1 Security Monitoring

#### CloudWatch Alarms
- Failed authentication attempts (>10 in 5 minutes)
- Unusual API usage patterns
- High error rates (>5% in 5 minutes)
- Resource utilization spikes

#### AWS CloudTrail
- All API calls logged
- Log file integrity validation
- Multi-region logging enabled

### 7.2 Security Alerts

#### Critical Alerts (Immediate Response)
- Multiple failed login attempts
- Unauthorized API access attempts
- Resource configuration changes
- Security group modifications

#### Warning Alerts (24-hour Response)
- High resource utilization
- Certificate expiration warnings
- Unusual traffic patterns

---

## 8. Incident Response

### 8.1 Response Team

| Role | Contact | Responsibility |
|------|---------|---------------|
| Security Lead | ti@dadosfera.ai | Overall incident coordination |
| DevOps Lead | ti@dadosfera.ai | Infrastructure response |
| Development Lead | ti@dadosfera.ai | Application-level response |

### 8.2 Response Procedures

#### Security Incident Response
1. **Detection:** Automated alerts or manual discovery
2. **Assessment:** Determine scope and impact
3. **Containment:** Isolate affected resources
4. **Eradication:** Remove threat and vulnerabilities
5. **Recovery:** Restore normal operations
6. **Lessons Learned:** Document and improve

#### Emergency Contacts
- **AWS Support:** Enterprise support case
- **Security Team:** ti@dadosfera.ai
- **On-call Engineer:** [To be defined]

---

## 9. Compliance and Auditing

### 9.1 Audit Logging

#### Events Logged
- Authentication success/failure
- Authorization failures
- API access attempts
- Configuration changes
- Data access patterns

#### Log Retention
- **Security Logs:** 1 year
- **Audit Logs:** 2 years
- **Application Logs:** 90 days

### 9.2 Compliance Requirements

#### Data Protection
- GDPR compliance for EU users
- Data minimization principles
- Right to deletion support

#### Security Standards
- AWS Well-Architected Framework
- OWASP Top 10 mitigation
- Regular security assessments

---

## 10. Security Checklist

### 10.1 Pre-Deployment Security Checklist

- [ ] All secrets stored in AWS Secrets Manager
- [ ] No hardcoded credentials in code
- [ ] Security groups follow least privilege
- [ ] Encryption enabled for all data stores
- [ ] SSL/TLS certificates configured
- [ ] WAF rules configured
- [ ] CloudTrail logging enabled
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery tested

### 10.2 Post-Deployment Security Checklist

- [ ] Penetration testing completed
- [ ] Security scanning performed
- [ ] Access controls validated
- [ ] Monitoring alerts tested
- [ ] Incident response procedures tested
- [ ] Documentation updated
- [ ] Team training completed

---

## 11. Security Maintenance

### 11.1 Regular Security Tasks

#### Weekly
- Review security alerts and logs
- Check for security updates
- Validate backup integrity

#### Monthly
- Security group review
- Access control audit
- Certificate expiration check
- Vulnerability scanning

#### Quarterly
- Penetration testing
- Security policy review
- Incident response drill
- Security training update

### 11.2 Security Updates

#### Patch Management
- **Critical:** Within 24 hours
- **High:** Within 1 week
- **Medium:** Within 1 month
- **Low:** Next maintenance window

---

## 12. Contact Information

### Security Team
- **Primary Contact:** ti@dadosfera.ai
- **Emergency Contact:** ti@dadosfera.ai
- **AWS Account Owner:** ti@dadosfera.ai

### External Contacts
- **AWS Support:** Enterprise support portal
- **Security Vendor:** [To be defined]
- **Incident Response:** [To be defined]

---

## 13. Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-26 | AI Assistant | Initial security plan |

**Next Review Date:** 2025-04-26  
**Review Frequency:** Quarterly 