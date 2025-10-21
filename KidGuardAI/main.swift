import SwiftUI

@main
struct KidGuardAIApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        MenuBarExtra("KidGuard AI", systemImage: "shield.checkered") {
            MenuBarView()
                .environmentObject(appCoordinator)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(appCoordinator)
        }
    }
}