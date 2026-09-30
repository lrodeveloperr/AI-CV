import CareerDomain
import CoreGraphics
import DocumentEngine
import Foundation
import ImageIO
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

// MARK: - Portrait

private struct PortraitFixture {
    static func imageData(width: Int, height: Int, noisy: Bool) -> Data {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        var seed: UInt32 = 12345
        for index in stride(from: 0, to: pixels.count, by: 4) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let value = noisy ? UInt8(truncatingIfNeeded: seed >> 24) : 200
            pixels[index] = value
            pixels[index + 1] = noisy ? UInt8(truncatingIfNeeded: seed >> 16) : 180
            pixels[index + 2] = noisy ? UInt8(truncatingIfNeeded: seed >> 8) : 160
            pixels[index + 3] = 255
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}

private func portraitSnapshot(_ portrait: PortraitImage?, limit: Int = 50_000_000) -> DocumentSnapshot {
    DocumentSnapshot(
        documentID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        kind: .resume,
        templateID: "standard-ja-v1",
        fields: [
            .init(id: "name", section: .identity, text: "山田 太郎", isRequired: true),
            .init(id: "contact", section: .contact, text: "東京都千代田区 1-1-1  090-0000-0000")
        ],
        maximumPDFBytes: limit,
        portrait: portrait,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

@Test func portraitProcessorCropsToPortraitAspectAndDownsamples() throws {
    let prepared = try PortraitProcessor.prepare(PortraitFixture.imageData(width: 2_000, height: 1_000, noisy: false))
    #expect(prepared.pixelHeight <= PortraitProcessor.maximumPixelHeight)
    let ratio = Double(prepared.pixelWidth) / Double(prepared.pixelHeight)
    #expect(abs(ratio - 0.75) < 0.01)
    #expect(prepared.data.starts(with: [0xFF, 0xD8]))
}

@Test func unreadablePortraitIsRejected() {
    do {
        _ = try PortraitProcessor.prepare(Data([1, 2, 3]))
        Issue.record("Expected unreadable portrait to fail")
    } catch EngineError.validation(let issues) {
        #expect(issues.first?.code == "portrait.unreadable")
    } catch {
        Issue.record("Unexpected error \(error)")
    }
}

@Test func portraitBelowMinimumResolutionBlocksLayout() throws {
    let tiny = PortraitImage(data: Data([0]), pixelWidth: 100, pixelHeight: 100)
    let plan = try LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 20)).layout(portraitSnapshot(tiny))
    #expect(plan.issues.map(\.code).contains(.portraitTooSmall))
    #expect(!plan.canRender)
}

@Test func layoutReservesPortraitAndWrapsBesideItInNarrowColumn() throws {
    let image = PortraitImage(data: Data([0]), pixelWidth: 480, pixelHeight: 640)
    let plan = try LayoutEngine(measurer: FixedWidthMeasurer(charactersPerLine: 20)).layout(portraitSnapshot(image))
    let page = PageSpec.a4
    let portrait = try #require(plan.portrait)
    #expect(portrait.frame.x + portrait.frame.width == page.width - page.rightMargin)
    #expect(portrait.frame.y == page.topMargin)
    let narrow = page.contentWidth - LayoutEngine.portraitWidth - LayoutEngine.portraitGap
    let first = try #require(plan.pages.first?.textPlacements.first)
    #expect(first.frame.width == narrow)
}

@Test func snapshotHashChangesWithPortraitContent() {
    let a = PortraitImage(data: Data([1, 2, 3]), pixelWidth: 480, pixelHeight: 640)
    let b = PortraitImage(data: Data([1, 2, 4]), pixelWidth: 480, pixelHeight: 640)
    #expect(portraitSnapshot(a).stableContentHash != portraitSnapshot(b).stableContentHash)
    #expect(portraitSnapshot(a).stableContentHash != portraitSnapshot(nil).stableContentHash)
}

@Test func lowerPortraitQualityProducesSmallerRealPDFAndBudgetPicksIt() async throws {
    let portrait = try PortraitProcessor.prepare(PortraitFixture.imageData(width: 600, height: 800, noisy: true))
    let renderer = CoreGraphicsPDFRenderer()
    let probe = portraitSnapshot(portrait)
    let plan = try LayoutEngine(measurer: CoreTextMeasurer()).layout(probe)

    let high = try await renderer.render(plan, portraitQuality: 0.9).data.count
    let low = try await renderer.render(plan, portraitQuality: 0.45).data.count
    #expect(low < high)

    // A ceiling between the two forces recompression but still succeeds.
    let limited = portraitSnapshot(portrait, limit: (high + low) / 2)
    let limitedPlan = try LayoutEngine(measurer: CoreTextMeasurer()).layout(limited)
    let sized = try await SizeBudgetRenderer(renderer: renderer).render(snapshot: limited, plan: limitedPlan)
    #expect(sized.portraitQuality < SizeBudgetRenderer.normalQuality)
    #expect(sized.document.data.count <= limited.maximumPDFBytes)

    // A ceiling below anything achievable blocks export.
    let impossible = portraitSnapshot(portrait, limit: 10)
    let impossiblePlan = try LayoutEngine(measurer: CoreTextMeasurer()).layout(impossible)
    do {
        _ = try await SizeBudgetRenderer(renderer: renderer).render(snapshot: impossible, plan: impossiblePlan)
        Issue.record("Expected oversized export to be blocked")
    } catch EngineError.validation(let issues) {
        #expect(issues.first?.code == "pdf.size.exceeded")
    }
}
