# Product scope

**Status:** `LOCKED`

## Product

**Name:** 履歴書・職務経歴書 AI作成 [AI Résumé & Work History Maker]

**Market:** Japan.

**Platforms:** iPhone and iPad, with Apple-silicon Mac availability through the supported App Store compatibility path after validation.

**Promise:** Create accurate Japanese résumés, work-history documents, and cover letters without an account; improve wording with native on-device AI on supported devices; preview the exact PDF before submitting; and continue the same career workspace across Apple devices.

## Customer job

Turn a permanent, verified career record into a reliable application-specific document without retyping facts, surrendering personal data to a recruiter, or discovering output failures at submission time.

## Version 1.0 scope

- Permanent career profile: identity, contact details, education, employment, qualifications, skills, and reusable achievements.
- Résumé, work-history document, and cover letter.
- Gregorian and Japanese-era date entry and display.
- Manual entry plus OCR-assisted import from an existing document.
- Application-specific variants linked to one canonical career profile.
- Native AI suggestions for self-promotion, motivation, career summaries, shortening, and tone changes.
- Exact PDF preview, A4/A3 templates, deterministic pagination, overflow detection, and final byte-size validation.
- ID-photo selection, crop, and local background cleanup.
- Native share sheet and printing.
- Application tracker and document-version history.
- Private cross-device iCloud synchronization with local persistence.
- StoreKit 2 subscription and a genuinely usable free tier.

## Reliability promises

- Canonical employers, schools, dates, qualifications, titles, and metrics are never changed by AI.
- OCR and AI output remain proposals until the user confirms them.
- No field or employment entry is silently omitted.
- Preview, sharing, and printing use the same rendered PDF data.
- An exceeded file-size ceiling or unresolved overflow blocks export and names the affected section.
- The app never claims an email or application was delivered; it hands the file to Apple’s system UI.

## Privacy promises

- No custom account.
- No external AI provider.
- No ads, tracking, recruiter lead sale, or third-party analytics SDK.
- The user’s career data persists locally and syncs only through the user’s private iCloud database.
- Imported scan images are temporary unless the user explicitly keeps an attachment.
- The app remains usable when iCloud or native AI is unavailable.

## Non-goals

- Recruiter marketplace.
- Job-board scraping.
- Automated job applications.
- Public profiles or social sharing.
- Web account or custom backend.
- Guaranteed interview or employment claims.
- Custom document delivery service.

## Success criteria

- A new user can complete and export a valid document without an account.
- A returning user can tailor a new application without re-entering their career history.
- Long employment histories survive editing, synchronization, preview, and export without loss.
- The product visibly solves the market’s documented output, privacy, and late-fee frustrations.

