#!/bin/bash
# Platform adapter for Cursor IDE
# Handles cursor-specific setup and configuration

ENV="$1"
SPEED_MODE="$2"

# Source logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/logging.sh"

log_info "Cursor platform adapter starting" "cursor.sh"
log_info "Environment: $ENV, Speed Mode: $SPEED_MODE" "cursor.sh"

# Cursor-specific environment setup
case $ENV in
    dev)
        log_info "Setting up Cursor development environment" "cursor.sh"
        
        # Ensure development dependencies are available
        export NODE_ENV=development
        export DEBUG=true
        export HOT_RELOAD=true
        
        # Cursor-specific optimizations
        export TSC_WATCHFILE=UseFsEvents
        export CHOKIDAR_USEPOLLING=false
        ;;
    stg|hmg)
        log_info "Setting up Cursor staging environment" "cursor.sh"
        export NODE_ENV=staging
        ;;
    prd)
        log_info "Setting up Cursor production environment" "cursor.sh"
        export NODE_ENV=production
        ;;
esac

# Speed mode optimizations
case $SPEED_MODE in
    turbo)
        log_info "Turbo mode: minimal cursor setup" "cursor.sh"
        ;;
    fast)
        log_info "Fast mode: standard cursor setup" "cursor.sh"
        ;;
    full)
        log_info "Full mode: complete cursor setup with all features" "cursor.sh"
        
        # Enable all development features in full mode
        export VERBOSE_LOGGING=true
        export ENABLE_SOURCE_MAPS=true
        ;;
esac

log_success "Cursor platform adapter completed" "cursor.sh" 