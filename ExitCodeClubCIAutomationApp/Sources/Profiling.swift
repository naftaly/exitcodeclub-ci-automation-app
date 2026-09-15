import Foundation
import KSCrash
import KSCrashProfiler
#if canImport(UIKit)
import UIKit
#endif

private let profileWriteSampleRate: Double = 0.1

/// Wires up sampling profiles that piggy-back on the KSCrash report store.
///
/// Two profiles run by default:
/// - **startup**: opens at install time, closes when the app reaches `didBecomeActive`.
/// - **hang**: starts whenever the watchdog observes a main-thread hang and
///   ends when the hang resolves; profiles longer than 500 ms are written.
///
/// Both flows hand their finished profiles to KSCrash via `writeReport()`, so
/// they land in the report store alongside crash reports and upload through
/// the existing `CrashServiceSink`.
@MainActor
final class ProfilingCoordinator {
    static let shared = ProfilingCoordinator()

    private var hangProfiler: HangProfiler?
    private var startupProfileID: ProfileID?
    private var didBecomeActiveObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard hangProfiler == nil else { return }

        startupProfileID = TimeProfiler.main.beginProfile(named: "startup")

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

        guard let profile = TimeProfiler.main.endProfile(id: id) else { return }
        guard Double.random(in: 0..<1) < profileWriteSampleRate else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = profile.writeReport()
        }
    }
}

/// Captures backtraces while the watchdog reports a main-thread hang.
///
/// Begins a profile on `HangEvent.Change.started` and ends it on
/// `HangEvent.Change.ended`, writing the report on a background queue when the
/// hang lasted at least 500 ms. Ported from the Reliability SPM.
final class HangProfiler: @unchecked Sendable {
    private let profiler: TimeProfiler
    private var currentProfileID: ProfileID?
    private var eventsTask: Task<Void, Never>?
    private let lock = NSLock()

    init(profiler: TimeProfiler = .main) {
        self.profiler = profiler
    }

    func start() {
        lock.withLock {
            guard eventsTask == nil else { return }
            // Taken here rather than inside the task so the stream is
            // subscribed before start() returns.
            let events = KSCrash.shared.hangEvents
            eventsTask = Task { [weak self] in
                for await event in events {
                    self?.handleHangChange(event.change)
                }
            }
        }
    }

    func stop() {
        lock.withLock {
            eventsTask?.cancel()
            eventsTask = nil
            if let id = currentProfileID {
                _ = profiler.endProfile(id: id)
                currentProfileID = nil
            }
        }
    }

    private func handleHangChange(_ change: HangEvent.Change) {
        lock.withLock {
            switch change {
            case .started:
                currentProfileID = profiler.beginProfile(named: "com.kscrash.profile.hang")
            case .ended:
                if let id = currentProfileID {
                    if let profile = profiler.endProfile(id: id) {
                        if profile.durationNs > 500_000_000,
                           Double.random(in: 0..<1) < profileWriteSampleRate {
                            DispatchQueue.global(qos: .utility).async {
                                _ = profile.writeReport()
                            }
                        }
                    }
                    currentProfileID = nil
                }
            case .updated:
                break
            }
        }
    }
}
