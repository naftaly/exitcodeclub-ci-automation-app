import XCTest

final class ExitCodeClubCIAutomationAppUITests: XCTestCase {
    /// Number of crash/relaunch cycles per CI run (randomized).
    private let iterations = Int.random(in: 1...20)

    private let tag = "[CrashCI]"

    private var successCount = 0
    private var failCount = 0
    private var skippedIterations: [(Int, String)] = []

    private func log(_ message: String) {
        print("\(tag) \(message)")
    }

    private func baseEnvironment() -> [String: String] {
        [
            "KSCRASH_SIM_MEMORY_TERMINATION_ENABLED": "1",
            "KSCRASH_FORCE_ENABLE_WATCHDOG": "1",
        ]
    }

    func testCrashThenRelaunchSendsReports() throws {
        log("Starting \(iterations) crash/relaunch iterations")

        for i in 1...iterations {
            let runID = UUID().uuidString
            log("--- Iteration \(i)/\(iterations) (runID: \(runID)) ---")

            // 1. Launch normally and trigger crash via button tap
            let crashingApp = XCUIApplication()
            var env = baseEnvironment()
            env["CI_AUTOMATION_RUN_ID"] = runID
            crashingApp.launchEnvironment = env

            log("Launching app for crash...")
            crashingApp.launch()
            log("App state: \(crashingApp.state.rawValue)")

            let crashButton = crashingApp.buttons["Trigger Crash Now"]
            guard crashButton.waitForExistence(timeout: 10) else {
                let reason = "Crash button not found"
                log("ERROR: \(reason) — skipping iteration")
                skippedIterations.append((i, reason))
                failCount += 1
                crashingApp.terminate()
                sleep(2)
                continue
            }

            crashButton.tap()

            let crashTypeLabel = crashingApp.staticTexts["crashTypeLabel"]
            if crashTypeLabel.waitForExistence(timeout: 2) {
                log("Crash type: \(crashTypeLabel.label)")
            } else {
                log("Crash type: unknown (label not found)")
            }

            log("Tapped crash button, waiting for termination...")

            guard waitForTermination(of: crashingApp, timeout: 20) else {
                let reason = "App did not terminate within 20s"
                log("ERROR: \(reason) — force-terminating, skipping iteration")
                skippedIterations.append((i, reason))
                failCount += 1
                crashingApp.terminate()
                sleep(2)
                continue
            }
            log("App terminated (crashed)")

            // 2. Relaunch and send reports
            let relaunchedApp = XCUIApplication()
            var relaunchEnv = baseEnvironment()
            relaunchEnv["CI_AUTOMATION_RUN_ID"] = runID
            relaunchEnv["CI_AUTOMATION_CRASH_ON_LAUNCH"] = "0"
            relaunchedApp.launchEnvironment = relaunchEnv

            log("Relaunching app to send reports...")
            relaunchedApp.launch()
            log("App state: \(relaunchedApp.state.rawValue)")

            let sendButton = relaunchedApp.buttons["sendReportsButton"]
            guard sendButton.waitForExistence(timeout: 10) else {
                let reason = "Send button not found after relaunch"
                log("ERROR: \(reason) — skipping iteration")
                skippedIterations.append((i, reason))
                failCount += 1
                relaunchedApp.terminate()
                sleep(2)
                continue
            }

            log("Tapping Send Pending Reports...")
            sendButton.tap()

            let status = relaunchedApp.staticTexts["reportsStatusLabel"]
            let sentPredicate = NSPredicate(format: "label CONTAINS[c] %@", "Sent:")
            expectation(for: sentPredicate, evaluatedWith: status)
            let waitResult = XCTWaiter().wait(for: [expectation(for: sentPredicate, evaluatedWith: status)], timeout: 60)

            if waitResult == .completed {
                let statusText = status.label
                log("Report status: \(statusText)")
                successCount += 1
            } else {
                let currentLabel = status.exists ? status.label : "<not found>"
                let reason = "Timed out waiting for send (last status: \(currentLabel))"
                log("ERROR: \(reason)")
                skippedIterations.append((i, reason))
                failCount += 1
            }

            relaunchedApp.terminate()
            sleep(1)
        }

        log("=== Summary ===")
        log("Iterations: \(iterations)")
        log("Succeeded: \(successCount)")
        log("Failed: \(failCount)")
        if !skippedIterations.isEmpty {
            log("Failures:")
            for (iter, reason) in skippedIterations {
                log("  Iteration \(iter): \(reason)")
            }
        }
    }

    private func waitForTermination(of app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.state == .notRunning {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }
}
