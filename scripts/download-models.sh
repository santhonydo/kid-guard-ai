#!/bin/bash

# Download AI models for KidGuard AI
# This script downloads the required Ollama models

set -e

echo "Starting Ollama service..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to start
echo "Waiting for Ollama to be ready..."
sleep 10

# Function to download model with retry
download_model() {
    local model=$1
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        echo "Downloading model: $model (attempt $((retry_count + 1))/$max_retries)"
        
        if ollama pull "$model"; then
            echo "Successfully downloaded $model"
            return 0
        else
            echo "Failed to download $model"
            retry_count=$((retry_count + 1))
            sleep 5
        fi
    done
    
    echo "Failed to download $model after $max_retries attempts"
    return 1
}

# Download required models
echo "Downloading required AI models..."

# Base model for text analysis
download_model "mistral:7b-instruct"

# Vision model for screenshot analysis  
download_model "llava:7b"

# Optional: Premium model (larger, more accurate)
if [ "${DOWNLOAD_PREMIUM_MODEL:-false}" = "true" ]; then
    echo "Downloading premium model..."
    download_model "mixtral:8x7b-instruct"
fi

echo "Model download completed!"

# Kill Ollama background process
kill $OLLAMA_PID 2>/dev/null || true

echo "All models downloaded successfully"