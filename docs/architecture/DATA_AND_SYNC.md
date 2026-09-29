# Data, persistence, and synchronization

**Status:** `LOCKED`

## Strategy

Use SwiftData for persistence and a private CloudKit database for native cross-device synchronization. The local store remains usable offline; CloudKit synchronizes when the user’s Apple Account, settings, connectivity, and system state allow it.

Do not build a custom server, account, sync protocol, or manual “sync now” button.

## Configuration

- Define an explicit versioned `Schema`.
- Define a `SchemaMigrationPlan` from the first release.
- Configure `ModelContainer` with a named private CloudKit database identifier.
- Enable iCloud/CloudKit entitlements for every shipped target.
- Use separate development and production CloudKit environments.
- Promote and verify the production schema before App Store submission.

The app does not provide its own sync toggle. Users enable or disable the app’s iCloud access in system settings. The UI reports state; it does not promise immediate synchronization.

## Persistence models

| Model | Purpose | Key fields |
|---|---|---|
| `CareerProfileRecord` | Root career workspace | stable ID, person fields, timestamps |
| `EducationRecord` | Confirmed education | stable ID, school, course, start/end, order |
| `EmploymentRecord` | Confirmed employment | stable ID, employer, title, dates, duties, order |
| `QualificationRecord` | Confirmed qualification | stable ID, name, issuer, awarded date |
| `AchievementRecord` | Reusable confirmed fact | stable ID, text, permitted metrics |
| `ApplicationRecord` | Target role tracking | stable ID, company, role, stage, deadline |
| `DocumentRecord` | Document identity/settings | stable ID, kind, template, date style |
| `DocumentVersionRecord` | Frozen accepted content | stable ID, parent, timestamp, snapshot payload |
| `NarrativeRecord` | User-approved prose | stable ID, field kind, text, cited fact IDs |
| `UsageLedgerRecord` | Free-limit history | stable ID, completed exports, timestamps |

Rendered PDFs and raw scans are caches/artifacts, not authoritative synced records. They are recreated from frozen snapshots.

## Domain separation

SwiftData classes live only in `PersistenceSync`. Repositories map them to pure domain values. This protects domain tests from framework behavior and allows migrations without rewriting business rules.

## Conflict policy

- Use stable UUIDs and modification timestamps generated at commit time.
- Independent child records merge by identity.
- Deletion uses tombstone state until synchronization has propagated.
- Concurrent edits to the same canonical fact never silently choose one text value; surface a conflict for confirmation.
- Concurrent narrative edits preserve both as document versions.
- Ordering uses explicit sortable ranks, not array position alone.
- PDF caches are discarded after a merge and rendered again.

## Storage minimization

- Sync confirmed structured data, accepted prose, application state, versions, and the cropped portrait.
- Do not sync temporary OCR pages, AI prompts, rejected suggestions, or rendered-PDF caches.
- Downsample the retained portrait before persistence.
- Keep diagnostics free of document text and personal fields.

## Sync states shown to users

- Saved locally.
- Syncing.
- Synced.
- iCloud unavailable; saved locally.
- Conflict requires review.

Never display “Synced” based on a timer or network reachability alone.

## Migration and recovery

- Ship schema version 1 even for the first build.
- Test migration using copies of every previous schema fixture.
- Export a portable local archive before destructive recovery operations.
- Never delete a store automatically after a migration or CloudKit error.
- Provide a diagnostics view with non-sensitive model counts, schema version, and sync state.

## Official references

- SwiftData `ModelConfiguration`: https://developer.apple.com/documentation/swiftdata/modelconfiguration
- Cross-device synchronization: https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices
- `ModelContainer`: https://developer.apple.com/documentation/swiftdata/modelcontainer
- Schema migration: https://developer.apple.com/documentation/swiftdata/schemamigrationplan

