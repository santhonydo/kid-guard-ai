import SwiftUI
import KidGuardCore

struct SubscriptionView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedBilling: BillingPeriod = .yearly
    @State private var isPurchasing = false
    
    enum BillingPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var discount: String {
            switch self {
            case .monthly: return ""
            case .yearly: return "Save 17%"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Current Plan
                currentPlanSection
                
                // Billing Toggle
                billingToggleSection
                
                // Plans
                plansSection
                
                // Features Comparison
                featuresSection
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Upgrade Your Protection")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Get advanced AI monitoring and cloud storage")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Plan")
                    .font(.headline)
                Spacer()
                if coordinator.currentSubscription.isActive {
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coordinator.currentSubscription.tier.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    
                    if let expiresAt = coordinator.currentSubscription.expiresAt {
                        Text("Expires: \(expiresAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if coordinator.currentSubscription.tier != .free {
                    Text("$\(String(format: "%.2f", selectedBilling == .monthly ? coordinator.currentSubscription.tier.monthlyPrice : coordinator.currentSubscription.tier.yearlyPrice))")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var billingToggleSection: some View {
        HStack {
            Text("Billing Period")
                .font(.headline)
            
            Spacer()
            
            Picker("Billing", selection: $selectedBilling) {
                ForEach(BillingPeriod.allCases, id: \.self) { period in
                    HStack {
                        Text(period.rawValue)
                        if !period.discount.isEmpty {
                            Text(period.discount)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
        }
    }
    
    private var plansSection: some View {
        VStack(spacing: 12) {
            ForEach([SubscriptionTier.free, .basic, .premium], id: \.self) { tier in
                PlanCard(
                    tier: tier,
                    billingPeriod: selectedBilling,
                    isCurrentPlan: coordinator.currentSubscription.tier == tier,
                    isPurchasing: isPurchasing
                ) {
                    purchasePlan(tier)
                }
            }
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Comparison")
                .font(.headline)
            
            FeatureComparisonView()
        }
    }
    
    private func purchasePlan(_ tier: SubscriptionTier) {
        guard tier != .free else { return }
        
        isPurchasing = true
        Task {
            await coordinator.purchaseSubscription(tier)
            await MainActor.run {
                isPurchasing = false
            }
        }
    }
}

struct PlanCard: View {
    let tier: SubscriptionTier
    let billingPeriod: SubscriptionView.BillingPeriod
    let isCurrentPlan: Bool
    let isPurchasing: Bool
    let onPurchase: () -> Void
    
    private var price: Double {
        billingPeriod == .monthly ? tier.monthlyPrice : tier.yearlyPrice
    }
    
    private var priceText: String {
        if tier == .free {
            return "Free"
        } else {
            let periodicPrice = billingPeriod == .monthly ? tier.monthlyPrice : (tier.yearlyPrice / 12)
            return "$\(String(format: "%.2f", periodicPrice))/mo"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tier.displayName)
                            .font(.system(size: 18, weight: .semibold))
                        
                        if tier == .premium {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(priceText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(tier == .premium ? .blue : .primary)
                    
                    if billingPeriod == .yearly && tier != .free {
                        Text("Billed yearly: $\(String(format: "%.2f", tier.yearlyPrice))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Features
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.caption)
                        
                        Spacer()
                    }
                }
            }
            
            // Action Button
            if isCurrentPlan {
                Button("Current Plan") { }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .frame(maxWidth: .infinity)
            } else if tier == .free {
                Button("Downgrade") {
                    // Handle downgrade
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            } else {
                Button(isPurchasing ? "Processing..." : "Upgrade") {
                    onPurchase()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPurchasing)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(tier == .premium ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}

struct FeatureComparisonView: View {
    let features = [
        ("Local AI monitoring", [true, true, true]),
        ("Screenshot analysis", [true, true, true]),
        ("Voice rule setting", [true, true, true]),
        ("7-day history", [true, false, false]),
        ("Cloud storage", [false, true, true]),
        ("Unlimited history", [false, true, true]),
        ("Extended reports", [false, true, true]),
        ("Premium AI models", [false, false, true]),
        ("Advanced analytics", [false, false, true]),
        ("Priority support", [false, false, true])
    ]
    
    let tiers = [SubscriptionTier.free, .basic, .premium]
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Feature")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(tiers, id: \.self) { tier in
                    Text(tier.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 60)
                }
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            // Features
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack {
                    Text(feature.0)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(Array(feature.1.enumerated()), id: \.offset) { tierIndex, hasFeature in
                        Image(systemName: hasFeature ? "checkmark" : "xmark")
                            .foregroundColor(hasFeature ? .green : .secondary)
                            .font(.caption)
                            .frame(width: 60)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(index % 2 == 0 ? Color(.controlBackgroundColor).opacity(0.5) : Color.clear)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
            // Settings implementation would go here
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}