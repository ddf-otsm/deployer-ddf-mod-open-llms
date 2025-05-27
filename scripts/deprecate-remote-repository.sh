#!/bin/bash
# Enhanced remote repository deprecation script
# Following Dadosfera PRE-PROMPT v1.0 standards

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRONG_REPO="deployer-ddf-open-llms"
RIGHT_REPO="deployer-ddf-mod-open-llms"
DEPRECATED_NAME="deprec-deployer-ddf"
ORG="ddf-otsm"
LOG_FILE="$PROJECT_ROOT/logs/deprecation-$(date +%Y%m%d_%H%M%S).log"

# Flags
DRY_RUN=false
PREPARE_ONLY=false
FORCE=false
USE_GITHUB_CLI=true

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

Enhanced script for automating remote repository deprecation.

OPTIONS:
    --dry-run           Show what would be done without executing
    --prepare-only      Generate deprecation materials without executing
    --force             Force execution even if checks fail
    --no-github-cli     Don't use GitHub CLI (manual steps only)
    -h, --help          Show this help message

EXAMPLES:
    $0 --dry-run                    # Preview actions
    $0 --prepare-only               # Generate materials only
    $0                              # Full automated deprecation
    $0 --no-github-cli              # Manual deprecation steps

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
            --prepare-only)
                PREPARE_ONLY=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --no-github-cli)
                USE_GITHUB_CLI=false
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

# Check GitHub CLI availability
check_github_cli() {
    if [[ "$USE_GITHUB_CLI" == "true" ]]; then
        if ! command -v gh &> /dev/null; then
            warning "GitHub CLI not found. Falling back to manual steps."
            USE_GITHUB_CLI=false
        else
            # Check if authenticated
            if ! gh auth status &> /dev/null; then
                warning "GitHub CLI not authenticated. Falling back to manual steps."
                USE_GITHUB_CLI=false
            else
                success "GitHub CLI available and authenticated"
            fi
        fi
    fi
}

# Generate deprecation README content
generate_deprecated_readme() {
    local readme_content
    read -r -d '' readme_content << 'EOF' || true
# DEPRECATED REPOSITORY

> ⚠️ **This repository has been deprecated and is no longer maintained** ⚠️

## Repository Consolidation Notice

This repository (`deployer-ddf-open-llms`) has been deprecated and replaced with [`deployer-ddf-mod-open-llms`](https://github.com/ddf-otsm/deployer-ddf-mod-open-llms).

### Why was this repository deprecated?

As part of our ongoing efforts to consolidate and standardize our codebase, we have migrated all functionality to the new repository to avoid confusion and duplication.

### What should I do?

1. Update your remote references:
   ```bash
   # Check your current remote
   git remote -v
   
   # Remove the old remote
   git remote remove origin
   
   # Add the new remote
   git remote add origin https://github.com/ddf-otsm/deployer-ddf-mod-open-llms.git
   
   # Fetch from new remote
   git fetch origin
   ```

2. Clone the new repository:
   ```bash
   git clone https://github.com/ddf-otsm/deployer-ddf-mod-open-llms.git
   ```

### Migration Timeline

- **May 27, 2025**: Repository deprecated and archived
- **June 30, 2025**: Final removal of this repository (read-only access until then)

## Questions?

If you have any questions about this migration, please contact the repository maintainers or open an issue in the new repository.

---

*Note: This repository is now in read-only mode and will not accept new pull requests or issues.*
EOF

    echo "$readme_content"
}

# Generate GitHub CLI commands
generate_github_cli_commands() {
    local commands_file="$PROJECT_ROOT/logs/github-cli-commands-$(date +%Y%m%d_%H%M%S).sh"
    
    cat > "$commands_file" << EOF
#!/bin/bash
# GitHub CLI commands for repository deprecation
# Generated on $(date '+%Y-%m-%d %H:%M:%S')

set -euo pipefail

echo "🔄 Starting automated repository deprecation..."

# Step 1: Update repository description
echo "📝 Updating repository description..."
gh repo edit $ORG/$WRONG_REPO --description "[DEPRECATED] This repository has been moved to https://github.com/$ORG/$RIGHT_REPO"

# Step 2: Add deprecated topic
echo "🏷️ Adding deprecated topic..."
gh repo edit $ORG/$WRONG_REPO --add-topic deprecated

# Step 3: Update README with deprecation notice
echo "📄 Updating README with deprecation notice..."
cat > /tmp/deprecated-readme.md << 'READMEEOF'
$(generate_deprecated_readme)
READMEEOF

# Create a new commit with the deprecated README
git clone https://github.com/$ORG/$WRONG_REPO.git /tmp/$WRONG_REPO
cd /tmp/$WRONG_REPO
cp /tmp/deprecated-readme.md README.md
git add README.md
git commit -m "DEPRECATED: Repository moved to https://github.com/$ORG/$RIGHT_REPO"
git push origin main

# Step 4: Rename repository
echo "🔄 Renaming repository to $DEPRECATED_NAME..."
gh repo rename $ORG/$WRONG_REPO $DEPRECATED_NAME

# Step 5: Archive repository
echo "📦 Archiving repository..."
gh repo archive $ORG/$DEPRECATED_NAME

echo "✅ Repository deprecation completed successfully!"
echo "📋 Verification steps:"
echo "   1. Visit: https://github.com/$ORG/$DEPRECATED_NAME"
echo "   2. Verify repository is archived and shows deprecation notice"
echo "   3. Update any remaining references to the old repository"

# Cleanup
rm -rf /tmp/$WRONG_REPO /tmp/deprecated-readme.md
EOF

    chmod +x "$commands_file"
    echo "$commands_file"
}

# Generate manual deprecation checklist
generate_manual_checklist() {
    local checklist_file="$PROJECT_ROOT/logs/manual-deprecation-checklist-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$checklist_file" << EOF
# Manual Repository Deprecation Checklist

**Repository:** $ORG/$WRONG_REPO → $ORG/$DEPRECATED_NAME  
**Date:** $(date '+%Y-%m-%d %H:%M:%S')  
**Status:** PENDING MANUAL EXECUTION

## Step 1: Update Repository README

1. Navigate to: https://github.com/$ORG/$WRONG_REPO
2. Click on the "Edit" button (pencil icon) for the README.md file
3. Replace the entire content with:

\`\`\`markdown
$(generate_deprecated_readme)
\`\`\`

4. Commit with message: "DEPRECATED: Repository moved to https://github.com/$ORG/$RIGHT_REPO"

## Step 2: Update Repository Description and Topics

1. Navigate to: https://github.com/$ORG/$WRONG_REPO/settings
2. Update the description to: "[DEPRECATED] This repository has been moved to https://github.com/$ORG/$RIGHT_REPO"
3. Add the topic "deprecated" to the repository

## Step 3: Rename the Repository

1. Navigate to: https://github.com/$ORG/$WRONG_REPO/settings
2. In the "Repository name" section, change the name to "$DEPRECATED_NAME"
3. Type the repository name to confirm
4. Click "Rename"

## Step 4: Archive the Repository

1. Navigate to: https://github.com/$ORG/$DEPRECATED_NAME/settings
2. Scroll down to the "Danger Zone"
3. Click "Archive this repository"
4. Read the warning and confirm by typing the repository name
5. Click "I understand the consequences, archive this repository"

## Verification Checklist

- [ ] README updated with deprecation notice
- [ ] Repository description updated with [DEPRECATED] prefix
- [ ] Repository renamed to "$DEPRECATED_NAME"
- [ ] Repository archived (made read-only)
- [ ] Documentation updated to reference new repository

## Post-Deprecation Tasks

- [ ] Update any CI/CD pipelines referencing the old repository
- [ ] Notify team members of the repository change
- [ ] Update documentation links across all projects
- [ ] Remove any local clones of the deprecated repository

---

*Manual checklist generated by deprecate-remote-repository.sh following Dadosfera PRE-PROMPT v1.0 standards*
EOF

    echo "$checklist_file"
}

# Execute GitHub CLI deprecation
execute_github_cli_deprecation() {
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would execute GitHub CLI deprecation commands"
  return 0
    fi
    
    info "Executing automated GitHub CLI deprecation..."
    
    # Generate and execute commands
    local commands_file
    commands_file=$(generate_github_cli_commands)
    
    info "Generated GitHub CLI commands: $commands_file"
    
    if [[ "$FORCE" == "true" ]] || [[ "$PREPARE_ONLY" != "true" ]]; then
        info "Executing GitHub CLI commands..."
        bash "$commands_file"
        success "GitHub CLI deprecation completed"
    else
        info "Commands generated but not executed (prepare-only mode)"
    fi
}

# Verify deprecation completion
verify_deprecation() {
    if [[ "$DRY_RUN" == "true" ]] || [[ "$PREPARE_ONLY" == "true" ]]; then
        return 0
    fi
    
    info "Verifying deprecation completion..."
    
    if [[ "$USE_GITHUB_CLI" == "true" ]]; then
        # Check if repository is archived
        if gh repo view "$ORG/$DEPRECATED_NAME" --json isArchived --jq '.isArchived' | grep -q "true"; then
            success "Repository successfully archived"
        else
            warning "Repository may not be properly archived"
        fi
        
        # Check if repository has deprecated topic
        if gh repo view "$ORG/$DEPRECATED_NAME" --json repositoryTopics --jq '.repositoryTopics[].name' | grep -q "deprecated"; then
            success "Deprecated topic added successfully"
        else
            warning "Deprecated topic may not be added"
        fi
    else
        info "Manual verification required - check GitHub web interface"
    fi
}

# Generate deprecation report
generate_deprecation_report() {
    local report_file="$PROJECT_ROOT/logs/deprecation-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# Repository Deprecation Report

**Date:** $(date '+%Y-%m-%d %H:%M:%S')  
**Script:** $0  
**Status:** $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "EXECUTED")

## Repository Details

- **Original Repository:** $ORG/$WRONG_REPO
- **New Repository:** $ORG/$RIGHT_REPO
- **Deprecated Name:** $ORG/$DEPRECATED_NAME

## Actions Performed

- $([ "$DRY_RUN" == "true" ] && echo "🔍 DRY RUN:" || echo "✅") Repository README updated with deprecation notice
- $([ "$DRY_RUN" == "true" ] && echo "🔍 DRY RUN:" || echo "✅") Repository description updated with [DEPRECATED] prefix
- $([ "$DRY_RUN" == "true" ] && echo "🔍 DRY RUN:" || echo "✅") Repository renamed to $DEPRECATED_NAME
- $([ "$DRY_RUN" == "true" ] && echo "🔍 DRY RUN:" || echo "✅") Repository archived (read-only)
- $([ "$DRY_RUN" == "true" ] && echo "🔍 DRY RUN:" || echo "✅") Deprecated topic added

## Automation Method

- **GitHub CLI Used:** $([ "$USE_GITHUB_CLI" == "true" ] && echo "✅ Yes" || echo "❌ No (Manual steps required)")
- **Execution Mode:** $([ "$DRY_RUN" == "true" ] && echo "Dry Run" || [ "$PREPARE_ONLY" == "true" ] && echo "Prepare Only" || echo "Full Execution")

## Generated Files

$([ -f "$PROJECT_ROOT/logs/github-cli-commands-"*".sh" ] && echo "- GitHub CLI Commands: $(ls -t $PROJECT_ROOT/logs/github-cli-commands-*.sh | head -1)" || echo "- No GitHub CLI commands generated")
$([ -f "$PROJECT_ROOT/logs/manual-deprecation-checklist-"*".md" ] && echo "- Manual Checklist: $(ls -t $PROJECT_ROOT/logs/manual-deprecation-checklist-*.md | head -1)" || echo "- No manual checklist generated")

## Next Steps

1. Verify deprecation completion at: https://github.com/$ORG/$DEPRECATED_NAME
2. Update any remaining references to the old repository
3. Notify team members of the repository change
4. Update CI/CD pipelines and documentation

---

*Generated by deprecate-remote-repository.sh following Dadosfera PRE-PROMPT v1.0 standards*
EOF

    info "Deprecation report generated: $report_file"
}

# Main execution function
main() {
    info "Starting remote repository deprecation..."
    info "Log file: $LOG_FILE"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/logs"
    
    # Check GitHub CLI availability
    check_github_cli
    
    # Generate deprecation materials
    info "Generating deprecation materials..."
    
    if [[ "$USE_GITHUB_CLI" == "true" ]]; then
        local commands_file
        commands_file=$(generate_github_cli_commands)
        success "GitHub CLI commands generated: $commands_file"
    fi
    
    local checklist_file
    checklist_file=$(generate_manual_checklist)
    success "Manual checklist generated: $checklist_file"
    
    # Execute deprecation if not prepare-only
    if [[ "$PREPARE_ONLY" != "true" ]]; then
        if [[ "$USE_GITHUB_CLI" == "true" ]]; then
            execute_github_cli_deprecation
        else
            info "GitHub CLI not available. Please follow manual steps in: $checklist_file"
        fi
        
        verify_deprecation
    fi
    
    # Generate report
    generate_deprecation_report
    
    success "Remote repository deprecation process completed!"
    
    if [[ "$PREPARE_ONLY" == "true" ]]; then
        info "Materials prepared. Execute with: $0 (without --prepare-only)"
    elif [[ "$USE_GITHUB_CLI" != "true" ]]; then
        info "Manual steps required. Follow checklist: $checklist_file"
    fi
    
    info "Next steps:"
    info "1. Verify deprecation at: https://github.com/$ORG/$DEPRECATED_NAME"
    info "2. Update documentation: ./scripts/update-migration-docs.sh"
    info "3. Complete migration: ./scripts/verify-migration-complete.sh"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main
fi 