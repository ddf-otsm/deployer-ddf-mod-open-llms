#!/bin/bash

# Security Check Script for Deployer DDF Mod LLM Models
# This script verifies security configuration and identifies potential issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
CHECKS=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
    ((CHECKS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((ERRORS++))
    ((CHECKS++))
}

# Check if file exists
check_file_exists() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_success "$description exists: $file"
        return 0
    else
        log_error "$description missing: $file"
        return 1
    fi
}

# Check if directory exists and is properly secured
check_directory_security() {
    local dir="$1"
    local description="$2"
    
    if [[ -d "$dir" ]]; then
        local perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null || echo "unknown")
        if [[ "$perms" == "700" ]] || [[ "$perms" == "750" ]]; then
            log_success "$description has secure permissions ($perms): $dir"
        else
            log_warning "$description has loose permissions ($perms): $dir"
        fi
    else
        log_warning "$description directory does not exist: $dir"
    fi
}

# Check for placeholder values in configuration files
check_placeholders() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        local placeholders=$(grep -c "REPLACE_WITH_" "$file" 2>/dev/null || echo "0")
        if [[ "$placeholders" -eq 0 ]]; then
            log_success "$description has no placeholder values"
        else
            log_error "$description contains $placeholders placeholder values that need to be replaced"
        fi
    fi
}

# Check git status for sensitive files
check_git_status() {
    log_info "Checking git status for sensitive files..."
    
    # Check if any sensitive files are tracked
    local sensitive_files=(
        "secrets/"
        ".env"
        "*.secret"
        "*.secrets"
    )
    
    for file in "${sensitive_files[@]}"; do
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            log_error "Sensitive file is tracked by git: $file"
        else
            log_success "Sensitive file is not tracked by git: $file"
        fi
    done
}

# Check secrets directory structure
check_secrets_structure() {
    log_info "Checking secrets directory structure..."
    
    if [[ -d "secrets" ]]; then
        log_success "Secrets directory exists"
        
        # Check if secrets directory is properly ignored
        if git check-ignore secrets >/dev/null 2>&1; then
            log_success "Secrets directory is properly git-ignored"
        else
            log_error "Secrets directory is NOT git-ignored"
        fi
        
        # Check for deployment files in secrets
        local deployment_files=(
            "secrets/deployments/aws/aws-dev-account-deployment.yml"
            "secrets/deployments/auth/auth-config-deployment.yml"
            "secrets/deployments/auth/keycloak-integration-deployment.yml"
            "secrets/deployments/docker/docker-compose-deployment.yml"
        )
        
        for file in "${deployment_files[@]}"; do
            if [[ -f "$file" ]]; then
                log_success "Deployment file exists: $file"
                check_placeholders "$file" "$(basename "$file")"
            else
                log_warning "Deployment file missing: $file"
            fi
        done
    else
        log_warning "Secrets directory does not exist - run setup first"
    fi
}

# Check AWS CLI configuration
check_aws_config() {
    log_info "Checking AWS CLI configuration..."
    
    if command -v aws >/dev/null 2>&1; then
        log_success "AWS CLI is installed"
        
        # Check if default profile is configured
        if aws configure list >/dev/null 2>&1; then
            log_success "AWS CLI default profile is configured"
        else
            log_warning "AWS CLI default profile is not configured"
        fi
        
        # Check for dev profile if specified in config
        if aws configure list --profile dev >/dev/null 2>&1; then
            log_success "AWS CLI dev profile is configured"
        else
            log_warning "AWS CLI dev profile is not configured"
        fi
    else
        log_error "AWS CLI is not installed"
    fi
}

# Check Docker configuration
check_docker_config() {
    log_info "Checking Docker configuration..."
    
    if command -v docker >/dev/null 2>&1; then
        log_success "Docker is installed"
        
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon is running"
        else
            log_warning "Docker daemon is not running"
        fi
    else
        log_error "Docker is not installed"
    fi
}

# Check Node.js and npm
check_nodejs_config() {
    log_info "Checking Node.js configuration..."
    
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        log_success "Node.js is installed: $node_version"
        
        if command -v npm >/dev/null 2>&1; then
            local npm_version=$(npm --version)
            log_success "npm is installed: $npm_version"
        else
            log_error "npm is not installed"
        fi
    else
        log_error "Node.js is not installed"
    fi
}

# Check file permissions
check_file_permissions() {
    log_info "Checking file permissions..."
    
    # Check secrets directory permissions
    if [[ -d "secrets" ]]; then
        local perms=$(stat -c "%a" "secrets" 2>/dev/null || stat -f "%A" "secrets" 2>/dev/null || echo "unknown")
        if [[ "$perms" == "700" ]] || [[ "$perms" == "750" ]]; then
            log_success "Secrets directory has secure permissions ($perms)"
        else
            log_warning "Secrets directory has loose permissions ($perms)"
        fi
    fi
    
    # Check API token files
    if [[ -d "api-tokens/dev" ]]; then
        for file in api-tokens/dev/*; do
            if [[ -f "$file" && ! "$file" == *".template" ]]; then
                local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null || echo "unknown")
                if [[ "$perms" == "600" ]] || [[ "$perms" == "400" ]]; then
                    log_success "API token file has secure permissions ($perms): $file"
                else
                    log_warning "API token file has loose permissions ($perms): $file"
                fi
            fi
        done
    fi
}

# Main security check function
main() {
    echo "=================================================="
    echo "Security Check for Deployer DDF Mod LLM Models"
    echo "=================================================="
    echo
    
    log_info "Starting security verification..."
    echo
    
    # Check configuration templates
    log_info "Checking configuration templates..."
    check_file_exists "config/aws-dev-account.template.yml" "AWS dev account template" || true
    check_file_exists "config/auth-config.template.yml" "Auth config template" || true
    check_file_exists "config/auth/keycloak-integration.template.yml" "Keycloak integration template" || true
    check_file_exists "config/docker/docker-compose.template.yml" "Docker Compose template" || true
    echo
    
    # Check secrets directory structure
    check_secrets_structure || true
    echo
    
    # Check directory security
    log_info "Checking directory security..."
    check_directory_security "secrets" "Secrets directory" || true
    check_directory_security "api-tokens" "API tokens directory" || true
    check_directory_security "aws-credentials" "AWS credentials directory" || true
    echo
    
    # Check file permissions
    check_file_permissions || true
    echo
    
    # Check git status
    check_git_status || true
    echo
    
    # Check system dependencies
    check_aws_config || true
    echo
    check_docker_config || true
    echo
    check_nodejs_config || true
    echo
    
    # Check .gitignore
    log_info "Checking .gitignore configuration..."
    if grep -q "secrets/" .gitignore 2>/dev/null; then
        log_success ".gitignore excludes secrets directory"
    else
        log_error ".gitignore does not exclude secrets directory"
    fi
    
    if grep -q "api-tokens/" .gitignore 2>/dev/null; then
        log_success ".gitignore excludes api-tokens directory"
    else
        log_error ".gitignore does not exclude api-tokens directory"
    fi
    echo
    
    # Summary
    echo "=================================================="
    echo "Security Check Summary"
    echo "=================================================="
    echo "Total checks performed: $CHECKS"
    echo -e "Passed: ${GREEN}$((CHECKS - WARNINGS - ERRORS))${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo -e "Errors: ${RED}$ERRORS${NC}"
    echo
    
    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}❌ Security check failed with $ERRORS errors${NC}"
        echo "Please fix the errors before proceeding with deployment."
        echo
        echo "To set up secrets properly:"
        echo "  bash workflow_tasks/run.sh --env=dev --platform=cursor --setup"
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Security check completed with $WARNINGS warnings${NC}"
        echo "Consider addressing the warnings for better security."
        exit 0
    else
        echo -e "${GREEN}✅ Security check passed successfully${NC}"
        echo "Your configuration appears to be secure."
        exit 0
    fi
}

# Run main function
main "$@" 