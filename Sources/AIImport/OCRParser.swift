import CareerDomain
import Foundation

/// Deterministic Japanese résumé parser.
///
/// Turns recognized lines into review candidates only. It never infers a
/// missing date, employer, or qualification; a line without a recognizable
/// date and event keyword produces nothing.
public struct OCRParser: Sendable {
    public init() {}

    private enum Section {
        case education
        case employment
        case qualifications
    }

    private struct EducationDraft {
        var school: String
        var start: PartialDate?
        var end: PartialDate?
        var sources: [String]
        var confidence: Double
    }

    private struct EmploymentDraft {
        var employer: String
        var start: PartialDate?
        var end: PartialDate?
        var isCurrent: Bool
        var sources: [String]
        var confidence: Double
    }

    public func parse(_ lines: [RecognizedTextLine]) -> [ImportCandidate] {
        var candidates: [ImportCandidate] = []
        var section: Section?
        var education: [EducationDraft] = []
        var employment: [EmploymentDraft] = []
        var qualifications: [ImportCandidate] = []
        var sawName = false

        let ordered = lines.enumerated()
            .sorted { ($0.element.pageIndex, $0.offset) < ($1.element.pageIndex, $1.offset) }
            .map(\.element)

        for line in ordered {
            let text = line.text.precomposedStringWithCompatibilityMapping
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let compact = text.filter { !$0.isWhitespace }

            if !sawName, let name = Self.name(from: text) {
                sawName = true
                candidates.append(ImportCandidate(
                    value: .contactName(name),
                    sourceText: line.text,
                    confidence: line.confidence
                ))
                continue
            }

            switch compact {
            case "学歴":
                section = .education
                continue
            case "職歴":
                section = .employment
                continue
            case "免許・資格", "免許資格", "資格", "免許":
                section = .qualifications
                continue
            case "以上":
                section = nil
                continue
            default:
                break
            }

            guard let section else { continue }

            if section == .employment, compact.hasPrefix("現在に至る") {
                if let index = employment.lastIndex(where: { $0.end == nil && !$0.isCurrent }) {
                    employment[index].isCurrent = true
                    employment[index].sources.append(line.text)
                    employment[index].confidence = min(employment[index].confidence, line.confidence)
                }
                continue
            }

            guard let (date, rest) = Self.leadingDate(in: text) else { continue }

            switch section {
            case .education:
                Self.applyEducation(date: date, rest: rest, line: line, to: &education)
            case .employment:
                Self.applyEmployment(date: date, rest: rest, line: line, to: &employment)
            case .qualifications:
                let name = Self.strip(rest, suffixes: ["取得", "合格", "修了", "認定", "登録"])
                guard !name.isEmpty else { continue }
                qualifications.append(ImportCandidate(
                    value: .qualification(Qualification(name: name, awarded: date)),
                    sourceText: line.text,
                    confidence: line.confidence
                ))
            }
        }

        candidates.append(contentsOf: education.compactMap { draft in
            guard !draft.school.isEmpty else { return nil }
            return ImportCandidate(
                value: .education(Education(school: draft.school, start: draft.start, end: draft.end)),
                sourceText: draft.sources.joined(separator: "\n"),
                confidence: draft.confidence
            )
        })
        candidates.append(contentsOf: employment.compactMap { draft in
            guard !draft.employer.isEmpty else { return nil }
            return ImportCandidate(
                value: .employment(Employment(
                    employer: draft.employer,
                    start: draft.start,
                    end: draft.end,
                    isCurrent: draft.isCurrent
                )),
                sourceText: draft.sources.joined(separator: "\n"),
                confidence: draft.confidence
            )
        })
        candidates.append(contentsOf: qualifications)
        return candidates
    }

    // MARK: - Sections

    private static let educationStartKeywords = ["入学"]
    private static let educationEndKeywords = ["卒業見込み", "卒業見込", "卒業", "修了", "中退"]
    private static let employmentStartKeywords = ["入社", "入職"]
    private static let employmentEndKeywords = ["退社", "退職"]

    private static func applyEducation(
        date: PartialDate,
        rest: String,
        line: RecognizedTextLine,
        to drafts: inout [EducationDraft]
    ) {
        if endsWithAny(rest, educationStartKeywords) {
            let school = strip(rest, suffixes: educationStartKeywords)
            guard !school.isEmpty else { return }
            drafts.append(EducationDraft(
                school: school, start: date, end: nil,
                sources: [line.text], confidence: line.confidence
            ))
        } else if endsWithAny(rest, educationEndKeywords) {
            let school = strip(rest, suffixes: educationEndKeywords)
            guard !school.isEmpty else { return }
            if let index = drafts.lastIndex(where: { $0.school == school && $0.end == nil }) {
                drafts[index].end = date
                drafts[index].sources.append(line.text)
                drafts[index].confidence = min(drafts[index].confidence, line.confidence)
            } else {
                drafts.append(EducationDraft(
                    school: school, start: nil, end: date,
                    sources: [line.text], confidence: line.confidence
                ))
            }
        }
    }

    private static func applyEmployment(
        date: PartialDate,
        rest: String,
        line: RecognizedTextLine,
        to drafts: inout [EmploymentDraft]
    ) {
        if endsWithAny(rest, employmentStartKeywords) {
            let employer = strip(rest, suffixes: employmentStartKeywords)
            guard !employer.isEmpty else { return }
            drafts.append(EmploymentDraft(
                employer: employer, start: date, end: nil, isCurrent: false,
                sources: [line.text], confidence: line.confidence
            ))
        } else if endsWithAny(rest, employmentEndKeywords) {
            if let index = drafts.lastIndex(where: { $0.end == nil && !$0.isCurrent }) {
                drafts[index].end = date
                drafts[index].sources.append(line.text)
                drafts[index].confidence = min(drafts[index].confidence, line.confidence)
            }
        }
    }

    // MARK: - Text helpers

    private static func name(from text: String) -> String? {
        let compact = text.filter { !$0.isWhitespace }
        guard compact.hasPrefix("氏名") else { return nil }
        var value = String(text.drop(while: { $0.isWhitespace }).dropFirst(2))
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: ":：").union(.whitespacesAndNewlines))
        return value.isEmpty ? nil : value
    }

    private static func endsWithAny(_ text: String, _ suffixes: [String]) -> Bool {
        suffixes.contains { text.hasSuffix($0) }
    }

    private static func strip(_ text: String, suffixes: [String]) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in suffixes where value.hasSuffix(suffix) {
            value = String(value.dropLast(suffix.count))
            break
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let datePatternSource =
        "^\\s*(令和|平成|昭和)?\\s*(元|[0-9]{1,4})\\s*(?:年|/|\\.)\\s*(?:([0-9]{1,2})\\s*月?)?(?:\\s*([0-9]{1,2})\\s*日)?\\s*"

    /// Parses a leading Gregorian or Japanese-era date and returns it with the
    /// remaining text. Returns nil when no valid date starts the line.
    static func leadingDate(in text: String) -> (PartialDate, String)? {
        guard let pattern = try? NSRegularExpression(pattern: datePatternSource) else { return nil }
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        guard let match = pattern.firstMatch(in: text, range: full) else { return nil }

        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : nsText.substring(with: range)
        }

        guard let yearText = group(2) else { return nil }
        let rawYear = yearText == "元" ? 1 : Int(yearText)
        guard let rawYear else { return nil }

        let year: Int
        switch group(1) {
        case "令和": year = 2018 + rawYear
        case "平成": year = 1988 + rawYear
        case "昭和": year = 1925 + rawYear
        case nil:
            guard yearText != "元", yearText.count == 4 else { return nil }
            year = rawYear
        default: return nil
        }

        let month = group(3).flatMap { Int($0) }
        let day = group(4).flatMap { Int($0) }
        guard let date = try? PartialDate(year: year, month: month, day: month == nil ? nil : day) else {
            return nil
        }
        let rest = nsText.substring(from: match.range.location + match.range.length)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (date, rest)
    }
}
