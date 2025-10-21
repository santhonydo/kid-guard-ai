import Foundation

public struct Rule: Codable, Identifiable {
    public let id: UUID
    public let description: String
    public let categories: [String]
    public let actions: [RuleAction]
    public let severity: RuleSeverity
    public let isActive: Bool
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        description: String,
        categories: [String],
        actions: [RuleAction],
        severity: RuleSeverity = .medium,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.description = description
        self.categories = categories
        self.actions = actions
        self.severity = severity
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

public enum RuleAction: String, Codable, CaseIterable {
    case block = "block"
    case alert = "alert"
    case log = "log"
    case redirect = "redirect"
}

public enum RuleSeverity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}