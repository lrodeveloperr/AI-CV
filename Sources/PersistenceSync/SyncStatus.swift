import Foundation

/// Facts reported by the store and account layers. Status is derived only
/// from these, never from timers or network reachability alone.
public struct SyncObservation: Equatable, Sendable {
    public var iCloudAccountAvailable: Bool
    public var hasUnsyncedLocalChanges: Bool
    public var exportInProgress: Bool
    public var importInProgress: Bool
    public var lastSuccessfulSync: Date?
    public var lastSyncFailed: Bool
    public var unresolvedConflictCount: Int

    public init(
        iCloudAccountAvailable: Bool,
        hasUnsyncedLocalChanges: Bool = false,
        exportInProgress: Bool = false,
        importInProgress: Bool = false,
        lastSuccessfulSync: Date? = nil,
        lastSyncFailed: Bool = false,
        unresolvedConflictCount: Int = 0
    ) {
        self.iCloudAccountAvailable = iCloudAccountAvailable
        self.hasUnsyncedLocalChanges = hasUnsyncedLocalChanges
        self.exportInProgress = exportInProgress
        self.importInProgress = importInProgress
        self.lastSuccessfulSync = lastSuccessfulSync
        self.lastSyncFailed = lastSyncFailed
        self.unresolvedConflictCount = unresolvedConflictCount
    }
}

public enum SyncStatusResolver {
    public static func resolve(_ observation: SyncObservation) -> SyncState {
        if observation.unresolvedConflictCount > 0 { return .conflictRequiresReview }
        if !observation.iCloudAccountAvailable { return .iCloudUnavailable }
        if observation.exportInProgress || observation.importInProgress { return .syncing }
        if observation.lastSyncFailed { return .savedLocally }
        if observation.hasUnsyncedLocalChanges { return .savedLocally }
        if let synced = observation.lastSuccessfulSync { return .synced(synced) }
        // No confirmed sync has completed yet: never claim "Synced".
        return .savedLocally
    }

    /// Folds a merge result into the observation so its conflicts surface as
    /// review-required until the user resolves them.
    public static func observation(
        _ observation: SyncObservation,
        applying merge: WorkspaceMergeResult
    ) -> SyncObservation {
        var updated = observation
        updated.unresolvedConflictCount = merge.conflicts.count
        updated.hasUnsyncedLocalChanges = true
        return updated
    }
}
