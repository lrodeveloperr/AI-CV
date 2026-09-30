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

// MARK: - Variants and version links

private let proAccess = SubscriptionStatus.proActive(expiresAt: nil)
private let variantNow = Date(timeIntervalSince1970: 1_800_000_000)

private func seededService() async throws -> (WorkspaceService, Workspace) {
    let service = WorkspaceService(repository: InMemoryWorkspaceRepository())
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    var workspace = try await service.createDocument(
        kind: .resume, title: "Resume", subscription: proAccess, operationID: UUID(), now: variantNow
    )
    workspace = try await service.createApplication(
        company: "Acme", role: "Engineer", subscription: proAccess, operationID: UUID(), now: variantNow
    )
    return (service, workspace)
}

@Test func proUserCreatesApplicationVariantLinkedToApplication() async throws {
    let (service, seeded) = try await seededService()
    let source = seeded.documents[0]
    let application = seeded.applications[0]
    let narrative = Narrative(field: .motivation, text: "Why Acme", citedFactIDs: [], acceptedAt: variantNow)
    _ = try await service.acceptNarrative(narrative, documentID: source.id, operationID: UUID(), now: variantNow)

    let result = try await service.createVariant(
        of: source.id, applicationID: application.id, title: "Resume – Acme",
        subscription: proAccess, operationID: UUID(), now: variantNow
    )
    let variant = try #require(result.documents.last)
    #expect(result.documents.count == 2)
    #expect(variant.applicationID == application.id)
    #expect(variant.narratives.map(\.text) == ["Why Acme"])
    #expect(variant.narratives.first?.id != narrative.id)
    #expect(result.applications[0].documentIDs.contains(variant.id))
}

@Test func freeUserCannotCreateVariant() async throws {
    let service = WorkspaceService(repository: InMemoryWorkspaceRepository())
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    let created = try await service.createDocument(
        kind: .resume, title: "Resume", subscription: .free, operationID: UUID(), now: variantNow
    )
    do {
        _ = try await service.createVariant(
            of: created.documents[0].id, applicationID: UUID(), title: "Variant",
            subscription: .free, operationID: UUID(), now: variantNow
        )
        Issue.record("Expected an error")
    } catch {
        // Application lookup or entitlement must stop a free user either way.
        #expect(error is EngineError)
    }
}

@Test func freezingAVariantAssociatesTheVersionWithItsApplication() async throws {
    let (service, seeded) = try await seededService()
    let withVariant = try await service.createVariant(
        of: seeded.documents[0].id, applicationID: seeded.applications[0].id, title: "Variant",
        subscription: proAccess, operationID: UUID(), now: variantNow
    )
    let variantID = try #require(withVariant.documents.last?.id)
    let frozen = try await service.freezeDocumentVersion(
        documentID: variantID, subscription: proAccess, operationID: UUID(), now: variantNow
    )
    let versionID = try #require(frozen.documentVersions.last?.id)
    #expect(frozen.applications[0].documentVersionIDs == [versionID])
}

@Test func attachingVersionRequiresExistingVersionAndApplication() async throws {
    let (service, seeded) = try await seededService()
    let frozen = try await service.freezeDocumentVersion(
        documentID: seeded.documents[0].id, subscription: proAccess, operationID: UUID(), now: variantNow
    )
    let versionID = try #require(frozen.documentVersions.first?.id)

    let attached = try await service.attachVersion(
        versionID: versionID, toApplication: seeded.applications[0].id,
        subscription: proAccess, operationID: UUID(), now: variantNow
    )
    #expect(attached.applications[0].documentVersionIDs == [versionID])

    do {
        _ = try await service.attachVersion(
            versionID: UUID(), toApplication: seeded.applications[0].id,
            subscription: proAccess, operationID: UUID(), now: variantNow
        )
        Issue.record("Expected missing version to be rejected")
    } catch {
        #expect(error as? EngineError == .invalidInput("Document version does not exist"))
    }
}
