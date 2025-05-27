#!/bin/bash
# Port Manager Script
# Handles port checking, service killing, and port management

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_PORTS=(7001 7002 7003 11434)  # API, Frontend, Test, Ollama
TIMEOUT=5

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

header() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================${NC}"
}

# Show usage
show_usage() {
    cat << EOF
Port Manager Script

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    check [PORT...]        Check if ports are available
    kill [PORT...]         Kill processes using specified ports
    kill-all              Kill all project-related processes
    status                 Show status of all project ports
    find-free [COUNT]      Find COUNT free ports starting from 7001
    cleanup                Kill services and clean up ports

OPTIONS:
    --timeout SECONDS      Timeout for operations [default: 5]
    --verbose             Enable verbose logging
    -h, --help            Show this help message

EXAMPLES:
    # Check if default ports are available
    $0 check

    # Kill process on specific port
    $0 kill 7001

    # Kill all project services
    $0 kill-all

    # Find 3 free ports
    $0 find-free 3

    # Full cleanup
    $0 cleanup

EOF
}

# Parse command line arguments
parse_args() {
    local command=""
    local ports=()
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            check|kill|kill-all|status|find-free|cleanup)
                command="$1"
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --timeout=*)
                TIMEOUT="${1#*=}"
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            [0-9]*)
                ports+=("$1")
                shift
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    export COMMAND="$command"
    export PORTS=("${ports[@]:-${DEFAULT_PORTS[@]}}")
    export VERBOSE="$verbose"
}

# Check if port is in use
is_port_in_use() {
    local port="$1"
    
    if command -v lsof >/dev/null 2>&1; then
        lsof -i ":$port" >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -an | grep -q ":$port.*LISTEN"
    else
        # Fallback: try to connect
        timeout "$TIMEOUT" bash -c "</dev/tcp/localhost/$port" >/dev/null 2>&1
    fi
}

# Get process using port
get_port_process() {
    local port="$1"
    
    if command -v lsof >/dev/null 2>&1; then
        lsof -ti ":$port" 2>/dev/null | head -1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1
    else
        echo ""
    fi
}

# Get process info
get_process_info() {
    local pid="$1"
    
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
        ps -p "$pid" -o pid,ppid,comm,args --no-headers 2>/dev/null
    else
        echo ""
    fi
}

# Check ports
check_ports() {
    header "🔍 CHECKING PORTS"
    
    local all_free=true
    
    for port in "${PORTS[@]}"; do
        if is_port_in_use "$port"; then
            local pid=$(get_port_process "$port")
            local process_info=$(get_process_info "$pid")
            
            warning "Port $port is in use"
            if [[ -n "$process_info" ]]; then
                echo "   Process: $process_info"
            fi
            all_free=false
        else
            success "Port $port is available"
        fi
    done
    
    if [[ "$all_free" == "true" ]]; then
        success "All ports are available!"
        return 0
    else
        warning "Some ports are in use"
        return 1
    fi
}

# Kill processes on ports
kill_ports() {
    header "💀 KILLING PROCESSES ON PORTS"
    
    local killed_count=0
    
    for port in "${PORTS[@]}"; do
        if is_port_in_use "$port"; then
            local pid=$(get_port_process "$port")
            
            if [[ -n "$pid" ]]; then
                local process_info=$(get_process_info "$pid")
                log "Killing process on port $port (PID: $pid)"
                
                if [[ "$VERBOSE" == "true" && -n "$process_info" ]]; then
                    echo "   Process: $process_info"
                fi
                
                if kill "$pid" 2>/dev/null; then
                    sleep 1
                    
                    # Force kill if still running
                    if ps -p "$pid" >/dev/null 2>&1; then
                        kill -9 "$pid" 2>/dev/null || true
                        sleep 1
                    fi
                    
                    if ! is_port_in_use "$port"; then
                        success "Killed process on port $port"
                        ((killed_count++))
                    else
                        error "Failed to free port $port"
                    fi
                else
                    error "Failed to kill process $pid on port $port"
                fi
            else
                warning "Could not find process for port $port"
            fi
        else
            log "Port $port is already free"
        fi
    done
    
    if [[ $killed_count -gt 0 ]]; then
        success "Killed $killed_count processes"
    else
        log "No processes were killed"
    fi
}

# Kill all project-related processes
kill_all_project() {
    header "💀 KILLING ALL PROJECT PROCESSES"
    
    local patterns=(
        "tsx.*src/index.ts"
        "node.*src/index.ts"
        "npm.*run.*dev"
        "deployer-ddf"
        "ollama-server"
    )
    
    local killed_count=0
    
    for pattern in "${patterns[@]}"; do
        log "Looking for processes matching: $pattern"
        
        local pids=$(pgrep -f "$pattern" 2>/dev/null || true)
        
        if [[ -n "$pids" ]]; then
            for pid in $pids; do
                local process_info=$(get_process_info "$pid")
                
                if [[ -n "$process_info" ]]; then
                    log "Killing: $process_info"
                    
                    if kill "$pid" 2>/dev/null; then
                        sleep 1
                        
                        # Force kill if still running
                        if ps -p "$pid" >/dev/null 2>&1; then
                            kill -9 "$pid" 2>/dev/null || true
                        fi
                        
                        success "Killed process $pid"
                        ((killed_count++))
                    else
                        error "Failed to kill process $pid"
                    fi
                fi
            done
        fi
    done
    
    # Also kill by ports
    PORTS=("${DEFAULT_PORTS[@]}")
    kill_ports
    
    success "Killed $killed_count project processes"
}

# Show port status
show_status() {
    header "📊 PORT STATUS"
    
    echo "Project Ports:"
    echo "  API Server: 7001"
    echo "  Frontend: 7002"
    echo "  Test Server: 7003"
    echo "  Ollama: 11434"
    echo
    
    for port in "${DEFAULT_PORTS[@]}"; do
        if is_port_in_use "$port"; then
            local pid=$(get_port_process "$port")
            local process_info=$(get_process_info "$pid")
            
            echo -e "${RED}❌ Port $port: IN USE${NC}"
            if [[ -n "$process_info" ]]; then
                echo "   $process_info"
            fi
        else
            echo -e "${GREEN}✅ Port $port: AVAILABLE${NC}"
        fi
    done
}

# Find free ports
find_free_ports() {
    local count="${1:-3}"
    local start_port=7001
    local found_ports=()
    
    header "🔍 FINDING $count FREE PORTS"
    
    for ((port=start_port; port<=9999 && ${#found_ports[@]}<count; port++)); do
        if ! is_port_in_use "$port"; then
            found_ports+=("$port")
            success "Found free port: $port"
        fi
    done
    
    if [[ ${#found_ports[@]} -eq $count ]]; then
        echo
        echo "Free ports: ${found_ports[*]}"
        return 0
    else
        error "Could only find ${#found_ports[@]} free ports out of $count requested"
        return 1
    fi
}

# Full cleanup
cleanup() {
    header "🧹 FULL CLEANUP"
    
    log "Stopping all project services..."
    kill_all_project
    
    log "Waiting for ports to be freed..."
    sleep 3
    
    log "Checking port status..."
    check_ports
    
    log "Cleaning up temporary files..."
    find "$PROJECT_ROOT" -name "*.pid" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name "*.lock" -delete 2>/dev/null || true
    
    success "Cleanup completed!"
}

# Main execution
main() {
    case "${COMMAND:-}" in
        check)
            check_ports
            ;;
        kill)
            kill_ports
            ;;
        kill-all)
            kill_all_project
            ;;
        status)
            show_status
            ;;
        find-free)
            find_free_ports "${PORTS[0]:-3}"
            ;;
        cleanup)
            cleanup
            ;;
        "")
            error "No command specified"
            show_usage
            exit 1
            ;;
        *)
            error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

# Parse arguments and run
parse_args "$@"
main 