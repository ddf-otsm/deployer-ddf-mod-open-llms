#!/bin/bash
# deployer-ddf-mod-llm-models/scripts/deploy/manage.sh
# Instance management for AI Testing Agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default configuration
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
ACTION=""
INSTANCE_COUNT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 ACTION [OPTIONS]

Manage AI Testing Agent instances on AWS.

ACTIONS:
    start                   Start AI Testing Agent instances
    stop                    Stop AI Testing Agent instances
    restart                 Restart AI Testing Agent instances
    scale COUNT             Scale to specified number of instances
    status                  Show current status
    logs                    Show recent logs
    cost                    Show cost information

OPTIONS:
    --env=ENV               Environment (dev|staging|prod) [default: dev]
    --region=REGION        AWS region [default: us-east-1]
    --help                 Show this help message

EXAMPLES:
    $0 start --env=prod --region=us-west-2
    $0 scale 5 --env=staging
    $0 stop --env=dev
    $0 status --env=prod
    $0 cost --env=staging

MANAGEMENT FEATURES:
    - Start/stop ECS services
    - Scale instance count
    - Monitor service status
    - View logs and metrics
    - Track costs and usage

EOF
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    error "No action specified"
    usage
    exit 1
fi

# Check for help first
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

ACTION="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --env=*)
            ENVIRONMENT="${1#*=}"
            shift
            ;;
        --region=*)
            AWS_REGION="${1#*=}"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            if [[ "$ACTION" == "scale" && -z "$INSTANCE_COUNT" ]]; then
                INSTANCE_COUNT="$1"
                shift
            else
                error "Unknown option: $1"
                usage
                exit 1
            fi
            ;;
    esac
done

# Validate inputs
validate_inputs() {
    log "Validating management parameters..."
    
    # Validate environment
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        error "Invalid environment: $ENVIRONMENT. Must be dev, staging, or prod."
        exit 1
    fi
    
    # Validate action
    if [[ ! "$ACTION" =~ ^(start|stop|restart|scale|status|logs|cost)$ ]]; then
        error "Invalid action: $ACTION. Must be start, stop, restart, scale, status, logs, or cost."
        exit 1
    fi
    
    # Validate instance count for scale action
    if [[ "$ACTION" == "scale" ]]; then
        if [[ -z "$INSTANCE_COUNT" ]]; then
            error "Instance count required for scale action"
            exit 1
        fi
        if ! [[ "$INSTANCE_COUNT" =~ ^[0-9]+$ ]] || [ "$INSTANCE_COUNT" -lt 0 ] || [ "$INSTANCE_COUNT" -gt 20 ]; then
            error "Invalid instance count: $INSTANCE_COUNT. Must be between 0 and 20."
            exit 1
        fi
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    success "All parameters validated successfully"
}

# Get cluster and service names
get_service_info() {
    local stack_name="deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    # Get cluster name from CloudFormation stack
    local cluster_name
    if cluster_name=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
        --output text 2>/dev/null); then
        echo "cluster:$cluster_name"
    else
        # Fallback to standard naming
        echo "cluster:deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    fi
    
    # Service name is typically the same as stack name
    echo "service:deployer-ddf-mod-llm-models"
}

# Start instances
start_instances() {
    log "Starting AI Testing Agent instances..."
    
    local service_info
    service_info=$(get_service_info)
    local cluster_name=$(echo "$service_info" | grep "cluster:" | cut -d: -f2)
    local service_name=$(echo "$service_info" | grep "service:" | cut -d: -f2)
    
    log "Cluster: $cluster_name"
    log "Service: $service_name"
    
    # Get current desired count
    local current_count
    if current_count=$(aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --region "$AWS_REGION" \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null); then
        
        if [[ "$current_count" == "0" ]]; then
            # Start with 2 instances by default
            local target_count="2"
            
            log "Starting service with $target_count instances..."
            
            aws ecs update-service \
                --cluster "$cluster_name" \
                --service "$service_name" \
                --desired-count "$target_count" \
                --region "$AWS_REGION" > /dev/null
            
            success "Service start initiated. Target count: $target_count"
            
            # Wait for service to stabilize
            log "Waiting for service to stabilize..."
            aws ecs wait services-stable \
                --cluster "$cluster_name" \
                --services "$service_name" \
                --region "$AWS_REGION"
            
            success "Service started successfully!"
        else
            warning "Service is already running with $current_count instances"
        fi
    else
        error "Could not find service: $service_name in cluster: $cluster_name"
        return 1
    fi
}

# Stop instances
stop_instances() {
    log "Stopping AI Testing Agent instances..."
    
    local service_info
    service_info=$(get_service_info)
    local cluster_name=$(echo "$service_info" | grep "cluster:" | cut -d: -f2)
    local service_name=$(echo "$service_info" | grep "service:" | cut -d: -f2)
    
    log "Cluster: $cluster_name"
    log "Service: $service_name"
    
    log "Scaling service to 0 instances..."
    
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --desired-count 0 \
        --region "$AWS_REGION" > /dev/null
    
    success "Service stop initiated"
    
    # Wait for service to scale down
    log "Waiting for instances to stop..."
    local max_wait=300
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        local running_count
        if running_count=$(aws ecs describe-services \
            --cluster "$cluster_name" \
            --services "$service_name" \
            --region "$AWS_REGION" \
            --query 'services[0].runningCount' \
            --output text 2>/dev/null); then
            
            if [[ "$running_count" == "0" ]]; then
                success "All instances stopped successfully!"
                return 0
            fi
            
            log "Waiting for $running_count instances to stop..."
            sleep 10
            wait_time=$((wait_time + 10))
        else
            error "Could not check service status"
            return 1
        fi
    done
    
    warning "Timeout waiting for instances to stop. Some instances may still be running."
}

# Restart instances
restart_instances() {
    log "Restarting AI Testing Agent instances..."
    
    # Get current desired count before stopping
    local service_info
    service_info=$(get_service_info)
    local cluster_name=$(echo "$service_info" | grep "cluster:" | cut -d: -f2)
    local service_name=$(echo "$service_info" | grep "service:" | cut -d: -f2)
    
    local current_count
    if current_count=$(aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --region "$AWS_REGION" \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null); then
        
        log "Current instance count: $current_count"
        
        # Stop instances
        stop_instances
        
        # Wait a moment
        sleep 5
        
        # Start instances with previous count
        if [[ "$current_count" -gt 0 ]]; then
            scale_instances "$current_count"
        else
            start_instances
        fi
        
        success "Service restarted successfully!"
    else
        error "Could not determine current instance count"
        return 1
    fi
}

# Scale instances
scale_instances() {
    local target_count="$1"
    
    log "Scaling AI Testing Agent to $target_count instances..."
    
    local service_info
    service_info=$(get_service_info)
    local cluster_name=$(echo "$service_info" | grep "cluster:" | cut -d: -f2)
    local service_name=$(echo "$service_info" | grep "service:" | cut -d: -f2)
    
    log "Cluster: $cluster_name"
    log "Service: $service_name"
    
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --desired-count "$target_count" \
        --region "$AWS_REGION" > /dev/null
    
    success "Scaling initiated. Target count: $target_count"
    
    # Wait for service to stabilize
    if [[ "$target_count" -gt 0 ]]; then
        log "Waiting for service to stabilize..."
        aws ecs wait services-stable \
            --cluster "$cluster_name" \
            --services "$service_name" \
            --region "$AWS_REGION"
        
        success "Service scaled successfully!"
    else
        log "Waiting for instances to stop..."
        # Use the stop_instances logic for waiting
        local max_wait=300
        local wait_time=0
        
        while [[ $wait_time -lt $max_wait ]]; do
            local running_count
            if running_count=$(aws ecs describe-services \
                --cluster "$cluster_name" \
                --services "$service_name" \
                --region "$AWS_REGION" \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null); then
                
                if [[ "$running_count" == "0" ]]; then
                    success "All instances stopped successfully!"
                    return 0
                fi
                
                log "Waiting for $running_count instances to stop..."
                sleep 10
                wait_time=$((wait_time + 10))
            else
                error "Could not check service status"
                return 1
            fi
        done
    fi
}

# Show status
show_status() {
    log "Getting AI Testing Agent status..."
    
    local service_info
    service_info=$(get_service_info)
    local cluster_name=$(echo "$service_info" | grep "cluster:" | cut -d: -f2)
    local service_name=$(echo "$service_info" | grep "service:" | cut -d: -f2)
    
    echo
    echo "=================================="
    echo "AI Testing Agent Status"
    echo "=================================="
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Cluster: $cluster_name"
    echo "Service: $service_name"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    
    # Get service details
    local service_details
    if service_details=$(aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null); then
        
        local status=$(echo "$service_details" | jq -r '.services[0].status')
        local desired_count=$(echo "$service_details" | jq -r '.services[0].desiredCount')
        local running_count=$(echo "$service_details" | jq -r '.services[0].runningCount')
        local pending_count=$(echo "$service_details" | jq -r '.services[0].pendingCount')
        
        echo "Service Status: $status"
        echo "Desired Count: $desired_count"
        echo "Running Count: $running_count"
        echo "Pending Count: $pending_count"
        echo
        
        # Get task details
        if [[ "$running_count" -gt 0 ]]; then
            log "Getting task details..."
            
            local task_arns
            if task_arns=$(aws ecs list-tasks \
                --cluster "$cluster_name" \
                --service-name "$service_name" \
                --region "$AWS_REGION" \
                --query 'taskArns' \
                --output text 2>/dev/null); then
                
                if [[ -n "$task_arns" ]]; then
                    local task_details
                    if task_details=$(aws ecs describe-tasks \
                        --cluster "$cluster_name" \
                        --tasks $task_arns \
                        --region "$AWS_REGION" \
                        --output json 2>/dev/null); then
                        
                        echo "Task Details:"
                        echo "$task_details" | jq -r '.tasks[] | "  Task: \(.taskArn | split("/") | last) | Status: \(.lastStatus) | Health: \(.healthStatus // "N/A") | CPU: \(.cpu) | Memory: \(.memory)"'
                        echo
                    fi
                fi
            fi
        fi
        
        # Health status
        if [[ "$running_count" -eq "$desired_count" && "$desired_count" -gt 0 ]]; then
            success "Service is healthy and running normally"
        elif [[ "$desired_count" -eq 0 ]]; then
            warning "Service is stopped (desired count is 0)"
        elif [[ "$running_count" -lt "$desired_count" ]]; then
            warning "Service is scaling up ($running_count/$desired_count running)"
        else
            warning "Service status unclear"
        fi
        
    else
        error "Could not retrieve service status"
        return 1
    fi
}

# Show logs
show_logs() {
    log "Getting AI Testing Agent logs..."
    
    local service_info
    service_info=$(get_service_info)
    local cluster_name=$(echo "$service_info" | grep "cluster:" | cut -d: -f2)
    local service_name=$(echo "$service_info" | grep "service:" | cut -d: -f2)
    
    # Get log group name
    local log_group="/ecs/deployer-ddf-mod-llm-models-${ENVIRONMENT}"
    
    log "Log group: $log_group"
    
    # Get recent log events
    if aws logs describe-log-groups \
        --log-group-name-prefix "$log_group" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        
        log "Fetching recent logs..."
        
        # Get log streams
        local log_streams
        if log_streams=$(aws logs describe-log-streams \
            --log-group-name "$log_group" \
            --order-by LastEventTime \
            --descending \
            --max-items 5 \
            --region "$AWS_REGION" \
            --query 'logStreams[].logStreamName' \
            --output text 2>/dev/null); then
            
            echo
            echo "Recent Logs:"
            echo "============"
            
            for stream in $log_streams; do
                echo
                echo "Log Stream: $stream"
                echo "---"
                
                aws logs get-log-events \
                    --log-group-name "$log_group" \
                    --log-stream-name "$stream" \
                    --start-time $(($(date +%s) * 1000 - 3600000)) \
                    --region "$AWS_REGION" \
                    --query 'events[].message' \
                    --output text 2>/dev/null | tail -20
            done
        else
            warning "No log streams found"
        fi
    else
        warning "Log group not found: $log_group"
    fi
}

# Show cost information
show_cost() {
    log "Getting cost information..."
    
    echo
    echo "=================================="
    echo "AI Testing Agent Cost Information"
    echo "=================================="
    echo "Environment: $ENVIRONMENT"
    echo "Region: $AWS_REGION"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    
    # Get current month costs
    local start_date=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
    local end_date=$(date +%Y-%m-%d)
    
    log "Getting costs from $start_date to $end_date..."
    
    # Get cost and usage
    if command -v aws &> /dev/null; then
        local cost_data
        if cost_data=$(aws ce get-cost-and-usage \
            --time-period Start="$start_date",End="$end_date" \
            --granularity MONTHLY \
            --metrics BlendedCost \
            --group-by Type=DIMENSION,Key=SERVICE \
            --filter '{"Tags":{"Key":"Project","Values":["deployer-ddf-mod-llm-models"]}}' \
            --region "$AWS_REGION" \
            --output json 2>/dev/null); then
            
            echo "Monthly Costs by Service:"
            echo "$cost_data" | jq -r '.ResultsByTime[0].Groups[] | "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount)"' | sort -k2 -nr
            echo
            
            # Total cost
            local total_cost
            if total_cost=$(echo "$cost_data" | jq -r '.ResultsByTime[0].Total.BlendedCost.Amount'); then
                echo "Total Monthly Cost: \$${total_cost}"
                echo
                
                # Cost analysis
                local cost_float=$(echo "$total_cost" | bc -l 2>/dev/null || echo "$total_cost")
                if (( $(echo "$cost_float > 120" | bc -l 2>/dev/null || echo "0") )); then
                    warning "Cost is above recommended budget (\$120/month)"
                elif (( $(echo "$cost_float > 100" | bc -l 2>/dev/null || echo "0") )); then
                    warning "Cost is approaching budget limit"
                else
                    success "Cost is within budget"
                fi
            fi
        else
            warning "Could not retrieve cost data. Cost Explorer may not be enabled."
        fi
    fi
    
    # Show resource usage
    log "Current resource usage:"
    show_status | grep -E "(Desired Count|Running Count|Task Details)" || true
}

# Main management function
main() {
    log "Starting AI Testing Agent management..."
    
    validate_inputs
    
    case "$ACTION" in
        "start")
            start_instances
            ;;
        "stop")
            stop_instances
            ;;
        "restart")
            restart_instances
            ;;
        "scale")
            scale_instances "$INSTANCE_COUNT"
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "cost")
            show_cost
            ;;
        *)
            error "Unknown action: $ACTION"
            usage
            exit 1
            ;;
    esac
    
    success "Management operation completed!"
}

# Error handling
trap 'error "Management operation failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 