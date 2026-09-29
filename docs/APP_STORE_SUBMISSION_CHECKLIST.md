# App Store submission checklist

## Current gate

**DRAFT_READY, not submission-ready.** Product copy, price architecture, native stack, free/paid boundary, and reviewer explanation are drafted. The following evidence must exist before anyone marks the release ready.

Begin repository review at [`INDEX.md`](INDEX.md). Commercial values must match [`product/PRICING_AND_ENTITLEMENTS.md`](product/PRICING_AND_ENTITLEMENTS.md), and shipped behavior must match the focused architecture documents.

## Build and metadata

- [ ] Final release build and signed archive identified.
- [ ] App name reserved and collision/trademark screen documented.
- [ ] Bundle ID confirmed before immutable in-app purchase product IDs are created.
- [ ] Version, build number, supported devices, and minimum OS match the archive.
- [ ] Primary and secondary categories verified in the current App Store Connect UI.
- [ ] Japanese name, subtitle, promotional text, description, and keyword byte count pasted exactly.
- [ ] No metadata describes an unshipped or unavailable feature.
- [ ] Native AI availability and non-AI fallback match the submitted binary.

## Product behavior

- [ ] Free user can create one résumé and one work-history document, see exact previews, and complete one clean export without an account.
- [ ] Pro entitlements match the listing and paywall.
- [ ] AI works only from confirmed facts and cannot mutate canonical facts silently.
- [ ] Unsupported devices receive an accurate explanation and retain the documented core features.
- [ ] Preview and export use the same immutable render snapshot.
- [ ] Long documents, Japanese-era dates, line breaks, file-size limits, and multi-page output pass golden tests.
- [ ] Restore Purchases and Manage Subscription work.
- [ ] Subscription remains available across the user's devices where the app is supported.

## Privacy and legal

- [ ] Privacy policy and support pages are live, readable without login, and contain current contact information.
- [ ] In-app privacy-policy link is easy to find.
- [ ] Final data-flow inventory includes Apple frameworks, CloudKit, StoreKit, diagnostics, and every dependency.
- [ ] App Privacy answers match actual final-build behavior.
- [ ] Signed archive privacy manifests and required-reason APIs inspected.
- [ ] Included SDK signatures inspected; third-party SDK declaration remains accurate.
- [ ] No tracking or unnecessary permission prompt.
- [ ] Camera and biometric permission strings describe the exact user-triggered purpose.
- [ ] CloudKit deletion and conflict behavior verified.
- [ ] Age-rating questionnaire completed against current App Store Connect questions.
- [ ] Content rights for every template, font, icon, and asset confirmed.
- [ ] Export-compliance answer confirmed from the final binary and entitlements.

## Visuals

- [ ] Final app icon installed in the build and checked at small search-result size.
- [ ] Screenshots use authentic final UI and one consistent fictional profile.
- [ ] Current Apple screenshot dimensions verified on capture day.
- [ ] Paid AI screenshot visibly says プロ [Pro].
- [ ] Free-value screenshot does not imply a purchase is required.
- [ ] Light/dark appearance and iPhone/iPad UI match the binary.
- [ ] No device frame or other-platform imagery creates a false impression.

## In-app purchases

- [ ] One subscription group created.
- [ ] Monthly product created at ¥500/month.
- [ ] Annual product created at ¥3,000/year.
- [ ] No lifetime product and no free trial configured.
- [ ] Localized display names and descriptions reviewed by a native Japanese reviewer.
- [ ] Paywall uses StoreKit localized price/period values and explains auto-renewal.
- [ ] Privacy policy, terms, restore, and manage-subscription actions are present.
- [ ] Subscription screenshot and review notes attached to both products.
- [ ] Products submitted with the app version if this is the first subscription submission.

## Accessibility and release QA

- [ ] VoiceOver labels/order verified.
- [ ] Dynamic Type and Japanese input verified.
- [ ] Contrast, Reduce Motion, keyboard, landscape, and iPad multitasking checked.
- [ ] Offline free flow tested.
- [ ] Purchase, renewal, expiration, refund, restore, and offline entitlement cache tested.
- [ ] Cold launch, migration, low storage, interrupted export, and interrupted sync tested.
- [ ] Crash-free launch and all links verified on the release candidate.

## Final App Store Connect fields

| Field | Draft answer |
|---|---|
| Name | 履歴書・職務経歴書 AI作成 [AI Résumé & Work History Maker] |
| Subtitle | 登録不要・自己PR作成・和暦対応・PDF出力 [No account, self-promotion writing, Japanese-era support, PDF export] |
| Primary language | Japanese |
| Availability | Japan |
| Price | Free |
| Primary category | Productivity |
| Secondary category | Business |
| Account | Not required |
| Privacy | Planned “Data Not Collected”; final verification required |
| Tracking | No |
| Ads | No |
| Copyright | © 2026 WorksBien Studios Inc. |
| Release | Manual |

## Official sources refreshed for this draft

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- App information: https://developer.apple.com/help/app-store-connect/reference/app-information/
- Product page: https://developer.apple.com/app-store/product-page/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
- App privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/
