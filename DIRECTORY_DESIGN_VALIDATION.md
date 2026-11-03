# Author / publisher design and complete pagination — 2026-11-03

Latency follow-up: counters no longer block rows, candidate pages request 100 entries, recent selections use a bounded two-minute memory cache, and obsolete requests are cancelled. Design and full-pagination behavior are preserved. Latest evidence: 511 Core tests and 22 directory-model tests passed; live iPhone latency remains unmeasured. See [performance validation](DIRECTORY_PERFORMANCE_VALIDATION.md).

## Scope

Only the native authors/publishers index presentation and matching-page collection are changed. Android `SiteDirectoryScreen.kt`, `DirectoryIndex.kt` and the two user-supplied screenshots are the reference. The existing author desk / publisher bookshelf assets are reused in a visible 150-point scenic band above serif headings and global statistics. Search and Turkish alphabet selection share one card, with a localized “Tümü” action, focus treatment and clear action. Entry cards use decorative book/pen/building illustrations; no invented author portraits are used. Rows grow for long names and accessibility text sizes, controls have at least 44-point targets, and the index is limited to 760 points on wide devices.

The directory-to-books destination and the entire `DirectoryBooksView` implementation are unchanged; a normalized before/after comparison verified this. A file-hash comparison verified the previous Agenda work is unchanged. No Android, backend, profile editor, entitlement, StoreKit or permission behavior is changed. The existing XcodeGen source rules and SwiftPM resource rules include the new files automatically.

## Pagination correction

The previous iOS implementation, like the current Android helper, stopped at the first server page containing any matching initial. A contains-search page with only one or two matching initials therefore produced a very short list even when more matches existed.

For a selected initial, the model now accumulates **at least 30 new unique matching entries, or reaches the server's last page**, publishing results as each page arrives. Thirty is a batch target, not a total-result limit. Whole pages are retained, including entries beyond that target; “Daha fazla yükle” resumes at the next server page. With no selected initial, normal server pagination is retained. Counts say “loaded” while further results remain and “all matches” only after completion. Changing filters or leaving the screen invalidates the old collection. Partial errors retain usable rows and retry the failed cursor.

The existing `q`/`page` contract is sufficient; no deployment or new API parameter is required. Initial matching and search intersection retain the existing Turkish locale rules. The backend remains authoritative for which entries can be viewed.

## Executed validation

Evidence: `.codex-artifacts/directory-modern-20261103/`.

- `Scripts/profile-directory-state-test-windows.ps1`: 26 tests passed, including **16 actual directory-model tests** and the existing 10 profile regressions. Test-only Combine storage shim; not Apple Combine/SwiftUI validation.
- New scenarios: 67 sparse matches across 67 server pages for each directory (30 → 60 → 67), whole-page overflow (40 → 65 without truncation), partial-batch error/retry, filter change during collection, and leaving the screen during a batch.
- `Scripts/swift-test-windows.ps1 -Jobs 4`: all **510 Core tests passed**.
- Workspace validation: static source/config/API checks, basic secret scan, accessibility-label audit and PHP syntax checks passed.
- Normal/DEBUG Swift syntax parsing and `bash -n Scripts/directory-design-macos.sh`: passed. Apple SDK typechecking is not provided by syntax parsing.

## Native checks pending

Windows has no Xcode, iOS SDK or Simulator. No native build or new iPhone/iPad screenshot is claimed. The user attachments are Android references, not evidence of the implemented iOS rendering.

`DirectoryDesignLayoutTests` captures both headers and long-name rows at widths 284/354/724 with normal/accessibility text. `DirectoryDesignUITests` checks inline-search recovery, “Tümü”, Turkish-letter reachability and accessibility hit/clipping audits. The two existing directory UI tests now require later sparse matches without extra taps and retain entry-to-books navigation coverage. These native tests are authored but unexecuted here.

Run `bash Scripts/directory-design-macos.sh` on macOS. It performs clean Development / unsigned Production builds and the targeted native tests on two iPhones and iPad, exporting result bundles and screenshots. Inspect scenic artwork, long names, keyboard, large text and rotation; verify real directory pagination on the deployed API before release. No publication, version bump or live account mutation is part of this work.
