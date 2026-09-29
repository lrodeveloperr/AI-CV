import CareerDomain
import Foundation

public struct RecognizedTextLine: Codable, Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let pageIndex: Int

    public init(text: String, confidence: Double, pageIndex: Int) {
        self.text = text
        self.confidence = confidence
        self.pageIndex = pageIndex
    }
}

public protocol TextRecognitionService: Sendable {
    func recognize(pages: [Data]) async throws -> [RecognizedTextLine]
}

public enum ImportCandidateValue: Codable, Equatable, Sendable {
    case contactName(String)
    case education(Education)
    case employment(Employment)
    case qualification(Qualification)
    case achievement(Achievement)
}

public enum ImportCandidateStatus: String, Codable, Equatable, Sendable {
    case pending
    case confirmed
    case rejected
}

public struct ImportCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let value: ImportCandidateValue
    public let sourceText: String
    public let confidence: Double
    public var status: ImportCandidateStatus

    public init(
        id: UUID = UUID(),
        value: ImportCandidateValue,
        sourceText: String,
        confidence: Double,
        status: ImportCandidateStatus = .pending
    ) {
        self.id = id
        self.value = value
        self.sourceText = sourceText
        self.confidence = confidence
        self.status = status
    }
}

public enum OCRImportState: String, Codable, Equatable, Sendable {
    case captured
    case recognized
    case reviewing
    case committed
    case canceled
}

public struct OCRImportSession: Codable, Equatable, Sendable {
    public let id: UUID
    public private(set) var state: OCRImportState
    public private(set) var candidates: [ImportCandidate]

    public init(id: UUID = UUID(), state: OCRImportState = .captured, candidates: [ImportCandidate] = []) {
        self.id = id
        self.state = state
        self.candidates = candidates
    }

    public mutating func receive(_ candidates: [ImportCandidate]) throws {
        guard state == .captured else {
            throw EngineError.invalidTransition("Recognition results can only follow capture")
        }
        self.candidates = candidates
        state = .recognized
    }

    public mutating func beginReview() throws {
        guard state == .recognized else {
            throw EngineError.invalidTransition("Review can only follow recognition")
        }
        state = .reviewing
    }

    public mutating func setStatus(_ status: ImportCandidateStatus, candidateID: UUID) throws {
        guard state == .reviewing else {
            throw EngineError.invalidTransition("Candidates can only change during review")
        }
        guard let index = candidates.firstIndex(where: { $0.id == candidateID }) else {
            throw EngineError.invalidInput("Import candidate does not exist")
        }
        candidates[index].status = status
    }

    public mutating func commit() throws -> [ImportCandidateValue] {
        guard state == .reviewing else {
            throw EngineError.invalidTransition("Import can only commit after review")
        }
        guard candidates.allSatisfy({ $0.status != .pending }) else {
            throw EngineError.invalidTransition("Every import candidate must be confirmed or rejected")
        }
        state = .committed
        return candidates.compactMap { $0.status == .confirmed ? $0.value : nil }
    }

    public mutating func cancel() throws {
        guard state != .committed else {
            throw EngineError.invalidTransition("A committed import cannot be canceled")
        }
        state = .canceled
        candidates.removeAll()
    }
}

public enum ImportMerger {
    public static func merging(_ values: [ImportCandidateValue], into original: CareerProfile) -> CareerProfile {
        var profile = original
        for value in values {
            switch value {
            case .contactName(let name):
                profile.contact.fullName = name
            case .education(let education):
                if !profile.education.contains(where: { $0.id == education.id }) {
                    profile.education.append(education)
                }
            case .employment(let employment):
                if !profile.employment.contains(where: { $0.id == employment.id }) {
                    profile.employment.append(employment)
                }
            case .qualification(let qualification):
                if !profile.qualifications.contains(where: { $0.id == qualification.id }) {
                    profile.qualifications.append(qualification)
                }
            case .achievement(let achievement):
                if !profile.achievements.contains(where: { $0.id == achievement.id }) {
                    profile.achievements.append(achievement)
                }
            }
        }
        return profile
    }
}
