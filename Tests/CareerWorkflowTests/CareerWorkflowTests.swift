import CareerDomain
import CareerWorkflow
import Foundation
import Testing

@Test func repeatedCreateOperationIsIdempotent() async throws {
    let repository = InMemoryWorkspaceRepository()
    let service = WorkspaceService(repository: repository)
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let operationID = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    _ = try await service.createDocument(
        kind: .resume,
        title: "Resume",
        subscription: .free,
        operationID: operationID,
        now: now
    )
    let repeated = try await service.createDocument(
        kind: .resume,
        title: "Resume",
        subscription: .free,
        operationID: operationID,
        now: now
    )

    #expect(repeated.documents.count == 1)
}

@Test func failedSavePreservesExistingWorkspaceAndCanRetry() async throws {
    let repository = InMemoryWorkspaceRepository()
    let service = WorkspaceService(repository: repository)
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let operationID = UUID()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    await repository.failNextSave(with: .internalFailure("simulated"))

    do {
        _ = try await service.createDocument(
            kind: .resume,
            title: "Resume",
            subscription: .free,
            operationID: operationID,
            now: now
        )
        Issue.record("Expected the queued persistence failure")
    } catch {
        #expect(error as? EngineError == .internalFailure("simulated"))
    }

    let afterFailure = try await repository.load()
    #expect(afterFailure?.documents.isEmpty == true)
    #expect(afterFailure?.processedOperationIDs.contains(operationID) == false)

    let retried = try await service.createDocument(
        kind: .resume,
        title: "Resume",
        subscription: .free,
        operationID: operationID,
        now: now
    )
    #expect(retried.documents.count == 1)
}

@Test func secondFreeResumeIsRejectedWithoutLosingTheFirst() async throws {
    let repository = InMemoryWorkspaceRepository()
    let service = WorkspaceService(repository: repository)
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    _ = try await service.createDocument(kind: .resume, title: "First", subscription: .free, operationID: UUID(), now: now)

    do {
        _ = try await service.createDocument(kind: .resume, title: "Second", subscription: .free, operationID: UUID(), now: now)
        Issue.record("Expected the second free résumé to require Pro")
    } catch {
        #expect(error as? EngineError == .entitlementRequired(.createResume))
    }
    let stored = try await repository.load()
    #expect(stored?.documents.map(\.title) == ["First"])
}

@Test func documentVersionsAreImmutableProSnapshots() async throws {
    let repository = InMemoryWorkspaceRepository()
    let service = WorkspaceService(repository: repository)
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let created = try await service.createDocument(
        kind: .resume,
        title: "Resume",
        subscription: .proActive(expiresAt: nil),
        operationID: UUID(),
        now: now
    )
    let documentID = try #require(created.documents.first?.id)
    let frozen = try await service.freezeDocumentVersion(
        documentID: documentID,
        subscription: .proActive(expiresAt: nil),
        operationID: UUID(),
        now: now
    )
    #expect(frozen.documentVersions.count == 1)
    #expect(frozen.documentVersions[0].document.title == "Resume")
    #expect(frozen.documentVersions[0].profile.contact.fullName == "Candidate")
}

@Test func applicationStateMachineRejectsImpossibleJump() async throws {
    let repository = InMemoryWorkspaceRepository()
    let service = WorkspaceService(repository: repository)
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let workspace = try await service.createApplication(
        company: "Company",
        role: "Role",
        subscription: .proActive(expiresAt: nil),
        operationID: UUID(),
        now: now
    )
    let applicationID = try #require(workspace.applications.first?.id)
    do {
        _ = try await service.changeApplicationStage(
            applicationID: applicationID,
            stage: .offered,
            subscription: .proActive(expiresAt: nil),
            operationID: UUID(),
            now: now
        )
        Issue.record("Expected preparing-to-offered to be rejected")
    } catch {
        #expect(error as? EngineError == .invalidTransition("Application stage transition is not allowed"))
    }
}
