import CareerDomain
import Foundation

public actor WorkspaceService {
    private let repository: any WorkspaceRepository

    public init(repository: any WorkspaceRepository) {
        self.repository = repository
    }

    public func loadOrCreate(profile: CareerProfile) async throws -> Workspace {
        if let existing = try await repository.load() {
            return existing
        }
        let workspace = Workspace(profile: profile)
        return try await repository.save(workspace, expectedRevision: 0)
    }

    public func replaceProfile(
        _ profile: CareerProfile,
        operationID: UUID
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        let blocking = CareerValidator.validate(profile).filter { $0.severity == .blocking }
        guard blocking.isEmpty else { throw EngineError.validation(blocking) }
        let expectedRevision = workspace.revision
        workspace.profile = profile
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    public func createDocument(
        kind: DocumentKind,
        title: String,
        subscription: SubscriptionStatus,
        operationID: UUID,
        now: Date
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        let gate = FeatureGate(subscription: subscription, now: now)
        guard gate.canCreate(kind, existing: workspace.documents) else {
            let feature: Feature = switch kind {
            case .resume: .createResume
            case .workHistory: .createWorkHistory
            case .coverLetter: .createCoverLetter
            }
            throw EngineError.entitlementRequired(feature)
        }
        let expectedRevision = workspace.revision
        workspace.documents.append(DocumentRecord(kind: kind, title: title, createdAt: now, modifiedAt: now))
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    public func acceptNarrative(
        _ narrative: Narrative,
        documentID: UUID,
        operationID: UUID,
        now: Date
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        guard let index = workspace.documents.firstIndex(where: { $0.id == documentID }) else {
            throw EngineError.invalidInput("Document does not exist")
        }
        guard narrative.citedFactIDs.isSubset(of: workspace.profile.confirmedFactIDs) else {
            throw EngineError.invalidInput("Narrative cites an unconfirmed or missing fact")
        }
        let expectedRevision = workspace.revision
        workspace.documents[index].narratives.removeAll { $0.field == narrative.field }
        workspace.documents[index].narratives.append(narrative)
        workspace.documents[index].modifiedAt = now
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    public func recordCompletedExport(
        operationID: UUID,
        subscription: SubscriptionStatus,
        now: Date
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        let gate = FeatureGate(subscription: subscription, now: now)
        guard gate.allows(.exportPDF, usage: workspace.usage) else {
            throw EngineError.entitlementRequired(.exportPDF)
        }
        let expectedRevision = workspace.revision
        workspace.usage.recordCompletedExport(operationID: operationID)
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    public func freezeDocumentVersion(
        documentID: UUID,
        subscription: SubscriptionStatus,
        operationID: UUID,
        now: Date
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        let gate = FeatureGate(subscription: subscription, now: now)
        guard gate.allows(.versionHistory, usage: workspace.usage) else {
            throw EngineError.entitlementRequired(.versionHistory)
        }
        guard let document = workspace.documents.first(where: { $0.id == documentID }) else {
            throw EngineError.invalidInput("Document does not exist")
        }
        let issues = CareerValidator.validate(workspace.profile)
            + CareerValidator.validate(document, against: workspace.profile)
        let blocking = issues.filter { $0.severity == .blocking }
        guard blocking.isEmpty else { throw EngineError.validation(blocking) }

        let expectedRevision = workspace.revision
        workspace.documentVersions.append(DocumentVersion(
            documentID: documentID,
            profile: workspace.profile,
            document: document,
            createdAt: now
        ))
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    public func createApplication(
        company: String,
        role: String,
        vacancyText: String? = nil,
        deadline: Date? = nil,
        subscription: SubscriptionStatus,
        operationID: UUID,
        now: Date
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        let gate = FeatureGate(subscription: subscription, now: now)
        guard gate.allows(.applicationTracking, usage: workspace.usage) else {
            throw EngineError.entitlementRequired(.applicationTracking)
        }
        let normalizedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRole = role.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCompany.isEmpty, !normalizedRole.isEmpty else {
            throw EngineError.invalidInput("Company and role are required")
        }
        let expectedRevision = workspace.revision
        workspace.applications.append(JobApplication(
            company: normalizedCompany,
            role: normalizedRole,
            vacancyText: vacancyText,
            deadline: deadline,
            modifiedAt: now
        ))
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    public func changeApplicationStage(
        applicationID: UUID,
        stage: ApplicationStage,
        subscription: SubscriptionStatus,
        operationID: UUID,
        now: Date
    ) async throws -> Workspace {
        var workspace = try await requireWorkspace()
        if workspace.processedOperationIDs.contains(operationID) { return workspace }
        let gate = FeatureGate(subscription: subscription, now: now)
        guard gate.allows(.applicationTracking, usage: workspace.usage) else {
            throw EngineError.entitlementRequired(.applicationTracking)
        }
        guard let index = workspace.applications.firstIndex(where: { $0.id == applicationID }) else {
            throw EngineError.invalidInput("Application does not exist")
        }
        guard Self.canTransition(from: workspace.applications[index].stage, to: stage) else {
            throw EngineError.invalidTransition("Application stage transition is not allowed")
        }
        let expectedRevision = workspace.revision
        workspace.applications[index].stage = stage
        workspace.applications[index].modifiedAt = now
        workspace.processedOperationIDs.insert(operationID)
        return try await repository.save(workspace, expectedRevision: expectedRevision)
    }

    private static func canTransition(from: ApplicationStage, to: ApplicationStage) -> Bool {
        if from == to { return true }
        return switch from {
        case .preparing:
            [.submitted, .withdrawn].contains(to)
        case .submitted:
            [.interviewing, .rejected, .withdrawn].contains(to)
        case .interviewing:
            [.offered, .rejected, .withdrawn].contains(to)
        case .offered:
            [.withdrawn].contains(to)
        case .rejected, .withdrawn:
            false
        }
    }

    private func requireWorkspace() async throws -> Workspace {
        guard let workspace = try await repository.load() else {
            throw EngineError.invalidTransition("Workspace must be created first")
        }
        return workspace
    }
}
