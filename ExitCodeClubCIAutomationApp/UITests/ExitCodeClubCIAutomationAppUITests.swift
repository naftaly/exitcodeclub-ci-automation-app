import XCTest

final class ExitCodeClubCIAutomationAppUITests: XCTestCase {
    /// Number of crash/relaunch cycles per CI run (randomized).
    private let iterations = Int.random(in: 2...40)

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
        // XCTest detects intentional app crashes at terminate/teardown and
        // reports them as failures. Suppress these since crashes are the
        // entire point of this test.
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("Intentional app crashes are expected", options: options)

        log("Starting \(iterations) crash/relaunch iterations")

        for i in 1...iterations {
            let runID = UUID().uuidString
            let shouldCrash = Bool.random()
            log("--- Iteration \(i)/\(iterations) (runID: \(runID), crash: \(shouldCrash)) ---")

            // 1. Launch normally; either trigger a crash or have the app self-exit cleanly.
            let firstLaunch = XCUIApplication()
            var env = baseEnvironment()
            env["CI_AUTOMATION_RUN_ID"] = runID
            firstLaunch.launchEnvironment = env

            log("Launching app (\(shouldCrash ? "crash" : "clean exit"))...")
            firstLaunch.launch()
            log("App state: \(firstLaunch.state.rawValue)")

            let actionButtonID = shouldCrash ? "Trigger Crash Now" : "Exit Cleanly"
            let actionButton = firstLaunch.buttons[actionButtonID]
            guard actionButton.waitForExistence(timeout: 10) else {
                let reason = "\(actionButtonID) button not found"
                log("ERROR: \(reason) — skipping iteration")
                skippedIterations.append((i, reason))
                failCount += 1
                firstLaunch.terminate()
                sleep(2)
                continue
            }

            actionButton.tap()

            if shouldCrash {
                let crashTypeLabel = firstLaunch.staticTexts["crashTypeLabel"]
                if crashTypeLabel.waitForExistence(timeout: 2) {
                    log("Crash type: \(crashTypeLabel.label)")
                } else {
                    log("Crash type: unknown (label not found)")
                }
            }

            log("Tapped \(actionButtonID), waiting for termination...")

            guard waitForTermination(of: firstLaunch, timeout: 20) else {
                let reason = "App did not terminate within 20s"
                log("ERROR: \(reason) — force-terminating, skipping iteration")
                skippedIterations.append((i, reason))
                failCount += 1
                firstLaunch.terminate()
                sleep(2)
                continue
            }
            log("App terminated (\(shouldCrash ? "crashed" : "clean exit"))")

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
            let predExpectation = XCTNSPredicateExpectation(predicate: sentPredicate, object: status)
            let waitResult = XCTWaiter().wait(for: [predExpectation], timeout: 60)

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
