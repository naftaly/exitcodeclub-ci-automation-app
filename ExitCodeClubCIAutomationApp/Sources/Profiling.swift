import Foundation
import KSCrashRecording
import KSCrashProfiler
#if canImport(UIKit)
import UIKit
#endif

/// Wires up sampling profiles that piggy-back on the KSCrash report store.
///
/// Two profiles run by default:
/// - **startup**: opens at install time, closes when the app reaches `didBecomeActive`.
/// - **hang**: starts whenever the watchdog observes a main-thread hang and
///   ends when the hang resolves; profiles longer than 500 ms are written.
///
/// Both flows hand their finished profiles to KSCrash via `writeReport()`, so
/// they appear in `KSCrash.shared.reportStore` alongside crash reports and
/// upload through the existing `CrashServiceSink`.
@MainActor
final class ProfilingCoordinator {
    static let shared = ProfilingCoordinator()

    private var hangProfiler: HangProfiler?
    private var startupProfileID: ProfileID?
    private var didBecomeActiveObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard hangProfiler == nil else { return }

        startupProfileID = Profiler.main.beginProfile(named: "startup")

        let profiler = HangProfiler(profiler: .main)
        profiler.start()
        hangProfiler = profiler

#if canImport(UIKit)
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.endStartupProfile()
            }
        }
#endif
    }

    private func endStartupProfile() {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            didBecomeActiveObserver = nil
        }

        guard let id = startupProfileID else { return }
        startupProfileID = nil

        guard let profile = Profiler.main.endProfile(id: id) else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = profile.writeReport()
        }
    }
}

/// Captures backtraces while the watchdog reports a main-thread hang.
///
/// Begins a profile on `HangChangeType.started` and ends it on
/// `HangChangeType.ended`, writing the report on a background queue when the
/// hang lasted at least 500 ms. Ported from the Reliability SPM.
final class HangProfiler: @unchecked Sendable {
    private let profiler: Profiler
    private var currentProfileID: ProfileID?
    private var observerToken: AnyObject?
    private let lock = NSLock()

    init(profiler: Profiler = .main) {
        self.profiler = profiler
    }

    func start() {
        lock.withLock {
            guard observerToken == nil else { return }
            let token = KSCrash.shared.addHangObserver { [weak self] change, start, end in
                self?.handleHangChange(change, startTimestamp: start, endTimestamp: end)
            }
            observerToken = token as AnyObject
        }
    }

    func stop() {
        lock.withLock {
            observerToken = nil
            if let id = currentProfileID {
                _ = profiler.endProfile(id: id)
                currentProfileID = nil
            }
        }
    }

    private func handleHangChange(_ change: HangChangeType, startTimestamp: UInt64, endTimestamp: UInt64) {
        lock.withLock {
            switch change {
            case .started:
                currentProfileID = profiler.beginProfile(named: "com.kscrash.profile.hang")
            case .ended:
                if let id = currentProfileID {
                    if let profile = profiler.endProfile(id: id) {
                        if profile.durationNs > 500_000_000 {
                            DispatchQueue.global(qos: .utility).async {
                                _ = profile.writeReport()
                            }
                        }
                    }
                    currentProfileID = nil
                }
            case .updated, .none:
                break
            @unknown default:
                break
            }
        }
    }
}
