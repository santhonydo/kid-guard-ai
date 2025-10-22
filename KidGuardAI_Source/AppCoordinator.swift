import Foundation
import SwiftUI
import KidGuardCore

@MainActor
public class AppCoordinator: ObservableObject {
    @Published var rules: [Rule] = []
    @Published var recentEvents: [MonitoringEvent] = []
    @Published var isMonitoring = false
    @Published var currentSubscription = Subscription()
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    private let llmService = LLMService()
    private let voiceService = VoiceService()
    private let screenshotService = ScreenshotService()
    private let storageService = StorageService.shared
    private let subscriptionService = SubscriptionService.shared
    
    public init() {
        setupServices()
        loadData()
    }
    
    private func setupServices() {
        voiceService.delegate = self
        screenshotService.delegate = self
        subscriptionService.delegate = self
        
        // Request necessary permissions
        voiceService.requestAuthorization()
    }
    
    private func loadData() {
        rules = storageService.loadRules()
        recentEvents = storageService.loadEvents(limit: 50)
        currentSubscription = subscriptionService.currentSubscription
        
        // Load available subscription products
        Task {
            await subscriptionService.loadProducts()
        }
    }
    
    // MARK: - Rule Management
    
    public func addRule(from text: String) async {
        do {
            let rule = try await llmService.parseRule(from: text)
            rules.append(rule)
            storageService.saveRule(rule)
        } catch {
            showAlert("Failed to create rule: \(error.localizedDescription)")
        }
    }
    
    public func removeRule(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        // TODO: Remove from Core Data
    }
    
    public func toggleRule(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            let updatedRule = Rule(
                id: rule.id,
                description: rule.description,
                categories: rule.categories,
                actions: rule.actions,
                severity: rule.severity,
                isActive: !rule.isActive,
                createdAt: rule.createdAt
            )
            rules[index] = updatedRule
            storageService.saveRule(updatedRule)
        }
    }
    
    // MARK: - Voice Commands
    
    public func startVoiceInput() {
        do {
            try voiceService.startListening()
        } catch {
            showAlert("Failed to start voice input: \(error.localizedDescription)")
        }
    }
    
    public func stopVoiceInput() {
        voiceService.stopListening()
    }
    
    public func processVoiceQuery(_ query: String) async {
        do {
            let response = try await llmService.queryStatus(query)
            voiceService.speak(response)
        } catch {
            showAlert("Failed to process query: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Monitoring Control
    
    public func startMonitoring() {
        isMonitoring = true
        screenshotService.startCapturing()
        // TODO: Start proxy service
    }
    
    public func stopMonitoring() {
        isMonitoring = false
        screenshotService.stopCapturing()
        // TODO: Stop proxy service
    }
    
    public func pauseMonitoring(for duration: TimeInterval) {
        stopMonitoring()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.startMonitoring()
        }
    }
    
    // MARK: - Subscription Management
    
    public func purchaseSubscription(_ tier: SubscriptionTier) async {
        guard let product = subscriptionService.availableProducts.first(where: { product in
            product.id.contains(tier.rawValue)
        }) else {
            showAlert("Product not available")
            return
        }
        
        do {
            try await subscriptionService.purchase(product)
        } catch {
            showAlert("Purchase failed: \(error.localizedDescription)")
        }
    }
    
    public func restorePurchases() async {
        await subscriptionService.restorePurchases()
    }
    
    // MARK: - Utilities
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    private func logEvent(_ event: MonitoringEvent) {
        recentEvents.insert(event, at: 0)
        if recentEvents.count > 50 {
            recentEvents.removeLast()
        }
        storageService.saveEvent(event)
        
        // Show notification for violations
        if event.action == .alert && event.ruleViolated != nil {
            showNotification(for: event)
        }
    }
    
    private func showNotification(for event: MonitoringEvent) {
        // TODO: Implement local notifications
        showAlert("Rule violation detected: \(event.explanation ?? "Unknown violation")")
    }
}

// MARK: - Service Delegates

extension AppCoordinator: VoiceServiceDelegate {
    public func voiceService(_ service: VoiceService, didRecognize text: String) {
        Task {
            // Determine if this is a rule or a query
            if text.lowercased().contains("rule") || text.lowercased().contains("block") || text.lowercased().contains("alert") {
                await addRule(from: text)
            } else {
                await processVoiceQuery(text)
            }
        }
    }
    
    public func voiceService(_ service: VoiceService, didFailWithError error: Error) {
        showAlert("Voice recognition failed: \(error.localizedDescription)")
    }
}

extension AppCoordinator: ScreenshotServiceDelegate {
    public func screenshotService(_ service: ScreenshotService, didCaptureScreenshot event: MonitoringEvent) {
        Task {
            // Analyze screenshot against active rules
            if let screenshotPath = event.screenshotPath {
                do {
                    let analysis = try await llmService.analyzeScreenshot(at: screenshotPath, against: rules)
                    
                    if analysis.violation {
                        let violationEvent = MonitoringEvent(
                            timestamp: event.timestamp,
                            type: .screenshot,
                            screenshotPath: screenshotPath,
                            action: analysis.recommendedAction,
                            severity: analysis.severity
                        )
                        
                        await MainActor.run {
                            logEvent(violationEvent)
                        }
                    }
                } catch {
                    print("Failed to analyze screenshot: \(error)")
                }
            }
        }
    }
    
    public func screenshotService(_ service: ScreenshotService, didFailWithError error: Error) {
        print("Screenshot service error: \(error)")
    }
}

extension AppCoordinator: SubscriptionServiceDelegate {
    public func subscriptionService(_ service: SubscriptionService, didUpdateSubscription subscription: Subscription) {
        currentSubscription = subscription
        
        // Update AI model based on subscription
        // TODO: Switch to premium AI model if subscription.premiumAIEnabled
    }
    
    public func subscriptionService(_ service: SubscriptionService, didFailWithError error: Error) {
        showAlert("Subscription error: \(error.localizedDescription)")
    }
}