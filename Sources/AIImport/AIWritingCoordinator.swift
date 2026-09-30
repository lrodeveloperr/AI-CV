import CareerDomain
import Foundation

public enum AIAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

public protocol AIAvailabilityProviding: Sendable {
    func availability() async -> AIAvailability
}

/// Serializes writing requests so only one uses the model at a time, and
/// passes every result through deterministic validation before it can become
/// a narrative proposal. The result is never written to the canonical profile.
public actor AIWritingCoordinator {
    private let service: any AIWritingService
    private let availability: any AIAvailabilityProviding
    private let validator: AIWritingValidator
    private var current: (id: UUID, task: Task<AIWritingDraft, Error>)?

    public init(
        service: any AIWritingService,
        availability: any AIAvailabilityProviding,
        validator: AIWritingValidator = AIWritingValidator()
    ) {
        self.service = service
        self.availability = availability
        self.validator = validator
    }

    public var isGenerating: Bool { current != nil }

    public func propose(_ request: AIWritingRequest, now: Date) async throws -> Narrative {
        if case .unavailable(let reason) = await availability.availability() {
            throw EngineError.unavailable(reason)
        }
        guard current == nil else {
            throw EngineError.invalidTransition("A writing request is already in progress")
        }

        let id = UUID()
        let service = self.service
        let task = Task { try await service.generate(request) }
        current = (id, task)
        defer { if current?.id == id { current = nil } }

        let draft: AIWritingDraft
        do {
            draft = try await task.value
        } catch is CancellationError {
            throw EngineError.canceled
        }
        if task.isCancelled { throw EngineError.canceled }
        return try validator.validate(draft, against: request, acceptedAt: now)
    }

    public func cancelCurrent() {
        current?.task.cancel()
        current = nil
    }
}
