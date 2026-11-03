# Profile editor and directory correction — 2026-11-03

## Implemented scope

Android reference was read from `C:\Users\Monster\Downloads\startdesign (1)`: `ProfileEditScreen.kt`, `SiteDirectoryScreen.kt`, directory helpers in `EKitapligimApp.kt`, and the MobileApi authors/publishers controllers plus `MetaDirectoryTrait.php`. The saved `profil-duzenle.png` was blank and is not visual validation evidence.

The existing native Profile → Edit route now presents cream/green cards, a full-width cover preview, avatar and member identity, full-width image actions, labelled fields with visible focus, an activity switch, and a prominent save action. Layout is content-driven with a 640-point width limit, vertical accessibility-size media layout, keyboard dismissal, and localized Turkish/English copy. Existing fields, permissions, limits, profile/media endpoints, dismissal after successful save, and separate account-security flow remain in place. There are no placeholder media deletion controls.

`ProfileEditorModel` owns draft/loading/error and repository operations. Server refreshes after an image upload preserve the unsaved draft. Media transfer and save are mutually exclusive; live account identity is checked even if an old view has been disposed. PhotosPicker content is encoded as actual JPEG before sending the existing JPEG upload metadata, with the 12 MB checks applied before decoding and after encoding.

The authors/publishers defect was local filtering of only the downloaded page, combined with hiding pagination when that local subset was empty. `DirectoryFilter` now constructs the existing `q` search and applies Turkish initial matching. `DirectoryListModel` advances through candidate pages without an initial match until it finds matching entries or exhausts pagination. Further matching pages stay accessible through the existing load-more control. Search and letter selection intersect; clearing filters resets pagination. Selection generations discard stale responses, page IDs deduplicate, and transient pagination failures preserve rows and retry the failed cursor. Repeated malformed cursors produce a recoverable error. Hero, statistics, alphabet, sort, entry cards and entry → books navigation remain native and retain their existing structure. Statistics remain global when site totals are available.

## Executed evidence

Logs: `.codex-artifacts/profile-directory-20261103/`.

- `Scripts/swift-test-windows.ps1 -Jobs 4`: **510 Core tests passed**, including six new Turkish/search/sort filter tests.
- `Scripts/swift-test-windows.ps1 -Clean -Release -Jobs 4`: **510 Core tests passed** after a clean optimized build. This is a portable Core build, not an iOS Production build.
- `Scripts/profile-directory-state-test-windows.ps1`: **21 tests passed** compiling the actual app models, with a test-only Combine storage shim. Eleven directory tests cover later pages, Turkish initials, filtering, stale responses, deduplication, retry, malformed cursors and optional statistics. Ten editor tests cover late data, draft preservation, limits, permissions, operation overlap and account changes, including a disposed view with no reconfiguration. Apple Combine publication is not tested by this shim.
- `Scripts/validate-workspace.ps1`: passed source/config/route contracts, static accessibility-label checks, basic secret scan and PHP syntax checks.
- Normal and DEBUG Swift syntax parsing and `bash -n Scripts/profile-directory-macos.sh`: passed. Syntax parsing does not typecheck SwiftUI/UIKit/XCTest against Apple SDKs.

## Native validation still required

This Windows environment has no Xcode, iOS SDK or Simulator. No new iPhone/iPad rendering, native build or native UI test result is claimed.

Three `ProfilePhotoLoaderTests` and four `ProfileDirectoryUITests` are authored but unexecuted. The UI fixtures use the actual shipping screens, intercepted offline transport, paginated directory candidates and rejected profile writes. They capture screenshots and check large text, keyboard/draft retention, tap targets, later-page initial filters, further pagination and book-list navigation. Existing fixture behavior is unchanged unless the new directory flag is enabled.

On macOS:

```bash
bash Scripts/profile-directory-macos.sh
```

The runner generates the existing project, performs clean Development and unsigned Production builds, then executes the 21 model, three photo and four UI tests on two iPhones and an iPad. It exports result bundles, summaries and screenshots under a unique `build/profile-directory-*` directory. Inspect normal/large-text/landscape layouts, VoiceOver labels, real PhotosPicker uploads, production directory responses and the successful profile save/back flow with an approved test account before release. Offline fixtures are not proof of live server writes.

## Configuration and data

The existing `project.yml` source-directory rules and SwiftPM resource rules automatically include the new source/tests/localizations. API paths, response schemas, authentication, release URLs, StoreKit products, entitlements and permission categories are unchanged; no backend deployment is required for the existing `q`/`page` contract. Photo encoding is memory-only and uses the existing first-party profile-media upload. No additional SDK, tracking or collected-data category is introduced. App Store copy/checklist, API documentation, parity and privacy notes are synchronized. No commit, publication, version bump or real account mutation was performed.
