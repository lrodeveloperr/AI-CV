import CareerDomain
import CareerWorkflow
import Foundation

public enum ExportHandoffOutcome: Equatable, Sendable {
    case completed
    case canceled
    case failed
}

/// Turns the result of a share, save, or print flow into free-limit
/// accounting. Only a completed handoff consumes the free export; cancelling
/// or failing leaves the ledger untouched.
public struct ExportHandoffRecorder: Sendable {
    private let service: WorkspaceService

    public init(service: WorkspaceService) {
        self.service = service
    }

    /// Returns the updated workspace when the export was recorded, nil otherwise.
    @discardableResult
    public func finish(
        _ outcome: ExportHandoffOutcome,
        operationID: UUID,
        subscription: SubscriptionStatus,
        now: Date
    ) async throws -> Workspace? {
        guard outcome == .completed else { return nil }
        return try await service.recordCompletedExport(
            operationID: operationID,
            subscription: subscription,
            now: now
        )
    }
}
