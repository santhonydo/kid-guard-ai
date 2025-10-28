import Foundation
import KidGuardCore
import OSLog

class AIRuleSyncService {
    static let shared = AIRuleSyncService()
    
    private let log = OSLog(subsystem: "com.kidguardai.app", category: "ai-rule-sync")
    private let storageService = StorageService.shared
    private let aiCategorizer: AIDomainCategorizer
    private var domainCache: [String: Bool] = [:]
    
    private init() {
        // Initialize with LLM service
        let llmService = LLMService()
        self.aiCategorizer = AIDomainCategorizer(llmService: llmService)
    }
    
    // Enhanced rule structure for Network Extension with AI data
    struct AIRule: Codable {
        let description: String
        let categories: [String]
        let shouldBlock: Bool
        let isActive: Bool
        let aiCategories: [String]? // AI-determined categories
        let domainPatterns: [String] // Known domain patterns
    }
    
    func syncRulesToExtension() {
        os_log("Syncing AI-enhanced rules to Network Extension", log: log, type: .info)
        
        Task {
            do {
                // Load rules from main app storage
                let rules = try storageService.loadRules()
                
                // Convert to AI-enhanced format
                let aiRules = await convertRulesToAIEnhanced(rules)
                
                // Save to App Group for Network Extension
                try saveAIRules(aiRules)
                
                os_log("Synced %d AI-enhanced rules to Network Extension", log: log, type: .info, aiRules.count)
                
            } catch {
                os_log("Failed to sync AI rules: %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func convertRulesToAIEnhanced(_ rules: [Rule]) async -> [AIRule] {
        var aiRules: [AIRule] = []
        
        for rule in rules {
            // Get AI categories for common domains
            let aiCategories = await getAICategoriesForRule(rule)
            
            // Extract domain patterns from rule description
            let domainPatterns = extractDomainPatterns(from: rule.description)
            
            let aiRule = AIRule(
                description: rule.description,
                categories: rule.categories,
                shouldBlock: rule.actions.contains(.block),
                isActive: rule.isActive,
                aiCategories: aiCategories,
                domainPatterns: domainPatterns
            )
            
            aiRules.append(aiRule)
        }
        
        return aiRules
    }
    
    private func getAICategoriesForRule(_ rule: Rule) async -> [String]? {
        // Extract potential domains from rule description
        let domains = extractDomainsFromDescription(rule.description)
        
        if domains.isEmpty {
            return nil
        }
        
        // Get AI categories for the first domain (most relevant)
        if let firstDomain = domains.first {
            do {
                return try await aiCategorizer.categorizeDomain(firstDomain)
            } catch {
                os_log("Failed to get AI categories for %{public}@: %{public}@", log: log, type: .error, firstDomain, error.localizedDescription)
            }
        }
        
        return nil
    }
    
    private func extractDomainPatterns(from description: String) -> [String] {
        let text = description.lowercased()
        var patterns: [String] = []
        
        // Common domain patterns
        let commonDomains = ["tiktok", "facebook", "instagram", "twitter", "youtube", "snapchat", "netflix", "reddit", "pinterest", "linkedin"]
        
        for domain in commonDomains {
            if text.contains(domain) {
                patterns.append(domain)
            }
        }
        
        return patterns
    }
    
    private func extractDomainsFromDescription(_ description: String) -> [String] {
        let text = description.lowercased()
        var domains: [String] = []
        
        // Look for .com, .org, .net patterns
        let regex = try? NSRegularExpression(pattern: "\\b[a-zA-Z0-9-]+\\.(com|org|net|edu|gov)\\b")
        let range = NSRange(location: 0, length: text.utf16.count)
        
        if let matches = regex?.matches(in: text, range: range) {
            for match in matches {
                if let range = Range(match.range, in: text) {
                    domains.append(String(text[range]))
                }
            }
        }
        
        return domains
    }
    
    private func saveAIRules(_ rules: [AIRule]) throws {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.kidguardai.shared") else {
            throw RuleSyncError.noAppGroupContainer
        }
        
        let rulesURL = containerURL.appendingPathComponent("ai-rules.json")
        let data = try JSONEncoder().encode(rules)
        try data.write(to: rulesURL, options: .atomic)
        
        os_log("Saved AI rules to: %{public}@", log: log, type: .debug, rulesURL.path)
    }
}

