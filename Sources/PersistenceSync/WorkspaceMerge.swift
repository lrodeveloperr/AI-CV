import CareerDomain
import Foundation

public struct MergeConflict: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case bothEdited
        case editedVersusDeleted
        case bothAdded
    }

    public let collection: String
    public let id: UUID
    public let kind: Kind

    public init(collection: String, id: UUID, kind: Kind) {
        self.collection = collection
        self.id = id
        self.kind = kind
    }
}

public struct WorkspaceMergeResult: Equatable, Sendable {
    /// Merged state. Where a conflict exists, no data is dropped: the local
    /// value (or the surviving side of an edit-versus-delete) is kept here and
    /// the conflict is reported for explicit user confirmation.
    public let workspace: Workspace
    public let conflicts: [MergeConflict]
    /// Remote narrative/document edits that lost to a local edit, preserved
    /// as frozen document versions instead of being discarded.
    public let preservedVersions: [DocumentVersion]

    public var requiresReview: Bool { !conflicts.isEmpty }

    /// `.conflictRequiresReview` when user attention is needed; nil otherwise.
    /// A clean merge never claims "Synced" — that comes only from the store.
    public var syncState: SyncState? { requiresReview ? .conflictRequiresReview : nil }
}

/// Three-way merge of a whole workspace by stable identity. Deletions are
/// detected against the common base, so concurrent edits are never silently
/// resolved by picking one text value.
public enum WorkspaceMerge {
    public static func merge(base: Workspace, local: Workspace, remote: Workspace) -> WorkspaceMergeResult {
        var conflicts: [MergeConflict] = []

        // Contact details merge per field.
        var contact = local.profile.contact
        let profileID = local.profile.id
        func resolve<V: Equatable & Sendable>(_ keyPath: WritableKeyPath<ContactDetails, V>, _ name: String) {
            switch ThreeWayMerge.resolve(
                base: base.profile.contact[keyPath: keyPath],
                local: local.profile.contact[keyPath: keyPath],
                remote: remote.profile.contact[keyPath: keyPath]
            ) {
            case .merged(let value):
                contact[keyPath: keyPath] = value
            case .conflict:
                conflicts.append(MergeConflict(collection: "contact.\(name)", id: profileID, kind: .bothEdited))
            }
        }
        resolve(\.fullName, "fullName")
        resolve(\.phoneticName, "phoneticName")
        resolve(\.email, "email")
        resolve(\.phone, "phone")
        resolve(\.postalCode, "postalCode")
        resolve(\.address, "address")

        let education = mergeCollection(
            base: base.profile.education, local: local.profile.education,
            remote: remote.profile.education, name: "education"
        )
        let employment = mergeCollection(
            base: base.profile.employment, local: local.profile.employment,
            remote: remote.profile.employment, name: "employment"
        )
        let qualifications = mergeCollection(
            base: base.profile.qualifications, local: local.profile.qualifications,
            remote: remote.profile.qualifications, name: "qualifications"
        )
        let achievements = mergeCollection(
            base: base.profile.achievements, local: local.profile.achievements,
            remote: remote.profile.achievements, name: "achievements"
        )
        let applications = mergeCollection(
            base: base.applications, local: local.applications,
            remote: remote.applications, name: "applications"
        )
        conflicts += education.conflicts + employment.conflicts
            + qualifications.conflicts + achievements.conflicts + applications.conflicts

        let profile = CareerProfile(
            id: profileID,
            contact: contact,
            education: education.merged,
            employment: employment.merged,
            qualifications: qualifications.merged,
            achievements: achievements.merged
        )

        let documents = mergeDocuments(
            base: base.documents, local: local.documents, remote: remote.documents, profile: profile
        )
        conflicts += documents.conflicts

        var versions: [DocumentVersion] = []
        var seenVersionIDs: Set<UUID> = []
        for version in local.documentVersions + remote.documentVersions + base.documentVersions
        where seenVersionIDs.insert(version.id).inserted {
            versions.append(version)
        }
        versions += documents.preserved

        let workspace = Workspace(
            profile: profile,
            documents: documents.merged,
            documentVersions: versions,
            applications: applications.merged,
            usage: UsageLedger(completedExportOperationIDs:
                local.usage.completedExportOperationIDs
                    .union(remote.usage.completedExportOperationIDs)
                    .union(base.usage.completedExportOperationIDs)),
            processedOperationIDs: local.processedOperationIDs
                .union(remote.processedOperationIDs)
                .union(base.processedOperationIDs),
            revision: max(local.revision, remote.revision)
        )
        return WorkspaceMergeResult(
            workspace: workspace,
            conflicts: conflicts,
            preservedVersions: documents.preserved
        )
    }

    // MARK: - Collections

    static func mergeCollection<T: Identifiable & Equatable>(
        base: [T], local: [T], remote: [T], name: String
    ) -> (merged: [T], conflicts: [MergeConflict]) where T.ID == UUID {
        let baseByID = index(base)
        let localByID = index(local)
        let remoteByID = index(remote)
        var merged: [T] = []
        var conflicts: [MergeConflict] = []

        for id in orderedIDs(base, local, remote) {
            let b = baseByID[id], l = localByID[id], r = remoteByID[id]
            if l == r {
                if let l { merged.append(l) }
            } else if b == nil {
                if let l, r != nil {
                    conflicts.append(MergeConflict(collection: name, id: id, kind: .bothAdded))
                    merged.append(l)
                } else if let survivor = l ?? r {
                    merged.append(survivor)
                }
            } else if l == b {
                if let r { merged.append(r) }
            } else if r == b {
                if let l { merged.append(l) }
            } else if let l, r != nil {
                conflicts.append(MergeConflict(collection: name, id: id, kind: .bothEdited))
                merged.append(l)
            } else if let survivor = l ?? r {
                conflicts.append(MergeConflict(collection: name, id: id, kind: .editedVersusDeleted))
                merged.append(survivor)
            }
        }
        return (merged, conflicts)
    }

    private static func mergeDocuments(
        base: [DocumentRecord], local: [DocumentRecord], remote: [DocumentRecord], profile: CareerProfile
    ) -> (merged: [DocumentRecord], conflicts: [MergeConflict], preserved: [DocumentVersion]) {
        let baseByID = index(base)
        let localByID = index(local)
        let remoteByID = index(remote)
        var merged: [DocumentRecord] = []
        var conflicts: [MergeConflict] = []
        var preserved: [DocumentVersion] = []

        for id in orderedIDs(base, local, remote) {
            let b = baseByID[id], l = localByID[id], r = remoteByID[id]
            if l == r {
                if let l { merged.append(l) }
                continue
            }
            guard let b else {
                if let l, r != nil {
                    conflicts.append(MergeConflict(collection: "documents", id: id, kind: .bothAdded))
                    merged.append(l)
                } else if let survivor = l ?? r {
                    merged.append(survivor)
                }
                continue
            }
            if l == b {
                if let r { merged.append(r) }
                continue
            }
            if r == b {
                if let l { merged.append(l) }
                continue
            }
            guard let l, let r else {
                conflicts.append(MergeConflict(collection: "documents", id: id, kind: .editedVersusDeleted))
                if let survivor = l ?? r { merged.append(survivor) }
                continue
            }

            // Both sides edited the document: merge narratives by identity and
            // the remaining settings as a unit.
            let narratives = mergeCollection(
                base: b.narratives, local: l.narratives, remote: r.narratives, name: "narratives"
            )
            var document = l
            var losingRemote = !narratives.conflicts.isEmpty
            switch ThreeWayMerge.resolve(base: stripped(b), local: stripped(l), remote: stripped(r)) {
            case .merged(let value):
                document = value
            case .conflict:
                conflicts.append(MergeConflict(collection: "documents", id: id, kind: .bothEdited))
                losingRemote = true
            }
            document.narratives = narratives.merged
            document.modifiedAt = max(l.modifiedAt, r.modifiedAt)
            conflicts += narratives.conflicts
            merged.append(document)

            if losingRemote {
                preserved.append(DocumentVersion(
                    documentID: id,
                    profile: profile,
                    document: r,
                    createdAt: max(l.modifiedAt, r.modifiedAt)
                ))
            }
        }
        return (merged, conflicts, preserved)
    }

    private static func stripped(_ document: DocumentRecord) -> DocumentRecord {
        var copy = document
        copy.narratives = []
        copy.modifiedAt = .distantPast
        return copy
    }

    private static func index<T: Identifiable>(_ items: [T]) -> [UUID: T] where T.ID == UUID {
        Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func orderedIDs<T: Identifiable>(_ lists: [T]...) -> [UUID] where T.ID == UUID {
        var seen: Set<UUID> = []
        var order: [UUID] = []
        for list in lists {
            for item in list where seen.insert(item.id).inserted {
                order.append(item.id)
            }
        }
        return order
    }
}
