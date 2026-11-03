# Library, favorites and activity — 18 October 2026

The Android reference is `C:/Users/Monster/Downloads/startdesign (1)`: `BookDetailScreen.kt`, `EKitapligimApp.kt`, its library payloads and the shared XenForo shelf/activity source were inspected. Android source was not changed.

## Findings and changes

- XenForo's older PUT parser did not recognize the iOS UTF-8 form content type. An empty request could default to `NONE` and still report success. The iOS library controller now parses bounded UTF-8 forms, validates fields, and rejects empty requests.
- The old shelf operation removed every reading and favorite membership before adding one. `LibraryShelfManager` now keeps Favorites independent from the mutually exclusive reading shelves. It uses permission-checked XenForo entities, an account transaction lock, committed readback, stable retry dates and existing entity counter hooks. Reader positions are preserved.
- iOS sends only `is_favorite` when changing Favorites. Shelf/favorite requests require an explicit positive acknowledgement. A malformed library fetch fails rather than publishing an empty library.
- AppContainer owns mutation logic and shares the reader write queue. UI state updates after acknowledgement, preserves newer local progress, and rejects old-account results. A successful change invalidates older library fetches and server-backed activity views.
- PDF/EPUB promotes a book to Reading only after the native reader restores displayed content. Favorites remain set, Finished remains Finished, and a failed promotion has a visible Retry action.
- Live activity and the Home preview listen for library changes. Refreshes arriving during a request are retained. Feed entries still come from actual server shelf records; no local activity rows are synthesized.
- Book detail presents a full-width **Rafa Ekle** card directly below the reading controls, with a current-shelf subtitle and a native shelf chooser. The separate labeled favorite action shows saved state, pending writes disable repeat taps, and guests receive a localized sign-in prompt. Large text can wrap naturally.

## Executed verification

- Core: **456/456 tests passed**. Six new transport/decoding regressions exercise independent favorite payloads, strict acknowledgement and invalid library responses.
- A previous full run exposed an unrelated category test selecting the test bundle's language instead of the Core resource bundle. Its language selector was corrected while retaining the exact 32-title/order/ID assertions; the full rerun passed.
- Feed model: **8/8 state tests passed** against the actual model source with test-only Combine storage on Windows. This checks asynchronous state, not native Combine/SwiftUI lifecycle.
- Library mutations: **12/12 state tests passed** using the actual AppContainer mutation methods and authentication observer with the real Core API client, repository and reader queue. This includes new-book metadata, failed acknowledgements, account changes, queue ordering and rebasing onto newer reader progress. The harness stubs native collaborators and publication.
- Backend: **26 test files passed**, including **37 new library checks**; changed PHP sources passed syntax checks. Real proprietary entity definitions were read locally, without bootstrapping XenForo or connecting to a database.
- Workspace validation passed, including route contract, privacy/entitlement, basic secret, PHP syntax, Swift static and accessibility-source audits. Configured text contrast for the saved-favorite label is 5.75:1; native rendering is not established by this calculation.
- Three `BookLibraryUITests` scenarios were added for the actual catalog/detail/profile/activity navigation, rejected favorite acknowledgement and large-text guest action. They are included in the macOS parity runner and have not run on iOS here.

## Backend delivery and platform limits

The upgrade is [IosApi 1.0.37 / 1000037](artifacts/library-favorites-20261018/Ekitapligim-IosApi.zip), with [installation and staging checks](artifacts/library-favorites-20261018/INSTALL.md). The archive contains the updated controllers and new service and passed packaging gates. SHA-256: `de46e68120d9bc8685e4a0703d289a16ba8f8fe6a1654e8f421f1c9dd462cc75`.

**The backend upgrade has not been deployed.** The independent favorite contract requires this package and the matching iOS source. No live authenticated write or production account mutation was made.

Xcode, iOS simulator, physical-device UI, clean/release builds and final native accessibility rendering have not run on this Windows machine. Execute the new native tests and verify staging persistence after relaunch, website/iOS agreement, real feed rows, authorization failures and PDF/EPUB behavior before release. Existing privacy data categories, Keychain storage, entitlements and purchase flows are unchanged.
