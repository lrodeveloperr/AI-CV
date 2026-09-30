import Foundation

/// Builds the minimal prompt packet for a writing task. Pure and deterministic
/// so it can be tested without a model.
public enum AIPromptBuilder {
    public static let instructions = """
    You draft Japanese job-application text. Use only the facts supplied. \
    Do not add, change, or guess facts, dates, employers, schools, qualifications, \
    numbers, metrics, or outcomes. Write in natural Japanese. \
    Report the IDs of the supplied facts you used.
    """

    public static func prompt(for request: AIWritingRequest) -> String {
        var lines: [String] = []
        lines.append("Operation: \(operationText(request.operation))")
        lines.append("Target field: \(fieldText(request.field))")
        lines.append("Maximum length: \(request.maximumCharacters) characters")
        lines.append("Facts:")
        for fact in request.facts {
            lines.append("- [\(fact.id.uuidString)] \(fact.label): \(fact.value)")
        }
        if let existing = request.existingText, !existing.isEmpty {
            lines.append("Existing text:\n\(existing)")
        }
        if let vacancy = request.vacancyText, !vacancy.isEmpty {
            lines.append("Vacancy text supplied by the user:\n\(vacancy)")
        }
        return lines.joined(separator: "\n")
    }

    private static func operationText(_ operation: WritingOperation) -> String {
        switch operation {
        case .draft: "draft new text"
        case .shorten: "shorten the existing text"
        case .expand: "expand the existing text"
        case .changeTone: "change the tone of the existing text"
        case .tailor: "tailor the text to the vacancy"
        }
    }

    private static func fieldText(_ field: NarrativeField) -> String {
        switch field {
        case .selfPromotion: "self-promotion"
        case .motivation: "motivation"
        case .careerSummary: "career summary"
        case .employmentSummary: "employment summary"
        }
    }
}
