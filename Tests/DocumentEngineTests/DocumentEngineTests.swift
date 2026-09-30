import CareerDomain
import DocumentEngine
import Foundation
import Testing

private struct FixedWidthMeasurer: TextMeasurer {
    let charactersPerLine: Int

    func measure(text: String, style: TextStyle, width: Double) throws -> [MeasuredLine] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }
        return stride(from: 0, to: characters.count, by: charactersPerLine).map { start in
            let end = min(start + charactersPerLine, characters.count)
            return MeasuredLine(text: String(characters[start..<end]), height: style.lineHeight)
        }
    }
}

@Test func longWorkHistoryPlacesEveryFieldWithoutOmission() throws {
    let fields = (0..<30).map { index in
        DocumentField(
            id: "employment-\(index)",
            section: .employment,
            text: "Employer \(index) — responsibilities and achievements",
            keepTogether: true
        )
    }
    let snapshot = DocumentSnapshot(
        documentID: UUID(),
        kind: .workHistory,
        templateID: "standard-ja-v1",
        fields: fields,
        maximumPDFBytes: 5_000_000,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let plan = try LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 12)).layout(snapshot)
    #expect(plan.issues.isEmpty)
    #expect(plan.placedFieldIDs == Set(fields.map(\.id)))
    #expect(plan.pages.count > 1)
}

@Test func layoutIsDeterministicForTheSameSnapshot() throws {
    let snapshot = DocumentSnapshot(
        documentID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        kind: .resume,
        templateID: "standard-ja-v1",
        fields: [.init(id: "name", section: .identity, text: "山田 太郎", isRequired: true)],
        maximumPDFBytes: 1_000_000,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let engine = LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 10))
    #expect(try engine.layout(snapshot) == engine.layout(snapshot))
}

@Test func unsplittableOversizedFieldBlocksRendering() throws {
    let tinyPage = PageSpec(width: 200, height: 100, topMargin: 10, rightMargin: 10, bottomMargin: 10, leftMargin: 10)
    let field = DocumentField(
        id: "oversized",
        section: .narrative,
        text: String(repeating: "長", count: 200),
        style: TextStyle(lineHeight: 20),
        keepTogether: true
    )
    let snapshot = DocumentSnapshot(
        documentID: UUID(),
        kind: .resume,
        templateID: "standard-ja-v1",
        page: tinyPage,
        fields: [field],
        maximumPDFBytes: 1_000_000,
        createdAt: Date()
    )
    let plan = try LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 5)).layout(snapshot)
    #expect(plan.issues.map(\.code).contains(.unsplittableField))
    #expect(!plan.canRender)
}

@Test func exportValidationRejectsWrongSnapshotAndOversizeData() throws {
    let snapshot = DocumentSnapshot(
        documentID: UUID(),
        kind: .resume,
        templateID: "standard-ja-v1",
        fields: [.init(id: "name", section: .identity, text: "Candidate")],
        maximumPDFBytes: 2,
        createdAt: Date()
    )
    let plan = try LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 20)).layout(snapshot)
    let artifact = RenderedDocument(data: Data([1, 2, 3]), snapshotHash: 99, pageCount: plan.pages.count)
    let validation = ExportValidator.validate(artifact: artifact, snapshot: snapshot, plan: plan)
    let codes = Set(validation.issues.map(\.code))
    #expect(codes.contains("pdf.snapshot.mismatch"))
    #expect(codes.contains("pdf.size.exceeded"))
    #expect(!validation.isValid)
}

@Test func composerIncludesEveryEmploymentRecord() throws {
    let employments = try (0..<30).map { index in
        Employment(
            employer: "Employer \(index)",
            start: try PartialDate(year: 1990 + index, month: 1),
            end: try PartialDate(year: 1990 + index, month: 12),
            responsibilities: ["Responsibility \(index)"]
        )
    }
    let profile = CareerProfile(
        contact: ContactDetails(fullName: "Candidate"),
        employment: employments
    )
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let document = DocumentRecord(kind: .workHistory, title: "Work History", createdAt: now, modifiedAt: now)
    let snapshot = try DocumentComposer().compose(
        profile: profile,
        document: document,
        maximumPDFBytes: 5_000_000,
        createdAt: now
    )
    let employmentFieldIDs = Set(snapshot.fields.filter { $0.section == .employment }.map(\.id))
    let expected = Set(employments.map { "employment.\($0.id.uuidString)" })
    #expect(employmentFieldIDs == expected)
}

@Test func nativeRendererProducesTheExactValidatedArtifact() async throws {
    let snapshot = DocumentSnapshot(
        documentID: UUID(),
        kind: .resume,
        templateID: "standard-ja-v1",
        fields: [
            .init(id: "name", section: .identity, text: "山田 太郎", isRequired: true),
            .init(id: "summary", section: .narrative, text: "確認済みの職歴を記載します。")
        ],
        maximumPDFBytes: 1_000_000,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let plan = try LayoutEngine(measurer: CoreTextMeasurer()).layout(snapshot)
    let artifact = try await CoreGraphicsPDFRenderer().render(plan)
    let validation = ExportValidator.validate(artifact: artifact, snapshot: snapshot, plan: plan)

    #expect(artifact.data.starts(with: Data("%PDF".utf8)))
    #expect(artifact.pageCount == plan.pages.count)
    #expect(validation.isValid)
}

// MARK: - Size budget

private struct QualitySizedRenderer: PortraitQualityRendering {
    let sizeAtQuality: @Sendable (Double) -> Int

    func render(_ plan: LayoutPlan, portraitQuality: Double) async throws -> RenderedDocument {
        RenderedDocument(
            data: Data(count: sizeAtQuality(portraitQuality)),
            snapshotHash: plan.snapshotHash,
            pageCount: plan.pages.count
        )
    }
}

private func budgetFixture(portraitBytes: Int, limit: Int) throws -> (DocumentSnapshot, LayoutPlan) {
    let snapshot = DocumentSnapshot(
        documentID: UUID(),
        kind: .resume,
        templateID: "standard-ja-v1",
        fields: [.init(id: "name", section: .identity, text: "山田 太郎", isRequired: true)],
        maximumPDFBytes: limit,
        portraitBytes: portraitBytes,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
    let plan = try LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 10)).layout(snapshot)
    return (snapshot, plan)
}

@Test func sizeBudgetKeepsNormalQualityWhenWithinLimit() async throws {
    let (snapshot, plan) = try budgetFixture(portraitBytes: 100, limit: 1_000)
    let sized = try await SizeBudgetRenderer(renderer: QualitySizedRenderer { _ in 500 })
        .render(snapshot: snapshot, plan: plan)
    #expect(sized.attempts == 1)
    #expect(sized.portraitQuality == SizeBudgetRenderer.normalQuality)
}

@Test func sizeBudgetRecompressesOnlyAsFarAsNeeded() async throws {
    let (snapshot, plan) = try budgetFixture(portraitBytes: 100, limit: 1_000)
    let renderer = QualitySizedRenderer { quality in Int(quality * 1_400) }
    let sized = try await SizeBudgetRenderer(renderer: renderer).render(snapshot: snapshot, plan: plan)
    #expect(sized.portraitQuality == 0.6)
    #expect(sized.attempts == 3)
    #expect(sized.document.data.count <= 1_000)
}

@Test func sizeBudgetBlocksExportWhenMinimumQualityStillTooLarge() async throws {
    let (snapshot, plan) = try budgetFixture(portraitBytes: 100, limit: 1_000)
    do {
        _ = try await SizeBudgetRenderer(renderer: QualitySizedRenderer { _ in 5_000 })
            .render(snapshot: snapshot, plan: plan)
        Issue.record("Expected oversized output to be blocked")
    } catch EngineError.validation(let issues) {
        #expect(issues.first?.code == "pdf.size.exceeded")
    }
}

@Test func sizeBudgetDoesNotRetryWithoutPortrait() async throws {
    let (snapshot, plan) = try budgetFixture(portraitBytes: 0, limit: 1_000)
    do {
        _ = try await SizeBudgetRenderer(renderer: QualitySizedRenderer { _ in 5_000 })
            .render(snapshot: snapshot, plan: plan)
        Issue.record("Expected oversized output to be blocked")
    } catch EngineError.validation(let issues) {
        #expect(issues.first?.message.contains("1 attempt") == true)
    }
}
