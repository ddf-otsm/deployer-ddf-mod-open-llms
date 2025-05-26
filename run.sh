#!/bin/bash
# Central run.sh interface for deployer-ddf-mod-open-llms
# Follows Dadosfera PRE-PROMPT v1.0 requirements

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Default values
ENV=""
PLATFORM=""
SETUP=false
TURBO=false
FAST=false
FULL=false
TOLERANT=false
VERBOSE=false
DEBUG=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    case $level in
        ERROR) echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        INFO)  echo -e "${GREEN}[INFO]${NC} $message" ;;
        DEBUG) [[ "$DEBUG" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
    
    # Also log to file if logs directory exists
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"script\":\"run.sh\"}" >> "$PROJECT_ROOT/logs/run.log"
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $0 --env=<environment> --platform=<platform> [options]

MANDATORY FLAGS:
  --env=<env>           Environment config to load (dev|staging|prd)
  --platform=<platform> Deployment platform (dadosfera|replit|cursor|docker|aws)

OPERATION FLAGS:
  --setup              Perform one-time setup tasks
  --turbo              Skip optional pre/post tasks for fastest run
  --fast               Skip tests but run core build/logic
  --full               Full pipeline including lint, test, deploy

UTILITY FLAGS:
  --tolerant           Suppress non-blocking warnings during bootstrap
  --verbose            Enable verbose output
  --debug              Include debug output/logs
  --dry-run            Show what would be done without executing
  --help               Show this help message

EXAMPLES:
  $0 --env=dev --platform=cursor --fast
  $0 --env=dev --platform=aws --setup --verbose
  $0 --env=prd --platform=dadosfera --full --dry-run

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env=*)
            ENV="${1#*=}"
            shift
            ;;
        --platform=*)
            PLATFORM="${1#*=}"
            shift
            ;;
        --setup)
            SETUP=true
            shift
            ;;
        --turbo)
            TURBO=true
            shift
            ;;
        --fast)
            FAST=true
            shift
            ;;
        --full)
            FULL=true
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
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log ERROR "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate mandatory flags
if [[ -z "$ENV" ]]; then
    log ERROR "Missing required --env flag"
    usage
    exit 1
fi

if [[ -z "$PLATFORM" ]]; then
    log ERROR "Missing required --platform flag"
    usage
    exit 1
fi

# Validate environment
case $ENV in
    dev|staging|prd) ;;
    *)
        log ERROR "Invalid environment: $ENV. Must be one of: dev, staging, prd"
        exit 1
        ;;
esac

# Validate platform
case $PLATFORM in
    dadosfera|replit|cursor|docker|aws) ;;
    *)
        log ERROR "Invalid platform: $PLATFORM. Must be one of: dadosfera, replit, cursor, docker, aws"
        exit 1
        ;;
esac

log INFO "Starting deployer-ddf-mod-open-llms with env=$ENV platform=$PLATFORM"

# Create logs directory if it doesn't exist
mkdir -p "$PROJECT_ROOT/logs"

# Load configuration
CONFIG_FILE="$PROJECT_ROOT/config/${ENV}.${PLATFORM}.yml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    # Try fallback config files
    FALLBACK_CONFIG="$PROJECT_ROOT/config/${ENV}.yml"
    if [[ -f "$FALLBACK_CONFIG" ]]; then
        CONFIG_FILE="$FALLBACK_CONFIG"
        log WARN "Using fallback config: $FALLBACK_CONFIG"
    else
        log ERROR "Configuration file not found: $CONFIG_FILE"
        log INFO "Available configs:"
        ls -la "$PROJECT_ROOT/config/" || true
        exit 1
    fi
fi

log INFO "Using config: $CONFIG_FILE"

# Function to run commands with dry-run support
run_cmd() {
    local cmd="$*"
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "[DRY-RUN] Would execute: $cmd"
    else
        log DEBUG "Executing: $cmd"
        eval "$cmd"
    fi
}

# Function to check dependencies
check_dependencies() {
    log INFO "Checking dependencies..."
    
    # Check Node.js
    if ! command -v node >/dev/null 2>&1; then
        log ERROR "Node.js not found. Please install Node.js 18+"
        exit 1
    fi
    
    # Check npm
    if ! command -v npm >/dev/null 2>&1; then
        log ERROR "npm not found. Please install npm"
        exit 1
    fi
    
    # Check Docker if needed
    if [[ "$PLATFORM" == "docker" ]] && ! command -v docker >/dev/null 2>&1; then
        log ERROR "Docker not found. Please install Docker"
        exit 1
    fi
    
    # Check AWS CLI if needed
    if [[ "$PLATFORM" == "aws" ]] && ! command -v aws >/dev/null 2>&1; then
        log ERROR "AWS CLI not found. Please install AWS CLI"
        exit 1
    fi
    
    log INFO "Dependencies check passed"
}

# Function to setup environment
setup_environment() {
    log INFO "Setting up environment..."
    
    # Install npm dependencies
    if [[ ! -d "$PROJECT_ROOT/node_modules" ]] || [[ "$SETUP" == "true" ]]; then
        log INFO "Installing npm dependencies..."
        run_cmd "cd '$PROJECT_ROOT' && npm install"
    fi
    
    # Create necessary directories
    run_cmd "mkdir -p '$PROJECT_ROOT/logs'"
    run_cmd "mkdir -p '$PROJECT_ROOT/dist'"
    
    # Setup platform-specific environment
    case $PLATFORM in
        aws)
            if [[ "$SETUP" == "true" ]]; then
                log INFO "Setting up AWS environment..."
                run_cmd "bash '$PROJECT_ROOT/scripts/deploy/setup-aws.sh'"
            fi
            ;;
        docker)
            if [[ "$SETUP" == "true" ]]; then
                log INFO "Setting up Docker environment..."
                # Docker setup would go here
            fi
            ;;
    esac
}

# Function to build the application
build_application() {
    log INFO "Building application..."
    
    if [[ "$TURBO" == "true" ]]; then
        log INFO "Turbo mode: skipping build optimizations"
        run_cmd "cd '$PROJECT_ROOT' && npm run build"
    else
        # Full build with linting
        if [[ "$FULL" == "true" ]]; then
            log INFO "Running linter..."
            run_cmd "cd '$PROJECT_ROOT' && npm run lint"
        fi
        
        log INFO "Building TypeScript..."
        run_cmd "cd '$PROJECT_ROOT' && npm run build"
    fi
}

# Function to run tests
run_tests() {
    if [[ "$FAST" == "true" ]] || [[ "$TURBO" == "true" ]]; then
        log INFO "Fast/Turbo mode: skipping tests"
        return
    fi
    
    log INFO "Running tests..."
    run_cmd "cd '$PROJECT_ROOT' && npm test"
    
    if [[ "$FULL" == "true" ]]; then
        log INFO "Running coverage tests..."
        run_cmd "cd '$PROJECT_ROOT' && npm run test:coverage"
    fi
}

# Function to start the application
start_application() {
    log INFO "Starting application for platform: $PLATFORM"
    
    case $PLATFORM in
        cursor|dev)
            log INFO "Starting development server..."
            run_cmd "cd '$PROJECT_ROOT' && npm run dev &"
            ;;
        docker)
            log INFO "Starting with Docker..."
            run_cmd "cd '$PROJECT_ROOT' && docker-compose up -d"
            ;;
        aws)
            log INFO "Deploying to AWS..."
            run_cmd "bash '$PROJECT_ROOT/scripts/deploy/aws-deploy.sh'"
            ;;
        replit)
            log INFO "Starting for Replit..."
            run_cmd "cd '$PROJECT_ROOT' && npm start"
            ;;
        dadosfera)
            log INFO "Starting for Dadosfera Orchest..."
            run_cmd "cd '$PROJECT_ROOT' && npm start"
            ;;
    esac
}

# Function to run health checks
health_check() {
    if [[ "$TURBO" == "true" ]]; then
        log INFO "Turbo mode: skipping health checks"
        return
    fi
    
    log INFO "Running health checks..."
    
    # Wait a moment for the service to start
    sleep 5
    
    # Check if the service is responding
    if command -v curl >/dev/null 2>&1; then
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log INFO "Health check passed"
        else
            log WARN "Health check failed - service may still be starting"
        fi
    else
        log WARN "curl not available - skipping health check"
    fi
}

# Main execution flow
main() {
    log INFO "=== Starting deployer-ddf-mod-open-llms ==="
    log INFO "Environment: $ENV"
    log INFO "Platform: $PLATFORM"
    log INFO "Setup: $SETUP"
    log INFO "Mode: $(if [[ "$TURBO" == "true" ]]; then echo "turbo"; elif [[ "$FAST" == "true" ]]; then echo "fast"; elif [[ "$FULL" == "true" ]]; then echo "full"; else echo "standard"; fi)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log INFO "=== DRY RUN MODE - No actual changes will be made ==="
    fi
    
    # Execute pipeline
    check_dependencies
    setup_environment
    build_application
    run_tests
    start_application
    health_check
    
    log INFO "=== Deployment completed successfully ==="
    log INFO "Service should be available at: http://localhost:3000"
    log INFO "Health check: http://localhost:3000/health"
    log INFO "API status: http://localhost:3000/api/status"
}

# Execute main function
main "$@" 