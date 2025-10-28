import SwiftUI

struct NetworkExtensionView: View {
    @StateObject private var extensionManager = SystemExtensionManager()
    @State private var showingUninstallConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.blue)
                Text("Network Protection")
                    .font(.headline)
                Spacer()
            }
            
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(extensionManager.status)
                        .font(.caption)
                    Spacer()
                }
                
                if let error = extensionManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 16)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Controls Section
            VStack(spacing: 12) {
                if !extensionManager.isInstalled {
                    Button(action: {
                        extensionManager.installSystemExtension()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Install System Extension")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(extensionManager.status.contains("Installing"))
                } else {
                    HStack(spacing: 8) {
                        if extensionManager.isInstalled {
                            Button("Uninstall Extension") {
                                extensionManager.uninstallSystemExtension()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Install Extension") {
                                extensionManager.installSystemExtension()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if showingUninstallConfirmation {
                            VStack(spacing: 8) {
                                Text("Are you sure you want to uninstall?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Button("Cancel") {
                                        showingUninstallConfirmation = false
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button("Uninstall") {
                                        extensionManager.uninstallSystemExtension()
                                        showingUninstallConfirmation = false
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                }
                            }
                        } else {
                            Button("Uninstall") {
                                showingUninstallConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                }
                
                if extensionManager.isInstalled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Network filtering is active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Instructions
            if !extensionManager.isInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Setup Instructions:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Click 'Install System Extension'")
                        Text("2. Approve the system extension in System Settings")
                        Text("3. Click 'Enable Filtering' to start blocking content")
                        Text("4. Test with facebook.com or tiktok.com")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var statusColor: Color {
        if extensionManager.error != nil {
            return .red
        } else if extensionManager.isInstalled {
            return .green
        } else {
            return .gray
        }
    }
    
}

#Preview {
    NetworkExtensionView()
        .frame(width: 400, height: 500)
}