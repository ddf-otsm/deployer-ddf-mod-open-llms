#!/bin/bash
# Centralized logging helper for workflow_tasks
# Provides structured JSON logging with fallback to console

# Global variables
LOG_DIR="${LOG_DIR:-logs}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
LOG_FILE="${LOG_DIR}/${RUN_ID}/combined-${RUN_ID}.log"

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize logging
init_logging() {
    local log_dir="$1"
    local run_id="$2"
    
    LOG_DIR="${log_dir:-logs}"
    RUN_ID="${run_id:-$(date +%Y%m%d_%H%M%S)}"
    LOG_FILE="${LOG_DIR}/${RUN_ID}/combined-${RUN_ID}.log"
    
    # Create log directory
    mkdir -p "${LOG_DIR}/${RUN_ID}"
    
    # Initialize log file with metadata
    cat > "$LOG_FILE" << EOF
{"timestamp":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","level":"INFO","message":"Log session started","run_id":"$RUN_ID","script":"logging.sh"}
EOF
}

# Main logging function
log_message() {
    local level="$1"
    local message="$2"
    local script="${3:-unknown}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Ensure log directory exists
    if [[ ! -d "${LOG_DIR}/${RUN_ID}" ]]; then
        mkdir -p "${LOG_DIR}/${RUN_ID}"
    fi
    
    # Create structured log entry
    local log_entry="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"script\":\"$script\",\"run_id\":\"$RUN_ID\"}"
    
    # Write to log file (with fallback)
    if [[ -w "${LOG_DIR}/${RUN_ID}" ]]; then
        echo "$log_entry" >> "$LOG_FILE"
    else
        # Fallback to console if file logging fails
        echo "[FALLBACK] $log_entry" >&2
    fi
    
    # Console output with colors
    case $level in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        INFO)    echo -e "${GREEN}[INFO]${NC} $message" ;;
        DEBUG)   [[ "${DEBUG:-false}" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        STEP)    echo -e "${CYAN}[STEP]${NC} $message" ;;
        *)       echo -e "${PURPLE}[$level]${NC} $message" ;;
    esac
}

# Convenience functions
log_error() { log_message "ERROR" "$1" "${2:-$(basename "$0")}" ; }
log_warn() { log_message "WARN" "$1" "${2:-$(basename "$0")}" ; }
log_info() { log_message "INFO" "$1" "${2:-$(basename "$0")}" ; }
log_debug() { log_message "DEBUG" "$1" "${2:-$(basename "$0")}" ; }
log_success() { log_message "SUCCESS" "$1" "${2:-$(basename "$0")}" ; }
log_step() { log_message "STEP" "$1" "${2:-$(basename "$0")}" ; }

# Progress indicator
show_spinner() {
    local pid=$1
    local message="$2"
    local delay=0.1
    local spinstr='|/-\'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] %s\r" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "    \r"
}

# Export functions for use in other scripts
export -f log_message log_error log_warn log_info log_debug log_success log_step show_spinner init_logging 