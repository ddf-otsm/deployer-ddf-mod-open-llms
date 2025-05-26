# Configuration Structure - Dadosfera PRE-PROMPT v1.0 Compliant

**Updated:** 2025-05-26  
**Compliance:** ✅ Dadosfera PRE-PROMPT v1.0  
**Pattern:** `{env}.{platform}.yml`

---

## 📁 Configuration Directory Structure

The `config/` directory now follows the Dadosfera PRE-PROMPT v1.0 requirements with environment-platform specific configurations:

```
config/
├── dev.yml                    # Base development configuration
├── dev.docker.yml            # Docker development configuration
├── dev.aws.yml               # AWS development configuration
├── prd.aws.yml               # AWS production configuration
├── prd.docker.yml            # Docker production configuration
├── auth-config.template.yml  # Keycloak authentication template
├── aws-dev-account.template.yml # AWS account configuration template
├── llm-models.json           # LLM model definitions
├── pre-prompts/              # Pre-prompt configurations
└── schemas/                  # Configuration schemas
```

## 🎯 Configuration Pattern

### Naming Convention
```
{environment}.{platform}.yml
```

### Supported Combinations

| Environment | Platform | File | Status |
|-------------|----------|------|--------|
| `dev` | `cursor` | `dev.yml` (fallback) | ✅ Active |
| `dev` | `docker` | `dev.docker.yml` | ✅ Active |
| `dev` | `aws` | `dev.aws.yml` | ✅ Active |
| `prd` | `aws` | `prd.aws.yml` | ✅ Active |
| `prd` | `docker` | `prd.docker.yml` | ✅ Active |
| `staging` | `aws` | `staging.aws.yml` | 🔄 Planned |
| `staging` | `docker` | `staging.docker.yml` | 🔄 Planned |

## 🔧 How It Works

### 1. Central Run Script
The `run.sh` script automatically selects the appropriate configuration:

```bash
# Uses config/dev.docker.yml
./run.sh --env=dev --platform=docker

# Uses config/dev.aws.yml  
./run.sh --env=dev --platform=aws

# Uses config/prd.aws.yml
./run.sh --env=prd --platform=aws
```

### 2. Configuration Inheritance
Configurations can extend base configurations:

```yaml
# config/dev.docker.yml
environment: "development"
platform: "docker"
extends: "dev.yml"  # Inherits from base dev config
```

### 3. Fallback Mechanism
If a specific env-platform config doesn't exist, the system falls back to:
1. `{env}.yml` (e.g., `dev.yml`)
2. Error if no fallback exists

## 📋 Configuration Examples

### Development Docker (`config/dev.docker.yml`)
```yaml
environment: "development"
platform: "docker"
extends: "dev.yml"

docker:
  compose_file: "docker-compose.yml"
  containers:
    ai-testing-agent:
      image: "deployer-ddf-mod-llm-models:dev"
      ports: ["3000:3000"]

auth:
  enabled: false  # Disabled for development
  
environment_variables:
  NODE_ENV: "development"
  AUTH_DISABLED: "true"
```

### Production AWS (`config/prd.aws.yml`)
```yaml
environment: "production"
platform: "aws"

aws:
  region: "us-east-1"
  deployment:
    type: "ecs-fargate"
    cluster_name: "deployer-ddf-mod-llm-models-prd"
  resources:
    cpu: 2048
    memory: 4096
    desired_count: 2

auth:
  enabled: true  # Enabled for production
  method: "keycloak"
```

## 🚀 Usage Examples

### Local Development
```bash
# Start with Docker
./run.sh --env=dev --platform=docker --fast

# Start with local Node.js
./run.sh --env=dev --platform=cursor --fast
```

### AWS Deployment
```bash
# Development deployment
./run.sh --env=dev --platform=aws --setup --verbose

# Production deployment
./run.sh --env=prd --platform=aws --full --verbose
```

### Docker Compose Generation
```bash
# Generate from config
bash scripts/generate-docker-compose.sh --env=dev --platform=docker

# Generate production compose
bash scripts/generate-docker-compose.sh --env=prd --platform=docker
```

## 🔐 Authentication Configuration

### Development (Authentication Bypassed)
```yaml
auth:
  enabled: false
  method: "none"
```

### Production (Authentication Required)
```yaml
auth:
  enabled: true
  method: "keycloak"
  keycloak:
    server_url: "${KEYCLOAK_SERVER_URL}"
    realm: "${KEYCLOAK_REALM}"
    client_id: "${KEYCLOAK_CLIENT_ID}"
```

## 📊 Platform-Specific Features

### Docker Platform
- **Auto-generation** of `docker-compose.yml` from config
- **Volume mappings** for logs and configuration
- **Health checks** for all services
- **Network isolation** with custom networks

### AWS Platform
- **ECS Fargate** deployment
- **Auto-scaling** configuration
- **CloudWatch** logging and monitoring
- **Load balancer** setup
- **Security groups** and VPC configuration

## 🛠 Configuration Management

### Adding New Environment
1. Create `{env}.yml` base configuration
2. Create platform-specific `{env}.{platform}.yml` files
3. Update `run.sh` validation (if needed)
4. Test with `--dry-run` flag

### Adding New Platform
1. Create `dev.{platform}.yml` configuration
2. Add platform logic to `run.sh`
3. Create platform-specific scripts if needed
4. Update documentation

## ✅ Compliance Checklist

- ✅ **Single source of truth**: `config/` directory
- ✅ **Environment-platform pattern**: `{env}.{platform}.yml`
- ✅ **Central orchestration**: `run.sh` script
- ✅ **No duplicate configurations**: Inheritance and fallbacks
- ✅ **Generated files marked**: Docker compose has generation headers
- ✅ **Move log tracking**: All changes logged in `logs/move.log`

## 🔄 Migration from Old Structure

The old `docker-compose.yml` has been:
1. **Moved to config-driven generation**
2. **Marked as generated** with proper headers
3. **Regenerated from** `config/dev.docker.yml`
4. **Tracked in move log** for audit trail

---

**✅ Configuration structure is now fully compliant with Dadosfera PRE-PROMPT v1.0 requirements!** 