import CareerDomain
import Foundation
import Purchases
import Testing

@Test func entitlementResolverHandlesActiveGraceExpiredAndUnknownProducts() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let future = now.addingTimeInterval(3_600)
    let past = now.addingTimeInterval(-3_600)
    let known = PurchaseEngine.monthlyProductID

    #expect(EntitlementResolver.resolve(
        subscriptions: [.init(productID: known, expirationDate: future, state: .subscribed)],
        recognizedProductIDs: PurchaseEngine.productIDs,
        now: now
    ) == .proActive(expiresAt: future))

    #expect(EntitlementResolver.resolve(
        subscriptions: [.init(productID: known, expirationDate: future, state: .gracePeriod)],
        recognizedProductIDs: PurchaseEngine.productIDs,
        now: now
    ) == .proGracePeriod(expiresAt: future))

    #expect(EntitlementResolver.resolve(
        subscriptions: [
            .init(productID: known, expirationDate: past, state: .subscribed),
            .init(productID: "unknown", expirationDate: future, state: .subscribed)
        ],
        recognizedProductIDs: PurchaseEngine.productIDs,
        now: now
    ) == .free)
}

@Test func revokedSubscriptionNeverGrantsPro() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let result = EntitlementResolver.resolve(
        subscriptions: [.init(
            productID: PurchaseEngine.annualProductID,
            expirationDate: now.addingTimeInterval(10_000),
            state: .revoked
        )],
        recognizedProductIDs: PurchaseEngine.productIDs,
        now: now
    )
    #expect(result == .free)
}


private struct FailingClient: PurchaseClient {
    func products(for identifiers: Set<String>) async throws -> [StoreProductInfo] { [] }
    func currentSubscriptions() async throws -> [VerifiedSubscription] {
        throw EngineError.unavailable("App Store unreachable")
    }
    func purchase(productID: String) async throws -> PurchaseOutcome { .canceled }
}

@Test func unavailableStoreKeepsCachedVerifiedEntitlement() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let future = now.addingTimeInterval(3_600)
    let cache = InMemoryEntitlementCache([
        .init(productID: PurchaseEngine.annualProductID, expirationDate: future, state: .subscribed)
    ])
    let engine = PurchaseEngine(client: FailingClient(), cache: cache)

    #expect(await engine.restoreFromCache(now: now) == .proActive(expiresAt: future))
    do {
        _ = try await engine.refresh(now: now)
        Issue.record("Expected refresh to fail")
    } catch {
        #expect(error as? EngineError == .unavailable("App Store unreachable"))
    }
    #expect(await engine.entitlement == .proActive(expiresAt: future))
}

@Test func ingestedSubscriptionsArePersistedToCache() async {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let cache = InMemoryEntitlementCache()
    let engine = PurchaseEngine(client: FailingClient(), cache: cache)
    let sub = VerifiedSubscription(
        productID: PurchaseEngine.monthlyProductID,
        expirationDate: now.addingTimeInterval(100),
        state: .subscribed
    )
    await engine.ingest([sub], now: now)
    #expect(await cache.load() == [sub])
}
