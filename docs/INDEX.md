# Documentation index

This index is the entry point for humans and repository tools. Each decision has one authoritative file; other documents link to it instead of maintaining a second copy.

Engine source is under `Sources/`, focused engine evidence is under `Tests/`, and the authoritative workflow is `.github/workflows/engine-ci.yml`.

## Read order

1. [`product/PRODUCT_SCOPE.md`](product/PRODUCT_SCOPE.md) — customer, promise, version 1.0 scope, and non-goals.
2. [`product/USER_FLOWS.md`](product/USER_FLOWS.md) — end-to-end free, Pro, import, AI, export, and cross-device flows.
3. [`product/PRICING_AND_ENTITLEMENTS.md`](product/PRICING_AND_ENTITLEMENTS.md) — authoritative prices, free limits, Pro entitlements, and paywall rules.
4. [`architecture/SYSTEM_ARCHITECTURE.md`](architecture/SYSTEM_ARCHITECTURE.md) — module boundaries, dependency rules, and implementation sequence.
5. [`architecture/AI_AND_IMPORT_PIPELINE.md`](architecture/AI_AND_IMPORT_PIPELINE.md) — Foundation Models, OCR, confirmation, and hallucination containment.
6. [`architecture/DOCUMENT_PIPELINE.md`](architecture/DOCUMENT_PIPELINE.md) — deterministic layout, preview, preflight, export, and printing.
7. [`architecture/DATA_AND_SYNC.md`](architecture/DATA_AND_SYNC.md) — SwiftData schema, private CloudKit synchronization, conflicts, and migration.
8. [`architecture/PURCHASES.md`](architecture/PURCHASES.md) — StoreKit 2 products, transaction lifecycle, and offline behavior.
9. [`quality/TEST_STRATEGY.md`](quality/TEST_STRATEGY.md) — automated and device-level acceptance gates.
10. [`APP_STORE_LISTING_JA.md`](APP_STORE_LISTING_JA.md) — Japanese production metadata with English working translations.
11. [`APP_STORE_SUBMISSION_CHECKLIST.md`](APP_STORE_SUBMISSION_CHECKLIST.md) — final submission evidence and compliance gates.
12. [`listing-manifest.json`](listing-manifest.json) — machine-readable listing state.

## Source-of-truth map

| Decision | Authoritative file |
|---|---|
| Product promise and scope | `product/PRODUCT_SCOPE.md` |
| User journeys and states | `product/USER_FLOWS.md` |
| Prices, free limits, Pro benefits | `product/PRICING_AND_ENTITLEMENTS.md` |
| Modules and dependencies | `architecture/SYSTEM_ARCHITECTURE.md` |
| AI and OCR behavior | `architecture/AI_AND_IMPORT_PIPELINE.md` |
| PDF behavior | `architecture/DOCUMENT_PIPELINE.md` |
| Persistence and synchronization | `architecture/DATA_AND_SYNC.md` |
| Purchases and entitlement rules | `architecture/PURCHASES.md` |
| Test gates | `quality/TEST_STRATEGY.md` |
| Public store copy | `APP_STORE_LISTING_JA.md` |
| Submission readiness | `APP_STORE_SUBMISSION_CHECKLIST.md` and `listing-manifest.json` |

## Editing rules for tools

- Read this index before changing the repository.
- Change the authoritative file first.
- Do not restate prices, entitlements, or architecture rules in unrelated documents.
- App Store copy may repeat customer-facing facts, but it must match the authoritative product files.
- A proposal becomes locked only when its authoritative file says `LOCKED`.
- Build-dependent statements remain blocked until supported by the release candidate.
- Do not commit personal App Review contact information to this public repository.
