import Foundation

public struct Subscription: Codable {
    public let tier: SubscriptionTier
    public let isActive: Bool
    public let expiresAt: Date?
    public let cloudStorageEnabled: Bool
    public let premiumAIEnabled: Bool
    
    public init(
        tier: SubscriptionTier = .free,
        isActive: Bool = true,
        expiresAt: Date? = nil,
        cloudStorageEnabled: Bool = false,
        premiumAIEnabled: Bool = false
    ) {
        self.tier = tier
        self.isActive = isActive
        self.expiresAt = expiresAt
        self.cloudStorageEnabled = cloudStorageEnabled
        self.premiumAIEnabled = premiumAIEnabled
    }
}

public enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"
    case basic = "basic"
    case premium = "premium"
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .basic: return "Basic"
        case .premium: return "Premium"
        }
    }
    
    public var monthlyPrice: Double {
        switch self {
        case .free: return 0.0
        case .basic: return 4.99
        case .premium: return 9.99
        }
    }
    
    public var yearlyPrice: Double {
        switch self {
        case .free: return 0.0
        case .basic: return 49.99
        case .premium: return 99.99
        }
    }
    
    public var features: [String] {
        switch self {
        case .free:
            return ["Local monitoring", "Basic AI analysis", "7-day history"]
        case .basic:
            return ["All Free features", "Cloud storage", "Unlimited history", "Extended reports"]
        case .premium:
            return ["All Basic features", "Premium AI models", "Advanced analytics", "Priority support"]
        }
    }
}