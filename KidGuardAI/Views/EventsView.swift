import SwiftUI
import KidGuardCore

struct EventsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedFilter: EventFilter = .all
    @State private var searchText = ""
    
    enum EventFilter: String, CaseIterable {
        case all = "All"
        case violations = "Violations"
        case blocked = "Blocked"
        case today = "Today"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .violations: return "exclamationmark.triangle"
            case .blocked: return "xmark.circle"
            case .today: return "calendar"
            }
        }
    }
    
    var filteredEvents: [MonitoringEvent] {
        var events = coordinator.recentEvents
        
        // Apply text search
        if !searchText.isEmpty {
            events = events.filter { event in
                (event.url?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.content?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            return events
        case .violations:
            return events.filter { $0.ruleViolated != nil }
        case .blocked:
            return events.filter { $0.action == .block }
        case .today:
            let today = Calendar.current.startOfDay(for: Date())
            return events.filter { Calendar.current.startOfDay(for: $0.timestamp) == today }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Text("Activity Monitor")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(filteredEvents.count) events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search events...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(8)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EventFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                icon: filter.icon,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            
            Divider()
            
            // Events List
            if filteredEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No events found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(emptyStateMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredEvents) { event in
                            EventDetailRow(event: event)
                                .background(Color(.controlBackgroundColor))
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return coordinator.isMonitoring ? "No activity detected yet" : "Start monitoring to see activity"
        case .violations:
            return "No rule violations detected"
        case .blocked:
            return "No content has been blocked"
        case .today:
            return "No activity today"
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EventDetailRow: View {
    let event: MonitoringEvent
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Row
            HStack(spacing: 12) {
                // Icon and Severity
                VStack(spacing: 4) {
                    Image(systemName: iconForEvent)
                        .foregroundColor(colorForSeverity)
                        .font(.system(size: 16))
                    
                    if event.ruleViolated != nil {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.type.rawValue.capitalized)
                            .font(.system(size: 13, weight: .medium))
                        
                        Spacer()
                        
                        Text(timeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let url = event.url {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    
                    if let content = event.content, !content.isEmpty {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }
                
                // Action Badge
                VStack(alignment: .trailing, spacing: 4) {
                    ActionBadge(action: event.action)
                    
                    if event.ruleViolated != nil {
                        Text("VIOLATION")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    HStack {
                        Text("Details")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    DetailRow(label: "Type", value: event.type.rawValue)
                    DetailRow(label: "Severity", value: event.severity.rawValue.capitalized)
                    DetailRow(label: "Action", value: event.action.rawValue.capitalized)
                    DetailRow(label: "Timestamp", value: fullTimeString)
                    
                    if let url = event.url {
                        DetailRow(label: "URL", value: url)
                    }
                    
                    if let screenshotPath = event.screenshotPath {
                        DetailRow(label: "Screenshot", value: URL(fileURLWithPath: screenshotPath).lastPathComponent)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private var iconForEvent: String {
        switch event.type {
        case .webRequest: return "globe"
        case .screenshot: return "camera"
        case .messaging: return "message"
        case .appUsage: return "app"
        }
    }
    
    private var colorForSeverity: Color {
        switch event.severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.timestamp)
    }
    
    private var fullTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: event.timestamp)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .lineLimit(3)
            
            Spacer()
        }
    }
}