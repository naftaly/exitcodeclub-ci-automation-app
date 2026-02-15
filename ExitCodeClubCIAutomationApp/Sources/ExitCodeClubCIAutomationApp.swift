import SwiftUI

@main
struct ExitCodeClubCIAutomationApp: App {
    @StateObject private var manager = CrashAutomationManager.shared

    init() {
        CrashAutomationManager.shared.startIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
        }
    }
}
