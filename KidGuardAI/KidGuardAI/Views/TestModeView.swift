import SwiftUI

struct TestModeView: View {
    @StateObject private var testModeManager = TestModeManager.shared
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundColor(.orange)
                Text("Test Mode")
                    .font(.headline)
                Spacer()
            }
            
            // Test Mode Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable Test Mode", isOn: Binding(
                    get: { testModeManager.isTestModeEnabled },
                    set: { _ in testModeManager.toggleTestMode() }
                ))
                
                Text("Test mode allows you to test filtering behavior without switching user accounts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Admin Bypass Control
            if testModeManager.isTestModeEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Disable Admin Bypass", isOn: Binding(
                        get: { testModeManager.adminBypassDisabled },
                        set: { _ in testModeManager.toggleAdminBypass() }
                    ))
                    
                    Text("When enabled, admin users will be treated the same as regular users for filtering purposes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            // Current Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(testModeManager.isTestModeEnabled ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(testModeManager.isTestModeEnabled ? "Test Mode Active" : "Normal Mode")
                        .font(.caption)
                }
                
                if testModeManager.isTestModeEnabled {
                    HStack {
                        Circle()
                            .fill(testModeManager.adminBypassDisabled ? .red : .yellow)
                            .frame(width: 8, height: 8)
                        Text(testModeManager.adminBypassDisabled ? "Admin Bypass Disabled" : "Admin Bypass Enabled")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Warning
            if testModeManager.isTestModeEnabled && testModeManager.adminBypassDisabled {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Admin bypass is disabled. All users will be filtered equally.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Reset Button
            Button("Reset to Defaults") {
                showingResetAlert = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .alert("Reset Test Mode", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                testModeManager.resetToDefaults()
            }
        } message: {
            Text("This will disable test mode and restore normal admin privileges. Are you sure?")
        }
    }
}

#Preview {
    TestModeView()
        .frame(width: 400, height: 500)
}
