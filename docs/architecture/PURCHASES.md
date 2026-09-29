# StoreKit purchases and entitlements

**Status:** `LOCKED`

The commercial source of truth is [`../product/PRICING_AND_ENTITLEMENTS.md`](../product/PRICING_AND_ENTITLEMENTS.md). This file defines implementation only.

## Components

- `StoreClient` actor: loads products and performs purchases.
- `EntitlementStore`: observable, read-only UI state derived from verified transactions.
- `FeatureGate`: pure domain mapping from entitlement plus usage ledger to allowed actions.
- StoreKit configuration file: local and CI test products mirroring production IDs.

## Launch sequence

1. Start a long-lived task consuming `Transaction.updates`.
2. Load the two known product IDs.
3. Iterate `Transaction.currentEntitlements`.
4. Accept only verified transactions.
5. Derive active Pro state, including applicable grace-period access.
6. Publish localized product display data and entitlement state.

## Purchase sequence

1. User selects a StoreKit `Product`.
2. Call `purchase()`.
3. Handle success, pending, cancellation, and error distinctly.
4. On success, require a verified transaction.
5. Update entitlement state.
6. Finish the transaction after delivering access.

## Offline behavior

- Cache the last verified entitlement for fast launch presentation.
- Reconcile with StoreKit whenever available.
- Do not grant Pro from a locally edited flag or a device clock calculation.
- A temporarily unavailable App Store must not erase an already verified active entitlement prematurely.
- Free documents remain readable and export history remains intact after expiration.

## Free-limit accounting

- `FeatureGate` evaluates document counts and the completed-export ledger.
- Preview never consumes the free export.
- A canceled or failed share flow never consumes it.
- The app records consumption only after it has produced a valid PDF and completed the defined successful handoff event.
- Deleting a document does not reset historical completed-export usage.

## Required test cases

- Monthly and annual purchase.
- User cancellation.
- Ask-to-Buy/pending transaction.
- Verified and unverified results.
- Renewal, expiration, billing retry, grace period, refund, and revocation.
- Restore purchases.
- Upgrade/downgrade within the group.
- Offline launch with prior entitlement.
- Transaction update arriving while a paywall is visible.
- Purchase on one Apple device and entitlement refresh on another.

## Official references

- StoreKit 2: https://developer.apple.com/storekit/
- Current entitlements: https://developer.apple.com/documentation/storekit/transaction/currententitlements
- Transaction updates: https://developer.apple.com/documentation/storekit/transaction/updates

