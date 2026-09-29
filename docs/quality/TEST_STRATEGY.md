# Test strategy

**Status:** `LOCKED`

## Test layers

| Layer | Tool | Purpose |
|---|---|---|
| Domain | Swift Testing | Facts, validation, dates, state machines, feature gates |
| Persistence | Swift Testing + in-memory/on-disk SwiftData | Mapping, relationships, migration, deletion |
| Documents | Swift Testing + rendered fixtures | Layout, pagination, text presence, byte-size policy |
| Native adapters | XCTest integration tests | Vision, PDFKit bridges, permissions, file handoff |
| Purchases | StoreKit Test | Product loading and subscription lifecycle |
| UI | XCTest UI | Main flows, accessibility, device adaptation |
| Release | Physical devices/TestFlight | Camera, iCloud, Apple Intelligence, printing/sharing |

## Non-negotiable engine invariants

- Every confirmed employment and education record appears in the intended output or produces a blocking error.
- AI output cannot write canonical facts directly.
- OCR output cannot write canonical facts directly.
- Preview, share, and print receive identical PDF data for one snapshot hash.
- No successful export exceeds the selected byte ceiling.
- Free-limit counters change only after their defined successful event.
- Interrupted persistence, rendering, AI, and purchase operations leave recoverable state.
- Synchronization conflicts preserve user data and document versions.

## Fixture matrix

- Empty/minimum/complete career profiles.
- 1, 5, 15, and 30 employers.
- Japanese-era transitions and open-ended current roles.
- Long Japanese names, addresses, employers, qualifications, and mixed Latin text.
- Missing and low-resolution portraits.
- OCR with skew, noise, handwriting-like fonts, tables, and multiple pages.
- AI unavailable, model not ready, refusal, cancellation, excessive output, and unsupported facts.
- CloudKit account unavailable, offline edits, concurrent edits, deletion conflict, and first synchronization.

## CI split

### Every pull request

- Format/lint.
- Build all packages.
- Domain, renderer, persistence, and StoreKit fixture tests.
- Golden-PDF comparison.
- Baseline iOS 18 compile.
- Latest SDK compile for Foundation Models code.

### Release candidate

- Full UI suite on the smallest supported iPhone and current large iPhone.
- iPad portrait, landscape, Split View, and keyboard.
- VoiceOver, Dynamic Type, Reduce Motion, contrast, and Japanese input.
- StoreKit lifecycle suite.
- CloudKit development-to-production checklist.
- TestFlight installation and upgrade from the prior public schema.

### Physical-device checks

- Camera scan and photo picker.
- Share sheet, Files save, email handoff, and AirPrint path.
- Apple Intelligence generation on an eligible device.
- Non-AI fallback on an ineligible device such as the 2020 iPhone SE.
- Cross-device synchronization using the same Apple Account.

## Release gates

- Zero known silent data-loss or silent-omission paths.
- All golden documents visually approved.
- Final archive privacy manifest and required-reason APIs inspected.
- App Store metadata reconciled to the exact release build.
- Authentic screenshots captured from that build.

