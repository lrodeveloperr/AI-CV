# Pricing and entitlements

**Status:** `LOCKED`

This file is the sole authority for price and entitlement decisions. App Store metadata and paywall code must match it.

## Products

| Tier | Japan price | Billing | Product ID |
|---|---:|---|---|
| Free | ¥0 | None | None |
| Pro monthly | ¥500/month | Auto-renewable | `com.worksbienstudios.rirekishoai.pro.monthly` |
| Pro annual | ¥3,000/year | Auto-renewable | `com.worksbienstudios.rirekishoai.pro.annual` |

- One subscription group: `rirekisho_ai_pro`.
- No lifetime purchase.
- No introductory free trial.
- Product IDs remain proposed until the bundle identifier is confirmed because App Store Connect product IDs are permanent.

## Free entitlement

- One résumé.
- One work-history document.
- Manual editing.
- Exact PDF preview.
- One successfully completed clean PDF export.
- Local persistence.
- Japanese-era and Gregorian dates.

The free export is consumed only after a PDF is successfully handed to a completed export flow. Opening preview, canceling the share sheet, or encountering a render error does not consume it.

## Pro entitlement

- Unlimited documents and application-specific variants.
- Unlimited PDF exports.
- Native AI drafting, rewriting, shortening, and vacancy tailoring on supported devices.
- OCR-assisted import.
- Cover letters.
- Application tracker.
- Document-version history.
- ID-photo cleanup.
- Private iCloud synchronization across supported Apple devices.

## Paywall rules

- Trigger at the gated action, never at first launch.
- Preserve all user-entered work when the paywall appears.
- Show both plans, with annual visually recommended.
- Load price and billing period from StoreKit; never hard-code localized display strings.
- Clearly identify auto-renewal and recurring full price.
- Provide Restore Purchases, Manage Subscription, Privacy Policy, and Terms.
- Explain native-AI device requirements before purchase.
- Never imply that a subscription purchases Apple Intelligence eligibility.

## Why subscription

The ongoing product is a maintained career workspace: repeated application tailoring, application tracking, document histories, evolving templates, native-AI compatibility, and synchronized versions across devices. The subscription is not justified by invented server costs.

## Commercial evidence

- A high-volume Japanese résumé builder displays a ¥500 Premium purchase.
- A focused Japanese writing assistant charges approximately ¥550/month.
- Career-AI products show higher monthly and annual anchors.
- ¥500/month therefore enters at the validated low end; ¥3,000/year gives a simple six-month-equivalent annual price.

