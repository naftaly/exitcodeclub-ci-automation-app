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

            Text("Reported errors: \(manager.reportedErrorCount)")
                .font(.subheadline)
                .accessibilityIdentifier("reportedErrorLabel")

            Button("Trigger Crash Now") {
                manager.triggerCrashNow()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("triggerCrashButton")

            Button("Report Error") {
                manager.reportErrorNow()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("reportErrorButton")

            Button("Exit Cleanly") {
                manager.exitCleanlyNow()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("exitCleanlyButton")

            Button("Send Pending Reports") {
                manager.sendPendingReportsNow()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("sendReportsButton")
        }
        .padding()
        .onAppear {
            manager.onUIReady()
        }
    }
}
