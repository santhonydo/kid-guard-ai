import Foundation
import Security
import Combine

class TestModeManager: ObservableObject {
    static let shared = TestModeManager()
    
    @Published var isTestModeEnabled = false
    @Published var adminBypassDisabled = false
    
    private let testModeKey = "com.kidguardai.testmode"
    private let adminBypassKey = "com.kidguardai.disableadminbypass"
    
    private init() {
        loadSettings()
    }
    
    func toggleTestMode() {
        isTestModeEnabled.toggle()
        saveSettings()
        
        if isTestModeEnabled {
            print("🧪 Test Mode ENABLED - Admin bypasses may be disabled")
        } else {
            print("🧪 Test Mode DISABLED - Normal admin privileges")
        }
    }
    
    func toggleAdminBypass() {
        adminBypassDisabled.toggle()
        saveSettings()
        
        if adminBypassDisabled {
            print("🔒 Admin bypass DISABLED - All users treated equally")
        } else {
            print("🔓 Admin bypass ENABLED - Admin users have privileges")
        }
    }
    
    func shouldApplyFiltering() -> Bool {
        // If test mode is enabled and admin bypass is disabled, always apply filtering
        if isTestModeEnabled && adminBypassDisabled {
            return true
        }
        
        // If test mode is disabled, check if user is admin
        if !isTestModeEnabled {
            return !isCurrentUserAdmin()
        }
        
        // Default behavior
        return true
    }
    
    private func isCurrentUserAdmin() -> Bool {
        // Check if current user is in admin group
        let adminGroup = "admin"
        
        // Get current user
        let currentUser = NSUserName()
        
        // Check if user is in admin group using dscl
        let task = Process()
        task.launchPath = "/usr/bin/dscl"
        task.arguments = [".", "-read", "/Groups/\(adminGroup)", "GroupMembership"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return output.contains(currentUser)
        } catch {
            print("Error checking admin status: \(error)")
            return false
        }
    }
    
    private func loadSettings() {
        isTestModeEnabled = UserDefaults.standard.bool(forKey: testModeKey)
        adminBypassDisabled = UserDefaults.standard.bool(forKey: adminBypassKey)
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isTestModeEnabled, forKey: testModeKey)
        UserDefaults.standard.set(adminBypassDisabled, forKey: adminBypassKey)
    }
    
    func resetToDefaults() {
        isTestModeEnabled = false
        adminBypassDisabled = false
        saveSettings()
        print("🔄 Test mode reset to defaults")
    }
}
