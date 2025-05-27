#!/bin/bash
# Generate docker-compose.yml from configuration files
# Follows Dadosfera PRE-PROMPT v1.0 requirements

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ENV="dev"
PLATFORM="docker"
CONFIG_FILE=""
OUTPUT_FILE="$PROJECT_ROOT/config/docker/docker-compose-deployment.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
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
        --output=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [--env=ENV] [--platform=PLATFORM] [--output=FILE]"
            echo "  --env=ENV        Environment (default: dev)"
            echo "  --platform=PLATFORM  Platform (default: docker)"
            echo "  --output=FILE    Output file (default: config/docker/docker-compose-deployment.yml)"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "Generating docker-compose-deployment.yml for env=$ENV platform=$PLATFORM"

# Find configuration file
CONFIG_FILE="$PROJECT_ROOT/config/${ENV}.${PLATFORM}.yml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

log "Using config: $CONFIG_FILE"

# Generate docker-compose-deployment.yml
cat > "$OUTPUT_FILE" << 'EOF'
# Generated docker-compose-deployment.yml
# DO NOT EDIT MANUALLY - Generated from config files
# To regenerate: bash scripts/generate-docker-compose.sh --env=dev --platform=docker

version: '3.8'

services:
  ai-testing-agent:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: deployer-ddf-mod-llm-models-dev
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - AUTH_DISABLED=true
      - PORT=3000
      - LOG_LEVEL=debug
      - OLLAMA_HOST=ollama:11434
    volumes:
      - ./logs:/app/logs
      - ./config:/app/config:ro
    networks:
      - ai-testing-network
    depends_on:
      - ollama
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  ollama:
    image: ollama/ollama:latest
    container_name: ollama-server
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    networks:
      - ai-testing-network
    restart: unless-stopped
    environment:
      - OLLAMA_HOST=0.0.0.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # Optional: Redis for session storage (if needed later)
  redis:
    image: redis:7-alpine
    container_name: redis-cache
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - ai-testing-network
    restart: unless-stopped
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  ai-testing-network:
    driver: bridge
    name: ai-testing-network

volumes:
  ollama_data:
    name: ollama_data
  redis_data:
    name: redis_data
EOF

# Add generation timestamp
echo "" >> "$OUTPUT_FILE"
echo "# Generated on: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_FILE"
echo "# From config: $CONFIG_FILE" >> "$OUTPUT_FILE"

success "Generated docker-compose-deployment.yml at: $OUTPUT_FILE"
log "To use: docker-compose up -d"
log "To regenerate: bash scripts/generate-docker-compose.sh --env=$ENV --platform=$PLATFORM" 