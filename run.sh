#!/bin/bash
# Root run.sh wrapper - delegates to workflow_tasks/run.sh
# Follows Dadosfera Run-Script & Repository Blueprint v2.1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_SCRIPT="$SCRIPT_DIR/workflow_tasks/run.sh"

# Check if workflow_tasks/run.sh exists
if [[ ! -f "$WORKFLOW_SCRIPT" ]]; then
    echo "ERROR: workflow_tasks/run.sh not found"
    echo "Please ensure the repository structure follows the blueprint"
    exit 1
fi

# Delegate all arguments to the main workflow script
exec "$WORKFLOW_SCRIPT" "$@" 