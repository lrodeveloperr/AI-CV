import CareerDomain
import Foundation

public struct DocumentComposer: Sendable {
    public init() {}

    public func compose(
        profile: CareerProfile,
        document: DocumentRecord,
        application: JobApplication? = nil,
        maximumPDFBytes: Int,
        portraitBytes: Int = 0,
        createdAt: Date
    ) throws -> DocumentSnapshot {
        let issues = CareerValidator.validate(profile)
            + CareerValidator.validate(document, against: profile)
        let blocking = issues.filter { $0.severity == .blocking }
        guard blocking.isEmpty else { throw EngineError.validation(blocking) }
        guard maximumPDFBytes > 0 else {
            throw EngineError.invalidInput("PDF size limit must be positive")
        }

        let fields: [DocumentField]
        switch document.kind {
        case .resume:
            fields = resumeFields(profile: profile, document: document)
        case .workHistory:
            fields = workHistoryFields(profile: profile, document: document)
        case .coverLetter:
            fields = coverLetterFields(profile: profile, document: document, application: application)
        }

        return DocumentSnapshot(
            documentID: document.id,
            kind: document.kind,
            templateID: document.templateID,
            fields: fields,
            maximumPDFBytes: maximumPDFBytes,
            portraitBytes: portraitBytes,
            createdAt: createdAt
        )
    }

    private func resumeFields(profile: CareerProfile, document: DocumentRecord) -> [DocumentField] {
        var fields = identityAndContactFields(profile)
        fields.append(contentsOf: profile.education.map { item in
            .init(
                id: "education.\(item.id.uuidString)",
                section: .education,
                text: [dateRange(item.start, item.end, style: document.dateStyle), item.school, item.course]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  "),
                keepTogether: true
            )
        })
        fields.append(contentsOf: profile.employment.map { item in
            .init(
                id: "employment.\(item.id.uuidString)",
                section: .employment,
                text: [dateRange(item.start, item.isCurrent ? nil : item.end, style: document.dateStyle), item.employer, item.title]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  "),
                keepTogether: true
            )
        })
        fields.append(contentsOf: profile.qualifications.map { item in
            .init(
                id: "qualification.\(item.id.uuidString)",
                section: .qualifications,
                text: [dateText(item.awarded, style: document.dateStyle), item.name, item.issuer]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  "),
                keepTogether: true
            )
        })
        fields.append(contentsOf: narrativeFields(document, matching: [.motivation, .selfPromotion]))
        return fields
    }

    private func workHistoryFields(profile: CareerProfile, document: DocumentRecord) -> [DocumentField] {
        var fields = identityAndContactFields(profile)
        fields.append(contentsOf: narrativeFields(document, matching: [.careerSummary]))
        for item in profile.employment {
            let responsibilities = item.responsibilities.map { "• \($0)" }.joined(separator: "\n")
            let text = [
                dateRange(item.start, item.isCurrent ? nil : item.end, style: document.dateStyle),
                item.employer,
                item.title,
                responsibilities
            ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
            fields.append(.init(
                id: "employment.\(item.id.uuidString)",
                section: .employment,
                text: text,
                style: TextStyle(spacingBefore: 6, spacingAfter: 8),
                keepTogether: false
            ))
            fields.append(contentsOf: narrativeFields(document, matching: [.employmentSummary(item.id)]))
        }
        fields.append(contentsOf: narrativeFields(document, matching: [.selfPromotion]))
        return fields
    }

    private func coverLetterFields(
        profile: CareerProfile,
        document: DocumentRecord,
        application: JobApplication?
    ) -> [DocumentField] {
        var fields = identityAndContactFields(profile)
        if let application {
            fields.append(.init(
                id: "application.\(application.id.uuidString)",
                section: .application,
                text: "\(application.company)  \(application.role)",
                isRequired: true,
                keepTogether: true
            ))
        }
        fields.append(contentsOf: narrativeFields(document, matching: [.motivation]))
        return fields
    }

    private func identityAndContactFields(_ profile: CareerProfile) -> [DocumentField] {
        [
            .init(id: "identity.name", section: .identity, text: profile.contact.fullName, style: TextStyle(fontSize: 16, lineHeight: 22, spacingAfter: 8), isRequired: true, keepTogether: true),
            .init(
                id: "contact.primary",
                section: .contact,
                text: [profile.contact.postalCode, profile.contact.address, profile.contact.phone, profile.contact.email]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  "),
                keepTogether: true
            )
        ]
    }

    private func narrativeFields(_ document: DocumentRecord, matching fields: [NarrativeField]) -> [DocumentField] {
        document.narratives
            .filter { fields.contains($0.field) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { narrative in
                .init(
                    id: "narrative.\(narrative.id.uuidString)",
                    section: .narrative,
                    text: narrative.text,
                    style: TextStyle(spacingBefore: 6, spacingAfter: 8),
                    keepTogether: false
                )
            }
    }

    private func dateRange(_ start: PartialDate?, _ end: PartialDate?, style: DateDisplayStyle) -> String? {
        guard start != nil || end != nil else { return nil }
        return "\(dateText(start, style: style) ?? "")–\(dateText(end, style: style) ?? "現在")"
    }

    private func dateText(_ date: PartialDate?, style: DateDisplayStyle) -> String? {
        guard let date else { return nil }
        switch style {
        case .gregorian:
            return Self.gregorianText(date)
        case .japaneseEra:
            guard let month = date.month else { return "\(date.year)年" }
            let day = date.day ?? 1
            guard let complete = try? PartialDate(year: date.year, month: month, day: day),
                  let era = try? JapaneseEraDate(gregorian: complete) else {
                return Self.gregorianText(date)
            }
            let eraYear = era.year == 1 ? "元" : String(era.year)
            if let actualDay = date.day {
                return "\(era.era.japaneseName)\(eraYear)年\(month)月\(actualDay)日"
            }
            return "\(era.era.japaneseName)\(eraYear)年\(month)月"
        }
    }

    private static func gregorianText(_ date: PartialDate) -> String {
        if let month = date.month, let day = date.day {
            return "\(date.year)年\(month)月\(day)日"
        }
        if let month = date.month {
            return "\(date.year)年\(month)月"
        }
        return "\(date.year)年"
    }
}
