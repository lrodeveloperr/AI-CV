import CareerDomain
import Foundation

public struct FactReference: Codable, Equatable, Sendable {
    public let id: UUID
    public let label: String
    public let value: String

    public init(id: UUID, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public enum WritingOperation: String, Codable, Equatable, Sendable {
    case draft
    case shorten
    case expand
    case changeTone
    case tailor
}

public struct AIWritingRequest: Codable, Equatable, Sendable {
    public let field: NarrativeField
    public let operation: WritingOperation
    public let facts: [FactReference]
    public let existingText: String?
    public let vacancyText: String?
    public let maximumCharacters: Int

    public init(
        field: NarrativeField,
        operation: WritingOperation,
        facts: [FactReference],
        existingText: String? = nil,
        vacancyText: String? = nil,
        maximumCharacters: Int
    ) {
        self.field = field
        self.operation = operation
        self.facts = facts
        self.existingText = existingText
        self.vacancyText = vacancyText
        self.maximumCharacters = maximumCharacters
    }
}

public struct AIWritingDraft: Codable, Equatable, Sendable {
    public let proposedText: String
    public let citedFactIDs: Set<UUID>

    public init(proposedText: String, citedFactIDs: Set<UUID>) {
        self.proposedText = proposedText
        self.citedFactIDs = citedFactIDs
    }
}

public protocol AIWritingService: Sendable {
    func generate(_ request: AIWritingRequest) async throws -> AIWritingDraft
}

public struct AIWritingValidator: Sendable {
    public init() {}

    public func validate(
        _ draft: AIWritingDraft,
        against request: AIWritingRequest,
        acceptedAt: Date
    ) throws -> Narrative {
        let text = draft.proposedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw EngineError.invalidInput("AI suggestion is empty")
        }
        guard text.count <= request.maximumCharacters else {
            throw EngineError.invalidInput("AI suggestion exceeds the field limit")
        }
        let allowedIDs = Set(request.facts.map(\.id))
        guard draft.citedFactIDs.isSubset(of: allowedIDs) else {
            throw EngineError.invalidInput("AI suggestion cites an unavailable fact")
        }

        let permittedText = request.facts.map(\.value).joined(separator: " ")
            + " " + (request.existingText ?? "")
            + " " + (request.vacancyText ?? "")
        let permittedNumbers = Self.numericTokens(in: permittedText)
        let generatedNumbers = Self.numericTokens(in: text)
        guard generatedNumbers.isSubset(of: permittedNumbers) else {
            throw EngineError.invalidInput("AI suggestion introduced an unsupported number")
        }

        return Narrative(
            field: request.field,
            text: text,
            citedFactIDs: draft.citedFactIDs,
            acceptedAt: acceptedAt
        )
    }

    static func numericTokens(in text: String) -> Set<String> {
        let normalized = text.precomposedStringWithCompatibilityMapping
        var result: Set<String> = []
        var current = ""
        for scalar in normalized.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) || scalar == "." || scalar == "," {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                result.insert(current.trimmingCharacters(in: CharacterSet(charactersIn: ",.")))
                current = ""
            }
        }
        if !current.isEmpty {
            result.insert(current.trimmingCharacters(in: CharacterSet(charactersIn: ",.")))
        }
        return Set(result.filter { !$0.isEmpty })
    }
}
