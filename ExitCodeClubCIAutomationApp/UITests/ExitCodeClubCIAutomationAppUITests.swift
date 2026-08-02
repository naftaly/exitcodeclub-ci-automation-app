import XCTest

final class ExitCodeClubCIAutomationAppUITests: XCTestCase {
    /// Number of crash/relaunch cycles per CI run (randomized).
    private let iterations = Int.random(in: 2...40)

    private let tag = "[CrashCI]"

    /// Prefix on assertions this test raises deliberately. `XCTExpectFailure`
    /// below absorbs every issue it is not told to ignore, including our own
    /// `XCTFail` calls, so failures we want to surface are tagged and matched
    /// back out.
    private static let assertionMarker = "[CrashCI-Assert]"

    /// Mirrors `CrashAutomationManager.runsFailedMarker`.
    private static let runsFailedMarker = "RUNS_FAILED"

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
        options.issueMatcher = { !$0.compactDescription.contains(Self.assertionMarker) }
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

            // Exercise the app for a while before ending it, so runs differ in
            // shape: several sessions, some non-fatal reports, varied durations.
            let plan = Self.makePlan()
            log("Plan: \(Self.describe(plan))")
            execute(plan, on: firstLaunch)

            actionButton.tap()

            if shouldCrash {
                let crashTypeLabel = firstLaunch.staticTexts["crashTypeLabel"]
                if crashTypeLabel.waitForExistence(timeout: 2) {
                    log("Crash type: \(crashTypeLabel.label)")
                } else {
                    log("Crash type: unknown (label not found)")
                }
            }

            // Ending while backgrounded is the only way to get a run with
            // user_perceptible false. The termination is already pending on the
            // app's 5 to 10s timer, so it fires once the app is out of sight.
            if Bool.random() {
                log("Backgrounding before termination")
                XCUIDevice.shared.press(.home)
            }

            log("Tapped \(actionButtonID), waiting for termination...")

            // Must clear the app's crash delay (up to 10s) plus its abort
            // fallback (15s after the crash fires), or slow crash types like the
            // main thread hang get misreported as launches that never died.
            guard waitForTermination(of: firstLaunch, timeout: 30) else {
                let reason = "App did not terminate within 30s"
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
                if statusText.contains(Self.runsFailedMarker) {
                    let reason = "Run summary send failed (status: \(statusText))"
                    log("ERROR: \(reason)")
                    skippedIterations.append((i, reason))
                    failCount += 1
                    XCTFail("\(Self.assertionMarker) Iteration \(i): \(reason)")
                } else {
                    successCount += 1
                }
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

    // MARK: - Run plan

    /// One step of the randomized activity a run performs before it ends.
    private enum PlanStep {
        case reportError
        case background(TimeInterval)
        case idle(TimeInterval)
    }

    /// Kept short on purpose. Every second here multiplies by the iteration
    /// count, and the workflow has a 45 minute budget.
    private static func makePlan() -> [PlanStep] {
        (0..<Int.random(in: 0...4)).map { _ in
            switch Int.random(in: 0...2) {
            case 0: return .reportError
            case 1: return .background(TimeInterval.random(in: 1...3))
            default: return .idle(TimeInterval.random(in: 1...3))
            }
        }
    }

    private static func describe(_ plan: [PlanStep]) -> String {
        guard !plan.isEmpty else { return "<none>" }
        return plan.map { step in
            switch step {
            case .reportError: return "reportError"
            case .background(let seconds): return String(format: "bg %.1fs", seconds)
            case .idle(let seconds): return String(format: "idle %.1fs", seconds)
            }
        }.joined(separator: " -> ")
    }

    private func execute(_ plan: [PlanStep], on app: XCUIApplication) {
        for step in plan {
            switch step {
            case .reportError:
                let button = app.buttons["reportErrorButton"]
                guard button.waitForExistence(timeout: 5) else {
                    log("WARN: report error button not found, skipping step")
                    continue
                }
                // Confirm the count moved rather than assuming the tap landed.
                let counter = app.staticTexts["reportedErrorLabel"]
                let before = counter.exists ? counter.label : ""
                button.tap()
                let changed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label != %@", before),
                    object: counter
                )
                if XCTWaiter().wait(for: [changed], timeout: 5) != .completed {
                    log("WARN: reported error count did not change after tap")
                }

            case .background(let seconds):
                XCUIDevice.shared.press(.home)
                Thread.sleep(forTimeInterval: seconds)
                app.activate()

            case .idle(let seconds):
                Thread.sleep(forTimeInterval: seconds)
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
