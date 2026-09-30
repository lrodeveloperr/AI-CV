#if canImport(StoreKit)
import CareerDomain
import Foundation
import StoreKit

/// StoreKit 2 adapter. Only verified transactions are ever surfaced; an
/// unverified result never grants access.
public struct StoreKitPurchaseClient: PurchaseClient {
    public init() {}

    public func products(for identifiers: Set<String>) async throws -> [StoreProductInfo] {
        let products: [Product]
        do {
            products = try await Product.products(for: identifiers)
        } catch {
            throw EngineError.unavailable("The App Store is unavailable")
        }
        return products.compactMap { product in
            guard let period = Self.period(of: product) else { return nil }
            return StoreProductInfo(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                period: period
            )
        }
    }

    public func currentSubscriptions() async throws -> [VerifiedSubscription] {
        let products: [Product]
        do {
            products = try await Product.products(for: PurchaseEngine.productIDs)
        } catch {
            throw EngineError.unavailable("The App Store is unavailable")
        }

        var result: [VerifiedSubscription] = []
        for product in products {
            guard let statuses = try? await product.subscription?.status else { continue }
            for status in statuses {
                guard case .verified(let transaction) = status.transaction else { continue }
                result.append(VerifiedSubscription(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    state: Self.renewalState(status.state, revoked: transaction.revocationDate != nil)
                ))
            }
        }
        return result
    }

    public func purchase(productID: String) async throws -> PurchaseOutcome {
        let product: Product
        do {
            guard let found = try await Product.products(for: [productID]).first else {
                throw EngineError.invalidInput("Unknown subscription product")
            }
            product = found
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.unavailable("The App Store is unavailable")
        }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw EngineError.unavailable("The purchase could not be completed")
        }

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw EngineError.unavailable("The purchase could not be verified")
            }
            let subscription = VerifiedSubscription(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                state: .subscribed
            )
            await transaction.finish()
            return .purchased(subscription)
        case .pending:
            return .pending
        case .userCancelled:
            return .canceled
        @unknown default:
            throw EngineError.unavailable("The purchase ended in an unknown state")
        }
    }

    /// Asks the App Store to re-sync entitlements (Restore Purchases).
    public func restorePurchases() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw EngineError.unavailable("Purchases could not be restored")
        }
    }

    /// Consumes `Transaction.updates` for the life of the app, refreshing the
    /// entitlement from verified transactions and finishing them afterwards.
    /// Cancel the returned task to stop listening.
    public static func listenForTransactionUpdates(
        engine: PurchaseEngine,
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                _ = try? await engine.refresh(now: now())
                await transaction.finish()
            }
        }
    }

    // MARK: - Mapping

    static func period(of product: Product) -> StoreProductInfo.Period? {
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: .month
        case .year: .year
        default: nil
        }
    }

    static func renewalState(
        _ state: Product.SubscriptionInfo.RenewalState,
        revoked: Bool
    ) -> VerifiedSubscription.RenewalState {
        if revoked { return .revoked }
        switch state {
        case .subscribed: return .subscribed
        case .inGracePeriod: return .gracePeriod
        case .revoked: return .revoked
        default: return .expired  // expired, billing retry without grace
        }
    }
}
#endif
