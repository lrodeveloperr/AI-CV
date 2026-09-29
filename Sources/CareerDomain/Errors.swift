import Foundation

public struct ValidationIssue: Codable, Equatable, Sendable {
    public enum Severity: String, Codable, Equatable, Sendable {
        case warning
        case blocking
    }

    public let code: String
    public let message: String
    public let path: String
    public let severity: Severity

    public init(code: String, message: String, path: String, severity: Severity) {
        self.code = code
        self.message = message
        self.path = path
        self.severity = severity
    }
}

public enum EngineError: Error, Equatable, Sendable {
    case invalidInput(String)
    case validation([ValidationIssue])
    case conflict(expected: Int, actual: Int)
    case entitlementRequired(Feature)
    case unavailable(String)
    case invalidTransition(String)
    case incompatibleSchema(Int)
    case corruptData(String)
    case canceled
    case internalFailure(String)
}
