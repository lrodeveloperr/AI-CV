# User flows and state model

**Status:** `LOCKED`

## First document

1. Launch into “Start” with no registration wall.
2. Choose résumé, work-history document, or cover letter.
3. Start blank or scan an existing document.
4. Enter or confirm canonical facts.
5. Choose Gregorian or Japanese-era date presentation.
6. Select a template.
7. Optionally request an AI wording suggestion on a supported device.
8. Approve, edit, or discard the suggestion.
9. Open exact PDF preview.
10. Resolve missing-field, overflow, image, or file-size warnings.
11. Export through the native share sheet or print.

## OCR import

1. User explicitly opens Import and chooses Scan Document.
2. VisionKit captures pages.
3. Vision recognizes Japanese text locally.
4. Deterministic parsers create candidate facts with source ranges and confidence.
5. The user confirms, corrects, or rejects every candidate.
6. Confirmed facts are merged into the canonical profile.
7. Temporary scan images are discarded unless the user chooses to keep them.

OCR never writes directly to the canonical record.

## AI drafting

1. User selects a writing field and an action: draft, shorten, expand, change tone, or tailor.
2. The app builds a minimal fact packet from confirmed records and optional vacancy text.
3. Foundation Models returns a structured suggestion and the IDs of facts it used.
4. Deterministic validation rejects malformed output and unsupported fact references.
5. The app shows the proposal separately from the accepted document text.
6. The user accepts, edits, regenerates, or discards it.

AI never mutates dates, employers, qualifications, or other canonical facts.

## Application-specific variant

1. Create an application and enter the company, role, deadline, and vacancy text.
2. Duplicate a document as a lightweight variant referencing the canonical profile.
3. Tailor only narrative fields; factual sections continue reading confirmed profile data.
4. Freeze a version whenever a PDF is exported.
5. Associate the frozen version with the application event.

## Cross-device work

1. The app saves every committed change to SwiftData locally.
2. When the user is signed into iCloud and allows the app to use it, SwiftData synchronizes through the private CloudKit database.
3. The app shows a neutral state: saved locally, syncing, synced, iCloud unavailable, or attention required.
4. The user can continue working offline; synchronization resumes later.
5. Conflicting text edits create a recoverable version rather than silently deleting one side.

There is no custom login and no app-level “sync” switch. The user controls iCloud access in Apple system settings.

## Free-to-Pro flow

1. Free limits are checked only when the user attempts a gated action.
2. The paywall explains the exact action that needs Pro and preserves the user’s work.
3. The user can dismiss the paywall without losing data.
4. StoreKit completes or cancels the transaction.
5. A verified entitlement unlocks Pro immediately.
6. Restore Purchases and Manage Subscription remain available from Settings and the paywall.

## Failure recovery

- Interrupted generation: retain the last accepted text; allow retry.
- OCR failure: retain captured pages until the user retries or exits.
- Render failure: retain the document and identify the failed stage.
- Share cancellation: return to the exact preview without consuming another export.
- iCloud unavailable: continue locally and show status without blocking work.
- Purchase pending: preserve work and update entitlement when StoreKit reports a verified transaction.

