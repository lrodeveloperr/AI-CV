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

