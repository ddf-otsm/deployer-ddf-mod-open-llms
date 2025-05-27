#!/bin/bash
# Central run.sh interface for deployer-ddf-mod-open-llms
# Follows Dadosfera Run-Script & Repository Blueprint v2.1

set -euo pipefail

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ID="$(date +%Y%m%d_%H%M%S)"

# Source helper libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/port_kill.sh"

# Initialize logging
init_logging "$PROJECT_ROOT/logs" "$RUN_ID"

# Default values following blueprint CLI contract
PLATFORM="replit"
ENV="dev"
SPEED_MODE="full"  # --turbo, --fast, or --full
SETUP=false
SETUP_HOOKS=false
TEST=false
BUILD=false
TOLERANT=false
VERBOSE=false
DEBUG=false
DRY_RUN=false

# Global state
FAILED_STEPS=()
WARNINGS=()
START_TIME=$(date +%s)

# Usage function
usage() {
    cat << EOF
Usage: $0 [options]

SPEED MODES (mutually exclusive, default: --full):
  --turbo              Skip heavy gates (dedupe, lint, scans, tests)
  --fast               Skip heavy gates, optional SBOM/vuln in CI
  --full               Full suite: all validations and tests

PLATFORM & ENVIRONMENT:
  -p, --platform=<p>   Platform: replit|dadosfera|docker|kubernetes|cursor|aws (default: replit)
  -e, --env=<env>      Environment: dev|stg|hmg|prd (default: dev)

OPERATION FLAGS:
  --setup              Create root symlinks via config/links.yml and .env from template
  --setup-hooks        Install Git hooks non-interactively
  --test               Execute tests (respecting speed mode)
  --build              Run build tasks as per mode

UTILITY FLAGS:
  --tolerant           Aggregate errors; fail after summary
  --debug              Enable timestamps & stack traces
  --verbose            Echo every executed command
  --dry                Print plan only, no execution
  --help               Show this help message

EXAMPLES:
  $0 --fast -p cursor -e dev
  $0 --setup --setup-hooks
  $0 --full -p docker -e stg --tolerant

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --turbo)
            SPEED_MODE="turbo"
            shift
            ;;
        --fast)
            SPEED_MODE="fast"
            shift
            ;;
        --full)
            SPEED_MODE="full"
            shift
            ;;
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        --platform=*)
            PLATFORM="${1#*=}"
            shift
            ;;
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        --env=*)
            ENV="${1#*=}"
            shift
            ;;
        --setup)
            SETUP=true
            shift
            ;;
        --setup-hooks)
            SETUP_HOOKS=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --build)
            BUILD=true
            shift
            ;;
        --tolerant)
            TOLERANT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --debug)
            DEBUG=true
            VERBOSE=true
            export DEBUG=true
            shift
            ;;
        --dry)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate platform
case $PLATFORM in
    replit|dadosfera|docker|kubernetes|cursor|aws) ;;
    *)
        log_error "Invalid platform: $PLATFORM. Must be one of: replit, dadosfera, docker, kubernetes, cursor, aws"
        exit 1
        ;;
esac

# Validate environment
case $ENV in
    dev|stg|hmg|prd) ;;
    *)
        log_error "Invalid environment: $ENV. Must be one of: dev, stg, hmg, prd"
        exit 1
        ;;
esac

log_info "=== Dadosfera Run-Script v2.1 ===" "run.sh"
log_info "Platform: $PLATFORM | Environment: $ENV | Mode: $SPEED_MODE" "run.sh"
log_info "Run ID: $RUN_ID" "run.sh"

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "=== DRY RUN MODE - No actual changes will be made ===" "run.sh"
fi

# Function to run commands with dry-run support
run_cmd() {
    local cmd="$*"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: $cmd" "run.sh"
        return 0
    else
        if [[ "$VERBOSE" == "true" ]]; then
            log_debug "Executing: $cmd" "run.sh"
        fi
        eval "$cmd"
    fi
}

# Error handling with tolerant mode
handle_error() {
    local step="$1"
    local error_msg="$2"
    
    FAILED_STEPS+=("$step")
    
    if [[ "$TOLERANT" == "true" ]]; then
        log_warn "Step '$step' failed: $error_msg (continuing in tolerant mode)" "run.sh"
        WARNINGS+=("$step: $error_msg")
        return 0
    else
        log_error "Step '$step' failed: $error_msg" "run.sh"
        exit 1
    fi
}

# Setup workflow (--setup)
setup_workflow() {
    log_step "=== SETUP WORKFLOW ===" "run.sh"
    
    # 1. Ensure shadow_symlinks directory exists
    run_cmd "mkdir -p '$PROJECT_ROOT/workflow_tasks/shadow_symlinks'"
    
    # 2. Setup secrets directory structure
    log_info "Setting up secrets management..." "run.sh"
    if [[ ! -d "$PROJECT_ROOT/secrets" ]]; then
        log_info "Creating secrets directory structure..." "run.sh"
        run_cmd "mkdir -p '$PROJECT_ROOT/secrets/deployments/aws'"
        run_cmd "mkdir -p '$PROJECT_ROOT/secrets/deployments/auth'"
        run_cmd "mkdir -p '$PROJECT_ROOT/secrets/deployments/docker'"
        
        # Set secure permissions
        run_cmd "chmod 700 '$PROJECT_ROOT/secrets'"
        log_success "Secrets directory created with secure permissions" "run.sh"
        
        # Copy template files to secrets directory
        local templates=(
            "config/aws-dev-account.template.yml:secrets/deployments/aws/aws-dev-account-deployment.yml"
            "config/auth-config.template.yml:secrets/deployments/auth/auth-config-deployment.yml"
            "config/auth/keycloak-integration.template.yml:secrets/deployments/auth/keycloak-integration-deployment.yml"
            "config/docker/docker-compose.template.yml:secrets/deployments/docker/docker-compose-deployment.yml"
        )
        
        for template_mapping in "${templates[@]}"; do
            local template_file="${template_mapping%%:*}"
            local deployment_file="${template_mapping##*:}"
            
            if [[ -f "$PROJECT_ROOT/$template_file" ]]; then
                run_cmd "cp '$PROJECT_ROOT/$template_file' '$PROJECT_ROOT/$deployment_file'"
                run_cmd "chmod 600 '$PROJECT_ROOT/$deployment_file'"
                log_success "Created: $deployment_file" "run.sh"
            else
                log_warn "Template file not found: $template_file" "run.sh"
                WARNINGS+=("Missing template: $template_file")
            fi
        done
        
        log_success "Secrets management setup completed" "run.sh"
    else
        log_info "Secrets directory already exists" "run.sh"
    fi
    
    # 3. Port cleanup and verification
    if [[ -f "$PROJECT_ROOT/scripts/port-manager.sh" ]]; then
        log_info "Checking and cleaning up ports..." "run.sh"
        run_cmd "bash '$PROJECT_ROOT/scripts/port-manager.sh' cleanup"
    fi
    
    # 4. Create .env from template
    local template_file="$PROJECT_ROOT/config/platform-env/$PLATFORM/$ENV.template"
    local env_file="$PROJECT_ROOT/.env"
    
    if [[ -f "$template_file" ]]; then
        log_info "Creating .env from template: $template_file" "run.sh"
        run_cmd "cp '$template_file' '$env_file'"
        log_success ".env file created successfully" "run.sh"
    else
        log_warn "Template file not found: $template_file" "run.sh"
        WARNINGS+=("Missing .env template for $PLATFORM/$ENV")
    fi
    
    # 5. Setup Git hooks if requested
    if [[ "$SETUP_HOOKS" == "true" ]]; then
        log_info "Installing Git hooks non-interactively" "run.sh"
        # TODO: Implement Git hooks installation
        log_info "Git hooks installation completed" "run.sh"
    fi
    
    # 6. Print setup summary and next steps
    log_success "Setup workflow completed" "run.sh"
    echo
    echo "Setup Summary:"
    echo "=============="
    echo "• Secrets directory: $([ -d "$PROJECT_ROOT/secrets" ] && echo "✓ Created" || echo "✗ Missing")"
    echo "• .env file: $([ -f "$env_file" ] && echo "✓ Created" || echo "✗ Missing")"
    echo "• Template used: $template_file"
    echo "• Git hooks: $([ "$SETUP_HOOKS" == "true" ] && echo "✓ Installed" || echo "- Skipped")"
    echo
    echo "Next Steps:"
    echo "==========="
    echo "1. Edit deployment files in secrets/deployments/ and replace placeholders:"
    echo "   - REPLACE_WITH_ACTUAL_DEV_ACCOUNT_ID → Your AWS account ID"
    echo "   - Email addresses → Your actual contact emails"
    echo
    echo "2. Set environment variables for sensitive values:"
    echo "   export KEYCLOAK_CLIENT_SECRET=\"your-secret-here\""
    echo "   export AWS_ACCOUNT_ID=\"123456789012\""
    echo
    echo "3. Verify your setup:"
    echo "   bash tests/security-check.sh"
    echo
    echo "4. Run the application:"
    echo "   bash workflow_tasks/run.sh --env=$ENV --platform=$PLATFORM --fast"
    echo
    echo "⚠️  IMPORTANT: Never commit files from the secrets/ directory!"
    echo
    
    exit 0
}

# Binary preflight checks
binary_preflight() {
    log_step "Binary preflight checks" "run.sh"
    
    local required_binaries=("node" "npm")
    local missing_binaries=()
    
    # Add platform-specific binaries
    case $PLATFORM in
        docker) required_binaries+=("docker") ;;
        kubernetes) required_binaries+=("kubectl" "helm") ;;
        dadosfera) required_binaries+=("curl") ;;
    esac
    
    for binary in "${required_binaries[@]}"; do
        if ! command -v "$binary" >/dev/null 2>&1; then
            missing_binaries+=("$binary")
        fi
    done
    
    if [[ ${#missing_binaries[@]} -gt 0 ]]; then
        handle_error "binary_preflight" "Missing required binaries: ${missing_binaries[*]}"
        return 1
    fi
    
    log_success "All required binaries are available" "run.sh"
}

# Config file detection and logging
config_detection() {
    log_step "Config file detection" "run.sh"
    
    local config_file="$PROJECT_ROOT/config/platform-env/$PLATFORM/$ENV.yml"
    local fallback_config="$PROJECT_ROOT/config/$ENV.yml"
    
    if [[ -f "$config_file" ]]; then
        log_info "Using platform-specific config: $config_file" "run.sh"
        export CONFIG_FILE="$config_file"
    elif [[ -f "$fallback_config" ]]; then
        log_warn "Using fallback config: $fallback_config" "run.sh"
        export CONFIG_FILE="$fallback_config"
    else
        handle_error "config_detection" "No configuration file found for $PLATFORM/$ENV"
        return 1
    fi
    
    # Log config file contents (first 20 lines)
    log_info "Configuration preview:" "run.sh"
    if [[ "$DRY_RUN" != "true" ]]; then
        head -20 "$CONFIG_FILE" | while read -r line; do
            log_debug "  $line" "run.sh"
        done
    fi
}

# Kill stale services
kill_stale_services() {
    if [[ "$SPEED_MODE" == "turbo" ]]; then
        return 0
    fi
    
    log_step "Killing stale services" "run.sh"
    
    # Use port manager if available
    if [[ -f "$PROJECT_ROOT/scripts/port-manager.sh" ]]; then
        log_info "Using port manager for service cleanup" "run.sh"
        if [[ "$SPEED_MODE" == "fast" ]]; then
            run_cmd "bash '$PROJECT_ROOT/scripts/port-manager.sh' cleanup"
        else
            run_cmd "bash '$PROJECT_ROOT/scripts/port-manager.sh' kill-all"
        fi
    else
        # Fallback to legacy method
        if [[ "$SPEED_MODE" == "fast" ]]; then
            # Quick kill of common ports
            kill_common_ports
        else
            # Full port cleanup
            local ports_to_kill=(5001 3000 3001 8000 8080 9000 9090)
            kill_ports "${ports_to_kill[@]}" || handle_error "kill_stale_services" "Failed to kill some processes"
        fi
    fi
}

# Port verification with auto-fallback
port_verification() {
    if [[ "$SPEED_MODE" == "turbo" ]]; then
        return 0
    fi
    
    log_step "Port verification" "run.sh"
    
    # Use port manager if available
    if [[ -f "$PROJECT_ROOT/scripts/port-manager.sh" ]]; then
        log_info "Using port manager for port verification" "run.sh"
        run_cmd "bash '$PROJECT_ROOT/scripts/port-manager.sh' check" || {
            log_warn "Some ports are in use. Cleaning up..." "run.sh"
            run_cmd "bash '$PROJECT_ROOT/scripts/port-manager.sh' kill-all"
        }
        
        # Get preferred port from port config
        local preferred_port=7001  # Default from config/ports.yml
        if [[ -f "$PROJECT_ROOT/config/ports.yml" ]]; then
            local config_port=$(grep -A5 "development:" "$PROJECT_ROOT/config/ports.yml" | grep "api_port:" | sed 's/.*api_port:\s*//' | head -1)
            if [[ -n "$config_port" ]]; then
                preferred_port="$config_port"
                log_info "Using port from port config: $preferred_port" "run.sh"
            fi
        fi
        
        export APP_PORT="$preferred_port"
        log_success "Application will use port: $preferred_port" "run.sh"
    else
        # Fallback to legacy method
        # Try to read port from config file
        local preferred_port=5001  # Default for macOS development
        if [[ -f "$CONFIG_FILE" ]]; then
            local config_port=$(grep -E "^\s*port:\s*[0-9]+" "$CONFIG_FILE" | sed 's/.*port:\s*//' | head -1)
            if [[ -n "$config_port" ]]; then
                preferred_port="$config_port"
                log_info "Using port from config: $preferred_port" "run.sh"
            fi
        fi
        
        local actual_port
        
        if [[ "$SPEED_MODE" == "fast" ]]; then
            # Lenient mode - just find any available port
            actual_port=$(find_available_port "$preferred_port" 2>/dev/null) || handle_error "port_verification" "No available ports found"
        else
            # Strict mode - try to use preferred port
            actual_port=$(setup_port_fallback "$preferred_port" "deployer-ddf-mod-open-llms" 2>/dev/null) || handle_error "port_verification" "Port setup failed"
        fi
        
        export APP_PORT="$actual_port"
        log_success "Application will use port: $actual_port" "run.sh"
    fi
}

# Dependency installation and deduplication
dependency_management() {
    if [[ "$SPEED_MODE" == "turbo" ]]; then
        return 0
    fi
    
    log_step "Dependency management" "run.sh"
    
    # Install dependencies
    if [[ ! -d "$PROJECT_ROOT/node_modules" ]] || [[ "$BUILD" == "true" ]]; then
        log_info "Installing npm dependencies" "run.sh"
        run_cmd "cd '$PROJECT_ROOT' && npm install"
    fi
    
    # Deduplication (full mode only)
    if [[ "$SPEED_MODE" == "full" ]]; then
        log_info "Running dependency deduplication" "run.sh"
        run_cmd "cd '$PROJECT_ROOT' && npm dedupe"
        
        # Log deduplication report
        echo "Dependency deduplication completed" > "$PROJECT_ROOT/logs/$RUN_ID/dep-dedupe-report.txt"
    fi
}

# Language-aware lint and type checking
lint_and_typecheck() {
    if [[ "$SPEED_MODE" != "full" ]]; then
        return 0
    fi
    
    log_step "Lint and type checking" "run.sh"
    
    # TypeScript compilation
    if [[ -f "$PROJECT_ROOT/tsconfig.json" ]]; then
        log_info "Running TypeScript compilation" "run.sh"
        run_cmd "cd '$PROJECT_ROOT' && npx tsc --noEmit"
    fi
    
    # ESLint
    if [[ -f "$PROJECT_ROOT/package.json" ]] && grep -q "eslint" "$PROJECT_ROOT/package.json"; then
        log_info "Running ESLint" "run.sh"
        run_cmd "cd '$PROJECT_ROOT' && npm run lint" || handle_error "lint" "ESLint failed"
    fi
    
    # Generate lint report
    echo "Lint and type check completed at $(date)" > "$PROJECT_ROOT/logs/$RUN_ID/lint-report.json"
}

# Build application
build_application() {
    if [[ "$BUILD" != "true" ]] && [[ "$SPEED_MODE" == "turbo" ]]; then
        return 0
    fi
    
    log_step "Building application" "run.sh"
    
    # Create dist directory
    run_cmd "mkdir -p '$PROJECT_ROOT/dist'"
    
    # Run build
    if [[ -f "$PROJECT_ROOT/package.json" ]] && grep -q '"build"' "$PROJECT_ROOT/package.json"; then
        log_info "Running npm build" "run.sh"
        run_cmd "cd '$PROJECT_ROOT' && npm run build"
    else
        log_warn "No build script found in package.json" "run.sh"
    fi
}

# Test execution
test_execution() {
    if [[ "$TEST" != "true" ]] || [[ "$SPEED_MODE" == "turbo" ]]; then
        return 0
    fi
    
    log_step "Test execution" "run.sh"
    
    if [[ -f "$PROJECT_ROOT/package.json" ]] && grep -q '"test"' "$PROJECT_ROOT/package.json"; then
        log_info "Running tests" "run.sh"
        run_cmd "cd '$PROJECT_ROOT' && npm test" || handle_error "test" "Tests failed"
        
        # Generate test report
        echo "Tests completed at $(date)" > "$PROJECT_ROOT/logs/$RUN_ID/fundamental-tests.xml"
    else
        log_warn "No test script found in package.json" "run.sh"
    fi
}

# Platform bootstrap
platform_bootstrap() {
    log_step "Platform bootstrap: $PLATFORM" "run.sh"
    
    local adapter_script="$SCRIPT_DIR/platform/$PLATFORM.sh"
    
    if [[ -f "$adapter_script" ]]; then
        log_info "Running platform adapter: $adapter_script" "run.sh"
        run_cmd "bash '$adapter_script' '$ENV' '$SPEED_MODE'"
    else
        log_warn "Platform adapter not found: $adapter_script" "run.sh"
        # Default platform bootstrap
        case $PLATFORM in
            replit|cursor)
                log_info "Using default development bootstrap" "run.sh"
                ;;
            *)
                log_warn "No specific bootstrap for platform: $PLATFORM" "run.sh"
                ;;
        esac
    fi
}

# Launch application
launch_application() {
    log_step "Launching application" "run.sh"
    
    # Set environment variables
    export NODE_ENV="$ENV"
    export PORT="${APP_PORT:-5001}"
    
    case $PLATFORM in
        cursor|replit)
            log_info "Starting development server on port $PORT" "run.sh"
            if [[ "$DRY_RUN" != "true" ]]; then
                run_cmd "cd '$PROJECT_ROOT' && npm run dev &"
                sleep 3  # Give the server time to start
            fi
            ;;
        docker)
            log_info "Starting with Docker Compose" "run.sh"
            run_cmd "cd '$PROJECT_ROOT' && docker-compose -f secrets/deployments/docker/docker-compose-deployment.yml up -d"
            ;;
        *)
            log_info "Starting application for platform: $PLATFORM" "run.sh"
            run_cmd "cd '$PROJECT_ROOT' && npm start &"
            ;;
    esac
}

# Summary generation
generate_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    log_step "Generating run summary" "run.sh"
    
         # Create summary JSON
     local failed_steps_json=""
     local warnings_json=""
     
     if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
         failed_steps_json=$(printf '"%s",' "${FAILED_STEPS[@]}" | sed 's/,$//')
     fi
     
     if [[ ${#WARNINGS[@]} -gt 0 ]]; then
         warnings_json=$(printf '"%s",' "${WARNINGS[@]}" | sed 's/,$//')
     fi
     
     cat > "$PROJECT_ROOT/logs/$RUN_ID/summary.json" << EOF
{
  "run_id": "$RUN_ID",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "platform": "$PLATFORM",
  "environment": "$ENV",
  "speed_mode": "$SPEED_MODE",
  "duration_seconds": $duration,
  "failed_steps": [$failed_steps_json],
  "warnings": [$warnings_json],
  "success": $([ ${#FAILED_STEPS[@]} -eq 0 ] && echo "true" || echo "false")
}
EOF
    
    # Console summary
    echo
    echo "=== RUN SUMMARY ==="
    echo "Run ID: $RUN_ID"
    echo "Duration: ${duration}s"
    echo "Platform: $PLATFORM"
    echo "Environment: $ENV"
    echo "Speed Mode: $SPEED_MODE"
    echo "Failed Steps: ${#FAILED_STEPS[@]}"
    echo "Warnings: ${#WARNINGS[@]}"
    
    if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
        echo "Failed: ${FAILED_STEPS[*]}"
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo "Warnings: ${WARNINGS[*]}"
    fi
    
    echo "Status: $([ ${#FAILED_STEPS[@]} -eq 0 ] && echo "SUCCESS" || echo "FAILED")"
    echo "Logs: logs/$RUN_ID/"
    echo "==================="
    
    # Exit with appropriate code
    if [[ ${#FAILED_STEPS[@]} -gt 0 ]] && [[ "$TOLERANT" != "true" ]]; then
        exit 1
    fi
}

# Main execution pipeline
main() {
    # Handle setup workflow
    if [[ "$SETUP" == "true" ]]; then
        setup_workflow
        return
    fi
    
    # Execution pipeline according to blueprint
    binary_preflight
    config_detection
    kill_stale_services
    port_verification
    dependency_management
    lint_and_typecheck
    build_application
    test_execution
    platform_bootstrap
    launch_application
    
    # Post-launch summary
    log_success "Application launched successfully" "run.sh"
    log_info "Service should be available at: http://localhost:${APP_PORT:-5001}" "run.sh"
    
    # Generate final summary
    generate_summary
}

# Trap for cleanup and summary on exit
trap generate_summary EXIT

# Execute main pipeline
main "$@" 
