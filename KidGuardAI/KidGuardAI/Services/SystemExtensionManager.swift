import Foundation
import SystemExtensions
import OSLog
import Combine

@MainActor
class SystemExtensionManager: NSObject, ObservableObject {
    @Published var isInstalled = false
    @Published var status = "Checking..."
    @Published var error: String?
    
    private let log = OSLog(subsystem: "com.kidguardai.KidGuardAI", category: "SystemExtension")
    private let logger = Logger(subsystem: "com.kidguardai.KidGuardAI", category: "SystemExtension")
    
    override init() {
        super.init()
        checkInstallationStatus()
    }
    
    func checkInstallationStatus() {
        // Check if the system extension is installed
        // This is a simplified check - in a real implementation, you'd query the system
        status = "Not installed"
        isInstalled = false
    }
    
    func installSystemExtension() {
        guard !isInstalled else { return }
        
        status = "Installing..."
        error = nil
        
        // Create the system extension request
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: "com.kidguardai.KidGuardAI.KidGuardAIFilterExtension",
            queue: .main
        )
        request.delegate = self
        
        // Submit the request
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    
    func uninstallSystemExtension() {
        guard isInstalled else { return }
        
        status = "Uninstalling..."
        error = nil
        
        // Create the system extension request
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: "com.kidguardai.KidGuardAI.KidGuardAIFilterExtension",
            queue: .main
        )
        request.delegate = self
        
        // Submit the request
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

// MARK: - OSSystemExtensionRequestDelegate
extension SystemExtensionManager: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("System extension request finished with result: \(result.rawValue)")
        
        switch result {
        case .completed:
            // For now, assume installation completed successfully
            // In a real implementation, you'd track the request type
            isInstalled = true
            status = "Installed"
            logger.info("System extension operation completed successfully")
        case .willCompleteAfterReboot:
            status = "Will complete after reboot"
            logger.info("System extension operation will complete after reboot")
        @unknown default:
            status = "Unknown result"
            logger.warning("Unknown system extension result: \(result.rawValue)")
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension request failed: \(error.localizedDescription)")
        if let osError = error as? OSSystemExtensionError {
            logger.error("OSSystemExtensionError code: \(osError.code.rawValue)")
        }
        os_log("System extension request failed: %{public}@", log: log, type: .error, error.localizedDescription)
        
        self.error = "Installation failed: \(error.localizedDescription)"
        status = "Installation failed"
        isInstalled = false
    }
    
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension request needs user approval")
        status = "Waiting for user approval..."
        os_log("System extension request needs user approval", log: log, type: .info)
    }
    
    func request(_ request: OSSystemExtensionRequest, 
                foundProperties properties: [OSSystemExtensionProperties]) {
        logger.info("Found system extension properties: \(properties.count)")
        for property in properties {
            logger.info("Extension: \(property.bundleIdentifier)")
        }
    }
    
    func request(_ request: OSSystemExtensionRequest, 
                actionForReplacingExtension existing: OSSystemExtensionProperties, 
                withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        logger.info("System extension replacement requested")
        return .replace
    }
}