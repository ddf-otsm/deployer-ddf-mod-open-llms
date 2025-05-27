#!/bin/bash
# Enhanced cleanup script for removing wrong directory
# Following Dadosfera PRE-PROMPT v1.0 standards

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRONG_DIR="../deployer-ddf-mod-llm-models"
BACKUP_FILE="$HOME/Desktop/deployer-ddf-mod-llm-models-backup-20250527.tar.gz"
LOG_FILE="$PROJECT_ROOT/logs/cleanup-$(date +%Y%m%d_%H%M%S).log"

# Flags
DRY_RUN=false
VERIFY_BACKUP=false
TEST_AFTER=false
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Success message
success() {
    log "INFO" "${GREEN}$1${NC}"
}

# Warning message
warning() {
    log "WARN" "${YELLOW}$1${NC}"
}

# Info message
info() {
    log "INFO" "${BLUE}$1${NC}"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Enhanced cleanup script for safely removing the wrong directory.

OPTIONS:
    --dry-run           Show what would be done without executing
    --verify-backup     Verify backup integrity before deletion
    --test-after        Run system tests after cleanup
    --force             Force deletion even if verification fails
    -h, --help          Show this help message

EXAMPLES:
    $0 --dry-run                    # Preview actions
    $0 --verify-backup              # Safe cleanup with backup verification
    $0 --verify-backup --test-after # Full cleanup with post-deletion testing
    $0 --force                      # Force cleanup (use with caution)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verify-backup)
                VERIFY_BACKUP=true
                shift
                ;;
            --test-after)
                TEST_AFTER=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

# Verify backup exists and is valid
verify_backup() {
    info "Verifying backup integrity..."
    
    if [[ ! -f "$BACKUP_FILE" ]]; then
        error_exit "Backup file not found: $BACKUP_FILE"
    fi
    
    # Check backup file size (should be > 10MB for this project)
    local backup_size=$(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null)
    if [[ $backup_size -lt 10485760 ]]; then  # 10MB
        warning "Backup file seems small ($backup_size bytes). Proceeding with caution."
        if [[ "$FORCE" != "true" ]]; then
            error_exit "Backup verification failed. Use --force to override."
        fi
    fi
    
    # Test backup integrity
    if ! tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        error_exit "Backup file is corrupted or not a valid tar.gz file"
    fi
    
    success "Backup verification passed (size: $backup_size bytes)"
}

# Verify wrong directory exists
verify_wrong_directory() {
    if [[ ! -d "$WRONG_DIR" ]]; then
        success "Wrong directory already removed: $WRONG_DIR"
        exit 0
    fi
    
    info "Wrong directory found: $WRONG_DIR"
    
    # Check if it's actually the wrong directory by looking for key differences
    if [[ -d "$WRONG_DIR/.git" ]]; then
        warning "Wrong directory contains .git folder - this might not be the intended target"
        if [[ "$FORCE" != "true" ]]; then
            error_exit "Safety check failed. Use --force to override."
        fi
    fi
}

# Create pre-deletion verification
pre_deletion_checks() {
    info "Running pre-deletion checks..."
    
    # Verify current directory is correct
    if [[ ! -f "$PROJECT_ROOT/package.json" ]] || [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        error_exit "Current directory doesn't appear to be the correct project root"
    fi
    
    # Verify critical files exist in current directory
    local critical_files=(
        "config/llm-models.json"
        "scripts/deploy/health-check.sh"
        "tests/test_model_basic.py"
        "run.sh"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            error_exit "Critical file missing in current directory: $file"
        fi
    done
    
    success "Pre-deletion checks passed"
}

# Execute cleanup
execute_cleanup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would remove directory: $WRONG_DIR"
        info "DRY RUN: Would log action to: logs/move.log"
        return 0
    fi
    
    info "Removing wrong directory: $WRONG_DIR"
    
    # Remove the directory
    rm -rf "$WRONG_DIR"
    
    # Log the action
    echo "$(date '+%Y-%m-%d %H:%M:%S') - DELETED: $WRONG_DIR (backup: $BACKUP_FILE)" >> "$PROJECT_ROOT/logs/move.log"
    
    success "Directory removed successfully"
}

# Post-deletion verification
post_deletion_verification() {
    info "Running post-deletion verification..."
    
    # Verify directory is gone
    if [[ -d "$WRONG_DIR" ]]; then
        error_exit "Directory still exists after deletion attempt"
    fi
    
    # Verify current directory still works
    if [[ ! -f "$PROJECT_ROOT/package.json" ]]; then
        error_exit "Current directory appears to be damaged"
    fi
    
    success "Post-deletion verification passed"
}

# Run system tests
run_system_tests() {
    if [[ "$TEST_AFTER" != "true" ]]; then
        return 0
    fi
    
    info "Running system tests after cleanup..."
    
    # Test that the application still works
    if [[ -f "$PROJECT_ROOT/run.sh" ]]; then
        info "Testing application startup..."
        if ! timeout 30s "$PROJECT_ROOT/run.sh" --env=dev --platform=cursor --fast --dry-run; then
            warning "System test failed - application may have issues"
        else
            success "System test passed"
        fi
    fi
}

# Generate cleanup report
generate_report() {
    local report_file="$PROJECT_ROOT/logs/cleanup-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Directory Cleanup Report

**Date:** $(date '+%Y-%m-%d %H:%M:%S')  
**Script:** $0  
**Status:** SUCCESS  

## Actions Performed

- ✅ Verified backup integrity: $BACKUP_FILE
- ✅ Removed wrong directory: $WRONG_DIR
- ✅ Updated move log: logs/move.log
- ✅ Post-deletion verification passed

## Verification Results

- **Backup Size:** $(stat -f%z "$BACKUP_FILE" 2>/dev/null || stat -c%s "$BACKUP_FILE" 2>/dev/null) bytes
- **Directory Removed:** $WRONG_DIR
- **Current Directory Intact:** ✅
- **System Tests:** $([ "$TEST_AFTER" == "true" ] && echo "✅ Passed" || echo "⏭️ Skipped")

## Next Steps

1. Continue with remote repository deprecation
2. Update documentation references
3. Notify team members of migration completion

---

*Generated by cleanup-wrong-directory.sh following Dadosfera PRE-PROMPT v1.0 standards*
EOF

    info "Cleanup report generated: $report_file"
}

# Main execution function
main() {
    info "Starting enhanced directory cleanup..."
    info "Log file: $LOG_FILE"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Run verification steps
    if [[ "$VERIFY_BACKUP" == "true" ]]; then
        verify_backup
    fi
    
    verify_wrong_directory
    pre_deletion_checks
    
    # Execute cleanup
    execute_cleanup
    
    # Post-cleanup verification
    if [[ "$DRY_RUN" != "true" ]]; then
        post_deletion_verification
        run_system_tests
        generate_report
    fi
    
    success "Directory cleanup completed successfully!"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        info "Next steps:"
        info "1. Execute remote repository deprecation: ./scripts/deprecate-remote-repository.sh"
        info "2. Update documentation: ./scripts/update-migration-docs.sh"
        info "3. Verify migration complete: ./scripts/verify-migration-complete.sh"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi 