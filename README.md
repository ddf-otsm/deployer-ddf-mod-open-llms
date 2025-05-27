# DeployerDDF Module: Open Source LLM Models

An intelligent testing agent that uses open source Large Language Models to automatically generate, execute, and validate tests for your codebase. Part of the DeployerDDF ecosystem for AI-powered development and testing workflows.

## 🚀 Features

- 🤖 **AI-Powered Test Generation**: Uses local LLMs (Ollama) for intelligent test creation
- 🧬 **Mutation Testing**: Integrates with StrykerJS for comprehensive test validation
- 🐳 **Docker Support**: Containerized deployment for consistent environments
- ☁️ **AWS Deployment**: CloudFormation templates for scalable cloud deployment
- 🔄 **Smart Validation**: Quality checks and pattern analysis for generated tests
- 📊 **Comprehensive Reporting**: Detailed test coverage and mutation analysis

## 🏃 Quick Start

### Option 1: Local Development (Recommended)
```bash
# Clone the repository
git clone https://github.com/ddf-otsm/deployer-ddf-mod-open-llms.git
cd deployer-ddf-mod-open-llms

# Quick start with authentication bypass
NODE_ENV=development AUTH_DISABLED=true bash workflow_tasks/run.sh --env=dev --platform=cursor --fast

# Or use the central run script
bash workflow_tasks/run.sh --env=dev --platform=cursor --fast
```

### Option 2: Docker Deployment
```bash
# Start with Docker (includes Ollama and Redis)
bash workflow_tasks/run.sh --env=dev --platform=docker

# Or manually with docker-compose
docker-compose -f secrets/deployments/docker/docker-compose-deployment.yml up -d
```

### Option 3: AWS Deployment
```bash
# Test AWS availability first
bash scripts/test-aws-availability.sh

# Deploy to AWS
bash workflow_tasks/run.sh --env=dev --platform=aws --setup --verbose
```

### 🧪 Test the Service
```bash
# Run comprehensive test suite
bash scripts/quick-test.sh

# Test individual endpoints
curl http://localhost:7001/health
curl http://localhost:7001/api/status
curl -X POST http://localhost:7001/api/generate-tests \
  -H "Content-Type: application/json" \
  -d '{"code":"function add(a, b) { return a + b; }", "language":"javascript"}'
```

## 📚 Documentation

### Quick Links
- [Getting Started](docs/guides/getting-started.md)
- [LLM Setup](docs/guides/llm-setup.md)
- [Installation Guide](docs/setup/installation.md)
- [AWS Deployment](docs/deploy/aws.md)
- [Run Script Usage](docs/setup/run_script_usage.md)

### Project Structure
- **Main Entry Point**: `workflow_tasks/run.sh` - Central execution script
- **Configuration**: 
  - `config/auth/` - Authentication configurations (templates only)
  - `config/docker/` - Docker configurations and templates
  - `config/platform-env/` - Platform-specific environment settings
- **Tests**: `tests/` - Test scripts and security verification
- **Documentation**: `docs/` - Comprehensive project documentation
- **Scripts**: `scripts/` - Utility and deployment scripts

### Secrets Management

This project follows professional secrets management practices:

1. **Templates Only in Git**: Only `.template.yml` files are tracked
2. **External Secrets**: Deployment files are stored outside the repository
3. **Environment Variables**: Sensitive values use environment variable references
4. **Setup Script**: Use the setup script to create deployment files from templates

```bash
# First-time setup - creates deployment files from templates
bash workflow_tasks/run.sh --env=dev --platform=cursor --setup

# This will prompt you to configure secrets externally
```

### Development
```bash
# Run with specific environment and platform
bash workflow_tasks/run.sh --env=dev --platform=cursor --fast

# Available platforms: cursor, aws, docker, replit
# Available environments: dev, stg, hmg, prd
# Speed modes: --turbo, --fast, --full
```

> **Note**: Documentation is currently being restructured. See [Documentation Plans](docs/todos/plans/) for ongoing improvements.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms/issues)
- 💬 [Discussions](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms/discussions)