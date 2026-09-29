import AIImport
import CareerDomain
import Foundation
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

