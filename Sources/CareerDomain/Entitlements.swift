import Foundation

public enum Feature: String, Codable, CaseIterable, Hashable, Sendable {
    case createResume
    case createWorkHistory
    case createCoverLetter
    case exportPDF
    case nativeAI
    case ocrImport
    case applicationTracking
    case versionHistory
    case photoCleanup
    case privateSync
}

public enum SubscriptionStatus: Codable, Equatable, Sendable {
    case free
    case proActive(expiresAt: Date?)
    case proGracePeriod(expiresAt: Date?)

    public func grantsPro(at date: Date) -> Bool {
        switch self {
        case .free:
            false
        case .proActive(let expiry), .proGracePeriod(let expiry):
            expiry.map { $0 > date } ?? true
        }
    }
}

public struct UsageLedger: Codable, Equatable, Sendable {
    public private(set) var completedExportOperationIDs: Set<UUID>

    public init(completedExportOperationIDs: Set<UUID> = []) {
        self.completedExportOperationIDs = completedExportOperationIDs
    }

    public var completedExportCount: Int { completedExportOperationIDs.count }

    @discardableResult
    public mutating func recordCompletedExport(operationID: UUID) -> Bool {
        completedExportOperationIDs.insert(operationID).inserted
    }
}

public struct FeatureGate: Sendable {
    public let subscription: SubscriptionStatus
    public let now: Date

    public init(subscription: SubscriptionStatus, now: Date) {
        self.subscription = subscription
        self.now = now
    }

    public var isPro: Bool { subscription.grantsPro(at: now) }

    public func canCreate(_ kind: DocumentKind, existing: [DocumentRecord]) -> Bool {
        if isPro { return true }
        return switch kind {
        case .resume:
            existing.filter { $0.kind == .resume }.isEmpty
        case .workHistory:
            existing.filter { $0.kind == .workHistory }.isEmpty
        case .coverLetter:
            false
        }
    }

    public func allows(_ feature: Feature, usage: UsageLedger) -> Bool {
        if isPro { return true }
        return switch feature {
        case .createResume, .createWorkHistory:
            true
        case .exportPDF:
            usage.completedExportCount < 1
        case .createCoverLetter, .nativeAI, .ocrImport, .applicationTracking,
             .versionHistory, .photoCleanup, .privateSync:
            false
        }
    }
}
