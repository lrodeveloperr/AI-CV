import CareerDomain
import Foundation
import StoreKit
import Testing
@testable import Purchases

@Test func storeKitRenewalStatesMapToEntitlementStates() {
    #expect(StoreKitPurchaseClient.renewalState(.subscribed, revoked: false) == .subscribed)
    #expect(StoreKitPurchaseClient.renewalState(.inGracePeriod, revoked: false) == .gracePeriod)
    #expect(StoreKitPurchaseClient.renewalState(.expired, revoked: false) == .expired)
    #expect(StoreKitPurchaseClient.renewalState(.inBillingRetryPeriod, revoked: false) == .expired)
    #expect(StoreKitPurchaseClient.renewalState(.revoked, revoked: false) == .revoked)
}

@Test func revokedTransactionNeverMapsToActive() {
    #expect(StoreKitPurchaseClient.renewalState(.subscribed, revoked: true) == .revoked)
    #expect(StoreKitPurchaseClient.renewalState(.inGracePeriod, revoked: true) == .revoked)
}
