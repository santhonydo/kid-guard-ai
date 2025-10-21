import Foundation

public struct MonitoringEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: EventType
    public let url: String?
    public let content: String?
    public let screenshotPath: String?
    public let ruleViolated: UUID?
    public let action: RuleAction
    public let severity: RuleSeverity
    public let processed: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: EventType,
        url: String? = nil,
        content: String? = nil,
        screenshotPath: String? = nil,
        ruleViolated: UUID? = nil,
        action: RuleAction,
        severity: RuleSeverity,
        processed: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.url = url
        self.content = content
        self.screenshotPath = screenshotPath
        self.ruleViolated = ruleViolated
        self.action = action
        self.severity = severity
        self.processed = processed
    }
}

public enum EventType: String, Codable, CaseIterable {
    case webRequest = "web_request"
    case screenshot = "screenshot"
    case messaging = "messaging"
    case appUsage = "app_usage"
}