#if canImport(FoundationModels)
import CareerDomain
import Foundation
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
@Generable
struct DraftSuggestion {
    @Guide(description: "Japanese application text; do not add facts")
    var proposedText: String

    @Guide(description: "IDs of supplied facts used in the proposal")
    var citedFactIDs: [String]
}

@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelAvailability: AIAvailabilityProviding {
    public init() {}

    public func availability() async -> AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(reason: "This device does not support Apple Intelligence")
            case .appleIntelligenceNotEnabled:
                return .unavailable(reason: "Apple Intelligence is turned off in Settings")
            case .modelNotReady:
                return .unavailable(reason: "The on-device model is still downloading")
            @unknown default:
                return .unavailable(reason: "The on-device model is unavailable")
            }
        }
    }
}

/// Creates one `LanguageModelSession` per writing task. Output is only a
/// proposal; `AIWritingCoordinator` serializes requests and validates results.
@available(iOS 26.0, macOS 26.0, *)
public struct FoundationModelWritingService: AIWritingService {
    public init() {}

    public func generate(_ request: AIWritingRequest) async throws -> AIWritingDraft {
        let session = LanguageModelSession(instructions: AIPromptBuilder.instructions)
        do {
            let response = try await session.respond(
                to: AIPromptBuilder.prompt(for: request),
                generating: DraftSuggestion.self
            )
            let suggestion = response.content
            return AIWritingDraft(
                proposedText: suggestion.proposedText,
                citedFactIDs: Set(suggestion.citedFactIDs.compactMap { UUID(uuidString: $0) })
            )
        } catch is CancellationError {
            throw EngineError.canceled
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                throw EngineError.invalidInput("The request is too long for the on-device model")
            case .guardrailViolation:
                throw EngineError.unavailable("The on-device model declined this request")
            default:
                throw EngineError.unavailable("The on-device model could not complete the request")
            }
        }
    }
}
#endif
