import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var manager: CrashAutomationManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Exit Code Club CI Crash Automation")
                .font(.headline)

            if let crashType = manager.selectedCrashType {
                Text("Crash type: \(crashType.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("crashTypeLabel")
            }

            Text(manager.reportsStatusText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("reportsStatusLabel")

            Button("Trigger Crash Now") {
                manager.triggerCrashNow()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("triggerCrashButton")

            Button("Send Pending Reports") {
                manager.sendPendingReportsNow()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("sendReportsButton")
        }
        .padding()
    }
}
