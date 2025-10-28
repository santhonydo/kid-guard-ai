import Foundation

public class AIDomainCategorizer {
    private let llmService: LLMServiceProtocol
    private var categoryCache: [String: [String]] = [:]
    
    public init(llmService: LLMServiceProtocol) {
        self.llmService = llmService
    }
    
    /// Categorize a domain using AI
    public func categorizeDomain(_ hostname: String) async throws -> [String] {
        // Check cache first
        if let cached = categoryCache[hostname] {
            return cached
        }
        
        let categories = try await performAICategorization(hostname)
        
        // Cache the result
        categoryCache[hostname] = categories
        
        return categories
    }
    
    /// Check if a domain should be blocked based on AI categorization and rules
    public func shouldBlockDomain(_ hostname: String, rules: [SimpleRule]) async throws -> Bool {
        let categories = try await categorizeDomain(hostname)
        
        for rule in rules {
            if rule.shouldBlock && ruleMatchesCategories(rule: rule, categories: categories) {
                print("🤖 AI determined \(hostname) should be blocked - matched categories: \(categories) with rule: \(rule.description)")
                return true
            }
        }
        
        return false
    }
    
    private func performAICategorization(_ hostname: String) async throws -> [String] {
        let prompt = """
        Analyze the domain "\(hostname)" and categorize it into one or more of these categories:
        
        Categories:
        - Social Media (Facebook, Instagram, Twitter, TikTok, Snapchat, LinkedIn, etc.)
        - Entertainment (YouTube, Netflix, Hulu, Twitch, gaming sites, etc.)
        - News (CNN, BBC, Reuters, news aggregators, etc.)
        - Shopping (Amazon, eBay, online stores, etc.)
        - Education (Khan Academy, Coursera, educational sites, etc.)
        - Adult Content (pornographic, adult dating, etc.)
        - Violence (violent content, weapons, etc.)
        - Gambling (casinos, betting sites, etc.)
        - Technology (GitHub, Stack Overflow, tech blogs, etc.)
        - Health (medical sites, fitness, wellness, etc.)
        - Finance (banks, investment, crypto, etc.)
        - Government (official government sites, etc.)
        - Other (miscellaneous sites)
        
        Return only the category names separated by commas, no explanations.
        Example: "Social Media, Entertainment"
        """
        
        let response = try await llmService.queryStatus(prompt)
        
        // Parse the response
        let categories = response
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return categories.isEmpty ? ["Other"] : categories
    }
    
    private func ruleMatchesCategories(rule: SimpleRule, categories: [String]) -> Bool {
        for ruleCategory in rule.categories {
            let ruleCategoryLower = ruleCategory.lowercased()
            for domainCategory in categories {
                let domainCategoryLower = domainCategory.lowercased()
                
                // Direct match
                if ruleCategoryLower == domainCategoryLower {
                    return true
                }
                
                // Partial match for broader categories
                if ruleCategoryLower.contains("social") && domainCategoryLower.contains("social") {
                    return true
                }
                if ruleCategoryLower.contains("entertainment") && domainCategoryLower.contains("entertainment") {
                    return true
                }
                if ruleCategoryLower.contains("adult") && domainCategoryLower.contains("adult") {
                    return true
                }
                if ruleCategoryLower.contains("violence") && domainCategoryLower.contains("violence") {
                    return true
                }
            }
        }
        
        return false
    }
}

// Simple rule structure for compatibility
public struct SimpleRule: Codable {
    let description: String
    let categories: [String]
    let shouldBlock: Bool
    let isActive: Bool
}
