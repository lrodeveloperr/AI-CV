import CareerDomain
import Foundation

public struct StoreProductInfo: Codable, Equatable, Sendable {
    public enum Period: String, Codable, Equatable, Sendable {
        case month
        case year
    }

    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let period: Period

    public init(id: String, displayName: String, displayPrice: String, period: Period) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.period = period
    }
}

public struct VerifiedSubscription: Codable, Equatable, Sendable {
    public enum RenewalState: String, Codable, Equatable, Sendable {
        case subscribed
        case gracePeriod
        case expired
        case revoked
    }

    public let productID: String
    public let expirationDate: Date?
    public let state: RenewalState

    public init(productID: String, expirationDate: Date?, state: RenewalState) {
        self.productID = productID
        self.expirationDate = expirationDate
        self.state = state
    }
}

public enum PurchaseOutcome: Equatable, Sendable {
    case purchased(VerifiedSubscription)
    case pending
    case canceled
}

public protocol PurchaseClient: Sendable {
    func products(for identifiers: Set<String>) async throws -> [StoreProductInfo]
    func currentSubscriptions() async throws -> [VerifiedSubscription]
    func purchase(productID: String) async throws -> PurchaseOutcome
}

public enum EntitlementResolver {
    public static func resolve(
        subscriptions: [VerifiedSubscription],
        recognizedProductIDs: Set<String>,
        now: Date
    ) -> SubscriptionStatus {
        let eligible = subscriptions.filter { subscription in
            guard recognizedProductIDs.contains(subscription.productID) else { return false }
            guard subscription.state != .revoked && subscription.state != .expired else { return false }
            return subscription.expirationDate.map { $0 > now } ?? true
        }
        guard !eligible.isEmpty else { return .free }

        let best = eligible.max { lhs, rhs in
            (lhs.expirationDate ?? .distantFuture) < (rhs.expirationDate ?? .distantFuture)
        }!
        if best.state == .gracePeriod {
            return .proGracePeriod(expiresAt: best.expirationDate)
        }
        return .proActive(expiresAt: best.expirationDate)
    }
}

public protocol EntitlementCache: Sendable {
    func load() async -> [VerifiedSubscription]
    func store(_ subscriptions: [VerifiedSubscription]) async
}

public actor InMemoryEntitlementCache: EntitlementCache {
    private var stored: [VerifiedSubscription]

    public init(_ initial: [VerifiedSubscription] = []) {
        self.stored = initial
    }

    public func load() async -> [VerifiedSubscription] { stored }
    public func store(_ subscriptions: [VerifiedSubscription]) async { stored = subscriptions }
}

public actor PurchaseEngine {
    public static let monthlyProductID = "com.worksbienstudios.rirekishoai.pro.monthly"
    public static let annualProductID = "com.worksbienstudios.rirekishoai.pro.annual"
    public static let productIDs: Set<String> = [monthlyProductID, annualProductID]

    private let client: any PurchaseClient
    private let cache: (any EntitlementCache)?
    private var verified: [VerifiedSubscription] = []
    public private(set) var products: [StoreProductInfo] = []
    public private(set) var entitlement: SubscriptionStatus = .free

    public init(client: any PurchaseClient, cache: (any EntitlementCache)? = nil) {
        self.client = client
        self.cache = cache
    }

    /// Presents the last verified entitlement for fast launch. StoreKit
    /// reconciliation via `refresh` remains authoritative.
    @discardableResult
    public func restoreFromCache(now: Date) async -> SubscriptionStatus {
        if let cache {
            verified = await cache.load()
            entitlement = EntitlementResolver.resolve(
                subscriptions: verified,
                recognizedProductIDs: Self.productIDs,
                now: now
            )
        }
        return entitlement
    }

    /// An unavailable App Store never erases an entitlement that was already
    /// verified: on failure the current state is kept and the error rethrown.
    @discardableResult
    public func refresh(now: Date) async throws -> SubscriptionStatus {
        if let loaded = try? await client.products(for: Self.productIDs) {
            products = loaded.sorted { $0.id < $1.id }
        }
        let current = try await client.currentSubscriptions()
        await commit(current, now: now)
        return entitlement
    }

    public func purchase(productID: String, now: Date) async throws -> PurchaseOutcome {
        guard Self.productIDs.contains(productID) else {
            throw EngineError.invalidInput("Unknown subscription product")
        }
        let outcome = try await client.purchase(productID: productID)
        if case .purchased(let subscription) = outcome {
            let others = verified.filter { $0.productID != subscription.productID }
            await commit(others + [subscription], now: now)
        }
        return outcome
    }

    public func ingest(_ subscriptions: [VerifiedSubscription], now: Date) async {
        await commit(subscriptions, now: now)
    }

    private func commit(_ subscriptions: [VerifiedSubscription], now: Date) async {
        verified = subscriptions
        entitlement = EntitlementResolver.resolve(
            subscriptions: subscriptions,
            recognizedProductIDs: Self.productIDs,
            now: now
        )
        await cache?.store(subscriptions)
    }
}
