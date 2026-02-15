import Foundation
import KSCrashRecording

enum CallChain {

    static func run(_ action: @escaping () -> Void) {
        let depth = Int.random(in: 3...8)
        handleUserInteraction(action, remaining: depth)
    }

    static func run(userInfo key: String, _ action: @escaping () -> Void) {
        setUserInfo(key)
        run {
            action()
            clearUserInfo(key)
        }
    }

    static func setUserInfo(_ key: String) {
        var info = KSCrash.shared.userInfo ?? [:]
        info["call_chain"] = key
        KSCrash.shared.userInfo = info
    }

    static func clearUserInfo(_ key: String) {
        var info = KSCrash.shared.userInfo ?? [:]
        info.removeValue(forKey: "call_chain")
        KSCrash.shared.userInfo = info
    }

    // MARK: - Dispatcher

    private static let allFunctions: [(@escaping () -> Void, Int) -> Void] = [
        // UI flow
        handleUserInteraction,
        processViewUpdate,
        layoutSubviewHierarchy,
        renderVisibleContent,
        // Data/network
        fetchRemoteResource,
        processNetworkResponse,
        deserializePayload,
        validateResponseIntegrity,
        // Business logic
        applyBusinessRules,
        computeDerivedState,
        resolveConflicts,
        transformDataModel,
        // Storage
        persistToLocalStore,
        synchronizeWithBackend,
        migrateSchemaVersion,
        indexSearchableContent,
        // Auth/session
        refreshSessionToken,
        validateUserPermissions,
        decryptSecurePayload,
        auditAccessLog,
    ]

    @inline(never)
    private static func dispatch(_ action: @escaping () -> Void, remaining: Int) {
        let next = allFunctions.randomElement()!
        next(action, remaining)
    }

    // MARK: - UI Flow

    @inline(never)
    private static func handleUserInteraction(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func processViewUpdate(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func layoutSubviewHierarchy(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func renderVisibleContent(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    // MARK: - Data/Network

    @inline(never)
    private static func fetchRemoteResource(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func processNetworkResponse(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func deserializePayload(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func validateResponseIntegrity(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    // MARK: - Business Logic

    @inline(never)
    private static func applyBusinessRules(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func computeDerivedState(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func resolveConflicts(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func transformDataModel(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    // MARK: - Storage

    @inline(never)
    private static func persistToLocalStore(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func synchronizeWithBackend(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func migrateSchemaVersion(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func indexSearchableContent(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    // MARK: - Auth/Session

    @inline(never)
    private static func refreshSessionToken(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func validateUserPermissions(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func decryptSecurePayload(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }

    @inline(never)
    private static func auditAccessLog(_ action: @escaping () -> Void, remaining: Int) {
        guard remaining > 0 else { action(); return }
        dispatch(action, remaining: remaining - 1)
    }
}
