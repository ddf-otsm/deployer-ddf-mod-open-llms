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

```bash
# Clone the repository
git clone https://github.com/ddf-otsm/deployer-ddf-mod-open-llms.git
cd deployer-ddf-mod-open-llms

# Install dependencies
npm install

# Start with Docker
docker-compose up -d

# Run AI test generation
npm run ai:test:smart
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
