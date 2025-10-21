import Foundation
import StoreKit

public protocol SubscriptionServiceDelegate: AnyObject {
    func subscriptionService(_ service: SubscriptionService, didUpdateSubscription subscription: Subscription)
    func subscriptionService(_ service: SubscriptionService, didFailWithError error: Error)
}

public class SubscriptionService: NSObject, ObservableObject {
    public static let shared = SubscriptionService()
    
    public weak var delegate: SubscriptionServiceDelegate?
    
    @Published public var currentSubscription = Subscription()
    @Published public var availableProducts: [Product] = []
    @Published public var isLoading = false
    
    private let productIDs = [
        "com.kidguardai.basic.monthly",
        "com.kidguardai.basic.yearly", 
        "com.kidguardai.premium.monthly",
        "com.kidguardai.premium.yearly"
    ]
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    private override init() {
        super.init()
        updateListenerTask = listenForTransactions()
        loadStoredSubscription()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    public func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: productIDs)
            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
            }
        } catch {
            delegate?.subscriptionService(self, didFailWithError: error)
        }
    }
    
    public func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscription(from: transaction)
            await transaction.finish()
            
        case .userCancelled:
            break
            
        case .pending:
            break
            
        @unknown default:
            break
        }
    }
    
    public func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            let transaction = try? checkVerified(result)
            if let transaction = transaction {
                await updateSubscription(from: transaction)
            }
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscription(from: transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updateSubscription(from transaction: Transaction) async {
        let tier = determineTier(from: transaction.productID)
        let expirationDate = transaction.expirationDate
        
        let subscription = Subscription(
            tier: tier,
            isActive: !transaction.isUpgraded,
            expiresAt: expirationDate,
            cloudStorageEnabled: tier != .free,
            premiumAIEnabled: tier == .premium
        )
        
        await MainActor.run {
            self.currentSubscription = subscription
            self.delegate?.subscriptionService(self, didUpdateSubscription: subscription)
        }
        
        saveSubscription(subscription)
    }
    
    private func determineTier(from productID: String) -> SubscriptionTier {
        if productID.contains("premium") {
            return .premium
        } else if productID.contains("basic") {
            return .basic
        } else {
            return .free
        }
    }
    
    private func saveSubscription(_ subscription: Subscription) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(subscription) {
            UserDefaults.standard.set(data, forKey: "currentSubscription")
        }
    }
    
    private func loadStoredSubscription() {
        if let data = UserDefaults.standard.data(forKey: "currentSubscription") {
            let decoder = JSONDecoder()
            if let subscription = try? decoder.decode(Subscription.self, from: data) {
                currentSubscription = subscription
            }
        }
    }
}

public enum SubscriptionError: Error {
    case failedVerification
    case networkError
    case unknownError
    
    public var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Failed to verify purchase"
        case .networkError:
            return "Network error occurred"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}