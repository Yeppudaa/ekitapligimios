# Catalog search correction — 2026-10-22

The native catalog search field remains visible. The home shortcut opens the
existing Books tab and activates search for typing. Clearing the query reloads
the catalog with the existing filters and pagination guards.

The complete home search label, including its empty space, is tappable. The next
book spotlight constrains interaction to its visible card and ignores decorative
artwork hit testing. Layout, styling and purchase flows are preserved.

Executed validation:

- Windows Core XCTest suite: 467 passed.
- macOS Core XCTest suite: 467 passed.
- Native iOS model/layout/audio regressions: 65 passed, zero failed/skipped.
- iPhone 17 Pro, iOS Simulator 26.2: all 3 CatalogSearchUITests passed.
- iPad Pro 13-inch (M5), iOS Simulator 26.2: the same 3 tests passed.
- Swift parser, workspace/secret scan, static Swift and accessibility audits passed.
- Live public HTTPS catalog searches returned query-dependent results and an empty
  list for the deliberately unmatched query. These were read-only requests.

The first iPad run caught the home shortcut hit-area defect. Its assertions were
retained; the corrected production source passed both device suites.

Validated app/test source: `7928c43824070623f9a9bf39f22d453bba8dff86`.
Evidence: https://codemagic.io/app/6a5221a644ecae83eeea61ec/build/6ada6f4c8a524d15d6a6293b
Downloaded evidence archive SHA-256:
`16bde961fcab82109526ddbbd56b6b23ccb44c49d8ef4bcd8d244d64c816813f`.

The signed 1.1.0 (48) IPA passed verification but Apple rejected its upload because
1.1.0 had already been approved. The patch version is now 1.1.1. Packaging reuses
the executed test evidence only after checking identical app/core/test sources,
65 unchanged protected files, and the sole marketing-version change in project.yml.
A fresh clean Production archive and signed IPA verification passed before upload.

Successful 1.1.1 (49) package and Apple upload:
https://codemagic.io/app/6a5221a644ecae83eeea61ec/build/6ada73c08a524d15d6a62aa5

At the user's subsequent request, 1.1.1 (49) was submitted to public App Review.
App Store Connect confirmed **Waiting for Review**, submission
`29215adf-243d-4fc4-88c8-71f571ec6e46`, on 22 October 2026 at 23:56 Europe/Istanbul.
Automatic release after approval and immediate availability to all users are
selected. Existing purchases, reviewer credentials and screenshots were preserved.
Release notes are stored in `AppStore/1.1.1/whats-new.tr.txt`.
Submission evidence is saved under the task's ignored `.codex-artifacts` directory.

Physical-device testing, an iOS 17 runtime run and live Sandbox transactions were
not performed for this search correction. These limits are disclosed in the Apple
review notes. Submission does not establish Apple approval or public availability.
