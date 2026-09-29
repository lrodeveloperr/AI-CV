# 履歴書・職務経歴書 AI作成 [AI Résumé & Work History Maker]

A private, native iPhone and iPad app for creating Japanese résumés, work-history documents, and cover letters.

## Decision status

- Product: **LOCKED**
- Technical architecture: **LOCKED**
- Monetization: **LOCKED**
- App Store copy: **DRAFT_READY**
- App Store submission: **BLOCKED until the final build, screenshots, public URLs, and App Store Connect facts are verified**

## Locked offer

- Free: one résumé, one work-history document, exact preview, and one clean PDF export.
- Pro monthly: **¥500/month**.
- Pro annual: **¥3,000/year**.
- No lifetime purchase and no introductory free trial.
- Pro unlocks unlimited documents, variants, and exports; native AI drafting and tailoring; OCR import; application tracking; version history; photo cleanup; and private iCloud sync.

Prices are configured in App Store Connect and rendered in-app using StoreKit's localized values. Static prices are intentionally excluded from public metadata.

## Repository documents

- [`docs/PRODUCT_AND_TECH_SPEC.md`](docs/PRODUCT_AND_TECH_SPEC.md) — locked product, architecture, data model, feature boundary, and quality gates.
- [`docs/APP_STORE_LISTING_JA.md`](docs/APP_STORE_LISTING_JA.md) — complete Japanese App Store listing draft with English working translations.
- [`docs/APP_STORE_SUBMISSION_CHECKLIST.md`](docs/APP_STORE_SUBMISSION_CHECKLIST.md) — App Store Connect answers, compliance controls, review notes, and remaining blockers.
- [`docs/listing-manifest.json`](docs/listing-manifest.json) — machine-readable listing and submission state.

## Product principle

The app never lets generative AI silently change an employer, date, qualification, or other factual record. AI proposes wording; the user approves it; deterministic code owns the final document.

