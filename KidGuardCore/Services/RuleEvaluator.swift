import Foundation

public class RuleEvaluator {
    private var rules: [Rule] = []
    private var hostnameCache: [String: Bool] = [:]
    
    public init() {}
    
    public func loadRules(_ rules: [Rule]) {
        self.rules = rules.filter { $0.isActive }
        self.hostnameCache.removeAll()
        print("RuleEvaluator loaded \(self.rules.count) active rules")
    }
    
    public func shouldBlock(hostname: String) -> Bool {
        // Check cache first for performance
        if let cached = hostnameCache[hostname] {
            return cached
        }
        
        let result = evaluateHostname(hostname)
        
        // Cache result (limit cache size to prevent memory issues)
        if hostnameCache.count < 1000 {
            hostnameCache[hostname] = result
        }
        
        return result
    }
    
    private func evaluateHostname(_ hostname: String) -> Bool {
        // Clean hostname (remove port, etc.)
        let cleanHostname = cleanHostname(hostname)
        
        for rule in rules {
            // Check if rule should block this hostname
            if ruleMatchesHostname(rule: rule, hostname: cleanHostname) {
                // If rule contains block action, block it
                if rule.actions.contains(.block) {
                    print("Blocking \(hostname) - matched rule: \(rule.description)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func ruleMatchesHostname(rule: Rule, hostname: String) -> Bool {
        // For now, use simple category-based matching
        // This can be enhanced with more sophisticated parsing
        
        let lowerHostname = hostname.lowercased()
        
        for category in rule.categories {
            let lowerCategory = category.lowercased()
            
            // Direct hostname match
            if lowerHostname.contains(lowerCategory) {
                return true
            }
            
            // Common domain patterns
            if matchesCategoryPattern(category: lowerCategory, hostname: lowerHostname) {
                return true
            }
        }
        
        // Also check rule description for explicit hostnames
        return ruleDescriptionMatchesHostname(rule: rule, hostname: lowerHostname)
    }
    
    private func matchesCategoryPattern(category: String, hostname: String) -> Bool {
        // Map categories to common domain patterns
        switch category {
        case "adult", "pornography":
            return hostname.contains("porn") || 
                   hostname.contains("xxx") || 
                   hostname.contains("adult") ||
                   hostname.contains("sex")
        case "violence", "violent":
            return hostname.contains("violence") ||
                   hostname.contains("gore") ||
                   hostname.contains("death")
        case "gambling":
            return hostname.contains("casino") ||
                   hostname.contains("poker") ||
                   hostname.contains("bet") ||
                   hostname.contains("gambling")
        case "social", "social media":
            return hostname.contains("facebook") ||
                   hostname.contains("twitter") ||
                   hostname.contains("instagram") ||
                   hostname.contains("tiktok") ||
                   hostname.contains("snapchat")
        case "gaming", "games":
            return hostname.contains("gaming") ||
                   hostname.contains("steam") ||
                   hostname.contains("game")
        case "youtube", "video":
            return hostname.contains("youtube") ||
                   hostname.contains("youtu.be")
        default:
            return false
        }
    }
    
    private func ruleDescriptionMatchesHostname(rule: Rule, hostname: String) -> Bool {
        let description = rule.description.lowercased()
        
        // Extract hostnames from rule description
        // Look for patterns like "block youtube.com" or "no facebook"
        if description.contains(hostname) {
            return true
        }
        
        // Check for common domain names mentioned in description
        let commonDomains = ["youtube.com", "facebook.com", "twitter.com", "instagram.com", 
                           "tiktok.com", "snapchat.com", "reddit.com", "discord.com"]
        
        for domain in commonDomains {
            if description.contains(domain) && hostname.contains(domain.replacingOccurrences(of: ".com", with: "")) {
                return true
            }
        }
        
        return false
    }
    
    private func cleanHostname(_ hostname: String) -> String {
        var clean = hostname
        
        // Remove port number
        if let colonIndex = clean.firstIndex(of: ":") {
            clean = String(clean[..<colonIndex])
        }
        
        // Remove www. prefix
        if clean.hasPrefix("www.") {
            clean = String(clean.dropFirst(4))
        }
        
        return clean
    }
    
    public func getMatchingRules(for hostname: String) -> [Rule] {
        let cleanHostname = cleanHostname(hostname)
        return rules.filter { ruleMatchesHostname(rule: $0, hostname: cleanHostname) }
    }
}