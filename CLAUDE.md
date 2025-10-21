# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KidGuard AI is a macOS parental monitoring application using local AI (Ollama) for intelligent content filtering. It features:
- Natural language rule setting with voice support
- Screenshot analysis via AI vision models
- System-wide web traffic monitoring (planned)
- SwiftUI menu bar app with background daemon
- Optional cloud storage for paid tiers

## Development Commands

### Building

```bash
# Build all targets (release)
make build
swift build -c release

# Build debug
make build-debug
swift build

# Build specific target
swift build --target KidGuardCore
swift build --target KidGuardAI
swift build --target KidGuardAIDaemon
```

### Testing

```bash
# Run all tests
make test
swift test

# Run specific test
swift test --filter KidGuardAITests
```

### Running

```bash
# Run daemon in foreground with verbose logging
make run
./.build/release/KidGuardAIDaemon --foreground --verbose

# Run debug build
make run-debug
```

### Docker Development (Recommended)

```bash
# Build and run in container
make docker-run
docker-compose up --build

# Run detached
make docker-run-detached

# View logs
make docker-logs

# Stop containers
make docker-stop

# Health check
make health-check
curl http://localhost:11434/api/tags
```

### Dependencies

```bash
# Install Ollama and AI models
make install

# Download AI models manually
make download-models
ollama pull mistral:7b-instruct
ollama pull llava:7b

# Premium models
make download-premium-models
ollama pull mixtral:8x7b-instruct
```

## Architecture

### Component Structure

**Three-tier architecture:**

1. **KidGuardCore** (Shared Library)
   - `Models/`: Data models (Rule, MonitoringEvent, Subscription)
   - `Services/`: Core services (LLMService, VoiceService, ScreenshotService, StorageService, SubscriptionService)
   - `Utilities/`: Helper functions

2. **KidGuardAI** (Main App)
   - SwiftUI menu bar application
   - `Views/`: MenuBarView, DashboardView, RulesView, EventsView, SubscriptionView
   - `AppCoordinator.swift`: Main app state management

3. **KidGuardAIDaemon** (Background Service)
   - Handles monitoring and AI processing
   - Uses ArgumentParser for CLI options
   - IPC communication with main app

### Key Service Interactions

**Rule Processing Flow:**
1. User input (voice/text) → VoiceService (if voice)
2. Text → LLMService.parseRule() → Structured Rule object
3. Rule → StorageService.saveRule() → Core Data
4. Active rules loaded for monitoring

**Content Analysis Flow:**
1. Content capture (web/screenshot) → Raw data
2. LLMService.analyzeContent() with active rules → AnalysisResult
3. If violation detected → MonitoringEvent created
4. Event → StorageService.logEvent() + Notification

**AI Model Integration:**
- LLMService communicates with Ollama via HTTP (localhost:11434)
- Text analysis: `mistral:7b-instruct`
- Screenshot analysis: `llava:7b` (multimodal vision model)
- Premium tier: `mixtral:8x7b-instruct`

### Data Models

**Rule** - Parental control rules
- `description: String` - Natural language rule
- `categories: [String]` - Content categories (violence, adult, etc.)
- `actions: [RuleAction]` - Actions to take (block, alert, log, redirect)
- `severity: RuleSeverity` - low, medium, high, critical
- `isActive: Bool`

**MonitoringEvent** - Captured activities
- `type: EventType` - web, screenshot, messaging
- `timestamp: Date`
- `content: String` - Captured content/URL
- `violated: Bool` - Whether rules were violated
- `violatedRules: [String]` - Which rules triggered
- `aiAnalysis: String?` - AI explanation

**Subscription** - User tier management
- `tier: SubscriptionTier` - free, basic, premium
- `features: [String]` - Available features per tier

### Dependencies

- **Alamofire** (5.8.0+): HTTP networking for cloud API
- **RevenueCat** (4.0.0+): In-app purchase and subscription management
- **ArgumentParser** (1.0.0+): CLI parsing for daemon

### Platform Requirements

- macOS 13.0+ (Ventura)
- Swift 5.9+
- Xcode 15.0+ (for development)
- Ollama installed (for AI processing)

## Implementation Status

### ✅ Complete
- Project structure and build system
- Core data models (Rule, MonitoringEvent, Subscription)
- Service layer (LLM, Voice, Screenshot, Storage, Subscription)
- SwiftUI interface (all views)
- Background daemon (basic implementation)
- Docker/container infrastructure
- Ollama integration framework

### 🚧 Partial
- AI model integration (framework ready, prompt engineering needed)
- Core Data persistence (service layer complete, schema file needed)
- Screenshot analysis (framework ready, integration testing needed)

### ⏳ Not Started
- Network proxy module (Network Extension)
- Cloud storage integration (AWS S3)
- macOS system integration (LaunchDaemon, permissions)
- Native macOS notifications
- Installer package (.pkg)

## Development Notes

### Container-First Approach
The implementation prioritizes Docker development for rapid iteration before full macOS integration. The container provides:
- Ollama API at localhost:11434
- Proxy service at localhost:8080
- Persistent volumes for data, models, screenshots, logs

### Testing AI Features
```bash
# Test Ollama connectivity
curl http://localhost:11434/api/tags

# Test rule parsing (manual)
curl -X POST http://localhost:11434/api/generate \
  -d '{"model": "mistral:7b-instruct", "prompt": "Parse this rule: Block violent content"}'
```

### Service Initialization Order
1. StorageService (load persisted rules)
2. LLMService (verify Ollama connection)
3. VoiceService (request microphone permissions)
4. ScreenshotService (request screen recording permissions)
5. SubscriptionService (restore purchases)

### Security Considerations
- All data stored in encrypted Core Data
- Local processing by default (privacy-first)
- Cloud storage is opt-in with end-to-end encryption
- AI models run entirely on-device

## Common Workflows

### Adding a New AI Model
1. Update model name in LLMService initializer
2. Add to scripts/download-models.sh
3. Update docker-compose.yml environment if needed
4. Test with `ollama pull <model-name>`

### Adding a New Service
1. Create protocol in KidGuardCore/Services/
2. Implement service class conforming to protocol
3. Add to Package.swift if external deps needed
4. Initialize in AppCoordinator or Daemon
5. Wire up to UI views as needed

### Adding a New View
1. Create SwiftUI view in KidGuardAI/Views/
2. Add @StateObject or @ObservedObject for data binding
3. Register in MenuBarView tab navigation
4. Update AppCoordinator if state management needed

### Testing Container Changes
```bash
# Rebuild and restart
docker-compose down
docker-compose up --build

# View specific service logs
docker-compose logs -f kidguard-ai

# Execute commands in container
docker exec -it kidguard-ai /bin/bash
```
