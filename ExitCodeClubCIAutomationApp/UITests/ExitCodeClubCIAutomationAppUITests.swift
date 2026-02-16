import XCTest

final class ExitCodeClubCIAutomationAppUITests: XCTestCase {
    /// Number of crash/relaunch cycles per CI run (randomized).
    private let iterations = Int.random(in: 1...20)

    private func baseEnvironment() -> [String: String] {
        [
            "KSCRASH_SIM_MEMORY_TERMINATION_ENABLED": "1",
            "KSCRASH_FORCE_ENABLE_WATCHDOG": "1",
        ]
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCrashThenRelaunchSendsReports() throws {
        for i in 1...iterations {
            let runID = UUID().uuidString

            // 1. Launch and crash — don't query UI elements, the app may die instantly
            let crashingApp = XCUIApplication()
            var env = baseEnvironment()
            env["CI_AUTOMATION_RUN_ID"] = runID
            env["CI_AUTOMATION_CRASH_ON_LAUNCH"] = "1"
            crashingApp.launchEnvironment = env
            crashingApp.launch()

            print("Iteration \(i)/\(iterations): Launched, waiting for crash...")

            guard waitForTermination(of: crashingApp, timeout: 30) else {
                XCTFail("Iteration \(i)/\(iterations): App did not terminate")
                continue
            }
            print("Iteration \(i)/\(iterations): Crashed OK")

            // 2. Relaunch and send reports
            let relaunchedApp = XCUIApplication()
            var relaunchEnv = baseEnvironment()
            relaunchEnv["CI_AUTOMATION_RUN_ID"] = runID
            relaunchEnv["CI_AUTOMATION_CRASH_ON_LAUNCH"] = "0"
            relaunchedApp.launchEnvironment = relaunchEnv
            relaunchedApp.launch()

            let status = relaunchedApp.staticTexts["reportsStatusLabel"]
            guard status.waitForExistence(timeout: 15) else {
                XCTFail("Iteration \(i)/\(iterations): Status label not found after relaunch")
                continue
            }

            let sentPredicate = NSPredicate(format: "label CONTAINS[c] %@", "Sent:")
            expectation(for: sentPredicate, evaluatedWith: status)
            waitForExpectations(timeout: 60)

            let statusText = status.label
            print("Iteration \(i)/\(iterations): Report status — \(statusText)")
            XCTAssertFalse(
                statusText.contains("Failed: 1"),
                "Iteration \(i)/\(iterations): At least one report failed to send"
            )
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
