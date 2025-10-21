# KidGuard AI: Application Specifications

## Introduction
This document outlines the full technical specifications for **KidGuard AI**, a macOS-first parental monitoring application designed to empower parents to safeguard their children's online activities using local AI (Large Language Models or LLMs). The app runs entirely on-device for core functionality, ensuring privacy by avoiding mandatory cloud dependencies. It allows parents to set rules via natural language (text or voice), screens web URLs and content, captures and analyzes screenshots periodically, and provides alerts for violations—all without requiring technical setup like manual proxy configurations or browser extensions.

## Market Research on Pricing
To inform the subscription model for KidGuard AI, I conducted market research on comparable parental control apps as of October 2025. The focus was on subscription-based services with features like content filtering, monitoring, alerts, and AI-driven analysis (e.g., Qustodio, Bark, Norton Family, Net Nanny, and Aura).

### Pricing Trends
- **Common Models**: Most apps use tiered subscriptions (free/basic/premium), billed monthly or annually (annual often 20-40% cheaper). Pricing aligns with device limits, feature depth, and family size. Entry-level plans start at $4-5/month (billed annually), while premium/family plans range from $8-14/month.
- **Free Tiers**: Many offer limited free versions (e.g., basic monitoring for 1-5 devices) to hook users, with upsells for advanced features like AI alerts or extended reports.
- **Market Averages**:
  - Basic (core filtering/monitoring): $40-60/year (~$3.33-5/mo).
  - Premium (AI enhancements, unlimited devices, cloud storage): $80-120/year (~$6.67-10/mo).
  - Family/Enterprise: $150-300/year for extended features.

### Competitor Breakdown
| App | Tiers and Pricing (Annual Billing) | Key Features in Tiers |
|-----|------------------------------------|-----------------------|
| **Qustodio** | - Free: Limited reports, 1 device.<br>- Basic: $54.95/year (~$4.58/mo).<br>- Complete: $99.95/year (~$8.33/mo). | Basic: Core protection, multi-device.<br>Complete: AI alerts, games blocking, 30-day history. |
| **Bark** | - Jr: $49/year (~$4.08/mo).<br>- Premium: $99/year (~$8.25/mo). | Jr: Screen time, basic filters.<br>Premium: AI monitoring for texts/social, unlimited devices. |
| **Norton Family** | - Single Plan: $49.99/year (~$4.17/mo). | Unlimited devices, web filtering, time limits, location tracking. |
| **Net Nanny** | - 1 Device: $39.99/year (~$3.33/mo).<br>- 5 Devices: $54.99/year (~$4.58/mo).<br>- 20 Devices: $89.99/year (~$7.50/mo). | Tiered by devices: AI filtering, reports, app blocking. |

## User Stories

### Epic 1: Installation and Setup
- **US-1.1** (High): As a non-technical parent, I want a one-click installer so that I can set up the app without entering technical details like IPs or configurations.
- **US-1.2** (High): As a parent, I want the app to auto-configure system-wide monitoring (e.g., proxy and background service) during install so that it works seamlessly across all browsers and apps without extensions.
- **US-1.3** (Medium): As a parent, I want an initial guided tour (voice or text) after install so that I can quickly set my first rule.

### Epic 2: Rule Setting via Natural Language
- **US-2.1** (High): As a parent, I want to set rules using voice commands (e.g., "Block violent content") so that I don't need to type or navigate menus.
- **US-2.2** (High): As a parent, I want to set rules via text input (e.g., chat interface) so that I can define custom blocks like "Alert on bullying in chats" without technical knowledge.
- **US-2.3** (Medium): As a parent, I want the app to confirm and suggest refinements to my rules (e.g., "Did you mean block all social media?") so that rules are accurate.
- **US-2.4** (Low): As a parent, I want to update or delete rules via voice/text so that I can adapt monitoring as needed.

### Epic 3: Web and Messaging Monitoring
- **US-3.1** (High): As a parent, I want all web traffic (including messaging services like WhatsApp Web) to be screened automatically so that inappropriate URLs or content are blocked before loading.
- **US-3.2** (High): As a parent, I want messaging in desktop apps (e.g., Discord) to be monitored via content analysis so that risks like stranger interactions are flagged.
- **US-3.3** (Medium): As a parent, I want previews of blocked content explained (e.g., "Blocked due to adult themes") so that I understand decisions.

### Epic 4: Screenshot Analysis and Alerts
- **US-4.1** (High): As a parent, I want periodic screenshots analyzed locally for violations (e.g., every 10 seconds) so that non-web activities are monitored.
- **US-4.2** (High): As a parent, I want real-time alerts (notifications or sounds) for violations so that I can intervene immediately.
- **US-4.3** (Medium): As a parent, I want daily/weekly summaries of activities (e.g., via dashboard or voice readout) so that I can review usage patterns.
- **US-4.4** (Low): As a parent, I want adjustable screenshot intervals (via voice) so that I can balance performance and monitoring depth.

### Epic 5: Dashboard and Management
- **US-5.1** (High): As a parent, I want a minimal dashboard (accessible via menu bar icon) to view logs, activities, and screenshots so that I can check status without disruption.
- **US-5.2** (Medium): As a parent, I want to query status via voice (e.g., "What's my kid doing now?") so that I get quick updates hands-free.
- **US-5.3** (Medium): As a parent, I want to pause or disable monitoring temporarily (e.g., "Pause for 1 hour") so that I maintain control ethically.
- **US-5.4** (Low): As a parent, I want logs exported to PDF or email so that I can archive reports.

### Epic 6: Privacy and Ethics
- **US-6.1** (High): As a parent, I want all data processed and stored locally (encrypted) so that privacy is preserved.
- **US-6.2** (Medium): As a parent, I want easy uninstallation that reverses all changes (e.g., proxy settings) so that the app leaves no traces.
- **US-6.3** (High): As a parent, I want optional cloud storage for history/logs so that I can prevent local storage from filling up my laptop's memory, with easy opt-in/opt-out.

### Epic 7: Subscriptions and Monetization
- **US-7.1** (High): As a parent, I want a free tier with basic features so that I can try the app without commitment.
- **US-7.2** (High): As a paying parent, I want access to cloud storage for extended history (e.g., beyond 7 days local) so that I can review long-term patterns without local storage issues.
- **US-7.3** (High): As a premium parent, I want a smarter AI model (e.g., more accurate analysis) so that monitoring is more reliable and nuanced.
- **US-7.4** (Medium): As a parent, I want seamless subscription management (e.g., via in-app purchase) so that I can upgrade/downgrade without hassle.
- **US-7.5** (Low): As a parent, I want a free trial for premium features so that I can test cloud and advanced AI before paying.

## Technical Specifications

### 1. Architecture Overview
- **High-Level Design**: Client-server model where the app is a macOS menu bar application (frontend) communicating with a background daemon (backend) for monitoring. The daemon hosts the local LLM, proxy server, and screenshot analyzer. Optional cloud backend for subscriptions.
- **Components**:
  - **Frontend**: SwiftUI app for dashboard, voice/text input, alerts, and subscription management.
  - **Backend Daemon**: LaunchDaemon service using Swift or embedded Python for LLM integration.
  - **LLM Engine**: Ollama (embedded or subprocess) for natural language processing and content analysis.
  - **Proxy Module**: Network Extension framework for system-wide HTTP/HTTPS interception.
  - **Screenshot Module**: Core Graphics for capture, multimodal LLM (e.g., LLaVA via Ollama) for analysis.
  - **Voice Module**: SFSpeechRecognizer (Apple's local Speech framework) for offline speech-to-text.
  - **Storage**: Encrypted Core Data or SQLite for local rules/logs/screenshots.
  - **Subscription Module**: Integrate with RevenueCat or StoreKit for in-app purchases.

### 2. Tech Stack
- **Language**: Swift 5+ for native macOS integration
- **Frameworks/Libraries**:
  - **UI**: SwiftUI for dashboard
  - **LLM**: Ollama (via subprocess or API; supports models like Mistral 7B, LLaVA for vision)
  - **Proxy**: Network.framework and NetworkExtension for transparent proxy
  - **Screenshots**: CoreGraphics (CGDisplayCreateImage) or AVFoundation for screen capture
  - **Voice STT**: Speech.framework (SFSpeechRecognizer for local, offline recognition)
  - **Notifications**: UserNotifications.framework
  - **Encryption**: CommonCrypto for log storage
  - **Cloud**: Alamofire for API calls; AWS SDK or Firebase for storage
  - **Subscriptions**: StoreKit 2 for in-app purchases; RevenueCat for management
- **Models**:
  - Basic/Free: Mistral-7B-Instruct (quantized for speed)
  - Premium: Larger/smarter (e.g., LLaMA-13B or fine-tuned variant)
  - Multimodal: LLaVA-1.5-7B (for screenshot analysis)

### 3. Subscription Model
- **Tiers**:
  - **Free**: Local only, basic LLM, 7-day history limit
  - **Basic ($4.99/mo or $49.99/year)**: Cloud storage for unlimited history, extended reports
  - **Premium ($9.99/mo or $99.99/year)**: All Basic features + smarter AI model

### 4. Security and Performance
- **Privacy**: All data in sandboxed ~/Library/Application Support/; encrypted with device key
- **Optimization**: LLM quantization (4-bit); GPU acceleration via Metal
- **Error Handling**: Graceful fallbacks (e.g., rule-based filters if LLM slow)

### 5. Installation and Deployment
- **Installer**: Use Xcode's Archive > Distribute App to create a signed .pkg
- **Post-Install Script**: Install Ollama, set up LaunchDaemon, configure system proxy
- **Size**: ~200-500MB (including models)

### 6. Testing and Deployment
- **Unit Tests**: XCTest for LLM parsing, proxy mocks, subscription flows
- **Integration Tests**: Simulator for end-to-end testing
- **Deployment**: Notarize for Gatekeeper; optional App Store submission

## Hardware Requirements
- **Minimum**: macOS Ventura 13.0+, 8GB RAM, Apple Silicon M1+ (preferred)
- **Recommended**: 16GB+ RAM for smooth LLM operation
- **Storage**: 10GB for app and models, additional space for monitoring data

## Ethical Considerations
- Transparent monitoring with easy disable options
- Encrypted local storage
- Optional cloud with user control
- Clear privacy policy and data handling