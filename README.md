# KidGuard AI

A macOS-first parental monitoring application that uses local AI to protect children online. Features intelligent content filtering, screenshot analysis, voice-controlled rule setting, and optional cloud storage.

## Features

### Core Functionality
- **Local AI Processing**: All content analysis happens on-device using Ollama
- **Smart Content Filtering**: Natural language rule setting with voice support
- **Screenshot Monitoring**: Periodic screen capture and AI analysis
- **Web Traffic Monitoring**: System-wide proxy for HTTP/HTTPS interception
- **Real-time Alerts**: Instant notifications for rule violations

### Subscription Tiers
- **Free**: Local monitoring, basic AI, 7-day history
- **Basic ($4.99/mo)**: Cloud storage, unlimited history, extended reports
- **Premium ($9.99/mo)**: Advanced AI models, analytics, priority support

## Quick Start

### Running in Docker (Recommended for Testing)

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd kid_guard_ai
   ```

2. **Build and run with Docker Compose**:
   ```bash
   docker-compose up --build
   ```

3. **Access the services**:
   - Ollama API: http://localhost:11434
   - Proxy Service: http://localhost:8080
   - Health Check: `curl http://localhost:11434/api/tags`

### Manual Build (macOS)

1. **Install Dependencies**:
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Install Swift (if not already installed)
   xcode-select --install
   ```

2. **Download AI Models**:
   ```bash
   ollama pull mistral:7b-instruct
   ollama pull llava:7b
   ```

3. **Build the Application**:
   ```bash
   swift build -c release
   ```

4. **Run the Daemon**:
   ```bash
   ./.build/release/KidGuardAIDaemon --foreground --verbose
   ```

## Container Configuration

### Environment Variables

- `DOWNLOAD_PREMIUM_MODEL`: Set to "true" to download larger AI models
- `LOG_LEVEL`: Set logging level (debug, info, warn, error)
- `OLLAMA_HOST`: Ollama server host (default: 0.0.0.0:11434)

### Volumes

- `/app/data`: Application data and databases
- `/app/data/models`: AI model storage
- `/app/data/screenshots`: Screenshot storage
- `/app/data/logs`: Application logs

### Resource Requirements

**Minimum Requirements**:
- RAM: 4GB
- CPU: 2 cores
- Storage: 10GB

**Recommended for Production**:
- RAM: 8GB+
- CPU: 4+ cores (Apple Silicon M1+ preferred)
- Storage: 20GB+

## Development

### Project Structure

```
KidGuardAI/
├── KidGuardCore/          # Shared library
│   ├── Models/            # Data models
│   └── Services/          # Core services
├── KidGuardAI/            # Main macOS app
│   └── Views/             # SwiftUI views
├── KidGuardAIDaemon/      # Background daemon
├── NetworkExtension/      # System proxy
├── Tests/                 # Unit tests
├── scripts/               # Build and deployment scripts
└── Installer/             # macOS installer
```

### Building Components

**Core Library**:
```bash
swift build --target KidGuardCore
```

**Main Application**:
```bash
swift build --target KidGuardAI
```

**Background Daemon**:
```bash
swift build --target KidGuardAIDaemon
```

### Running Tests

```bash
swift test
```

## Architecture

### Components

1. **Main App** (SwiftUI): Menu bar application with dashboard
2. **Background Daemon**: Handles monitoring and AI processing
3. **Proxy Service**: Intercepts and analyzes web traffic
4. **LLM Service**: Local AI processing via Ollama
5. **Storage Service**: Encrypted local data storage
6. **Cloud Service**: Optional cloud sync for paid tiers

### AI Models

- **mistral:7b-instruct**: General content analysis
- **llava:7b**: Screenshot and image analysis
- **mixtral:8x7b-instruct**: Premium tier model (optional)

### Data Flow

1. User sets rules via voice/text → LLM parses → Stored locally
2. Web requests → Proxy intercepts → LLM analyzes → Block/Allow
3. Screenshots captured → LLM analyzes → Generate alerts
4. Events logged → Optional cloud sync → Dashboard display

## Security & Privacy

- **Local Processing**: All AI analysis happens on-device
- **Encrypted Storage**: Local data encrypted with device key
- **Optional Cloud**: Cloud storage is opt-in with end-to-end encryption
- **No Telemetry**: No tracking or analytics by default

## Deployment

### Container Deployment

```bash
# Build and deploy
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f kidguard-ai

# Stop services
docker-compose down
```

### Production Considerations

1. **Resource Monitoring**: Monitor CPU/RAM usage during AI processing
2. **Model Updates**: Periodically update AI models
3. **Log Rotation**: Configure log rotation to prevent disk fill
4. **Backup**: Regular backup of user data and rules
5. **Updates**: Automated security updates for container base images

## Troubleshooting

### Common Issues

**Ollama not starting**:
```bash
# Check if Ollama is installed
which ollama

# Check Ollama status
curl http://localhost:11434/api/tags
```

**Models not downloading**:
```bash
# Manual model download
ollama pull mistral:7b-instruct
ollama list
```

**Permission errors**:
```bash
# macOS: Grant screen recording permission
# System Preferences → Security & Privacy → Privacy → Screen Recording
```

### Debug Mode

```bash
# Run daemon with verbose logging
./.build/release/KidGuardAIDaemon --foreground --verbose

# Docker debug
docker-compose up kidguard-ai
docker exec -it kidguard-ai /bin/bash
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

[Add license information]

## Support

For issues and support:
- GitHub Issues: [repository-url]/issues
- Documentation: [Add documentation link]
- Email: [support email]