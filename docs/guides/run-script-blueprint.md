# Run Script Blueprint - Dadosfera v2.1 Implementation

*Last Updated: 2025-05-27*

## Overview

The `run.sh` script serves as the **single entry point** for all project operations, following Dadosfera Blueprint v2.1 standards. This document outlines the implementation plan and current status.

## Current Implementation Status

### ✅ Completed Features

1. **Centralized Entry Point**
   - Single `run.sh` at project root
   - All operations routed through this script
   - No duplicate run/start/main scripts

2. **Required Flag Support**
   - `--env=<dev|staging|prd>` - Environment selection
   - `--platform=<cursor|replit|aws|dadosfera|docker>` - Platform targeting
   - `--setup` - One-time initialization
   - `--turbo` / `--fast` / `--full` - Runtime depth control

3. **Configuration Integration**
   - Reads from `config/*.yml` files
   - Environment variable precedence
   - Platform-specific config loading
   - YAML-based configuration system

4. **Port Management**
   - Dynamic port resolution from config
   - macOS-friendly ports (5001+)
   - Port conflict detection and cleanup

### 🚧 In Progress Features

1. **Enhanced Logging**
   - Structured JSON logging to `logs/`
   - Console output for CLI/CI
   - Dry-run output capture

2. **Platform Orchestration**
   - Multi-language project coordination
   - Service dependency management
   - Health check integration

### 📋 Planned Features

1. **Advanced Flags**
   - `--dry-run` - Preview mode with file logging
   - `--tolerant` - Suppress non-blocking warnings
   - `--verbose` / `--quiet` - Verbosity control
   - `--debug` - Debug output and logging

2. **Deployment Automation**
   - AWS CloudFormation integration
   - Dadosfera Orchest pipeline support
   - Docker multi-stage builds
   - Kubernetes manifest generation

## Blueprint Compliance Matrix

| Requirement | Status | Implementation | Notes |
|-------------|--------|----------------|-------|
| Single Entry Point | ✅ | `run.sh` at root | No duplicate scripts |
| Required Flags | ✅ | `--env`, `--platform` | Fully implemented |
| Optional Flags | 🚧 | `--setup`, `--fast`, `--full` | Core flags done |
| Config Integration | ✅ | YAML-based system | Environment precedence |
| Platform Support | 🚧 | 5 platforms planned | 3 platforms active |
| Dry-Run Support | 📋 | Planned | File logging required |
| Multi-Language | 🚧 | Node.js + Python | Orchestration needed |
| No Symlinks | ✅ | Physical file moves | Blueprint compliant |
| Logging Standards | 🚧 | Basic implementation | JSON structure needed |
| Error Handling | 📋 | Planned | Retry logic needed |

## Architecture Design

### Script Structure
```bash
run.sh
├── Argument Parsing
├── Environment Loading
├── Platform Detection
├── Configuration Validation
├── Service Orchestration
├── Health Checks
└── Cleanup & Logging
```

### Configuration Flow
```
config/
├── {env}.yml           # Base environment config
├── platform-env/
│   └── {platform}/
│       └── {env}/      # Platform-specific overrides
└── deployments/
    └── may_2025/       # Deployment-specific configs
```

### Platform Support Matrix

| Platform | Status | Entry Command | Notes |
|----------|--------|---------------|-------|
| **Cursor** | ✅ | `bash run.sh --env=dev --platform=cursor --fast` | Local development |
| **Replit** | ✅ | `bash run.sh --env=dev --platform=replit --fast` | Cloud IDE |
| **AWS** | 🚧 | `bash run.sh --env=prd --platform=aws --full` | ECS deployment |
| **Dadosfera** | 📋 | `bash run.sh --env=prd --platform=dadosfera --full` | Orchest pipeline |
| **Docker** | 📋 | `bash run.sh --env=staging --platform=docker --full` | Containerized |

## Implementation Plan

### Phase 1: Core Infrastructure ✅
- [x] Single entry point script
- [x] Basic flag parsing
- [x] Environment configuration loading
- [x] Port management system
- [x] Platform detection logic

### Phase 2: Enhanced Operations 🚧
- [ ] Dry-run mode with file logging
- [ ] Comprehensive error handling
- [ ] Service dependency management
- [ ] Health check integration
- [ ] Structured logging system

### Phase 3: Platform Integration 📋
- [ ] AWS CloudFormation automation
- [ ] Dadosfera Orchest pipeline
- [ ] Docker multi-stage builds
- [ ] Kubernetes deployment
- [ ] CI/CD pipeline integration

### Phase 4: Advanced Features 📋
- [ ] Mutation testing integration
- [ ] Performance monitoring
- [ ] Security scanning
- [ ] Automated rollback
- [ ] Multi-region deployment

## Usage Examples

### Development Workflow
```bash
# Initial setup
bash run.sh --env=dev --platform=cursor --setup

# Fast development iteration
bash run.sh --env=dev --platform=cursor --fast --verbose

# Full development pipeline
bash run.sh --env=dev --platform=cursor --full --debug
```

### Production Deployment
```bash
# Preview deployment changes
bash run.sh --env=prd --platform=aws --full --dry-run

# Execute production deployment
bash run.sh --env=prd --platform=aws --full --verbose

# Quick health check
bash run.sh --env=prd --platform=aws --turbo
```

### Platform Migration
```bash
# Test on Replit
bash run.sh --env=staging --platform=replit --full

# Deploy to AWS
bash run.sh --env=staging --platform=aws --full

# Migrate to Dadosfera
bash run.sh --env=staging --platform=dadosfera --full
```

## Error Handling Strategy

### Retry Logic
- Network operations: 3 retries with exponential backoff
- Service startup: 5 retries with health checks
- Configuration loading: Immediate fail with clear error

### Logging Levels
- `ERROR`: Critical failures requiring intervention
- `WARN`: Non-blocking issues with fallbacks
- `INFO`: Normal operation status
- `DEBUG`: Detailed execution information

### Graceful Degradation
- Missing optional dependencies: Continue with warnings
- Network timeouts: Retry with backoff
- Configuration errors: Fail fast with clear messages

## Security Considerations

### Secrets Management
- Environment variables for sensitive data
- Platform-specific secret stores
- No secrets in configuration files
- Audit logging for secret access

### Access Control
- Platform-specific authentication
- Role-based deployment permissions
- Secure credential handling
- Network security policies

## Performance Optimization

### Execution Speed
- `--turbo`: Skip all optional operations
- `--fast`: Skip tests but run core logic
- `--full`: Complete pipeline with all checks

### Resource Management
- Parallel service startup where possible
- Efficient dependency resolution
- Memory-conscious operations
- Cleanup of temporary resources

## Monitoring & Observability

### Health Checks
- Application health endpoints
- Service dependency checks
- Platform-specific monitoring
- Automated alerting

### Metrics Collection
- Execution time tracking
- Resource utilization
- Error rate monitoring
- Performance benchmarks

## Future Enhancements

### Planned Improvements
1. **AI-Powered Optimization**: LLM-based configuration tuning
2. **Predictive Scaling**: Auto-scaling based on usage patterns
3. **Multi-Cloud Support**: Azure and GCP platform support
4. **Advanced Testing**: Chaos engineering integration
5. **Security Automation**: Automated vulnerability scanning

### Community Features
1. **Plugin System**: Extensible platform support
2. **Template Library**: Reusable configuration templates
3. **Best Practices**: Automated compliance checking
4. **Documentation**: Auto-generated platform guides

---

*This blueprint follows Dadosfera v2.1 standards for enterprise deployment automation.* 