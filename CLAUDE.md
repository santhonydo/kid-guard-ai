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

# Xcode development (for SwiftUI app)
open KidGuardAI/KidGuardAI.xcodeproj
# Use Cmd+B to build, Cmd+R to run
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
   - SwiftUI menu bar application (MenuBarExtra style)
   - `Views/`: MenuBarView, DashboardView, RulesView, EventsView, SubscriptionView, QuickActionsView
   - `AppCoordinator.swift`: Main app state management with service coordination
   - `main.swift`: App entry point with KidGuardAIApp struct
   - No traditional window, runs as menu bar extra with 400x500 popup

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
- Project structure and build system (Swift Package Manager + Xcode)
- Core data models (Rule, MonitoringEvent, Subscription)
- Service layer (LLM, Voice, Screenshot, Storage, Subscription)
- SwiftUI interface (all views with menu bar app)
- Background daemon (basic implementation)
- Docker/container infrastructure
- Ollama integration framework
- Voice rule input with QuickActionsView
- App coordinator with service delegation

### 🚧 Partial
- AI model integration (framework ready, prompt engineering in progress)
- Core Data persistence (service layer complete, schema in Resources/)
- Screenshot analysis (framework ready, integration testing needed)
- Proxy service integration (basic implementation in AppCoordinator)

### ⏳ Not Started
- Network proxy module (Network Extension)
- Cloud storage integration (AWS S3)
- macOS system integration (LaunchDaemon, permissions)
- Native macOS notifications
- Installer package (.pkg)

## Development Notes

### Working Directory
The project root is `/Users/anthony/Dev/apps/kid_guard_ai/` - ensure all commands run from this directory unless otherwise specified. The KidGuardAI subdirectory contains the Xcode project for the main SwiftUI app.

### Development Approaches
**Option 1: Xcode (Recommended for UI development)**
- Open `KidGuardAI/KidGuardAI.xcodeproj` in Xcode
- Use for SwiftUI interface development and debugging
- All dependencies managed automatically via Swift Package Manager

**Option 2: Command Line (Swift Package Manager)**
- Use `swift build`, `swift test`, `swift run` from project root
- Good for core library development and daemon work

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
3. Register in MenuBarView tab navigation (Tab enum and switch statement)
4. Update AppCoordinator if state management needed
5. Ensure view works within 400x500 menu bar popup constraints

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

## File Organization Rules

ALWAYS follow these file organization conventions:
- **Shell scripts (*.sh):** Place in `scripts/` directory
- **Documentation (*.md):** Place in `docs/` directory
- **EXCEPTIONS:** `CLAUDE.md` and `README.md` remain in root
- **Configuration files:** (.gitignore, Package.swift, Makefile, docker-compose.yml, etc.) Keep in root
- **Source code:** Keep in designated directories (KidGuardCore/, KidGuardAI/, KidGuardAIDaemon/, Tests/)
- When creating new scripts or documentation, ALWAYS put them in the appropriate directory from the start

## Testing & Scripts

All test and utility scripts are located in `scripts/`:
- `scripts/test_ai.sh` - Quick AI validation
- `scripts/test_ai_consistency.sh` - Comprehensive JSON consistency testing (22 test cases)
- `scripts/test_improved_prompts.sh` - Prompt engineering validation
- `scripts/download-models.sh` - Download Ollama AI models
- `scripts/start.sh` - Container startup script

All documentation is in `docs/`:
- `docs/AI_CONSISTENCY_SUMMARY.md` - Complete AI reliability analysis
- `docs/NEXT_STEPS.md` - Development roadmap and next steps
- `docs/ai-reliability-report.md` - Technical AI testing report
- `docs/model-comparison.md` - Mistral vs Mixtral comparison
- `docs/implementation-status.md` - Project status tracker
- `docs/architecture-diagram.md` - System architecture
- `docs/application-specs.md` - Application specifications

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
ALWAYS follow the file organization rules above - scripts in scripts/, docs in docs/.
