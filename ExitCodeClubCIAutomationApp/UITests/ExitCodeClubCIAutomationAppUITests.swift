import XCTest

final class ExitCodeClubCIAutomationAppUITests: XCTestCase {
    /// Number of crash/relaunch cycles per CI run.
    private let iterations = 5

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCrashThenRelaunchSendsReports() throws {
        for i in 1...iterations {
            let runID = UUID().uuidString

            // 1. Launch and crash
            let crashingApp = XCUIApplication()
            crashingApp.launchEnvironment["CI_AUTOMATION_RUN_ID"] = runID
            crashingApp.launchEnvironment["CI_AUTOMATION_CRASH_ON_LAUNCH"] = "1"
            crashingApp.launch()

            XCTAssertTrue(
                waitForTermination(of: crashingApp, timeout: 20),
                "Iteration \(i)/\(iterations): App did not terminate after crash trigger"
            )

            // 2. Relaunch and send reports
            let relaunchedApp = XCUIApplication()
            relaunchedApp.launchEnvironment["CI_AUTOMATION_RUN_ID"] = runID
            relaunchedApp.launchEnvironment["CI_AUTOMATION_CRASH_ON_LAUNCH"] = "0"
            relaunchedApp.launch()

            let status = relaunchedApp.staticTexts["reportsStatusLabel"]
            XCTAssertTrue(status.waitForExistence(timeout: 15), "Iteration \(i)/\(iterations): Status label not found")

            let sentPredicate = NSPredicate(format: "label CONTAINS[c] %@", "Sent:")
            expectation(for: sentPredicate, evaluatedWith: status)
            waitForExpectations(timeout: 60)

            XCTAssertFalse(
                status.label.contains("Failed: 1"),
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
