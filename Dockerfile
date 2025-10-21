# Use Ubuntu as base for better Swift and Ollama support
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV SWIFT_VERSION=5.9.2
ENV OLLAMA_VERSION=0.1.17

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    ca-certificates \
    gnupg \
    software-properties-common \
    libc6-dev \
    libssl-dev \
    libsqlite3-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Swift
RUN wget -q "https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2204/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04.tar.gz" \
    && tar xzf swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04.tar.gz \
    && mv swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04 /usr/share/swift \
    && rm swift-${SWIFT_VERSION}-RELEASE-ubuntu22.04.tar.gz

# Add Swift to PATH
ENV PATH="/usr/share/swift/usr/bin:${PATH}"

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Create app directory
WORKDIR /app

# Copy package files first for better caching
COPY Package.swift .

# Copy source code
COPY KidGuardCore/ KidGuardCore/
COPY KidGuardAIDaemon/ KidGuardAIDaemon/

# Build the application
RUN swift build --product KidGuardAIDaemon -c release

# Create directory for models and data
RUN mkdir -p /app/data/models \
    && mkdir -p /app/data/screenshots \
    && mkdir -p /app/data/logs

# Download required AI models (this will be done at runtime to save space)
COPY scripts/download-models.sh /app/scripts/
RUN chmod +x /app/scripts/download-models.sh

# Create non-root user
RUN useradd -m -u 1000 kidguard && \
    chown -R kidguard:kidguard /app

# Switch to non-root user
USER kidguard

# Expose ports
EXPOSE 8080 11434

# Create startup script
COPY scripts/start.sh /app/
RUN chmod +x /app/start.sh

# Set entrypoint
ENTRYPOINT ["/app/start.sh"]