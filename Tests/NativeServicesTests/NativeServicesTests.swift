import CareerDomain
import CareerWorkflow
import DocumentEngine
import Foundation
import NativeServices
import Testing

private struct OneLineMeasurer: TextMeasurer {
    func measure(text: String, style: TextStyle, width: Double) throws -> [MeasuredLine] {
        [MeasuredLine(text: text, height: style.lineHeight)]
    }
}

private func makeSnapshot(limit: Int = 1_000_000) -> DocumentSnapshot {
    DocumentSnapshot(
        documentID: UUID(),
        kind: .resume,
        templateID: "standard-ja-v1",
        fields: [.init(id: "name", section: .identity, text: "山田 太郎", isRequired: true)],
        maximumPDFBytes: limit,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

@Test func exportArtifactCarriesExactlyTheRenderedBytes() async throws {
    let snapshot = makeSnapshot()
    let plan = try LayoutEngine(measurer: CoreTextMeasurer()).layout(snapshot)
    let rendered = try await CoreGraphicsPDFRenderer().render(plan)
    let artifact = try ExportArtifact(rendered: rendered, snapshot: snapshot, plan: plan)
    #expect(artifact.data == rendered.data)
    #expect(artifact.pageCount == rendered.pageCount)

    let url = try artifact.writeFile(named: "resume-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(try Data(contentsOf: url) == artifact.data)
    #expect(url.pathExtension == "pdf")
}

@Test func exportArtifactRejectsDocumentThatFailedValidation() async throws {
    let snapshot = makeSnapshot(limit: 10)
    let plan = try LayoutEngine(measurer: CoreTextMeasurer()).layout(snapshot)
    let rendered = try await CoreGraphicsPDFRenderer().render(plan)
    do {
        _ = try ExportArtifact(rendered: rendered, snapshot: snapshot, plan: plan)
        Issue.record("Expected oversized PDF to be rejected")
    } catch EngineError.validation(let issues) {
        #expect(issues.map(\.code).contains("pdf.size.exceeded"))
    }
}

private func freeWorkspaceService() async throws -> WorkspaceService {
    let service = WorkspaceService(repository: InMemoryWorkspaceRepository())
    _ = try await service.loadOrCreate(profile: CareerProfile(contact: ContactDetails(fullName: "Candidate")))
    return service
}

@Test func onlyACompletedHandoffConsumesTheFreeExport() async throws {
    let service = try await freeWorkspaceService()
    let recorder = ExportHandoffRecorder(service: service)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    #expect(try await recorder.finish(.canceled, operationID: UUID(), subscription: .free, now: now) == nil)
    #expect(try await recorder.finish(.failed, operationID: UUID(), subscription: .free, now: now) == nil)

    let operationID = UUID()
    let recorded = try await recorder.finish(.completed, operationID: operationID, subscription: .free, now: now)
    #expect(recorded?.usage.completedExportCount == 1)

    // Repeating the same operation does not double count.
    let repeated = try await recorder.finish(.completed, operationID: operationID, subscription: .free, now: now)
    #expect(repeated?.usage.completedExportCount == 1)
}

@Test func secondFreeExportRequiresPro() async throws {
    let service = try await freeWorkspaceService()
    let recorder = ExportHandoffRecorder(service: service)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    _ = try await recorder.finish(.completed, operationID: UUID(), subscription: .free, now: now)
    do {
        _ = try await recorder.finish(.completed, operationID: UUID(), subscription: .free, now: now)
        Issue.record("Expected the free limit to apply")
    } catch {
        #expect(error as? EngineError == .entitlementRequired(.exportPDF))
    }
}
