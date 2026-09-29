# 履歴書・職務経歴書 AI作成 — TestFlight wiring

Status: `PROVISIONING_PENDING`

The minimal App Store Connect record, explicit bundle ID, and internal TestFlight group now exist. The Account Holder is in `Internal QA`; no build has been uploaded and no App Store listing copy has been entered. The repository contains a fail-closed TestFlight pipeline: cheap Linux preflight, one macOS archive/export/upload, then cheap Linux delivery of the exact processed build to the mapped group and attachment to the matching editable App Store version. It never submits for App Review.

## Locked identity

- Repository: `lrodeveloperr/AI-CV`
- App Store name: `履歴書・職務経歴書 AI作成`
- App Store Connect app ID: `6817388738`
- Bundle ID: `com.worksbienstudios.rirekishoai`
- Apple team: `49SQ3XQ68Q`
- Internal beta group: `Internal QA`
- Beta group resource ID: `297cda24-0a7a-4e42-a771-671c5021dfd9`
- Signing style: automatic
- Export method: App Store Connect
- Distribution certificate: Apple Distribution
- Platform: `IOS`
- Marketing version: `1.0`
- Primary App Store language: Japanese
- SKU: `RIREKISHO-AI-IOS-001`
- iCloud/CloudKit: enabled on the registered App ID; the workflow rejects archives that omit the iCloud container or CloudKit service entitlements.

## Deliberate blockers

The workflow cannot allocate a paid macOS runner until `.github/testflight-app-map.json` has `state: ready` and contains:

1. the exact non-secret API key ID and issuer ID;
2. the committed Xcode project/workspace path and type;
3. the shared app scheme.

The release workflow is locked to automatic signing with Apple Distribution export. It does not use ad-hoc signing or mutable provisioning-profile names. This repository currently has package-level iOS code but no committed distributable app project/workspace and shared app scheme, so the blocker is intentional.

## GitHub Actions credentials

Configure these repository secrets without exposing their values:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_PRIVATE_KEY`

Configure these repository variables with the same non-secret identifiers:

- `ASC_EXPECTED_KEY_ID`
- `ASC_EXPECTED_ISSUER_ID`

The workflow compares the secret route, repository variables, and app map before macOS allocation. It then authenticates and verifies the exact App Store Connect app ID and bundle ID.

## First run

The first accepted upload must use the full lane. Dispatch **Rirekisho AI TestFlight** with:

- confirmation: `UPLOAD RIREKISHO AI TESTFLIGHT`
- `validated_sha`: the full immutable commit SHA already carrying a successful `Swift package tests` check and the final iOS app project.

After the first build is processed, delivered to the tester, and attached to the listing, record that successful run as the baseline before considering an express lane.

## Review-artifact invariant

The `Internal QA` group contains both designated tester accounts (2 testers; 0 builds at provisioning). The release lane archives, signs, exports, and uploads exactly once, then attaches that same Apple-processed build to the matching editable App Store version. App Review must use that attached build without rebuilding or re-signing. This proves build readiness only; listing metadata, screenshots, privacy, compliance, agreements, and review information remain separate submission gates.
