# AI Testing Agent with Open Source LLMs

An intelligent testing agent that uses open source Large Language Models to automatically generate, execute, and validate tests for your codebase.

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
NODE_ENV=development AUTH_DISABLED=true ./run.sh --env=dev --platform=cursor --fast

# Or use the central run script
./run.sh --env=dev --platform=cursor --fast
```

### Option 2: Docker Deployment
```bash
# Start with Docker (includes Ollama and Redis)
./run.sh --env=dev --platform=docker

# Or manually with docker-compose
docker-compose up -d
```

### Option 3: AWS Deployment
```bash
# Test AWS availability first
bash scripts/test-aws-availability.sh

# Deploy to AWS
./run.sh --env=dev --platform=aws --setup --verbose
```

### 🧪 Test the Service
```bash
# Run comprehensive test suite
bash scripts/quick-test.sh

# Test individual endpoints
curl http://localhost:3000/health
curl http://localhost:3000/api/status
curl -X POST http://localhost:3000/api/generate-tests \
  -H "Content-Type: application/json" \
  -d '{"code":"function add(a, b) { return a + b; }", "language":"javascript"}'
```

## 📚 Documentation

- [Getting Started](docs/guides/getting-started.md)
- [LLM Setup](docs/guides/llm-setup.md)
- [Installation Guide](docs/setup/installation.md)
- [AWS Deployment](docs/deploy/aws.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms/issues)
- 💬 [Discussions](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms/discussions)
