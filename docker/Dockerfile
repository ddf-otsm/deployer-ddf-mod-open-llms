FROM python:3.11-slim

# Metadata
LABEL maintainer="devops-team"
LABEL project="deployer-ddf-mod-llm-models"
LABEL version="1.0"
LABEL description="Self-hosted AI Testing Agent with Ollama integration"

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app/src
ENV OLLAMA_HOST=localhost:11434
ENV LOG_LEVEL=INFO

# Create non-root user for security
RUN groupadd -r aitest && useradd -r -g aitest -d /app -s /bin/bash aitest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Create necessary directories
RUN mkdir -p /app/{src,config,results,logs,models} && \
    chown -R aitest:aitest /app

# Copy application code
COPY --chown=aitest:aitest ../src/ ./src/
COPY --chown=aitest:aitest ../config/ ./config/

# Copy scripts and make them executable
COPY --chown=aitest:aitest ../scripts/ ./scripts/
RUN chmod +x ./scripts/local/*.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Switch to non-root user
USER aitest

# Expose port for health checks
EXPOSE 8080

# Default command
CMD ["python", "src/local_llm_testgen.py", "--server"] 