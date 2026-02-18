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

            // 1. Launch normally and trigger crash via button tap
            let crashingApp = XCUIApplication()
            var env = baseEnvironment()
            env["CI_AUTOMATION_RUN_ID"] = runID
            crashingApp.launchEnvironment = env
            crashingApp.launch()

            let crashButton = crashingApp.buttons["Trigger Crash Now"]
            guard crashButton.waitForExistence(timeout: 10) else {
                XCTFail("Iteration \(i)/\(iterations): Crash button not found")
                crashingApp.terminate()
                sleep(2)
                continue
            }
            crashButton.tap()
            print("Iteration \(i)/\(iterations): Tapped crash button, waiting for termination...")

            guard waitForTermination(of: crashingApp, timeout: 20) else {
                XCTFail("Iteration \(i)/\(iterations): App did not terminate")
                crashingApp.terminate()
                sleep(2)
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

            let sendButton = relaunchedApp.buttons["sendReportsButton"]
            guard sendButton.waitForExistence(timeout: 10) else {
                XCTFail("Iteration \(i)/\(iterations): Send button not found after relaunch")
                relaunchedApp.terminate()
                sleep(2)
                continue
            }
            sendButton.tap()

            let status = relaunchedApp.staticTexts["reportsStatusLabel"]
            let sentPredicate = NSPredicate(format: "label CONTAINS[c] %@", "Sent:")
            expectation(for: sentPredicate, evaluatedWith: status)
            waitForExpectations(timeout: 60)

            let statusText = status.label
            print("Iteration \(i)/\(iterations): Report status — \(statusText)")

            relaunchedApp.terminate()
            sleep(1)
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
