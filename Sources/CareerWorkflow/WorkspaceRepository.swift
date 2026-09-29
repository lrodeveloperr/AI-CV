import CareerDomain
import Foundation

public protocol WorkspaceRepository: Sendable {
    func load() async throws -> Workspace?
    func save(_ workspace: Workspace, expectedRevision: Int) async throws -> Workspace
}

public actor InMemoryWorkspaceRepository: WorkspaceRepository {
    private var stored: Workspace?
    private var queuedFailure: EngineError?

    public init(initial: Workspace? = nil) {
        self.stored = initial
    }

    public func load() async throws -> Workspace? {
        stored
    }

    public func save(_ workspace: Workspace, expectedRevision: Int) async throws -> Workspace {
        if let queuedFailure {
            self.queuedFailure = nil
            throw queuedFailure
        }
        let actualRevision = stored?.revision ?? 0
        guard actualRevision == expectedRevision else {
            throw EngineError.conflict(expected: expectedRevision, actual: actualRevision)
        }
        var committed = workspace
        committed.revision = expectedRevision + 1
        stored = committed
        return committed
    }

    public func failNextSave(with error: EngineError) {
        queuedFailure = error
    }
}

