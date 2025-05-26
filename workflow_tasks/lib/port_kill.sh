#!/bin/bash
# Port management helper for workflow_tasks
# Handles killing processes on ports and port fallback logic

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Kill process on specific port
kill_port() {
    local port="$1"
    local force="${2:-false}"
    
    if [[ -z "$port" ]]; then
        log_error "Port number required" "port_kill.sh"
        return 1
    fi
    
    log_info "Checking for processes on port $port" "port_kill.sh"
    
    # Find processes using the port
    local pids=$(lsof -ti:$port 2>/dev/null)
    
    if [[ -z "$pids" ]]; then
        log_info "No processes found on port $port" "port_kill.sh"
        return 0
    fi
    
    log_info "Found processes on port $port: $pids" "port_kill.sh"
    
    # Kill processes
    for pid in $pids; do
        if [[ "$force" == "true" ]]; then
            log_info "Force killing process $pid on port $port" "port_kill.sh"
            kill -9 "$pid" 2>/dev/null
        else
            log_info "Gracefully terminating process $pid on port $port" "port_kill.sh"
            kill -TERM "$pid" 2>/dev/null
            
            # Wait a moment for graceful shutdown
            sleep 2
            
            # Check if process is still running
            if kill -0 "$pid" 2>/dev/null; then
                log_warn "Process $pid didn't terminate gracefully, force killing" "port_kill.sh"
                kill -9 "$pid" 2>/dev/null
            fi
        fi
    done
    
    # Verify port is free
    sleep 1
    local remaining_pids=$(lsof -ti:$port 2>/dev/null)
    if [[ -n "$remaining_pids" ]]; then
        log_error "Failed to free port $port, remaining processes: $remaining_pids" "port_kill.sh"
        return 1
    fi
    
    log_success "Port $port is now free" "port_kill.sh"
    return 0
}

# Check if port is available
is_port_available() {
    local port="$1"
    
    if [[ -z "$port" ]]; then
        log_error "Port number required" "port_kill.sh"
        return 1
    fi
    
    # Check if port is in use
    if lsof -ti:$port >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Find next available port starting from given port
find_available_port() {
    local start_port="$1"
    local max_attempts="${2:-10}"
    
    if [[ -z "$start_port" ]]; then
        log_error "Starting port number required" "port_kill.sh"
        return 1
    fi
    
    local current_port="$start_port"
    local attempts=0
    
    while [[ $attempts -lt $max_attempts ]]; do
        if is_port_available "$current_port"; then
            echo "$current_port"
            return 0
        fi
        
        current_port=$((current_port + 1))
        attempts=$((attempts + 1))
    done
    
    log_error "Could not find available port after $max_attempts attempts starting from $start_port" "port_kill.sh"
    return 1
}

# Kill multiple ports
kill_ports() {
    local ports=("$@")
    local failed_ports=()
    
    if [[ ${#ports[@]} -eq 0 ]]; then
        log_error "No ports specified" "port_kill.sh"
        return 1
    fi
    
    log_info "Killing processes on ports: ${ports[*]}" "port_kill.sh"
    
    for port in "${ports[@]}"; do
        if ! kill_port "$port"; then
            failed_ports+=("$port")
        fi
    done
    
    if [[ ${#failed_ports[@]} -gt 0 ]]; then
        log_error "Failed to free ports: ${failed_ports[*]}" "port_kill.sh"
        return 1
    fi
    
    log_success "All specified ports are now free" "port_kill.sh"
    return 0
}

# Kill common development ports
kill_common_ports() {
    local common_ports=(3000 3001 8000 8080 9000 9090)
    
    log_info "Killing processes on common development ports" "port_kill.sh"
    
    for port in "${common_ports[@]}"; do
        kill_port "$port" "false"  # Don't fail if port is already free
    done
}

# Port fallback logic for applications
setup_port_fallback() {
    local preferred_port="$1"
    local app_name="${2:-application}"
    
    if [[ -z "$preferred_port" ]]; then
        log_error "Preferred port required" "port_kill.sh"
        return 1
    fi
    
    log_info "Setting up port fallback for $app_name (preferred: $preferred_port)" "port_kill.sh"
    
    # Try to free the preferred port first
    if ! is_port_available "$preferred_port"; then
        log_warn "Preferred port $preferred_port is in use, attempting to free it" "port_kill.sh"
        if ! kill_port "$preferred_port"; then
            log_warn "Could not free preferred port $preferred_port, looking for alternative" "port_kill.sh"
            local fallback_port=$(find_available_port "$preferred_port")
            if [[ $? -eq 0 ]]; then
                log_info "Using fallback port $fallback_port for $app_name" "port_kill.sh"
                echo "$fallback_port"
                return 0
            else
                log_error "Could not find any available port for $app_name" "port_kill.sh"
                return 1
            fi
        fi
    fi
    
    log_success "Using preferred port $preferred_port for $app_name" "port_kill.sh"
    echo "$preferred_port"
    return 0
}

# Export functions
export -f kill_port is_port_available find_available_port kill_ports kill_common_ports setup_port_fallback 