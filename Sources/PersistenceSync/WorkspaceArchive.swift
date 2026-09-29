import CareerDomain
import Foundation

public struct WorkspaceArchive: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let workspace: Workspace

    public init(
        schemaVersion: Int = WorkspaceArchive.currentSchemaVersion,
        exportedAt: Date,
        workspace: Workspace
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.workspace = workspace
    }
}

public struct WorkspaceArchiveCodec: Sendable {
    public init() {}

    public func encode(_ archive: WorkspaceArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(archive)
        } catch {
            throw EngineError.internalFailure("Workspace archive encoding failed")
        }
    }

    public func decode(_ data: Data) throws -> WorkspaceArchive {
        struct Header: Decodable { let schemaVersion: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let header: Header
        do {
            header = try decoder.decode(Header.self, from: data)
        } catch {
            throw EngineError.corruptData("Workspace archive header is unreadable")
        }
        guard header.schemaVersion == WorkspaceArchive.currentSchemaVersion else {
            throw EngineError.incompatibleSchema(header.schemaVersion)
        }
        do {
            return try decoder.decode(WorkspaceArchive.self, from: data)
        } catch {
            throw EngineError.corruptData("Workspace archive content is unreadable")
        }
    }
}

