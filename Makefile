# KidGuard AI Makefile

.PHONY: help build run test clean docker-build docker-run docker-stop install

# Default target
help:
	@echo "KidGuard AI Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  build          - Build all Swift targets"
	@echo "  run           - Run the daemon in foreground"
	@echo "  test          - Run unit tests"
	@echo "  clean         - Clean build artifacts"
	@echo "  docker-build  - Build Docker image"
	@echo "  docker-run    - Run in Docker container"
	@echo "  docker-stop   - Stop Docker containers"
	@echo "  install       - Install dependencies (macOS)"
	@echo ""

# Swift build targets
build:
	@echo "Building KidGuard AI..."
	swift build -c release

build-debug:
	@echo "Building KidGuard AI (debug)..."
	swift build

# Run targets
run: build
	@echo "Starting KidGuard AI daemon..."
	./.build/release/KidGuardAIDaemon --foreground --verbose

run-debug: build-debug
	@echo "Starting KidGuard AI daemon (debug)..."
	./.build/debug/KidGuardAIDaemon --foreground --verbose

# Test target
test:
	@echo "Running tests..."
	swift test

# Clean target
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build/

# Docker targets
docker-build:
	@echo "Building Docker image..."
	docker-compose build

docker-run: docker-build
	@echo "Starting KidGuard AI in Docker..."
	docker-compose up

docker-run-detached: docker-build
	@echo "Starting KidGuard AI in Docker (background)..."
	docker-compose up -d

docker-stop:
	@echo "Stopping Docker containers..."
	docker-compose down

docker-logs:
	@echo "Showing Docker logs..."
	docker-compose logs -f

# Install dependencies (macOS)
install:
	@echo "Installing dependencies..."
	@echo "Checking for Ollama..."
	@which ollama || (echo "Installing Ollama..." && curl -fsSL https://ollama.ai/install.sh | sh)
	@echo "Downloading AI models..."
	ollama pull mistral:7b-instruct
	ollama pull llava:7b
	@echo "Dependencies installed!"

# Development helpers
format:
	@echo "Formatting Swift code..."
	find . -name "*.swift" -not -path "./.build/*" | xargs swiftformat

lint:
	@echo "Linting Swift code..."
	find . -name "*.swift" -not -path "./.build/*" | xargs swiftlint

# Package and installer (macOS)
package: build
	@echo "Creating installer package..."
	mkdir -p dist/
	cp ./.build/release/KidGuardAI dist/
	cp ./.build/release/KidGuardAIDaemon dist/
	# TODO: Create .pkg installer

# Container health check
health-check:
	@echo "Checking container health..."
	curl -f http://localhost:11434/api/tags || echo "Ollama not responding"
	curl -f http://localhost:8080/health || echo "Proxy not responding"

# Model management
download-models:
	@echo "Downloading AI models..."
	ollama pull mistral:7b-instruct
	ollama pull llava:7b

download-premium-models:
	@echo "Downloading premium AI models..."
	ollama pull mixtral:8x7b-instruct

list-models:
	@echo "Installed models:"
	ollama list

# Quick start for new users
quick-start: install build
	@echo ""
	@echo "🚀 KidGuard AI Quick Start Complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Run 'make run' to start the daemon"
	@echo "2. Open the macOS app to configure rules"
	@echo "3. Or run 'make docker-run' to test in container"
	@echo ""