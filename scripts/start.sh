#!/bin/bash

# KidGuard AI Container Startup Script

set -e

echo "Starting KidGuard AI in container mode..."

# Check if models need to be downloaded
if [ ! -f "/app/data/.models_downloaded" ]; then
    echo "First run detected, downloading AI models..."
    /app/scripts/download-models.sh
    touch /app/data/.models_downloaded
else
    echo "AI models already downloaded, skipping..."
fi

# Start Ollama service in the background
echo "Starting Ollama service..."
ollama serve &
OLLAMA_PID=$!

# Wait for Ollama to be ready
echo "Waiting for Ollama to initialize..."
sleep 10

# Function to check if Ollama is responding
check_ollama() {
    curl -f http://localhost:11434/api/tags >/dev/null 2>&1
}

# Wait for Ollama to be fully ready
echo "Checking Ollama health..."
for i in {1..30}; do
    if check_ollama; then
        echo "Ollama is ready!"
        break
    fi
    echo "Waiting for Ollama... ($i/30)"
    sleep 2
done

if ! check_ollama; then
    echo "ERROR: Ollama failed to start properly"
    exit 1
fi

# Set up graceful shutdown
cleanup() {
    echo "Shutting down KidGuard AI..."
    kill $OLLAMA_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start the KidGuard AI daemon
echo "Starting KidGuard AI daemon..."
/app/.build/release/KidGuardAIDaemon --foreground --verbose &
DAEMON_PID=$!

echo "KidGuard AI is running!"
echo "  - Ollama API: http://localhost:11434"
echo "  - Proxy service: http://localhost:8080"
echo "  - Data directory: /app/data"

# Keep the container running
wait $DAEMON_PID