import SwiftUI
import KidGuardCore

struct RulesView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showingAddRule = false
    @State private var newRuleText = ""
    @State private var isAddingRule = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Monitoring Rules")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddRule = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Rules List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(coordinator.rules) { rule in
                        RuleCard(rule: rule) {
                            coordinator.toggleRule(rule)
                        } onDelete: {
                            coordinator.removeRule(rule)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            if coordinator.rules.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No rules configured")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add your first rule to start monitoring")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Rule") {
                        showingAddRule = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .sheet(isPresented: $showingAddRule) {
            AddRuleSheet(
                text: $newRuleText,
                isLoading: $isAddingRule,
                onAdd: {
                    guard !newRuleText.isEmpty else { return }

                    isAddingRule = true
                    Task {
                        await coordinator.addRule(from: newRuleText)
                        await MainActor.run {
                            newRuleText = ""
                            isAddingRule = false
                            showingAddRule = false
                        }
                    }
                }
            )
        }
    }
}

struct RuleCard: View {
    let rule: Rule
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.description)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(2)
                    
                    HStack {
                        ForEach(rule.categories.prefix(3), id: \.self) { category in
                            Text(category)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        if rule.categories.count > 3 {
                            Text("+\(rule.categories.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { rule.isActive },
                        set: { _ in onToggle() }
                    ))
                    .toggleStyle(SwitchToggleStyle())

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: severityIcon(rule.severity))
                        .foregroundColor(severityColor(rule.severity))
                        .font(.caption)
                    Text(rule.severity.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(rule.actions, id: \.self) { action in
                        ActionBadge(action: action)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .opacity(rule.isActive ? 1.0 : 0.6)
    }
    
    private func severityIcon(_ severity: RuleSeverity) -> String {
        switch severity {
        case .low: return "circle"
        case .medium: return "diamond"
        case .high: return "triangle"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }
    
    private func severityColor(_ severity: RuleSeverity) -> Color {
        switch severity {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct ActionBadge: View {
    let action: RuleAction
    
    var body: some View {
        Text(action.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(3)
    }
    
    private var backgroundColor: Color {
        switch action {
        case .block: return .red.opacity(0.2)
        case .alert: return .orange.opacity(0.2)
        case .log: return .blue.opacity(0.2)
        case .redirect: return .purple.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch action {
        case .block: return .red
        case .alert: return .orange
        case .log: return .blue
        case .redirect: return .purple
        }
    }
}

struct AddRuleSheet: View {
    @Binding var text: String
    @Binding var isLoading: Bool
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Monitoring Rule")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Describe what you want to monitor or block in natural language.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Rule Description")
                    .font(.caption)
                    .fontWeight(.medium)

                ZStack(alignment: .topLeading) {
                    // Placeholder text
                    if text.isEmpty {
                        Text("e.g., Block violent content and mature themes")
                            .font(.body)
                            .foregroundColor(Color(.placeholderTextColor))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $text)
                        .font(.body)
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTextFieldFocused ? Color.accentColor : Color(.separatorColor), lineWidth: isTextFieldFocused ? 2 : 1)
                        )
                        .focused($isTextFieldFocused)
                }
            }

            Text("Examples:")
                .font(.caption)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 4) {
                ExampleText("Block violent content and mature themes")
                ExampleText("Alert me if social media is accessed")
                ExampleText("Log all messaging activity")
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button(isLoading ? "Adding..." : "Add Rule") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty || isLoading)
            }
        }
        .padding()
        .frame(width: 450, height: 380)
        .onAppear {
            // Auto-focus the text field when the sheet opens
            isTextFieldFocused = true
        }
    }
}

struct ExampleText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text("• \(text)")
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}
