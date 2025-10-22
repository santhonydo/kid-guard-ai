import SwiftUI
import KidGuardCore

struct DashboardView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status Section
                statusSection
                
                // Quick Actions
                quickActionsSection
                
                // Recent Activity Preview
                recentActivitySection
                
                Spacer()
            }
            .padding()
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Status")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(coordinator.isMonitoring ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(coordinator.isMonitoring ? "Active" : "Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                StatusCard(
                    title: "Rules",
                    value: "\(coordinator.rules.filter { $0.isActive }.count)",
                    subtitle: "Active",
                    icon: "shield",
                    color: .blue
                )
                
                StatusCard(
                    title: "Events",
                    value: "\(coordinator.recentEvents.count)",
                    subtitle: "Today",
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                ActionButton(
                    title: "Add Rule by Voice",
                    icon: "mic",
                    color: .green
                ) {
                    coordinator.startVoiceInput()
                }
                
                ActionButton(
                    title: "Pause for 1 Hour",
                    icon: "pause",
                    color: .orange
                ) {
                    coordinator.pauseMonitoring(for: 3600)
                }
                
                ActionButton(
                    title: "View All Activity",
                    icon: "list.bullet",
                    color: .blue
                ) {
                    // Switch to events tab
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                Text("Last 24 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if coordinator.recentEvents.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(coordinator.recentEvents.prefix(3)) { event in
                    EventRowView(event: event)
                }
            }
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EventRowView: View {
    let event: MonitoringEvent
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForEvent(event))
                .foregroundColor(colorForSeverity(event.severity))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let url = event.url {
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString(from: event.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if event.action == .block {
                    Text("BLOCKED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForEvent(_ event: MonitoringEvent) -> String {
        switch event.type {
        case .webRequest: return "globe"
        case .screenshot: return "camera"
        case .messaging: return "message"
        case .appUsage: return "app"
        }
    }
    
    private func colorForSeverity(_ severity: RuleSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
