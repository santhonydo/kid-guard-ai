import SwiftUI

struct KidGuardAIApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        MenuBarExtra("KidGuard AI", systemImage: "shield.checkered") {
            MenuBarView()
                .environmentObject(appCoordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

// Entry point for the app
KidGuardAIApp.main()
