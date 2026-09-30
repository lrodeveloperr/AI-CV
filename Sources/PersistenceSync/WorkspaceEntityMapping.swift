import CareerDomain
import Foundation

/// The persisted kinds of record. Each domain entity is stored as one record
/// keyed by its stable identifier so independent child records merge by
/// identity during synchronization.
public enum EntityKind: String, Codable, CaseIterable, Sendable {
    case contact
    case education
    case employment
    case qualification
    case achievement
    case application
    case document
    case documentVersion
    case completedExport
    case processedOperation
}

public struct EntityDraft: Equatable, Sendable {
    public let kind: EntityKind
    public let id: UUID
    public let rank: Int
    public let payload: Data

    public init(kind: EntityKind, id: UUID, rank: Int, payload: Data) {
        self.kind = kind
        self.id = id
        self.rank = rank
        self.payload = payload
    }
}

/// Pure mapping between the domain `Workspace` and flat record drafts. No
/// persistence framework types appear here, so it is testable in isolation.
public enum WorkspaceMapper {
    public static func drafts(from workspace: Workspace) throws -> [EntityDraft] {
        var drafts: [EntityDraft] = []
        let profile = workspace.profile
        drafts.append(EntityDraft(kind: .contact, id: profile.id, rank: 0, payload: try encode(profile.contact)))
        try append(profile.education, as: .education, to: &drafts)
        try append(profile.employment, as: .employment, to: &drafts)
        try append(profile.qualifications, as: .qualification, to: &drafts)
        try append(profile.achievements, as: .achievement, to: &drafts)
        try append(workspace.applications, as: .application, to: &drafts)
        try append(workspace.documents, as: .document, to: &drafts)
        try append(workspace.documentVersions, as: .documentVersion, to: &drafts)
        for (rank, id) in workspace.usage.completedExportOperationIDs.sorted(by: { $0.uuidString < $1.uuidString }).enumerated() {
            drafts.append(EntityDraft(kind: .completedExport, id: id, rank: rank, payload: Data()))
        }
        for (rank, id) in workspace.processedOperationIDs.sorted(by: { $0.uuidString < $1.uuidString }).enumerated() {
            drafts.append(EntityDraft(kind: .processedOperation, id: id, rank: rank, payload: Data()))
        }
        return drafts
    }

    public static func workspace(from drafts: [EntityDraft], revision: Int) throws -> Workspace {
        func sorted(_ kind: EntityKind) -> [EntityDraft] {
            drafts.filter { $0.kind == kind }.sorted { ($0.rank, $0.id.uuidString) < ($1.rank, $1.id.uuidString) }
        }
        guard let contactDraft = sorted(.contact).first else {
            throw EngineError.corruptData("Stored workspace has no profile record")
        }
        let profile = CareerProfile(
            id: contactDraft.id,
            contact: try decode(ContactDetails.self, contactDraft.payload),
            education: try sorted(.education).map { try decode(Education.self, $0.payload) },
            employment: try sorted(.employment).map { try decode(Employment.self, $0.payload) },
            qualifications: try sorted(.qualification).map { try decode(Qualification.self, $0.payload) },
            achievements: try sorted(.achievement).map { try decode(Achievement.self, $0.payload) }
        )
        return Workspace(
            profile: profile,
            documents: try sorted(.document).map { try decode(DocumentRecord.self, $0.payload) },
            documentVersions: try sorted(.documentVersion).map { try decode(DocumentVersion.self, $0.payload) },
            applications: try sorted(.application).map { try decode(JobApplication.self, $0.payload) },
            usage: UsageLedger(completedExportOperationIDs: Set(sorted(.completedExport).map(\.id))),
            processedOperationIDs: Set(sorted(.processedOperation).map(\.id)),
            revision: revision
        )
    }

    private static func append<T: Identifiable & Encodable>(
        _ items: [T], as kind: EntityKind, to drafts: inout [EntityDraft]
    ) throws where T.ID == UUID {
        for (rank, item) in items.enumerated() {
            drafts.append(EntityDraft(kind: kind, id: item.id, rank: rank, payload: try encode(item)))
        }
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(value)
        } catch {
            throw EngineError.internalFailure("Record encoding failed")
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw EngineError.corruptData("A stored record is unreadable")
        }
    }
}
