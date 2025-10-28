import Foundation
import NetworkExtension
import OSLog
import SystemExtensions
import Combine

@MainActor
class NetworkExtensionManager: NSObject, ObservableObject {
    @Published var isInstalled = false
    @Published var isEnabled = false
    @Published var status: String = "Not installed"
    @Published var error: String?
    
    private let log = OSLog(subsystem: "com.kidguardai.app", category: "network-extension")
    private let bundleIdentifier = "com.kidguardai.KidGuardAI.KidGuardAIFilterExtension"
    
    override init() {
        super.init()
        checkStatus()
    }
    
    // MARK: - Public Methods
    
    
    func uninstall() {
        guard isInstalled else {
            status = "Not installed"
            return
        }
        
        status = "Uninstalling system extension..."
        error = nil
        
        os_log("Uninstalling system extension", log: log, type: .info)
        
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: bundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func resetConfiguration() {
        status = "Resetting configuration..."
        error = nil
        
        Task {
            do {
                let manager = NEFilterManager.shared()
                try await manager.loadFromPreferences()
                
                // Remove the configuration
                manager.providerConfiguration = nil
                manager.isEnabled = false
                
                try await manager.saveToPreferences()
                
                await MainActor.run {
                    self.isInstalled = false
                    self.isEnabled = false
                    self.status = "Configuration reset"
                    os_log("Configuration reset successfully", log: self.log, type: .info)
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to reset configuration: \(error.localizedDescription)"
                    self.status = "Reset failed"
                    os_log("Failed to reset configuration: %{public}@", log: self.log, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func checkInstallationStatus() async {
        let manager = NEFilterManager.shared()
        do {
            try await manager.loadFromPreferences()
            await MainActor.run {
                self.isInstalled = manager.isEnabled
            }
        } catch {
            await MainActor.run {
                self.isInstalled = false
            }
        }
    }
    
    func install() {
        status = "Installing system extension..."
        error = nil
        
        os_log("Installing system extension with bundle ID: %{public}@", log: log, type: .info, bundleIdentifier)
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: bundleIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func enableFiltering() {
        status = "Enabling content filtering..."
        error = nil
        
        Task {
            do {
                try await enableContentFilter()
                await MainActor.run {
                    self.isEnabled = true
                    self.status = "Content filtering enabled"
                    os_log("Content filtering enabled successfully", log: self.log, type: .info)
                }
            } catch {
                await MainActor.run {
                    // Provide more specific error messaging for permission issues
                    if error.localizedDescription.contains("permission denied") {
                        self.error = "Permission required. Please approve network filtering in System Settings → General → Login Items & Extensions"
                        self.status = "Permission required"
                    } else {
                        self.error = "Failed to enable filtering: \(error.localizedDescription)"
                        self.status = "Failed to enable filtering"
                    }
                    os_log("Failed to enable content filtering: %{public}@", log: self.log, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    func disableFiltering() {
        status = "Disabling content filtering..."
        error = nil
        
        Task {
            do {
                try await disableContentFilter()
                await MainActor.run {
                    self.isEnabled = false
                    self.status = "Content filtering disabled"
                    os_log("Content filtering disabled successfully", log: self.log, type: .info)
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to disable filtering: \(error.localizedDescription)"
                    self.status = "Failed to disable filtering"
                    os_log("Failed to disable content filtering: %{public}@", log: self.log, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func installContentFilter() async throws {
        let manager = NEFilterManager.shared()
        
        os_log("Starting installContentFilter process", log: log, type: .info)
        
        // Load existing configuration first
        try await manager.loadFromPreferences()
        os_log("Loaded existing preferences, isEnabled: %{public}@", log: log, type: .info, String(manager.isEnabled))
        
        // Configure the filter with our extension
        let providerConfiguration = NEFilterProviderConfiguration()
        providerConfiguration.filterSockets = true
        providerConfiguration.filterPackets = false  // We're doing socket-level filtering
        providerConfiguration.vendorConfiguration = [:]
        
        // Set the bundle identifier of our content filter extension
        providerConfiguration.filterDataProviderBundleIdentifier = bundleIdentifier
        os_log("Configured filter with bundle ID: %{public}@", log: log, type: .info, bundleIdentifier)
        
        manager.providerConfiguration = providerConfiguration
        manager.localizedDescription = "KidGuard AI Content Filter"
        manager.isEnabled = false  // Install but don't enable yet
        
        os_log("About to save preferences for installation", log: log, type: .info)
        
        // Save the configuration - this will prompt for authorization if needed
        do {
            try await manager.saveToPreferences()
            os_log("Saved preferences successfully for installation", log: log, type: .info)
        } catch {
            os_log("Failed to save preferences for installation: %{public}@", log: log, type: .error, error.localizedDescription)
            os_log("Error domain: %{public}@, code: %d", log: log, type: .error, (error as NSError).domain, (error as NSError).code)
            throw error
        }
        
        // Load to verify installation
        try await manager.loadFromPreferences()
        os_log("Verified after installation, providerConfiguration: %{public}@", log: log, type: .info, manager.providerConfiguration != nil ? "Present" : "None")
        
        if manager.providerConfiguration == nil {
            os_log("Provider configuration is nil after installation, throwing error", log: log, type: .error)
            throw NetworkExtensionError.failedToEnable
        }
        
        os_log("Content filter installed successfully", log: log, type: .info)
    }
    
    private func checkStatus() {
        // Check content filter status
        Task {
            do {
                let manager = NEFilterManager.shared()
                try await manager.loadFromPreferences()
                await MainActor.run {
                    self.isInstalled = manager.isEnabled
                    self.isEnabled = manager.isEnabled
                    if self.isEnabled {
                        self.status = "Content filtering active"
                    } else {
                        self.status = "Content filtering inactive"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isInstalled = false
                    self.isEnabled = false
                    self.status = "No content filter configuration found"
                }
            }
        }
    }
    
    private func enableContentFilter() async throws {
        let manager = NEFilterManager.shared()
        
        os_log("Starting enableContentFilter process", log: log, type: .info)
        
        // Load existing configuration first
        try await manager.loadFromPreferences()
        os_log("Loaded existing preferences, isEnabled: %{public}@", log: log, type: .info, String(manager.isEnabled))
        
        // Check if we already have a configuration
        if manager.providerConfiguration == nil {
            os_log("No existing configuration, creating new one", log: log, type: .info)
            
            // Configure the filter with our extension
            let providerConfiguration = NEFilterProviderConfiguration()
            providerConfiguration.filterSockets = true
            providerConfiguration.filterPackets = false  // We're doing socket-level filtering
            providerConfiguration.vendorConfiguration = [:]
            
            // Set the bundle identifier of our content filter extension
            providerConfiguration.filterDataProviderBundleIdentifier = bundleIdentifier
            os_log("Configured filter with bundle ID: %{public}@", log: log, type: .info, bundleIdentifier)
            
            manager.providerConfiguration = providerConfiguration
            manager.localizedDescription = "KidGuard AI Content Filter"
        } else {
            os_log("Using existing configuration", log: log, type: .info)
        }
        
        manager.isEnabled = true
        
        os_log("About to save preferences", log: log, type: .info)
        
        // Save the configuration - this will prompt for authorization if needed
        do {
            try await manager.saveToPreferences()
            os_log("Saved preferences successfully", log: log, type: .info)
        } catch {
            os_log("Failed to save preferences: %{public}@", log: log, type: .error, error.localizedDescription)
            os_log("Error domain: %{public}@, code: %d", log: log, type: .error, (error as NSError).domain, (error as NSError).code)
            throw error
        }
        
        // Load to verify
        try await manager.loadFromPreferences()
        os_log("Verified after save, isEnabled: %{public}@", log: log, type: .info, String(manager.isEnabled))
        
        if !manager.isEnabled {
            os_log("Filter is not enabled after save, throwing error", log: log, type: .error)
            throw NetworkExtensionError.failedToEnable
        }
        
        os_log("Content filter enabled successfully", log: log, type: .info)
    }
    
    private func disableContentFilter() async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()
        manager.isEnabled = false
        try await manager.saveToPreferences()
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension NetworkExtensionManager: OSSystemExtensionRequestDelegate {
    
    nonisolated func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        os_log("System extension replacement requested", log: log, type: .info)
        return .replace
    }
    
    nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        os_log("System extension needs user approval", log: log, type: .info)
        DispatchQueue.main.async {
            self.status = "Waiting for user approval..."
        }
    }
    
    nonisolated func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        os_log("System extension request completed with result: %{public}@", log: log, type: .info, String(describing: result))
        
        DispatchQueue.main.async {
            switch result {
            case .completed:
                self.isInstalled = true
                self.status = "System extension installed"
                self.error = nil
            case .willCompleteAfterReboot:
                self.status = "Will complete after reboot"
                self.error = nil
            @unknown default:
                self.status = "Unknown completion state"
            }
        }
    }
    
    nonisolated func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        os_log("System extension request failed: %{public}@", log: log, type: .error, error.localizedDescription)
        
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.status = "Installation failed"
            self.isInstalled = false
        }
    }
}

// MARK: - Supporting Types

enum NetworkExtensionError: LocalizedError {
    case failedToEnable
    case notInstalled
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .failedToEnable:
            return "Failed to enable content filtering"
        case .notInstalled:
            return "System extension is not installed"
        case .permissionDenied:
            return "Permission required. Please approve network filtering in System Settings → General → Login Items & Extensions"
        }
    }
}