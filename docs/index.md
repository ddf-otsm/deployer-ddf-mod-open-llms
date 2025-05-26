# AI Testing Agent Documentation

## 🚀 Overview

The AI Testing Agent is an intelligent testing platform that leverages open-source Large Language Models (LLMs) to automatically generate, execute, and validate tests for your codebase.

## 📚 Quick Navigation

### 🏃 Getting Started
- [Installation Guide](setup/installation.md)
- [Quick Start](guides/getting-started.md)
- [Configuration](CONFIG_STRUCTURE.md)

### 🤖 LLM Testing
- [LLM Model Roadmap](#llm-model-roadmap)
- [Local Model Testing](#local-model-testing)
- [Advanced Testing](#advanced-testing)

### 🚀 Deployment
- [AWS Deployment](deploy/aws.md)
- [Docker Deployment](deploy/docker.md)
- [Local Development](guides/local-development.md)

## 🤖 LLM Model Roadmap

Our platform supports multiple tiers of LLM models for different testing scenarios:

### 📊 **Current Models (Available)**
| Model | Size | Type | Use Case | Status |
|-------|------|------|----------|--------|
| `deepseek-coder:1.3b` | 1.3B | Code | Fast iteration | ✅ Active |
| `deepseek-coder:6.7b` | 6.7B | Code | Balanced quality | ✅ Active |
| `llama3.2:1b` | 1B | General | Basic assistance | ✅ Active |
| `llama-3.1-8b` | 8B | General | Advanced reasoning | 📋 Planned |
| `codellama-34b` | 34B | Code | Expert code generation | 📋 Planned |

### 🚀 **Future Models (Llama 4 Series)**
| Model | Active Params | Total Params | Context | Specialty | Status |
|-------|---------------|--------------|---------|-----------|--------|
| `llama4-scout:17b` | 17B | 109B (16 experts) | 10M tokens | Multimodal | 🔬 Testing |
| `llama4-maverick:17b` | 17B | 400B (128 experts) | 1M tokens | Creative tasks | 🔬 Testing |
| `llama4-behemoth:288b` | 288B | ~2T (16 experts) | 1M tokens | Maximum quality | 🚧 In Training |

### 🏗️ **Testing Layers**
- **Layer 1**: Basic assistance (1B-8B models)
- **Layer 2**: Advanced reasoning (34B-70B models)  
- **Layer 3**: Expert analysis (reserved)
- **Layer 4**: Enterprise strategy (288B+ models)

## 🧪 Local Model Testing

### **Basic Model Tests**
Test all available local models:
```bash
# Activate virtual environment
source venv/bin/activate

# Test all models
python tests/test_model_basic.py --all

# Test specific model
python tests/test_model_basic.py --model deepseek-coder:6.7b
```

### **Smart Test Generation**
Generate intelligent tests using local LLMs:
```bash
# Generate test for a React component (default model)
python tests/local_llm_testgen.py src/components/Button.tsx

# Use higher quality model
python tests/local_llm_testgen.py --model=quality src/components/Button.tsx

# Available model tiers: fast, default, quality, context
```

### **Llama 4 Maverick Testing**
Test enterprise-level capabilities:
```bash
# Set HuggingFace token
export HF_TOKEN=your_huggingface_token

# Run comprehensive test
python tests/test_llama4_maverick.py --comprehensive

# Test specific capability
python tests/test_llama4_maverick.py --prompt enterprise_test_generation
```

## 🔧 Advanced Testing

### **Mutation Testing Integration**
The platform integrates with StrykerJS for mutation testing:
```bash
# Run mutation testing on specific file
npx stryker run --mutate src/components/Button.tsx

# Generate tests based on mutation results
python tests/local_llm_testgen.py --mutation-guided src/components/Button.tsx
```

### **Pattern Analysis**
The system analyzes existing test patterns:
- Extracts common testing patterns from your codebase
- Applies learned patterns to new test generation
- Validates generated tests against project standards

## 📊 Test Results

### **Current Test Status**
✅ **Local Models**: All 3 models tested successfully
- `deepseek-coder:1.3b`: 2.20s response time
- `llama3.2:1b`: 14.56s response time  
- `deepseek-coder:6.7b`: 18.02s response time

⚠️ **Llama 4 Maverick**: Requires HuggingFace provider setup
🚧 **AWS Infrastructure**: CloudFormation stack not deployed

## 🛠️ Configuration

Model configurations are stored in `config/llm-models.json`:
- Environment-specific model enablement
- Resource requirements and limits
- Testing layer assignments
- Provider configurations

## 🆘 Troubleshooting

### **Common Issues**
1. **Port 3000 in use**: Kill existing processes or use different port
2. **Missing HF_TOKEN**: Set HuggingFace token for Llama 4 models
3. **Ollama not running**: Start Ollama service for local models
4. **AWS credentials**: Configure AWS CLI for cloud deployment

### **Getting Help**
- 📖 Check specific guide documentation
- 🐛 [Report Issues](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms/issues)
- 💬 [Join Discussions](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms/discussions)

---

*Last updated: 2025-05-26* 