import AIImport
import CareerDomain
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import Testing

@Test func aiSuggestionAcceptsOnlySuppliedFactsAndNumbers() throws {
    let factID = UUID()
    let request = AIWritingRequest(
        field: .selfPromotion,
        operation: .draft,
        facts: [.init(id: factID, label: "Achievement", value: "Reduced processing time by 30 percent")],
        maximumCharacters: 200
    )
    let draft = AIWritingDraft(
        proposedText: "Processing time was reduced by 30 percent.",
        citedFactIDs: [factID]
    )
    let narrative = try AIWritingValidator().validate(draft, against: request, acceptedAt: Date())
    #expect(narrative.citedFactIDs == [factID])
}

@Test func aiSuggestionRejectsInventedMetric() {
    let factID = UUID()
    let request = AIWritingRequest(
        field: .selfPromotion,
        operation: .draft,
        facts: [.init(id: factID, label: "Achievement", value: "Improved processing")],
        maximumCharacters: 200
    )
    let draft = AIWritingDraft(
        proposedText: "Improved processing by 50 percent.",
        citedFactIDs: [factID]
    )
    do {
        _ = try AIWritingValidator().validate(draft, against: request, acceptedAt: Date())
        Issue.record("Expected an unsupported number to be rejected")
    } catch {
        #expect(error as? EngineError == .invalidInput("AI suggestion introduced an unsupported number"))
    }
}

@Test func ocrCandidatesRequireExplicitDispositionBeforeCommit() throws {
    let candidate = ImportCandidate(
        value: .contactName("Candidate"),
        sourceText: "Candidate",
        confidence: 0.99
    )
    var session = OCRImportSession()
    try session.receive([candidate])
    try session.beginReview()

    do {
        _ = try session.commit()
        Issue.record("Expected pending candidate to block import")
    } catch {
        #expect(error as? EngineError == .invalidTransition("Every import candidate must be confirmed or rejected"))
    }

    try session.setStatus(.confirmed, candidateID: candidate.id)
    let values = try session.commit()
    #expect(values == [.contactName("Candidate")])
    #expect(session.state == .committed)
}


// MARK: - OCR parser

private func line(_ text: String, page: Int = 0, confidence: Double = 0.9) -> RecognizedTextLine {
    RecognizedTextLine(text: text, confidence: confidence, pageIndex: page)
}

@Test func ocrParserExtractsEducationEmploymentAndQualifications() throws {
    let candidates = OCRParser().parse([
        line("氏名 山田 太郎"),
        line("学歴"),
        line("平成22年4月 東京大学 入学"),
        line("平成26年3月 東京大学 卒業"),
        line("職歴"),
        line("平成26年4月 株式会社サンプル 入社"),
        line("令和元年9月 一身上の都合により退職"),
        line("令和2年1月 合同会社テスト 入社"),
        line("現在に至る"),
        line("免許・資格"),
        line("2018年6月 普通自動車第一種運転免許 取得"),
        line("以上")
    ])

    #expect(candidates.count == 5)
    #expect(candidates.allSatisfy { $0.status == .pending })

    guard case .contactName(let name) = candidates[0].value else { Issue.record("name"); return }
    #expect(name == "山田 太郎")

    guard case .education(let education) = candidates[1].value else { Issue.record("education"); return }
    #expect(education.school == "東京大学")
    #expect(education.start == (try PartialDate(year: 2010, month: 4)))
    #expect(education.end == (try PartialDate(year: 2014, month: 3)))

    guard case .employment(let first) = candidates[2].value else { Issue.record("employment 1"); return }
    #expect(first.employer == "株式会社サンプル")
    #expect(first.end == (try PartialDate(year: 2019, month: 9)))
    #expect(!first.isCurrent)

    guard case .employment(let second) = candidates[3].value else { Issue.record("employment 2"); return }
    #expect(second.employer == "合同会社テスト")
    #expect(second.start == (try PartialDate(year: 2020, month: 1)))
    #expect(second.end == nil)
    #expect(second.isCurrent)

    guard case .qualification(let qualification) = candidates[4].value else { Issue.record("qualification"); return }
    #expect(qualification.name == "普通自動車第一種運転免許")
    #expect(qualification.awarded == (try PartialDate(year: 2018, month: 6)))
}

@Test func ocrParserNeverInventsMissingDatesOrEmployers() {
    let candidates = OCRParser().parse([
        line("職歴"),
        line("株式会社サンプル 入社"),
        line("令和3年4月 入社"),
        line("学歴"),
        line("東京大学 卒業")
    ])
    #expect(candidates.isEmpty)
}

@Test func ocrParserHandlesFullWidthDigitsAndMissingEnrollment() throws {
    let candidates = OCRParser().parse([
        line("学歴"),
        line("２０１４年３月 大阪高校 卒業")
    ])
    #expect(candidates.count == 1)
    guard case .education(let education) = candidates[0].value else { Issue.record("education"); return }
    #expect(education.start == nil)
    #expect(education.end == (try PartialDate(year: 2014, month: 3)))
}

// MARK: - AI coordinator

private struct StubAvailability: AIAvailabilityProviding {
    let value: AIAvailability
    func availability() async -> AIAvailability { value }
}

private struct SlowService: AIWritingService {
    let draft: AIWritingDraft
    func generate(_ request: AIWritingRequest) async throws -> AIWritingDraft {
        try await Task.sleep(nanoseconds: 300_000_000)
        return draft
    }
}

private func sampleRequest(factID: UUID) -> AIWritingRequest {
    AIWritingRequest(
        field: .selfPromotion,
        operation: .draft,
        facts: [.init(id: factID, label: "Achievement", value: "Improved processing")],
        maximumCharacters: 200
    )
}

@Test func coordinatorRejectsWhenModelUnavailable() async {
    let factID = UUID()
    let coordinator = AIWritingCoordinator(
        service: SlowService(draft: .init(proposedText: "Improved processing.", citedFactIDs: [factID])),
        availability: StubAvailability(value: .unavailable(reason: "Model not ready"))
    )
    do {
        _ = try await coordinator.propose(sampleRequest(factID: factID), now: Date())
        Issue.record("Expected unavailable error")
    } catch {
        #expect(error as? EngineError == .unavailable("Model not ready"))
    }
}

@Test func coordinatorRejectsConcurrentRequestsAndValidatesOutput() async throws {
    let factID = UUID()
    let coordinator = AIWritingCoordinator(
        service: SlowService(draft: .init(proposedText: "Improved processing.", citedFactIDs: [factID])),
        availability: StubAvailability(value: .available)
    )
    let request = sampleRequest(factID: factID)
    async let first = coordinator.propose(request, now: Date())
    try await Task.sleep(nanoseconds: 50_000_000)
    do {
        _ = try await coordinator.propose(request, now: Date())
        Issue.record("Expected concurrent request to be rejected")
    } catch {
        #expect(error as? EngineError == .invalidTransition("A writing request is already in progress"))
    }
    let narrative = try await first
    #expect(narrative.citedFactIDs == [factID])
    #expect(await coordinator.isGenerating == false)
}

@Test func coordinatorCancellationSurfacesCanceled() async throws {
    let factID = UUID()
    let coordinator = AIWritingCoordinator(
        service: SlowService(draft: .init(proposedText: "Improved processing.", citedFactIDs: [factID])),
        availability: StubAvailability(value: .available)
    )
    let request = sampleRequest(factID: factID)
    async let pending = coordinator.propose(request, now: Date())
    try await Task.sleep(nanoseconds: 50_000_000)
    await coordinator.cancelCurrent()
    do {
        _ = try await pending
        Issue.record("Expected cancellation")
    } catch {
        #expect(error as? EngineError == .canceled)
    }
}

// MARK: - Language check

@Test func japaneseFieldRejectsNonJapaneseOutput() throws {
    let factID = UUID()
    let request = sampleRequest(factID: factID)
    let validator = AIWritingValidator(requiredScript: .japanese(minimumRatio: 0.5))

    let english = AIWritingDraft(proposedText: "Improved processing.", citedFactIDs: [factID])
    do {
        _ = try validator.validate(english, against: request, acceptedAt: Date())
        Issue.record("Expected non-Japanese text to be rejected")
    } catch {
        #expect(error as? EngineError == .invalidInput("AI suggestion is not in the required language"))
    }

    let japanese = AIWritingDraft(proposedText: "業務の処理を改善しました。", citedFactIDs: [factID])
    let narrative = try validator.validate(japanese, against: request, acceptedAt: Date())
    #expect(narrative.text == "業務の処理を改善しました。")
}

@Test func japaneseCheckToleratesMixedLatinTerms() throws {
    let factID = UUID()
    let draft = AIWritingDraft(proposedText: "Swiftを用いたアプリ開発を担当しました。", citedFactIDs: [factID])
    _ = try AIWritingValidator(requiredScript: .japanese(minimumRatio: 0.5))
        .validate(draft, against: sampleRequest(factID: factID), acceptedAt: Date())
}


// MARK: - Prompt packet

@Test func promptContainsOnlySuppliedFactsAndLimits() {
    let factID = UUID()
    let request = AIWritingRequest(
        field: .motivation,
        operation: .shorten,
        facts: [.init(id: factID, label: "Employer", value: "株式会社サンプル")],
        existingText: "既存の文章",
        vacancyText: "募集要項",
        maximumCharacters: 120
    )
    let prompt = AIPromptBuilder.prompt(for: request)
    #expect(prompt.contains("[\(factID.uuidString)] Employer: 株式会社サンプル"))
    #expect(prompt.contains("Maximum length: 120 characters"))
    #expect(prompt.contains("既存の文章"))
    #expect(prompt.contains("募集要項"))
    #expect(AIPromptBuilder.instructions.contains("Do not add, change, or guess facts"))
}

@Test func promptOmitsAbsentOptionalSections() {
    let request = AIWritingRequest(field: .selfPromotion, operation: .draft, facts: [], maximumCharacters: 50)
    let prompt = AIPromptBuilder.prompt(for: request)
    #expect(!prompt.contains("Existing text"))
    #expect(!prompt.contains("Vacancy text"))
}

// MARK: - Vision adapter

private func textImagePNG(_ text: String) -> Data {
    let width = 1_200, height = 300
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(gray: 0, alpha: 1)
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 120, nil)
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font
    ])
    let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
    context.textPosition = CGPoint(x: 40, y: 100)
    CTLineDraw(line, context)
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return output as Data
}

#if canImport(Vision)
@Test func visionServiceRecognizesTextWithConfidenceAndBoundingBox() async throws {
    let lines = try await VisionTextRecognitionService().recognize(pages: [textImagePNG("RESUME 2020")])
    let joined = lines.map(\.text).joined(separator: " ").uppercased()
    #expect(joined.contains("RESUME"))
    let first = try #require(lines.first)
    #expect(first.pageIndex == 0)
    #expect(first.confidence > 0)
    #expect(first.boundingBox != nil)
}

@Test func visionServiceTagsEachPageIndex() async throws {
    let lines = try await VisionTextRecognitionService().recognize(
        pages: [textImagePNG("FIRST"), textImagePNG("SECOND")]
    )
    #expect(lines.contains { $0.pageIndex == 0 })
    #expect(lines.contains { $0.pageIndex == 1 })
}

@Test func visionServiceRejectsUnreadableImage() async {
    do {
        _ = try await VisionTextRecognitionService().recognize(pages: [Data([1, 2, 3])])
        Issue.record("Expected an unreadable page to fail")
    } catch {
        #expect(error as? EngineError == .unavailable("Text recognition could not process the page"))
    }
}
#endif
