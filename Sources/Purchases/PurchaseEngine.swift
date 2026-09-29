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

public actor PurchaseEngine {
    public static let monthlyProductID = "com.worksbienstudios.rirekishoai.pro.monthly"
    public static let annualProductID = "com.worksbienstudios.rirekishoai.pro.annual"
    public static let productIDs: Set<String> = [monthlyProductID, annualProductID]

    private let client: any PurchaseClient
    public private(set) var products: [StoreProductInfo] = []
    public private(set) var entitlement: SubscriptionStatus = .free

    public init(client: any PurchaseClient) {
        self.client = client
    }

    @discardableResult
    public func refresh(now: Date) async throws -> SubscriptionStatus {
        async let loadedProducts = client.products(for: Self.productIDs)
        async let subscriptions = client.currentSubscriptions()
        let (products, current) = try await (loadedProducts, subscriptions)
        self.products = products.sorted { $0.id < $1.id }
        entitlement = EntitlementResolver.resolve(
            subscriptions: current,
            recognizedProductIDs: Self.productIDs,
            now: now
        )
        return entitlement
    }

    public func purchase(productID: String, now: Date) async throws -> PurchaseOutcome {
        guard Self.productIDs.contains(productID) else {
            throw EngineError.invalidInput("Unknown subscription product")
        }
        let outcome = try await client.purchase(productID: productID)
        if case .purchased(let subscription) = outcome {
            entitlement = EntitlementResolver.resolve(
                subscriptions: [subscription],
                recognizedProductIDs: Self.productIDs,
                now: now
            )
        }
        return outcome
    }

    public func ingest(_ subscriptions: [VerifiedSubscription], now: Date) {
        entitlement = EntitlementResolver.resolve(
            subscriptions: subscriptions,
            recognizedProductIDs: Self.productIDs,
            now: now
        )
    }
}
