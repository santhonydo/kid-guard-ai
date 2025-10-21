# KidGuard AI Architecture Diagram

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           KidGuard AI System                             │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         User Interface Layer                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    KidGuardAI (macOS App)                        │   │
│  │                        SwiftUI Menu Bar                          │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │                                                                  │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │   │
│  │  │  Dashboard   │  │    Rules     │  │   Events     │          │   │
│  │  │     View     │  │     View     │  │    View      │          │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │   │
│  │                                                                  │   │
│  │  ┌──────────────┐  ┌──────────────────────────────────────┐    │   │
│  │  │ Subscription │  │      AppCoordinator                  │    │   │
│  │  │     View     │  │    (State Management)                │    │   │
│  │  └──────────────┘  └──────────────────────────────────────┘    │   │
│  │                                                                  │   │
│  └──────────────────────────────────┬───────────────────────────────┘   │
│                                     │ IPC                                │
└─────────────────────────────────────┼────────────────────────────────────┘
                                      │
┌─────────────────────────────────────┼────────────────────────────────────┐
│                         Background Service Layer                         │
├─────────────────────────────────────┴────────────────────────────────────┤
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │              KidGuardAIDaemon (Background Process)                 │  │
│  │                      ArgumentParser CLI                            │  │
│  ├────────────────────────────────────────────────────────────────────┤  │
│  │                                                                    │  │
│  │  ┌───────────────────────────────────────────────────────────┐   │  │
│  │  │                  MonitoringDaemon                          │   │  │
│  │  │  • Service initialization & lifecycle                     │   │  │
│  │  │  • Signal handling (SIGINT, SIGTERM)                      │   │  │
│  │  │  • Health monitoring                                      │   │  │
│  │  └─────────────────────┬─────────────────────────────────────┘   │  │
│  │                        │                                          │  │
│  └────────────────────────┼──────────────────────────────────────────┘  │
│                           │                                             │
└───────────────────────────┼─────────────────────────────────────────────┘
                            │
┌───────────────────────────┼─────────────────────────────────────────────┐
│                    Core Services Layer (KidGuardCore)                    │
├───────────────────────────┴─────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │  LLMService  │  │VoiceService  │  │ Screenshot   │                  │
│  │              │  │              │  │   Service    │                  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤                  │
│  │• parseRule() │  │• recognize() │  │• capture()   │                  │
│  │• analyze     │  │• speak()     │  │• analyze()   │                  │
│  │  Content()   │  │              │  │• cleanup()   │                  │
│  │• analyze     │  │              │  │              │                  │
│  │  Screenshot()│  │              │  │              │                  │
│  │• queryStatus│  │              │  │              │                  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘                  │
│         │                 │                 │                          │
│         ▼                 ▼                 ▼                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │   Storage    │  │ Subscription │  │   Network    │                  │
│  │   Service    │  │   Service    │  │   Proxy      │                  │
│  ├──────────────┤  ├──────────────┤  │  (Planned)   │                  │
│  │• saveRule()  │  │• validate    │  ├──────────────┤                  │
│  │• loadRules() │  │  Purchase()  │  │• intercept() │                  │
│  │• logEvent()  │  │• restore     │  │• filter()    │                  │
│  │• query()     │  │  Purchases() │  │• analyze()   │                  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘                  │
│         │                 │                                            │
└─────────┼─────────────────┼────────────────────────────────────────────┘
          │                 │
┌─────────┼─────────────────┼────────────────────────────────────────────┐
│         │     Data Models & Storage                │                    │
├─────────┴─────────────────┴────────────────────────┴────────────────────┤
│                                                                          │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐            │
│  │     Rule       │  │ Monitoring     │  │  Subscription  │            │
│  │                │  │     Event      │  │                │            │
│  ├────────────────┤  ├────────────────┤  ├────────────────┤            │
│  │• description   │  │• type          │  │• tier          │            │
│  │• categories    │  │• timestamp     │  │• features      │            │
│  │• actions       │  │• content       │  │• expiryDate    │            │
│  │• severity      │  │• violated      │  │• isActive      │            │
│  │• isActive      │  │• violatedRules │  │                │            │
│  └────────┬───────┘  └────────┬───────┘  └────────────────┘            │
│           │                   │                                         │
│           ▼                   ▼                                         │
│  ┌──────────────────────────────────────────────────────┐              │
│  │              Core Data (Encrypted Local Storage)      │              │
│  │          ~/Library/Application Support/KidGuardAI/    │              │
│  └──────────────────────────────────────────────────────┘              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│                      External Dependencies & Services                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────┐  │
│  │    Ollama API       │  │  Apple Frameworks   │  │  Cloud Services │  │
│  │  localhost:11434    │  │                     │  │   (Optional)    │  │
│  ├─────────────────────┤  ├─────────────────────┤  ├─────────────────┤  │
│  │• mistral:7b         │  │• Speech             │  │• AWS S3         │  │
│  │  -instruct          │  │• CoreGraphics       │  │• RevenueCat     │  │
│  │  (text analysis)    │  │• UserNotifications  │  │• StoreKit 2     │  │
│  │                     │  │• NetworkExtension   │  │                 │  │
│  │• llava:7b           │  │• CommonCrypto       │  │                 │  │
│  │  (vision/OCR)       │  │                     │  │                 │  │
│  │                     │  │                     │  │                 │  │
│  │• mixtral:8x7b       │  │                     │  │                 │  │
│  │  (premium tier)     │  │                     │  │                 │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────┘  │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### 1. Rule Creation Flow

```
┌──────────┐
│  Parent  │
└────┬─────┘
     │
     │ Voice/Text Input: "Block violent content"
     ▼
┌─────────────────┐
│  VoiceService   │ (if voice input)
│  Speech.framework│
└────┬────────────┘
     │
     │ Transcribed Text
     ▼
┌─────────────────┐         ┌──────────────┐
│   LLMService    │────────▶│ Ollama API   │
│  parseRule()    │         │ mistral:7b   │
└────┬────────────┘         └──────────────┘
     │
     │ Structured Rule Object
     ▼
┌─────────────────┐
│ StorageService  │
│  saveRule()     │
└────┬────────────┘
     │
     │ Persisted
     ▼
┌─────────────────┐
│   Core Data     │
│  (Encrypted)    │
└────┬────────────┘
     │
     │ Update UI
     ▼
┌─────────────────┐
│   RulesView     │
│  (SwiftUI)      │
└─────────────────┘
```

### 2. Content Analysis Flow

```
┌─────────────────┐         ┌─────────────────┐
│ Web Request or  │         │   Screenshot    │
│  User Activity  │         │    Capture      │
└────┬────────────┘         └────┬────────────┘
     │                           │
     │ URL/Content               │ Image Path
     ▼                           ▼
┌─────────────────────────────────────────────┐
│           MonitoringDaemon                   │
└─────────────────┬───────────────────────────┘
                  │
                  │ Load Active Rules
                  ▼
           ┌──────────────┐
           │Storage       │
           │Service       │
           │loadRules()   │
           └──────┬───────┘
                  │
                  │ Active Rules
                  ▼
           ┌──────────────────┐         ┌──────────────┐
           │   LLMService     │────────▶│  Ollama API  │
           │ analyzeContent() │         │ mistral:7b   │
           │      or          │         │   llava:7b   │
           │analyzeScreenshot()│         └──────────────┘
           └──────┬───────────┘
                  │
                  │ AnalysisResult
                  │ {violated: true/false,
                  │  violatedRules: [...]}
                  ▼
           ┌──────────────┐
           │   Storage    │
           │   Service    │
           │  logEvent()  │
           └──────┬───────┘
                  │
         ┌────────┴────────┐
         │                 │
    Violation?            No
         │                 │
        Yes                │
         │                 ▼
         ▼           ┌──────────┐
┌─────────────────┐  │   Log    │
│ Notification    │  │   Only   │
│   System        │  └──────────┘
│ (Alert Parent)  │
└─────────────────┘
```

### 3. Subscription Flow

```
┌──────────┐
│  Parent  │
└────┬─────┘
     │
     │ View Plans
     ▼
┌─────────────────┐
│ Subscription    │
│     View        │
└────┬────────────┘
     │
     │ Select Tier (Basic/Premium)
     ▼
┌─────────────────┐         ┌──────────────┐
│ Subscription    │────────▶│  StoreKit 2  │
│   Service       │         └──────┬───────┘
└────┬────────────┘                │
     │                             │
     │                             ▼
     │                      ┌──────────────┐
     │                      │  RevenueCat  │
     │                      │  (Backend)   │
     │                      └──────┬───────┘
     │                             │
     │◀────────────────────────────┘
     │ Purchase Validated
     ▼
┌─────────────────┐
│ Update Local    │
│ Subscription    │
│    State        │
└────┬────────────┘
     │
     │ Enable Features
     ▼
┌─────────────────┐
│ • Cloud Storage │
│ • Better Model  │
│ • Extended      │
│   History       │
└─────────────────┘
```

## Component Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                     Package Dependencies                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  KidGuardAI                                                  │
│      └── KidGuardCore                                        │
│                                                              │
│  KidGuardAIDaemon                                            │
│      ├── KidGuardCore                                        │
│      └── ArgumentParser (1.0.0+)                             │
│                                                              │
│  KidGuardCore                                                │
│      ├── Alamofire (5.8.0+)                                  │
│      └── RevenueCat/purchases-ios (4.0.0+)                   │
│                                                              │
│  Tests                                                       │
│      └── KidGuardCore                                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Architecture

### Local Development (macOS)

```
┌──────────────────────────────────────────────────┐
│              macOS Development Machine            │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌─────────────────┐      ┌──────────────────┐   │
│  │  KidGuardAI.app │      │  Ollama Service  │   │
│  │  (Menu Bar)     │      │  localhost:11434 │   │
│  └─────────┬───────┘      └────────┬─────────┘   │
│            │                       │             │
│            │ IPC                   │ HTTP        │
��            ▼                       ▼             │
│  ┌─────────────────────────────────────────┐     │
│  │      KidGuardAIDaemon Process           │     │
│  │  (LaunchDaemon - runs in background)    │     │
│  └─────────────────────────────────────────┘     │
│                                                   │
│  ┌─────────────────────────────────────────┐     │
│  │    ~/Library/Application Support/       │     │
│  │           KidGuardAI/                    │     │
│  │  • Core Data database                    │     │
│  │  • Screenshots                           │     │
│  │  • Logs                                  │     │
│  └─────────────────────────────────────────┘     │
│                                                   │
└──────────────────────────────────────────────────┘
```

### Docker/Container Deployment

```
┌──────────────────────────────────────────────────┐
│            Docker Host (Linux/macOS)              │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌────────────────────────────────────────────┐  │
│  │      kidguard-ai Container (Ubuntu)        │  │
│  ├────────────────────────────────────────────┤  │
│  │                                            │  │
│  │  ┌──────────────┐  ┌──────────────────┐   │  │
│  │  │ Daemon       │  │  Ollama Service  │   │  │
│  │  │ Process      │  │  :11434          │   │  │
│  │  └──────┬───────┘  └────────┬─────────┘   │  │
│  │         │                   │             │  │
│  │         └─────────┬─────────┘             │  │
│  │                   ▼                       │  │
│  │         ┌──────────────────┐              │  │
│  │         │  Proxy Service   │              │  │
│  │         │  :8080           │              │  │
│  │         └──────────────────┘              │  │
│  │                                            │  │
│  └────────────────────────────────────────────┘  │
│            │                                     │
│  ┌─────────┼─────────────────────────────────┐  │
│  │         ▼  Docker Volumes (Persistent)    │  │
│  │  • /app/data        - Application data    │  │
│  │  • /app/data/models - AI models           │  │
│  │  • /app/screenshots - Screenshot storage  │  │
│  │  • /app/logs        - Application logs    │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  Exposed Ports:                                  │
│  • 11434 → Ollama API                            │
│  • 8080  → Proxy Service                         │
│                                                   │
└──────────────────────────────────────────────────┘
```

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Language** | Swift 5.9+ | Native macOS development |
| **UI Framework** | SwiftUI | Menu bar app and views |
| **CLI** | ArgumentParser | Daemon command-line interface |
| **AI Engine** | Ollama | Local LLM hosting and inference |
| **AI Models** | Mistral 7B, LLaVA 7B, Mixtral 8x7B | Text and vision analysis |
| **Speech** | Speech.framework | Voice input recognition |
| **Graphics** | CoreGraphics | Screenshot capture |
| **Storage** | Core Data | Encrypted local persistence |
| **Networking** | Alamofire | HTTP client for cloud APIs |
| **Network Proxy** | NetworkExtension | System-wide traffic interception |
| **Subscriptions** | StoreKit 2 + RevenueCat | In-app purchases and management |
| **Cloud Storage** | AWS S3 (planned) | Optional encrypted backup |
| **Container** | Docker + Docker Compose | Development and deployment |
| **Encryption** | CommonCrypto | Data encryption at rest |

## Security Architecture

```
┌────────────────────────────────────────────────────────┐
│                    Security Layers                      │
├────────────────────────────────────────────────────────┤
│                                                         │
│  1. macOS Sandbox                                       │
│     └─ App sandboxing with limited file system access  │
│                                                         │
│  2. Data Encryption                                     │
│     ├─ Core Data encrypted with device key             │
│     └─ Screenshots encrypted on disk                   │
│                                                         │
│  3. Privacy-First Processing                            │
│     ├─ All AI analysis happens locally                 │
│     └─ No mandatory cloud dependencies                 │
│                                                         │
│  4. Optional Cloud Encryption                           │
│     └─ End-to-end encryption for cloud sync            │
│                                                         │
│  5. Secure IPC                                          │
│     └─ XPC for app-to-daemon communication             │
│                                                         │
│  6. Permissions                                         │
│     ├─ Screen Recording (for screenshots)              │
│     ├─ Microphone (for voice input)                    │
│     └─ Network Extension (for proxy)                   │
│                                                         │
└────────────────────────────────────────────────────────┘
```
