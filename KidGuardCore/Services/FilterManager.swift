import Foundation
import NetworkExtension
import SystemExtensions
import AppKit

@MainActor
public class FilterManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isExtensionEnabled = false
    @Published public var isFilterEnabled = false
    @Published public var status: FilterStatus = .notInstalled
    @Published public var needsUserApproval = false
    @Published public var errorMessage: String?
    
    // MARK: - Properties
    
    public static let shared = FilterManager()
    private let extensionIdentifier = "com.kidguardai.KidGuardAI.KidGuardAIFilterExtension"
    private let storageService = StorageService.shared
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        checkStatus()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    public func installExtension() {
        print("FilterManager: Installing system extension...")
        status = .installing
        needsUserApproval = false
        errorMessage = nil
        
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    public func uninstallExtension() {
        print("FilterManager: Uninstalling system extension...")
        status = .uninstalling
        
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    public func enableFilter() {
        print("FilterManager: Enabling network filter...")
        
        let manager = NEFilterManager.shared()
        
        manager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("FilterManager: Failed to load preferences: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load filter preferences: \(error.localizedDescription)"
                    self.status = .error
                }
                return
            }
            
            // Configure the filter if not already configured
            if manager.providerConfiguration == nil {
                let config = NEFilterProviderConfiguration()
                config.organization = "KidGuardAI"
                config.filterSockets = true
                config.filterPackets = false
                config.username = "KidGuardAI User"
                
                manager.providerConfiguration = config
            }
            
            manager.isEnabled = true
            
            manager.saveToPreferences { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("FilterManager: Failed to enable filter: \(error)")
                        self?.errorMessage = "Failed to enable filter: \(error.localizedDescription)"
                        self?.status = .error
                    } else {
                        print("FilterManager: Filter enabled successfully")
                        self?.isFilterEnabled = true
                        self?.status = .enabled
                        self?.syncRulesToExtension()
                    }
                }
            }
        }
    }
    
    public func disableFilter() {
        print("FilterManager: Disabling network filter...")
        
        let manager = NEFilterManager.shared()
        
        manager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("FilterManager: Failed to load preferences: \(error)")
                return
            }
            
            manager.isEnabled = false
            
            manager.saveToPreferences { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("FilterManager: Failed to disable filter: \(error)")
                        self?.errorMessage = "Failed to disable filter: \(error.localizedDescription)"
                    } else {
                        print("FilterManager: Filter disabled successfully")
                        self?.isFilterEnabled = false
                        self?.status = .installed
                    }
                }
            }
        }
    }
    
    public func checkStatus() {
        // Check system extension status
        checkExtensionStatus()
        
        // Check filter status
        checkFilterStatus()
    }
    
    public func syncRulesToExtension() {
        print("FilterManager: Syncing rules to extension...")
        
        let rules = storageService.loadRules()
        
        do {
            try SharedStorage.saveRules(rules)
            print("FilterManager: Successfully synced \(rules.count) rules to extension")
        } catch {
            print("FilterManager: Failed to sync rules: \(error)")
            errorMessage = "Failed to sync rules: \(error.localizedDescription)"
        }
    }
    
    public func loadFilteredEvents() -> [NetworkFilterEvent] {
        do {
            return try SharedStorage.loadEvents()
        } catch {
            print("FilterManager: Failed to load filter events: \(error)")
            return []
        }
    }
    
    public func clearFilteredEvents() {
        do {
            try SharedStorage.clearEvents()
            print("FilterManager: Cleared filter events")
        } catch {
            print("FilterManager: Failed to clear filter events: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkExtensionStatus() {
        // This is a simplified check - in a real implementation,
        // you'd query OSSystemExtensionManager for actual status
        
        // For now, assume extension needs to be installed
        if status == .notInstalled {
            status = .notInstalled
            isExtensionEnabled = false
        }
    }
    
    private func checkFilterStatus() {
        let manager = NEFilterManager.shared()
        
        manager.loadFromPreferences { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("FilterManager: Failed to check filter status: \(error)")
                    self.isFilterEnabled = false
                    return
                }
                
                self.isFilterEnabled = manager.isEnabled
                
                if self.isFilterEnabled && self.status != .enabled {
                    self.status = .enabled
                } else if !self.isFilterEnabled && self.status == .enabled {
                    self.status = .installed
                }
                
                print("FilterManager: Filter status - enabled: \(self.isFilterEnabled)")
            }
        }
    }
    
    private func setupNotifications() {
        // Listen for changes to NEFilterManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(filterConfigurationChanged),
            name: .NEFilterConfigurationDidChange,
            object: nil
        )
    }
    
    @objc private func filterConfigurationChanged() {
        checkFilterStatus()
    }
    
    public func showSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension FilterManager: OSSystemExtensionRequestDelegate {
    
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        print("FilterManager: System extension request finished with result: \(result.rawValue)")
        
        DispatchQueue.main.async {
            switch result {
            case .completed:
                self.status = .installed
                self.isExtensionEnabled = true
                self.needsUserApproval = false
                
                // Automatically try to enable the filter
                self.enableFilter()
                
            case .willCompleteAfterReboot:
                self.status = .willCompleteAfterReboot
                
            @unknown default:
                self.status = .error
                self.errorMessage = "Unknown result: \(result.rawValue)"
            }
        }
    }
    
    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        print("FilterManager: System extension request failed: \(error)")
        
        DispatchQueue.main.async {
            self.status = .error
            self.errorMessage = error.localizedDescription
            self.needsUserApproval = false
        }
    }
    
    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        print("FilterManager: System extension needs user approval")
        
        DispatchQueue.main.async {
            self.needsUserApproval = true
            self.status = .waitingForApproval
        }
    }
    
    public func request(_ request: OSSystemExtensionRequest, 
                       actionForReplacingExtension existing: OSSystemExtensionProperties,
                       withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        print("FilterManager: Replacing existing extension")
        return .replace
    }
}

// MARK: - Supporting Types

public enum FilterStatus: String, CaseIterable {
    case notInstalled = "Not Installed"
    case installing = "Installing..."
    case waitingForApproval = "Waiting for Approval"
    case installed = "Installed"
    case enabled = "Active"
    case uninstalling = "Uninstalling..."
    case willCompleteAfterReboot = "Will Complete After Reboot"
    case error = "Error"
    
    public var description: String {
        switch self {
        case .notInstalled:
            return "Network monitoring is not installed"
        case .installing:
            return "Installing network monitoring..."
        case .waitingForApproval:
            return "Waiting for user approval in System Preferences"
        case .installed:
            return "Network monitoring is installed but not active"
        case .enabled:
            return "Network monitoring is active"
        case .uninstalling:
            return "Uninstalling network monitoring..."
        case .willCompleteAfterReboot:
            return "Installation will complete after reboot"
        case .error:
            return "An error occurred"
        }
    }
    
    public var actionNeeded: String? {
        switch self {
        case .waitingForApproval:
            return "Please approve in System Preferences > Privacy & Security"
        case .willCompleteAfterReboot:
            return "Please restart your computer to complete installation"
        default:
            return nil
        }
    }
}