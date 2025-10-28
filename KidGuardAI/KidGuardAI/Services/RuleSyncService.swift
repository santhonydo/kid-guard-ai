import Foundation
import KidGuardCore
import OSLog

class RuleSyncService {
    static let shared = RuleSyncService()
    
    private let log = OSLog(subsystem: "com.kidguardai.app", category: "rule-sync")
    private let storageService = StorageService.shared
    
    private init() {}
    
    // Simple rule structure for Network Extension
    struct SimpleRule: Codable {
        let description: String
        let categories: [String]
        let shouldBlock: Bool
        let isActive: Bool
    }
    
    func syncRulesToExtension() {
        os_log("Syncing rules to Network Extension", log: log, type: .info)
        
        // Try AI-enhanced sync first
        AIRuleSyncService.shared.syncRulesToExtension()
        
        // Also sync simple rules as fallback
        do {
            // Load rules from main app storage
            let rules = try storageService.loadRules()
            
            // Convert to simple format for Network Extension
            let simpleRules = rules.map { rule in
                SimpleRule(
                    description: rule.description,
                    categories: rule.categories,
                    shouldBlock: rule.actions.contains(.block),
                    isActive: rule.isActive
                )
            }
            
            // Save to App Group for Network Extension
            try saveSimpleRules(simpleRules)
            
            os_log("Synced %d simple rules as fallback", log: log, type: .info, simpleRules.count)
            
        } catch {
            os_log("Failed to sync simple rules: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }
    
    func syncAIRulesToExtension() {
        os_log("Syncing AI-enhanced rules to Network Extension", log: log, type: .info)
        
        // Use the AI rule sync service
        AIRuleSyncService.shared.syncRulesToExtension()
    }
    
    private func saveSimpleRules(_ rules: [SimpleRule]) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kidguardai.shared") else {
            throw RuleSyncError.noAppGroupContainer
        }
        
        let rulesURL = containerURL.appendingPathComponent("simple-rules.json")
        let data = try JSONEncoder().encode(rules)
        try data.write(to: rulesURL, options: .atomic)
        
        os_log("Saved rules to: %{public}@", log: log, type: .debug, rulesURL.path)
    }
}

enum RuleSyncError: LocalizedError {
    case noAppGroupContainer
    
    var errorDescription: String? {
        switch self {
        case .noAppGroupContainer:
            return "Cannot access App Group container"
        }
    }
}