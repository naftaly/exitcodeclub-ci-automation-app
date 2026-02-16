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

    // CrashProbe – Memory access
    case garbagePointerDeref
    case writeToReadOnlyPage
    case jumpToNonExecutablePage

    // CrashProbe – Bad instruction
    case undefinedInstruction
    case privilegedInstruction
    case builtinTrap

    // CrashProbe – Stack corruption
    case smashStackTop
    case smashStackBottom
    case overwriteLinkRegister

    // CrashProbe – ObjC runtime
    case messageFreedObject
    case corruptObjCRuntime
    case objcMsgSendInvalidISA
    case nslogNonObject

    // CrashProbe – C++ exception
    case cppBadAlloc
    case cppStringExceptionHeap
    case cppStringExceptionStack
    case cppConstCharException

    // CrashProbe – ObjC exception
    case objcExceptionThrow
    case objcExceptionRaise
    case objcExceptionFromCPP

    // CrashProbe – Heap corruption
    case corruptMallocTracking

    // CrashProbe – Threading
    case pthreadCrashWithLockHeld

    // Memory
    case outOfMemory

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
        case .garbagePointerDeref: return "Garbage pointer deref"
        case .writeToReadOnlyPage: return "Write to read-only page"
        case .jumpToNonExecutablePage: return "Jump to non-executable page"
        case .undefinedInstruction: return "Undefined instruction"
        case .privilegedInstruction: return "Privileged instruction"
        case .builtinTrap: return "__builtin_trap()"
        case .smashStackTop: return "Smash stack top"
        case .smashStackBottom: return "Smash stack bottom"
        case .overwriteLinkRegister: return "Overwrite link register"
        case .messageFreedObject: return "Message freed object"
        case .corruptObjCRuntime: return "Corrupt ObjC runtime"
        case .objcMsgSendInvalidISA: return "objc_msgSend invalid ISA"
        case .nslogNonObject: return "NSLog non-object"
        case .cppBadAlloc: return "C++ bad_alloc"
        case .cppStringExceptionHeap: return "C++ string exception (heap)"
        case .cppStringExceptionStack: return "C++ string exception (stack)"
        case .cppConstCharException: return "C++ const char* exception"
        case .objcExceptionThrow: return "ObjC exception throw"
        case .objcExceptionRaise: return "ObjC exception raise"
        case .objcExceptionFromCPP: return "ObjC exception from C++"
        case .corruptMallocTracking: return "Corrupt malloc tracking"
        case .pthreadCrashWithLockHeld: return "pthread crash with lock held"
        case .outOfMemory: return "Out of memory (jetsam)"
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

        case .garbagePointerDeref:
            CrashWithGarbagePointerDeref()

        case .writeToReadOnlyPage:
            CrashWithWriteToReadOnlyPage()

        case .jumpToNonExecutablePage:
            CrashWithJumpToNonExecutablePage()

        case .undefinedInstruction:
            CrashWithUndefinedInstruction()

        case .privilegedInstruction:
            CrashWithPrivilegedInstruction()

        case .builtinTrap:
            CrashWithBuiltinTrap()

        case .smashStackTop:
            CrashWithSmashStackTop()

        case .smashStackBottom:
            CrashWithSmashStackBottom()

        case .overwriteLinkRegister:
            CrashWithOverwriteLinkRegister()

        case .messageFreedObject:
            CrashWithMessageFreedObject()

        case .corruptObjCRuntime:
            CrashWithCorruptObjCRuntime()

        case .objcMsgSendInvalidISA:
            CrashWithObjcMsgSendInvalidISA()

        case .nslogNonObject:
            CrashWithNSLogNonObject()

        case .cppBadAlloc:
            CrashWithCPPBadAlloc()

        case .cppStringExceptionHeap:
            CrashWithCPPStringExceptionHeap()

        case .cppStringExceptionStack:
            CrashWithCPPStringExceptionStack()

        case .cppConstCharException:
            CrashWithCPPConstCharException()

        case .objcExceptionThrow:
            CrashWithObjCExceptionThrow()

        case .objcExceptionRaise:
            CrashWithObjCExceptionRaise()

        case .objcExceptionFromCPP:
            CrashWithObjCExceptionFromCPP()

        case .corruptMallocTracking:
            CrashWithCorruptMallocTracking()
            abort() // fallback — UB may not crash

        case .pthreadCrashWithLockHeld:
            CrashWithPthreadLockHeld()

        case .outOfMemory:
            // Jetsam kills at ~6 GB — allocate in 512 MB chunks to hit the limit fast.
            // KSCrash's MemoryTermination monitor detects this on the next launch.
            let chunkSize = 512 * 1024 * 1024 // 512 MB
            while true {
                let buf = UnsafeMutableRawPointer.allocate(byteCount: chunkSize, alignment: 1)
                memset(buf, 0x41, chunkSize) // wire every page
            }

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

    // MARK: - Randomized trigger wrappers

    /// Picks a random wrapper so the "blamed" frame varies across crash reports.
    @inline(never)
    func triggerRandomized() {
        let wrappers: [@convention(thin) (CrashType) -> Void] = [
            commitTransaction,
            flushPendingUpdates,
            finalizeEventPayload,
            processIncomingMessage,
            applyConfigurationChange,
        ]
        wrappers.randomElement()!(self)
    }
}

@inline(never)
private func commitTransaction(_ crashType: CrashType) {
    crashType.trigger()
}

@inline(never)
private func flushPendingUpdates(_ crashType: CrashType) {
    crashType.trigger()
}

@inline(never)
private func finalizeEventPayload(_ crashType: CrashType) {
    crashType.trigger()
}

@inline(never)
private func processIncomingMessage(_ crashType: CrashType) {
    crashType.trigger()
}

@inline(never)
private func applyConfigurationChange(_ crashType: CrashType) {
    crashType.trigger()
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
            crashType.triggerRandomized()
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

        config.monitors = [config.monitors, .memoryTermination, .watchdog]

        do {
            try KSCrash.shared.install(with: config)
        } catch {
            reportsStatusText = "Install failed: \(error.localizedDescription)"
        }
    }

    private var pendingCrash = false

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

        selectedCrashType = resolveCrashType()
        pendingCrash = true
    }

    /// Called from ContentView.onAppear to trigger the crash once the UI is ready.
    func onUIReady() {
        guard pendingCrash, let crashType = selectedCrashType else { return }
        pendingCrash = false
        let delay = Double.random(in: 0.5...3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.scheduleAbortFallback()
            CallChain.run(userInfo: crashType.rawValue) {
                crashType.triggerRandomized()
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
                print("[CrashAutomation] Failed to send report \(reportID): \(error)")
            }
        }

        reportsStatusText = "Sent: \(sentCount), Failed: \(failedCount)"
    }
}
