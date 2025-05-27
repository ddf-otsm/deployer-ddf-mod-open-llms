# Deployer DDF Mod Open LLMs - Documentation Index

*Last Updated: 2025-05-27*

## Project Overview

The **Deployer DDF Mod Open LLMs** is a scalable deployment platform for open-source Large Language Models (LLMs) with automated testing and monitoring capabilities. This project follows the Dadosfera Blueprint v2.1 for enterprise-grade deployment patterns.

## Quick Start

### Local Development
```bash
# Clone and setup
git clone <repository-url>
cd deployer-ddf-mod-open-llms

# Run with default development settings
bash run.sh --env=dev --platform=cursor --fast

# Access the application
open http://localhost:5001
open http://localhost:5001/api-docs  # Swagger UI
```

### Production Deployment
```bash
# Deploy to AWS production
bash run.sh --env=prd --platform=aws --full

# Deploy to Dadosfera Orchest
bash run.sh --env=prd --platform=dadosfera --full
```

## Architecture

### Core Components
- **API Server**: Express.js with TypeScript (Port 5001+)
- **LLM Integration**: Hugging Face Transformers
- **Testing Framework**: Automated test generation and execution
- **Monitoring**: Health checks and status endpoints
- **Documentation**: Interactive Swagger/OpenAPI 3.0

### Supported Platforms
- **Local Development**: Cursor, Replit
- **Cloud Deployment**: AWS (ECS, ALB, S3, SQS)
- **Data Platform**: Dadosfera Orchest

## Documentation Structure

### Setup & Configuration
- [`setup/installation.md`](setup/installation.md) - Installation and dependencies
- [`setup/configuration.md`](setup/configuration.md) - Environment configuration
- [`setup/troubleshooting.md`](setup/troubleshooting.md) - Common issues and solutions

### Deployment Guides
- [`deploy/local-development.md`](deploy/local-development.md) - Local setup and development
- [`deploy/aws-deployment.md`](deploy/aws-deployment.md) - AWS ECS deployment
- [`deploy/dadosfera-deployment.md`](deploy/dadosfera-deployment.md) - Dadosfera platform deployment

### Guides & References
- [`guides/api-reference.md`](guides/api-reference.md) - API endpoints and usage
- [`guides/aws-resources-reference.md`](guides/aws-resources-reference.md) - AWS resource documentation
- [`guides/testing-framework.md`](guides/testing-framework.md) - Testing capabilities
- [`guides/monitoring.md`](guides/monitoring.md) - Health checks and observability

### Development
- [`../CONTRIBUTING.md`](../CONTRIBUTING.md) - Contribution guidelines
- [`todos/plans/`](todos/plans/) - Project roadmap and task planning

## Configuration Management

### Environment Files
```
config/
├── dev.yml              # Development environment
├── staging.yml          # Staging environment  
├── prd.yml              # Production environment
└── deployments/
    └── may_2025/
        ├── aws-resource-discovery.sh
        └── discovered-resources-*.yml
```

### Platform Configurations
```
config/platform-env/
├── aws/                 # AWS-specific configs
├── cursor/              # Cursor IDE configs
├── dadosfera/           # Dadosfera platform configs
├── docker/              # Docker configurations
├── kubernetes/          # K8s manifests
└── replit/              # Replit configurations
```

## Run Script Interface

The project uses a centralized `run.sh` script following Dadosfera Blueprint standards:

### Required Flags
- `--env=<dev|staging|prd>` - Environment configuration
- `--platform=<cursor|replit|aws|dadosfera|docker>` - Deployment platform

### Optional Flags
- `--setup` - One-time setup tasks
- `--turbo` - Skip optional tasks (fastest)
- `--fast` - Skip tests but run core logic
- `--full` - Complete pipeline with tests and deployment
- `--dry-run` - Preview changes without execution
- `--verbose` - Detailed logging
- `--debug` - Debug output

### Examples
```bash
# Development with hot reload
bash run.sh --env=dev --platform=cursor --fast --verbose

# Production deployment with full pipeline
bash run.sh --env=prd --platform=aws --full --dry-run

# Quick setup for new environment
bash run.sh --env=dev --platform=cursor --setup --turbo
```

## API Documentation

### Interactive Documentation
- **Swagger UI**: http://localhost:5001/api-docs
- **OpenAPI Spec**: Available at `/api-docs.json`

### Core Endpoints
- `GET /health` - Health check
- `GET /api/status` - System status
- `POST /api/generate-tests` - Generate LLM tests

### Authentication
- API Key authentication supported
- Bearer token authentication for production

## Monitoring & Observability

### Health Checks
- Application health: `/health`
- System status: `/api/status`
- Platform-specific health endpoints

### Logging
- **File Logs**: Structured JSON in `logs/`
- **Console Logs**: stdout/stderr for CLI
- **UI Logs**: Human-readable web interface

### AWS Resources
- CloudWatch log groups for ECS services
- SQS queues for job processing
- S3 buckets for result storage
- ALB for load balancing

## Development Workflow

### Branch Naming Convention
```
{role}-{level}-{platform}-{vNo}-{objective}-{baseSHA}
```

Example: `agent-minion-cursor-1-swagger-docs-a1b2c3d`

### Commit Standards
- Format: `<scope>: <imperative description>`
- Example: `api: add swagger documentation`
- Example: `config: switch to port 5001 for development`

### Testing
```bash
# Run all tests
bash run.sh --env=dev --platform=cursor --full

# Quick test run
bash run.sh --env=dev --platform=cursor --fast

# Test specific components
npm test
```

## Troubleshooting

### Common Issues
1. **Port Conflicts**: Use ports 5001+ for macOS development
2. **Config Loading**: Check YAML syntax in `config/*.yml`
3. **AWS Permissions**: Verify IAM roles and policies
4. **Dependencies**: Run `--setup` flag for fresh installations

### Debug Commands
```bash
# Check port usage
lsof -i :5001

# Validate configuration
bash run.sh --env=dev --platform=cursor --dry-run --debug

# View logs
tail -f logs/$(ls logs/ | tail -1)/app.log
```

## Contributing

1. Follow the Dadosfera Blueprint v2.1 standards
2. Use the centralized `run.sh` interface
3. Update documentation for any new features
4. Ensure all tests pass before submitting PRs
5. Follow the branch naming convention

## Support

- **Documentation**: This index and linked guides
- **API Reference**: Interactive Swagger UI
- **Issues**: GitHub issue tracker
- **Logs**: Check `logs/` directory for detailed information

---

*This documentation follows the Dadosfera Blueprint v2.1 standards for enterprise deployment patterns.* 