import SwiftUI
import KidGuardCore

struct MenuBarView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: CaseIterable {
        case dashboard, rules, events, subscription
        
        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .rules: return "Rules"
            case .events: return "Activity"
            case .subscription: return "Subscription"
            }
        }
        
        var icon: String {
            switch self {
            case .dashboard: return "house"
            case .rules: return "shield"
            case .events: return "clock"
            case .subscription: return "star"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                Text("KidGuard AI")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    if coordinator.isMonitoring {
                        coordinator.stopMonitoring()
                    } else {
                        coordinator.startMonitoring()
                    }
                }) {
                    Image(systemName: coordinator.isMonitoring ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(coordinator.isMonitoring ? .orange : .green)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Tab Selection
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.title)
                                .font(.caption)
                        }
                        .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .rules:
                    RulesView()
                case .events:
                    EventsView()
                case .subscription:
                    SubscriptionView()
                }
            }
            .environmentObject(coordinator)
        }
        .frame(width: 400, height: 500)
        .alert("KidGuard AI", isPresented: $coordinator.showingAlert) {
            Button("OK") { }
        } message: {
            Text(coordinator.alertMessage)
        }
    }
}