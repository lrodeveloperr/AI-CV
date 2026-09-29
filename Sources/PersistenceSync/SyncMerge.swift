import Foundation

public enum ThreeWayMergeResult<Value: Equatable & Sendable>: Equatable, Sendable {
    case merged(Value)
    case conflict(local: Value, remote: Value)
}

public enum ThreeWayMerge {
    public static func resolve<Value: Equatable & Sendable>(
        base: Value,
        local: Value,
        remote: Value
    ) -> ThreeWayMergeResult<Value> {
        if local == remote { return .merged(local) }
        if local == base { return .merged(remote) }
        if remote == base { return .merged(local) }
        return .conflict(local: local, remote: remote)
    }
}

public enum SyncState: Equatable, Sendable {
    case savedLocally
    case syncing
    case synced(Date)
    case iCloudUnavailable
    case conflictRequiresReview
}

