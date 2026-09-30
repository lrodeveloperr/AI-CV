import CareerDomain
import Foundation
import PersistenceSync
import Testing

@Test func workspaceArchiveRoundTripsDeterministically() throws {
    let workspace = Workspace(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let archive = WorkspaceArchive(
        exportedAt: Date(timeIntervalSince1970: 1_800_000_000),
        workspace: workspace
    )
    let codec = WorkspaceArchiveCodec()
    let first = try codec.encode(archive)
    let second = try codec.encode(archive)
    #expect(first == second)
    #expect(try codec.decode(first) == archive)
}

@Test func futureArchiveSchemaIsRejectedWithoutDataMutation() throws {
    let json = Data("{\"schemaVersion\":999,\"exportedAt\":\"2027-01-15T08:00:00Z\",\"workspace\":{}}".utf8)
    do {
        _ = try WorkspaceArchiveCodec().decode(json)
        Issue.record("Expected a future schema to be rejected")
    } catch {
        #expect(error as? EngineError == .incompatibleSchema(999))
    }
}

@Test func threeWayMergeNeverSilentlyDropsConcurrentChanges() {
    #expect(ThreeWayMerge.resolve(base: "A", local: "B", remote: "A") == .merged("B"))
    #expect(ThreeWayMerge.resolve(base: "A", local: "B", remote: "C") == .conflict(local: "B", remote: "C"))
}


// MARK: - Workspace merge

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func makeWorkspace(
    employment: [Employment] = [],
    documents: [DocumentRecord] = [],
    contact: ContactDetails = ContactDetails(fullName: "Candidate"),
    profileID: UUID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
) -> Workspace {
    Workspace(
        profile: CareerProfile(id: profileID, contact: contact, employment: employment),
        documents: documents
    )
}

@Test func independentAdditionsFromBothDevicesMerge() {
    let base = makeWorkspace()
    let a = Employment(employer: "A Corp")
    let b = Employment(employer: "B Corp")
    let result = WorkspaceMerge.merge(
        base: base,
        local: makeWorkspace(employment: [a]),
        remote: makeWorkspace(employment: [b])
    )
    #expect(result.conflicts.isEmpty)
    #expect(Set(result.workspace.profile.employment.map(\.employer)) == ["A Corp", "B Corp"])
    #expect(result.syncState == nil)
}

@Test func sameFactEditedOnBothSidesSurfacesConflictAndKeepsData() {
    let original = Employment(employer: "Acme")
    var local = original
    local.employer = "Acme Japan"
    var remote = original
    remote.employer = "Acme Holdings"
    let result = WorkspaceMerge.merge(
        base: makeWorkspace(employment: [original]),
        local: makeWorkspace(employment: [local]),
        remote: makeWorkspace(employment: [remote])
    )
    #expect(result.conflicts == [MergeConflict(collection: "employment", id: original.id, kind: .bothEdited)])
    #expect(result.workspace.profile.employment == [local])
    #expect(result.syncState == .conflictRequiresReview)
}

@Test func editVersusDeleteConflictsInsteadOfDeleting() {
    let original = Employment(employer: "Acme")
    var edited = original
    edited.employer = "Acme Japan"
    let result = WorkspaceMerge.merge(
        base: makeWorkspace(employment: [original]),
        local: makeWorkspace(employment: [edited]),
        remote: makeWorkspace(employment: [])
    )
    #expect(result.conflicts == [MergeConflict(collection: "employment", id: original.id, kind: .editedVersusDeleted)])
    #expect(result.workspace.profile.employment == [edited])
}

@Test func deletionOnOneSideWithoutEditPropagates() {
    let original = Employment(employer: "Acme")
    let result = WorkspaceMerge.merge(
        base: makeWorkspace(employment: [original]),
        local: makeWorkspace(employment: [original]),
        remote: makeWorkspace(employment: [])
    )
    #expect(result.conflicts.isEmpty)
    #expect(result.workspace.profile.employment.isEmpty)
}

@Test func contactFieldsMergeIndependently() {
    let base = makeWorkspace(contact: ContactDetails(fullName: "Candidate"))
    var localContact = base.profile.contact
    localContact.email = "a@example.com"
    var remoteContact = base.profile.contact
    remoteContact.phone = "090-0000-0000"
    let result = WorkspaceMerge.merge(
        base: base,
        local: makeWorkspace(contact: localContact),
        remote: makeWorkspace(contact: remoteContact)
    )
    #expect(result.conflicts.isEmpty)
    #expect(result.workspace.profile.contact.email == "a@example.com")
    #expect(result.workspace.profile.contact.phone == "090-0000-0000")
}

@Test func concurrentNarrativeEditsPreserveBothAsDocumentVersions() {
    let narrativeID = UUID()
    let docID = UUID()
    func document(_ text: String, modified: Date) -> DocumentRecord {
        DocumentRecord(
            id: docID, kind: .resume, title: "Resume",
            narratives: [Narrative(id: narrativeID, field: .selfPromotion, text: text, citedFactIDs: [], acceptedAt: t0)],
            createdAt: t0, modifiedAt: modified
        )
    }
    let result = WorkspaceMerge.merge(
        base: makeWorkspace(documents: [document("Base", modified: t0)]),
        local: makeWorkspace(documents: [document("Local", modified: t0.addingTimeInterval(10))]),
        remote: makeWorkspace(documents: [document("Remote", modified: t0.addingTimeInterval(20))])
    )
    #expect(result.requiresReview)
    #expect(result.workspace.documents.first?.narratives.first?.text == "Local")
    #expect(result.preservedVersions.count == 1)
    #expect(result.preservedVersions.first?.document.narratives.first?.text == "Remote")
    #expect(result.workspace.documentVersions.contains { $0.document.narratives.first?.text == "Remote" })
}

@Test func usageLedgerNeverLosesCompletedExportsDuringMerge() {
    let first = UUID(), second = UUID()
    var local = makeWorkspace()
    local.usage.recordCompletedExport(operationID: first)
    var remote = makeWorkspace()
    remote.usage.recordCompletedExport(operationID: second)
    let result = WorkspaceMerge.merge(base: makeWorkspace(), local: local, remote: remote)
    #expect(result.workspace.usage.completedExportOperationIDs == [first, second])
}

// MARK: - Record mapping and SwiftData store

private func richWorkspace() throws -> Workspace {
    let employment = Employment(
        employer: "株式会社サンプル",
        start: try PartialDate(year: 2015, month: 4),
        responsibilities: ["営業"]
    )
    let education = Education(school: "東京大学", start: try PartialDate(year: 2010, month: 4))
    let document = DocumentRecord(kind: .resume, title: "Resume", createdAt: t0, modifiedAt: t0)
    var workspace = Workspace(
        profile: CareerProfile(
            contact: ContactDetails(fullName: "山田 太郎", email: "a@example.com"),
            education: [education],
            employment: [employment, Employment(employer: "Second")]
        ),
        documents: [document],
        applications: [JobApplication(company: "C", role: "R", modifiedAt: t0)]
    )
    workspace.usage.recordCompletedExport(operationID: UUID())
    workspace.processedOperationIDs.insert(UUID())
    return workspace
}

@Test func mapperRoundTripsWorkspaceIncludingOrderAndLedger() throws {
    let workspace = try richWorkspace()
    let drafts = try WorkspaceMapper.drafts(from: workspace)
    #expect(try WorkspaceMapper.workspace(from: drafts.reversed(), revision: 0) == workspace)
}

@Test func mapperRejectsWorkspaceWithoutProfileRecord() {
    do {
        _ = try WorkspaceMapper.workspace(from: [], revision: 0)
        Issue.record("Expected corrupt data")
    } catch {
        #expect(error as? EngineError == .corruptData("Stored workspace has no profile record"))
    }
}

@Test func swiftDataRepositoryRoundTripsAndBumpsRevision() async throws {
    let container = try PersistenceContainerFactory.makeContainer(inMemory: true)
    let repository = SwiftDataWorkspaceRepository(modelContainer: container)
    #expect(try await repository.load() == nil)

    let workspace = try richWorkspace()
    let saved = try await repository.save(workspace, expectedRevision: 0)
    #expect(saved.revision == 1)

    var expected = workspace
    expected.revision = 1
    #expect(try await repository.load() == expected)
}

@Test func swiftDataRepositoryRejectsStaleRevision() async throws {
    let container = try PersistenceContainerFactory.makeContainer(inMemory: true)
    let repository = SwiftDataWorkspaceRepository(modelContainer: container)
    _ = try await repository.save(try richWorkspace(), expectedRevision: 0)
    do {
        _ = try await repository.save(try richWorkspace(), expectedRevision: 0)
        Issue.record("Expected a revision conflict")
    } catch {
        #expect(error as? EngineError == .conflict(expected: 0, actual: 1))
    }
}

@Test func swiftDataRepositoryRemovesDeletedRecordsAndReportsCounts() async throws {
    let container = try PersistenceContainerFactory.makeContainer(inMemory: true)
    let repository = SwiftDataWorkspaceRepository(modelContainer: container)
    var workspace = try await repository.save(try richWorkspace(), expectedRevision: 0)
    #expect(try await repository.diagnostics().recordCounts["employment"] == 2)

    workspace.profile.employment.removeFirst()
    let saved = try await repository.save(workspace, expectedRevision: workspace.revision)
    #expect(saved.profile.employment.count == 1)
    #expect(try await repository.load()?.profile.employment.count == 1)
    let diagnostics = try await repository.diagnostics()
    #expect(diagnostics.recordCounts["employment"] == 1)
    #expect(diagnostics.revision == 2)
}

@Test func cloudKitContainerIDFollowsBundleIdentifierConvention() throws {
    #expect(PersistenceContainerFactory.cloudKitContainerID == "iCloud.com.worksbienstudios.rirekishoai")
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let map = try String(contentsOf: root.appendingPathComponent(".github/testflight-app-map.json"), encoding: .utf8)
    #expect(map.contains("\"bundle_id\": \"\(PersistenceContainerFactory.bundleIdentifier)\""))
}

// MARK: - Sync status

@Test func syncStatusNeverClaimsSyncedWithoutConfirmation() {
    #expect(SyncStatusResolver.resolve(.init(iCloudAccountAvailable: true)) == .savedLocally)
    #expect(SyncStatusResolver.resolve(.init(iCloudAccountAvailable: false)) == .iCloudUnavailable)
    #expect(SyncStatusResolver.resolve(.init(iCloudAccountAvailable: true, exportInProgress: true)) == .syncing)
    #expect(SyncStatusResolver.resolve(.init(iCloudAccountAvailable: true, lastSuccessfulSync: t0)) == .synced(t0))
    #expect(SyncStatusResolver.resolve(.init(
        iCloudAccountAvailable: true, hasUnsyncedLocalChanges: true, lastSuccessfulSync: t0
    )) == .savedLocally)
    #expect(SyncStatusResolver.resolve(.init(
        iCloudAccountAvailable: true, lastSuccessfulSync: t0, lastSyncFailed: true
    )) == .savedLocally)
}

@Test func conflictsOutrankEveryOtherSyncState() {
    let observation = SyncObservation(
        iCloudAccountAvailable: false, exportInProgress: true, lastSuccessfulSync: t0, unresolvedConflictCount: 1
    )
    #expect(SyncStatusResolver.resolve(observation) == .conflictRequiresReview)
}

@Test func mergeConflictsSurfaceAsReviewRequiredStatus() {
    let original = Employment(employer: "Acme")
    var local = original
    local.employer = "Acme Japan"
    var remote = original
    remote.employer = "Acme Holdings"
    let merge = WorkspaceMerge.merge(
        base: makeWorkspace(employment: [original]),
        local: makeWorkspace(employment: [local]),
        remote: makeWorkspace(employment: [remote])
    )
    let observation = SyncStatusResolver.observation(
        .init(iCloudAccountAvailable: true, lastSuccessfulSync: t0), applying: merge
    )
    #expect(SyncStatusResolver.resolve(observation) == .conflictRequiresReview)
}
