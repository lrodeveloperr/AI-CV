# TestFlight issue ledger

No TestFlight session has run for this app yet.

## Provisioning pending

- Status: `open`
- Stage: `preflight`
- Signature: `ios-source-and-credential-route-missing`
- Resolved: Explicit bundle ID `com.worksbienstudios.rirekishoai`, App Store Connect app record `6817388738`, internal beta group `Internal QA` (`297cda24-0a7a-4e42-a771-671c5021dfd9`), and one internal tester are created and mapped.
- Symptom: The default branch does not yet contain a distributable app Xcode project/workspace with a shared scheme, and the App Store Connect API credential route is not configured.
- Prevention: The workflow is fail-closed and performs these checks on Linux before allocating macOS. It also rejects signed archives and IPAs that omit the required iCloud/CloudKit entitlements.
- Next action: Add the real iOS app project, fill the Xcode fields in the non-secret app map, configure the App Store Connect credential route, then switch the map state to `ready`.
