import Foundation
import KSCrashRecording
import KSCrashInstallations
import KSCrashFilters
import KSCrashDemangleFilter
import CrashGeneratorsObjC

enum CrashType: String, CaseIterable {
    // Swift errors
    case swiftFatalError
    case swiftAssertionFailure
    case forceUnwrapNil
    case arrayOutOfBounds

    // Signals
    case sigabrt
    case sigsegv
    case sigbus
    case sigfpe
    case sigill
    case sigtrap

    // ObjC/C++
    case cppException
    case useAfterFree
    case doubleFree
    case stackOverflow
    case bufferOverflow

    // Hang + watchdog kill
    case mainThreadHang

    static func random() -> CrashType {
        allCases.randomElement()!
    }

    var displayName: String {
        switch self {
        case .swiftFatalError: return "fatalError()"
        case .swiftAssertionFailure: return "assertionFailure()"
        case .forceUnwrapNil: return "Force-unwrap nil"
        case .arrayOutOfBounds: return "Array out-of-bounds"
        case .sigabrt: return "SIGABRT"
        case .sigsegv: return "SIGSEGV"
        case .sigbus: return "SIGBUS"
        case .sigfpe: return "SIGFPE"
        case .sigill: return "SIGILL"
        case .sigtrap: return "SIGTRAP"
        case .cppException: return "C++ exception"
        case .useAfterFree: return "Use-after-free"
        case .doubleFree: return "Double-free"
        case .stackOverflow: return "Stack overflow"
        case .bufferOverflow: return "Buffer overflow"
        case .mainThreadHang: return "Main thread hang (SIGKILL)"
        }
    }

    @inline(never)
    func trigger() {
        switch self {
        case .swiftFatalError:
            Swift.fatalError("Intentional CI crash: fatalError")

        case .swiftAssertionFailure:
            Swift.assertionFailure("Intentional CI crash: assertionFailure")
            Swift.fatalError("Intentional CI crash: assertionFailure (release fallback)")

        case .forceUnwrapNil:
            // Runtime-opaque nil the optimizer cannot constant-fold
            let value: String? = ProcessInfo.processInfo.environment["__CRASH_NIL__"]
            print(value!)

        case .arrayOutOfBounds:
            // Runtime-opaque index the optimizer cannot constant-fold
            let array = [1, 2, 3]
            let idx = Int(ProcessInfo.processInfo.processIdentifier) | 0x100
            print(array[idx])

        case .sigabrt:
            abort()

        case .sigsegv:
            let ptr = UnsafeMutablePointer<Int>(bitPattern: 0x1)!
            ptr.pointee = 42

        case .sigbus:
            raise(SIGBUS)

        case .sigfpe:
            raise(SIGFPE)

        case .sigill:
            raise(SIGILL)

        case .sigtrap:
            raise(SIGTRAP)

        case .cppException:
            CrashWithCPPException()

        case .useAfterFree:
            CrashWithUseAfterFree()
            abort() // fallback — UB may not crash

        case .doubleFree:
            CrashWithDoubleFree()
            abort() // fallback — UB may not crash

        case .stackOverflow:
            CrashWithStackOverflow()

        case .bufferOverflow:
            CrashWithBufferOverflow()
            abort() // fallback — UB may not crash

        case .mainThreadHang:
            // Watchdog kills after 10s, busy-wait main thread with realistic work
            let pid = getpid()
            DispatchQueue.global(qos: .userInitiated).async {
                sleep(10)
                kill(pid, SIGKILL)
            }
            FlamegraphHang.run(duration: 60)
        }
    }
}

@MainActor
final class CrashAutomationManager: ObservableObject {
    static let shared = CrashAutomationManager()

    @Published private(set) var reportsStatusText: String = "Starting..."
    @Published private(set) var selectedCrashType: CrashType?

    private var started = false

    private init() {}

    func startIfNeeded() {
        guard !started else { return }
        started = true

        installCrashReporter()
        maybeTriggerCrashOnLaunch()
        Task { await sendPendingReports() }
    }

    func sendPendingReportsNow() {
        Task { await sendPendingReports() }
    }

    func triggerCrashNow() {
        let crashType = resolveCrashType()
        selectedCrashType = crashType
        scheduleAbortFallback()
        CallChain.run(userInfo: crashType.rawValue) {
            crashType.trigger()
        }
    }

    /// If the chosen crash type didn't terminate the process, kill it.
    private func scheduleAbortFallback() {
        DispatchQueue.global(qos: .userInitiated).async {
            sleep(15)
            abort()
        }
    }

    private func resolveCrashType() -> CrashType {
        if let envType = ProcessInfo.processInfo.environment["CI_AUTOMATION_CRASH_TYPE"],
           let type = CrashType(rawValue: envType) {
            return type
        }
        return .random()
    }

    private func installCrashReporter() {
        let config = KSCrashConfiguration()
        config.enableSigTermMonitoring = true
        config.enableQueueNameSearch = true
        config.enableSwapCxaThrow = true
        config.enableCompactBinaryImages = true
        config.reportStoreConfiguration.maxReportCount = 50
        config.reportStoreConfiguration.reportCleanupPolicy = .onSuccess

        do {
            try KSCrash.shared.install(with: config)
        } catch {
            reportsStatusText = "Install failed: \(error.localizedDescription)"
        }
    }

    private func maybeTriggerCrashOnLaunch() {
        let env = ProcessInfo.processInfo.environment
        guard env["CI_AUTOMATION_CRASH_ON_LAUNCH"] == "1" else { return }

        let runID = env["CI_AUTOMATION_RUN_ID"] ?? "default"
        let crashKey = "ci.automation.didCrash.\(runID)"
        if UserDefaults.standard.bool(forKey: crashKey) {
            return
        }

        UserDefaults.standard.set(true, forKey: crashKey)
        UserDefaults.standard.synchronize()

        let crashType = resolveCrashType()
        selectedCrashType = crashType
        scheduleAbortFallback()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            CallChain.run(userInfo: crashType.rawValue) {
                crashType.trigger()
            }
        }
    }

    private static let backendBaseURL = "https://kscrash-api-765738384004.us-central1.run.app"

    private func reportsURL() -> URL {
        URL(string: "\(Self.backendBaseURL)/api/reports")!
    }

    private func sendPendingReports() async {
        guard let reportStore = KSCrash.shared.reportStore else {
            reportsStatusText = "No report store"
            return
        }

        let sink = CrashServiceSink(url: reportsURL())
        reportStore.sink = CrashReportFilterPipeline(filters: [sink])

        let reportIDs = reportStore.reportIDs.map { $0.int64Value }
        if reportIDs.isEmpty {
            reportsStatusText = "Sent: 0, Failed: 0"
            return
        }

        var sentCount = 0
        var failedCount = 0

        for reportID in reportIDs {
            do {
                _ = try await reportStore.sendReport(withID: reportID, includeCurrentRun: false)
                sentCount += 1
            } catch {
                failedCount += 1
            }
        }

        reportsStatusText = "Sent: \(sentCount), Failed: \(failedCount)"
    }
}
