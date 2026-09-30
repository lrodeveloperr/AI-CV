import CareerDomain
import CareerWorkflow
import Foundation
import SwiftData

/// One persisted record. Every property has a default and nothing is marked
/// unique, which keeps the schema compatible with a private CloudKit database;
/// identity uniqueness is enforced by the repository.
@Model
public final class StoredEntity {
    public var kind: String = ""
    public var entityID: UUID = UUID()
    public var rank: Int = 0
    public var payload: Data = Data()

    public init(kind: String, entityID: UUID, rank: Int, payload: Data) {
        self.kind = kind
        self.entityID = entityID
        self.rank = rank
        self.payload = payload
    }
}

@Model
public final class StoredWorkspaceMeta {
    public var revision: Int = 0
    public var schemaVersion: Int = 1

    public init(revision: Int, schemaVersion: Int) {
        self.revision = revision
        self.schemaVersion = schemaVersion
    }
}

public enum PersistenceSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] {
        [StoredEntity.self, StoredWorkspaceMeta.self]
    }
}

public enum PersistenceMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [PersistenceSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum PersistenceContainerFactory {
    public static let bundleIdentifier = "com.worksbienstudios.rirekishoai"

    /// Private CloudKit container, named by Apple's `iCloud.<bundle id>`
    /// convention. The name is permanent once created in the developer
    /// portal; confirm it exists (and is in the app's entitlements) before
    /// the first build that enables sync.
    public static let cloudKitContainerID = "iCloud.\(bundleIdentifier)"

    /// The store the shipped app opens: private CloudKit sync enabled.
    public static func makeSyncedContainer() throws -> ModelContainer {
        try makeContainer(cloudKitContainerID: cloudKitContainerID)
    }

    /// - Parameter cloudKitContainerID: the private CloudKit container, e.g.
    ///   "iCloud.com.example.app". Nil keeps the store local-only.
    public static func makeContainer(
        inMemory: Bool = false,
        cloudKitContainerID: String? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
        let configuration: ModelConfiguration
        if let cloudKitContainerID, !inMemory {
            configuration = ModelConfiguration(
                "Workspace",
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            configuration = ModelConfiguration(
                "Workspace",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: PersistenceMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            // Never delete or reset the store automatically.
            throw EngineError.unavailable("The local store could not be opened")
        }
    }
}

public struct StoreDiagnostics: Equatable, Sendable {
    public let schemaVersion: Int
    public let revision: Int
    /// Counts only; never document text or personal fields.
    public let recordCounts: [String: Int]
}

@ModelActor
public actor SwiftDataWorkspaceRepository: WorkspaceRepository {
    public func load() async throws -> Workspace? {
        guard let meta = try fetchMeta() else { return nil }
        let drafts = try fetchEntities().map(Self.draft)
        return try WorkspaceMapper.workspace(from: drafts, revision: meta.revision)
    }

    public func save(_ workspace: Workspace, expectedRevision: Int) async throws -> Workspace {
        let meta = try fetchMeta()
        let actual = meta?.revision ?? 0
        guard actual == expectedRevision else {
            throw EngineError.conflict(expected: expectedRevision, actual: actual)
        }

        var committed = workspace
        committed.revision = expectedRevision + 1
        let drafts = try WorkspaceMapper.drafts(from: committed)

        do {
            var existing: [String: StoredEntity] = [:]
            for entity in try fetchEntities() {
                let key = Self.key(kind: entity.kind, id: entity.entityID)
                if existing[key] == nil {
                    existing[key] = entity
                } else {
                    modelContext.delete(entity) // duplicate identity from a sync race
                }
            }
            var keep: Set<String> = []
            for draft in drafts {
                let key = Self.key(kind: draft.kind.rawValue, id: draft.id)
                keep.insert(key)
                if let entity = existing[key] {
                    if entity.payload != draft.payload { entity.payload = draft.payload }
                    if entity.rank != draft.rank { entity.rank = draft.rank }
                } else {
                    modelContext.insert(StoredEntity(
                        kind: draft.kind.rawValue, entityID: draft.id,
                        rank: draft.rank, payload: draft.payload
                    ))
                }
            }
            for (key, entity) in existing where !keep.contains(key) {
                modelContext.delete(entity)
            }
            if let meta {
                meta.revision = committed.revision
            } else {
                modelContext.insert(StoredWorkspaceMeta(
                    revision: committed.revision,
                    schemaVersion: WorkspaceArchive.currentSchemaVersion
                ))
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw EngineError.internalFailure("The workspace could not be saved")
        }
        return committed
    }

    public func diagnostics() throws -> StoreDiagnostics {
        var counts: [String: Int] = [:]
        for entity in try fetchEntities() { counts[entity.kind, default: 0] += 1 }
        let meta = try fetchMeta()
        return StoreDiagnostics(
            schemaVersion: meta?.schemaVersion ?? WorkspaceArchive.currentSchemaVersion,
            revision: meta?.revision ?? 0,
            recordCounts: counts
        )
    }

    private func fetchMeta() throws -> StoredWorkspaceMeta? {
        do {
            return try modelContext.fetch(FetchDescriptor<StoredWorkspaceMeta>()).first
        } catch {
            throw EngineError.corruptData("Workspace metadata is unreadable")
        }
    }

    private func fetchEntities() throws -> [StoredEntity] {
        do {
            return try modelContext.fetch(FetchDescriptor<StoredEntity>())
        } catch {
            throw EngineError.corruptData("Stored records are unreadable")
        }
    }

    private static func key(kind: String, id: UUID) -> String { "\(kind)/\(id.uuidString)" }

    private static func draft(_ entity: StoredEntity) throws -> EntityDraft {
        guard let kind = EntityKind(rawValue: entity.kind) else {
            throw EngineError.corruptData("Unknown record kind")
        }
        return EntityDraft(kind: kind, id: entity.entityID, rank: entity.rank, payload: entity.payload)
    }
}
