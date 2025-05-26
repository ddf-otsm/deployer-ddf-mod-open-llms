#!/bin/bash
# AI Testing Agent - Environment Setup Script
# Securely loads AWS credentials from environment files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
ENV_FILE="${PROJECT_ROOT}/.env"
PROFILE="default"
REGION="us-east-1"
VERBOSE=false

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Securely set up AWS environment variables from .env file.

OPTIONS:
    --env-file=FILE        Path to .env file [default: .env]
    --profile=PROFILE      AWS profile name [default: default]
    --region=REGION        AWS region [default: us-east-1]
    --verbose              Enable verbose output
    --help                 Show this help message

EXAMPLES:
    $0                                    # Use default .env file
    $0 --env-file=.env.prod              # Use production env file
    $0 --profile=ai-testing --region=us-west-2

SECURITY:
    This script loads AWS credentials from environment files instead of
    exposing them in command line arguments. Credentials are never logged
    or displayed in terminal output.

EOF
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*" >&2
    exit 1
}

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "$*"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file=*)
            ENV_FILE="${1#*=}"
            shift
            ;;
        --profile=*)
            PROFILE="${1#*=}"
            shift
            ;;
        --region=*)
            REGION="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate environment file exists
if [[ ! -f "$ENV_FILE" ]]; then
    error "Environment file not found: $ENV_FILE"
fi

log "Setting up AWS environment from: $ENV_FILE"

# Load environment variables from file
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a  # Stop auto-exporting

# Validate required AWS credentials are present
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    error "AWS_ACCESS_KEY_ID not found in $ENV_FILE"
fi

if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    error "AWS_SECRET_ACCESS_KEY not found in $ENV_FILE"
fi

# Set default region if not specified in env file
if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
    export AWS_DEFAULT_REGION="$REGION"
    verbose "Set AWS_DEFAULT_REGION to $REGION"
fi

# Mask credentials for logging (show only first 4 and last 4 characters)
mask_credential() {
    local cred="$1"
    local length=${#cred}
    if [[ $length -gt 8 ]]; then
        echo "${cred:0:4}****${cred: -4}"
    else
        echo "****"
    fi
}

# Verify AWS credentials are loaded (without exposing them)
verbose "AWS_ACCESS_KEY_ID: $(mask_credential "$AWS_ACCESS_KEY_ID")"
verbose "AWS_SECRET_ACCESS_KEY: $(mask_credential "$AWS_SECRET_ACCESS_KEY")"
verbose "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"

# Test AWS connectivity
log "Testing AWS connectivity..."
if aws sts get-caller-identity > /dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null)
    USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
    log "✅ AWS connectivity successful"
    verbose "Account ID: $ACCOUNT_ID"
    verbose "User ARN: $USER_ARN"
else
    error "AWS connectivity test failed. Please check your credentials."
fi

# Export environment setup function for other scripts
export_aws_env() {
    cat << EOF
# AWS Environment Variables (source this in your shell)
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION"
EOF
}

# Create a temporary environment file for current session
TEMP_ENV_FILE="/tmp/aws-env-$$"
export_aws_env > "$TEMP_ENV_FILE"

log "✅ AWS environment setup complete"
log "To use in current shell: source $TEMP_ENV_FILE"
log "To use in scripts: source $SCRIPT_DIR/setup-env.sh --env-file=$ENV_FILE"

# Clean up temp file after 1 hour
(sleep 3600 && rm -f "$TEMP_ENV_FILE" 2>/dev/null) &

echo "$TEMP_ENV_FILE"  # Return temp file path for other scripts 