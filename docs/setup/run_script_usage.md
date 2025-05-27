# Run Script Usage Guide

This document provides comprehensive guidance on using the centralized `workflow_tasks/run.sh` script and understanding the configuration file organization.

## Overview

DeployerDDF uses a centralized `workflow_tasks/run.sh` script following Dadosfera Blueprint standards to orchestrate all operations. The script provides a consistent interface across different environments and platforms.

## Run Script Architecture

- **Main Implementation**: `workflow_tasks/run.sh` (600+ lines)
  - Contains the full execution pipeline
  - Handles configuration loading, platform detection, and application startup
  - Follows Dadosfera PRE-PROMPT v1.0 requirements

## Basic Usage

```bash
# Basic usage
bash workflow_tasks/run.sh --env=<environment> --platform=<platform> [options]

# Example: Development on Cursor
bash workflow_tasks/run.sh --env=dev --platform=cursor --fast

# Example: Production on AWS
bash workflow_tasks/run.sh --env=prd --platform=aws --full
```

## Available Options

### Required Parameters
- `--env=<env>` - Environment (`dev`, `stg`, `hmg`, `prd`)
- `--platform=<platform>` - Platform (`cursor`, `replit`, `docker`, `aws`, `dadosfera`, `kubernetes`)

### Speed Modes (pick one)
- `--turbo` - Skip all non-essential steps (fastest)
- `--fast` - Skip some heavier steps (balanced)
- `--full` - Run all steps (most thorough)

### Additional Options
- `--setup` - First-time setup (create .env, etc.)
- `--setup-hooks` - Install Git hooks
- `--test` - Run tests
- `--build` - Run build tasks
- `--tolerant` - Continue on non-critical errors
- `--verbose` - Show detailed logs
- `--debug` - Show debug information
- `--dry` - Dry run (show commands without executing)

## Configuration File Organization

The configuration files have been organized following professional secrets management practices:

```
config/
├── auth/
│   ├── auth-config.template.yml                # Template for auth config
│   └── keycloak-integration.template.yml       # Template for Keycloak
├── docker/
│   ├── docker-compose.template.yml             # Template for Docker Compose
│   └── Dockerfile                              # Container build file
├── platform-env/
│   ├── aws/
│   ├── cursor/
│   ├── dadosfera/
│   ├── docker/
│   ├── kubernetes/
│   └── replit/
├── ports.yml                                   # Port configuration
├── dev.yml                                     # Development environment config
├── aws-dev-account.template.yml                # Template for AWS account
└── auth-config.template.yml                    # Template for authentication

secrets/                                         # NEVER COMMITTED TO GIT
├── deployments/
│   ├── aws/
│   │   └── aws-dev-account-deployment.yml      # Actual AWS config
│   ├── auth/
│   │   ├── auth-config-deployment.yml          # Actual auth config
│   │   └── keycloak-integration-deployment.yml # Actual Keycloak config
│   └── docker/
│       └── docker-compose-deployment.yml       # Actual Docker config
└── README.md                                   # Secrets management guide
```

## Secrets Management Strategy

### Professional Approach

1. **Templates in Git**: Only `.template.yml` files are version controlled
2. **Secrets External**: Actual deployment files are stored in `secrets/` directory
3. **Environment Variables**: Sensitive values use `${VARIABLE_NAME}` references
4. **External Systems**: Production uses cloud-native secret management

### Setup Process

1. **First-time setup:**
   ```bash
   # Create secrets directory and copy templates
   bash workflow_tasks/run.sh --env=dev --platform=cursor --setup
   ```

2. **Manual setup (if needed):**
   ```bash
   # Create secrets directory
   mkdir -p secrets/deployments/{aws,auth,docker}
   
   # Copy templates to secrets directory
   cp config/aws-dev-account.template.yml secrets/deployments/aws/aws-dev-account-deployment.yml
   cp config/auth-config.template.yml secrets/deployments/auth/auth-config-deployment.yml
   cp config/auth/keycloak-integration.template.yml secrets/deployments/auth/keycloak-integration-deployment.yml
   cp config/docker/docker-compose.template.yml secrets/deployments/docker/docker-compose-deployment.yml
   ```

3. **Configure secrets:**
   ```bash
   # Set environment variables
   export KEYCLOAK_CLIENT_SECRET="your-secret-here"
   export AWS_ACCOUNT_ID="123456789012"
   
   # Edit deployment files and replace placeholders
   # REPLACE_WITH_ACTUAL_DEV_ACCOUNT_ID → 123456789012
   # ${KEYCLOAK_CLIENT_SECRET} → Will be resolved from environment
   ```

## Examples

### Local Development
```bash
# Quick start
NODE_ENV=development AUTH_DISABLED=true bash workflow_tasks/run.sh --env=dev --platform=cursor --fast

# Full development mode
bash workflow_tasks/run.sh --env=dev --platform=cursor --full --verbose
```

### Docker Development
```bash
# Start with Docker
bash workflow_tasks/run.sh --env=dev --platform=docker --fast

# Or manually with docker-compose
docker-compose -f secrets/deployments/docker/docker-compose-deployment.yml up -d
```

### AWS Deployment
```bash
# Test deployment (dry run)
bash workflow_tasks/run.sh --env=dev --platform=aws --dry --verbose

# Full deployment
bash workflow_tasks/run.sh --env=prd --platform=aws --full --verbose
```

## Production Secrets Management

### AWS
```yaml
# Use AWS Secrets Manager
keycloak:
  client_secret: "{{resolve:secretsmanager:keycloak-client-secret:SecretString:client_secret}}"
```

### Kubernetes
```yaml
# Use Kubernetes Secrets
env:
  - name: KEYCLOAK_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: keycloak-secret
        key: client-secret
```

### Docker
```yaml
# Use Docker Secrets
secrets:
  keycloak_secret:
    external: true
services:
  app:
    secrets:
      - keycloak_secret
```

## Troubleshooting

If you encounter issues:

1. Check logs in `logs/<timestamp>/` directory
2. Ensure secrets directory exists and has correct files
3. Verify environment variables are set correctly
4. Try running with `--verbose` and `--debug` flags
5. Check that templates have been copied to secrets directory

## Security Notes

- **Never commit** files from the `secrets/` directory
- Use environment variables for sensitive values
- Implement secret rotation in production
- Use cloud-native secret management for production deployments
- Follow the principle of least privilege

## Migration from Old Structure

If you have old deployment files in `config/`, they have been moved to `secrets/deployments/`. Update any scripts or documentation that reference the old paths. 