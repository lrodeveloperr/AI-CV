# 履歴書・職務経歴書 AI作成 [AI Résumé & Work History Maker]

A private, native iPhone and iPad app for creating Japanese résumés, work-history documents, and cover letters.

## Decision status

- Product: **LOCKED**
- Technical architecture: **LOCKED**
- Monetization: **LOCKED**
- App Store copy: **DRAFT_READY**
- App Store submission: **BLOCKED until the final build, screenshots, public URLs, and App Store Connect facts are verified**

## Repository navigation

Start with [`docs/INDEX.md`](docs/INDEX.md). It maps each decision to one authoritative file so multiple tools can work in the repository without creating contradictory copies.

- Product scope and flows are under `docs/product/`.
- Native implementation architecture is under `docs/architecture/`.
- Automated and device-level quality gates are under `docs/quality/`.
- App Store listing, submission checklist, and machine-readable manifest remain separate files under `docs/`.

The authoritative pricing and entitlement record is [`docs/product/PRICING_AND_ENTITLEMENTS.md`](docs/product/PRICING_AND_ENTITLEMENTS.md).

The UI foundation is the audited [`lrodeveloperr/ios-18-shell`](https://github.com/lrodeveloperr/ios-18-shell). This repository adds only the résumé product's app-specific UI and engine wiring; reusable shell improvements belong upstream in the shell repository.

## Product principle

The app never lets generative AI silently change an employer, date, qualification, or other factual record. AI proposes wording; the user approves it; deterministic code owns the final document.
