import CareerDomain
import Foundation
import Testing

@Test func japaneseEraBoundariesAreDeterministic() throws {
    let lastHeisei = try JapaneseEraDate(era: .heisei, year: 31, month: 4, day: 30)
    let firstReiwa = try JapaneseEraDate(era: .reiwa, year: 1, month: 5, day: 1)
    #expect(try lastHeisei.gregorian == PartialDate(year: 2019, month: 4, day: 30))
    #expect(try firstReiwa.gregorian == PartialDate(year: 2019, month: 5, day: 1))
    #expect(firstReiwa.displayString == "令和元年5月1日")

    do {
        _ = try JapaneseEraDate(era: .reiwa, year: 1, month: 4, day: 30)
        Issue.record("Expected a pre-Reiwa date to be rejected")
    } catch {
        #expect(error as? EngineError == .invalidInput("Date is outside the selected Japanese era"))
    }
}

@Test func validatorRejectsChronologyAndCurrentRoleEndDate() throws {
    let employment = Employment(
        employer: "Example",
        start: try PartialDate(year: 2025, month: 1),
        end: try PartialDate(year: 2024, month: 12),
        isCurrent: true
    )
    let profile = CareerProfile(
        contact: ContactDetails(fullName: "Candidate"),
        employment: [employment]
    )
    let codes = Set(CareerValidator.validate(profile).map(\.code))
    #expect(codes.contains("employment.date.order"))
    #expect(codes.contains("employment.current.has-end"))
}

@Test func freeAndProEntitlementsMatchTheContract() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let free = FeatureGate(subscription: .free, now: now)
    let emptyUsage = UsageLedger()
    #expect(free.canCreate(.resume, existing: []))
    #expect(!free.canCreate(.coverLetter, existing: []))
    #expect(free.allows(.exportPDF, usage: emptyUsage))
    #expect(!free.allows(.nativeAI, usage: emptyUsage))
    #expect(!free.allows(.privateSync, usage: emptyUsage))

    let pro = FeatureGate(subscription: .proActive(expiresAt: now.addingTimeInterval(60)), now: now)
    #expect(pro.canCreate(.coverLetter, existing: []))
    #expect(pro.allows(.nativeAI, usage: emptyUsage))
    #expect(pro.allows(.privateSync, usage: emptyUsage))
}

@Test func exportLedgerIsIdempotent() {
    var ledger = UsageLedger()
    let operationID = UUID()
    #expect(ledger.recordCompletedExport(operationID: operationID))
    #expect(!ledger.recordCompletedExport(operationID: operationID))
    #expect(ledger.completedExportCount == 1)
}

@Test func narrativeCannotCiteUnconfirmedFacts() {
    let fact = Achievement(text: "Reduced processing time", isConfirmed: false)
    let profile = CareerProfile(
        contact: ContactDetails(fullName: "Candidate"),
        achievements: [fact]
    )
    let narrative = Narrative(
        field: .selfPromotion,
        text: "Improved processing",
        citedFactIDs: [fact.id],
        acceptedAt: Date()
    )
    let document = DocumentRecord(
        kind: .resume,
        title: "Resume",
        narratives: [narrative],
        createdAt: Date(),
        modifiedAt: Date()
    )
    let issues = CareerValidator.validate(document, against: profile)
    #expect(issues.map(\.code).contains("narrative.unconfirmed-fact"))
}

