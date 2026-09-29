# Product and technology overview

This file remains as a stable compatibility entry point for tools that were given the original path. Detailed decisions now live in focused files to prevent accidental cross-domain edits.

Start with [`INDEX.md`](INDEX.md).

## Locked product

- Japanese résumé, work-history document, and cover-letter workspace.
- No custom account, external AI, recruiter lead sale, ads, or tracking.
- Exact preview-to-PDF behavior and deterministic validation.
- Native AI suggestions from confirmed facts on supported devices.
- Local SwiftData persistence with private CloudKit synchronization across Apple devices.
- StoreKit 2 subscription with a useful free tier.

## Locked native stack

- Swift 6, SwiftUI, and Observation.
- iOS/iPadOS 18 baseline.
- Foundation Models on supported iOS/iPadOS 26+ devices, checked at runtime.
- VisionKit and Vision for scanning/OCR.
- Core Text, Core Graphics, and `UIGraphicsPDFRenderer` for output.
- PDFKit for exact preview.
- SwiftData and private CloudKit for persistence/synchronization.
- StoreKit 2 for subscriptions.
- PhotosUI, Vision person segmentation, LocalAuthentication, OSLog, and MetricKit where applicable.
- Swift Testing, XCTest UI, StoreKit Test, and golden-PDF fixtures.

## Detailed specifications

- Product scope: [`product/PRODUCT_SCOPE.md`](product/PRODUCT_SCOPE.md)
- User flows: [`product/USER_FLOWS.md`](product/USER_FLOWS.md)
- Pricing: [`product/PRICING_AND_ENTITLEMENTS.md`](product/PRICING_AND_ENTITLEMENTS.md)
- System architecture: [`architecture/SYSTEM_ARCHITECTURE.md`](architecture/SYSTEM_ARCHITECTURE.md)
- AI and import: [`architecture/AI_AND_IMPORT_PIPELINE.md`](architecture/AI_AND_IMPORT_PIPELINE.md)
- PDF pipeline: [`architecture/DOCUMENT_PIPELINE.md`](architecture/DOCUMENT_PIPELINE.md)
- Data and sync: [`architecture/DATA_AND_SYNC.md`](architecture/DATA_AND_SYNC.md)
- Purchases: [`architecture/PURCHASES.md`](architecture/PURCHASES.md)
- Tests: [`quality/TEST_STRATEGY.md`](quality/TEST_STRATEGY.md)

