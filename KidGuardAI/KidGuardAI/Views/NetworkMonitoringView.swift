import SwiftUI
import KidGuardCore

struct NetworkMonitoringView: View {
    @StateObject private var filterManager = FilterManager.shared
    @State private var showingInfo = false
    @State private var networkEvents: [NetworkFilterEvent] = []
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            statusSection
            controlSection
            
            if filterManager.isFilterEnabled {
                eventsSection
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Network Monitoring")
        .onAppear {
            filterManager.checkStatus()
            loadEvents()
        }
        .alert("Network Monitoring", isPresented: $showingInfo) {
            Button("Open System Preferences") {
                filterManager.showSystemPreferences()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(filterManager.status.actionNeeded ?? "Network monitoring helps protect against inappropriate content by filtering website access system-wide.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Network Protection")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("System-wide content filtering")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(filterManager.status.rawValue)
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
            
            Text(filterManager.status.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            if let errorMessage = filterManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var controlSection: some View {
        VStack(spacing: 12) {
            switch filterManager.status {
            case .notInstalled:
                Button("Install Network Monitoring") {
                    filterManager.installExtension()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filterManager.status == .installing)
                
            case .installing:
                ProgressView("Installing...")
                    .progressViewStyle(.linear)
                
            case .waitingForApproval:
                VStack(spacing: 8) {
                    Button("Open System Preferences") {
                        filterManager.showSystemPreferences()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Please approve KidGuardAI in Security & Privacy settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
            case .installed:
                Button("Enable Network Monitoring") {
                    filterManager.enableFilter()
                }
                .buttonStyle(.borderedProminent)
                
            case .enabled:
                VStack(spacing: 8) {
                    Button("Disable Network Monitoring") {
                        filterManager.disableFilter()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Sync Rules") {
                        filterManager.syncRulesToExtension()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                
            case .uninstalling:
                ProgressView("Uninstalling...")
                    .progressViewStyle(.linear)
                
            case .willCompleteAfterReboot:
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("Please restart your computer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
            case .error:
                Button("Retry Installation") {
                    filterManager.installExtension()
                }
                .buttonStyle(.borderedProminent)
            }
            
            if filterManager.status == .enabled || filterManager.status == .installed {
                Divider()
                
                Button("Uninstall", role: .destructive) {
                    filterManager.uninstallExtension()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    loadEvents()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                
                Button("Clear") {
                    filterManager.clearFilteredEvents()
                    networkEvents = []
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            
            if networkEvents.isEmpty {
                Text("No network activity recorded yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(networkEvents.prefix(10).enumerated()), id: \.offset) { _, event in
                        NetworkEventRow(event: event)
                    }
                }
                .frame(maxHeight: 200)
                
                if networkEvents.count > 10 {
                    Text("Showing 10 of \(networkEvents.count) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch filterManager.status {
        case .enabled:
            return .green
        case .installed, .notInstalled:
            return .orange
        case .error:
            return .red
        case .installing, .uninstalling, .waitingForApproval:
            return .blue
        case .willCompleteAfterReboot:
            return .purple
        }
    }
    
    private func loadEvents() {
        networkEvents = filterManager.loadFilteredEvents().sorted { $0.timestamp > $1.timestamp }
    }
}

struct NetworkEventRow: View {
    let event: NetworkFilterEvent
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.action == .blocked ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(event.action == .blocked ? .red : .green)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.hostname)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(event.sourceApp)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(formatTime(event.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NetworkMonitoringView()
}