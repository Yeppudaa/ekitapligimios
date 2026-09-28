# Reader experience — 2026-09-28

## Implemented scope

The native reader now opens as a full-screen presentation from book detail and the existing reader route. It starts with unobtrusive controls, paper across the screen, and a compact reading-position indicator. A tap on the PDF or the tools button reveals the floating controls. Page navigation, zoom, bookmarks, thumbnails and the existing preview limits remain available. EPUB also shows reading percentage and synchronization status when controls are open.

The reference is `C:/Users/Monster/Downloads/startdesign (1)/app/src/main/java/com/ekitapligim/app/ui/screens/ReaderScreen.kt`: sepia `#F4ECD8` / `#433422`, white / `#111111`, night `#1E1E1E` / `#E1E1E1`. The iOS implementation uses SwiftUI controls, PDFKit and the existing Readium navigator. It does not introduce a website wrapper. The theme is a local `reader.paperTheme` preference. PDF appearance changes retain the same view/document; EPUB preferences update the existing navigator. PDF color filters also affect illustrations, so illustrated books should be visually checked in each theme.

Loading displays session preparation, saved-position lookup, download, file validation and opening as distinct states. Download percentage comes from URLSession's received/expected bytes. An unknown total displays received bytes and an indeterminate indicator, never a guessed percentage. The screen provides Turkish connection, timeout and insufficient-space messages with retry.

Large transfers go directly to disk. Legacy JSON/base64 envelopes are decoded off the main actor using bounded 64 KiB buffers. Request/resource timeouts are 180 seconds / 30 minutes. Small HTTPS source-link JSON responses are supported with a four-request bound; credential-bearing redirects remain restricted to the approved API. File-backed PDF opening happens on a worker before the document is transferred to the main actor.

## Position and existing behavior

- Existing PDF restoration waits for attachment/layout and confirms the actual page before publishing progress. It does not save page 1 while restoring.
- The existing EPUB CFI adapter, progress repository, serialized write queue and progress synchronization service are unchanged.
- Returning from reader-owned sheets or the preview notice retains the active PDF backing file and avoids creating another reading session. The same EPUB navigator is reused instead of returning to its initial CFI.
- Reader metadata loading does not replace an already opened reader on reappearance. Settings cannot interrupt an in-flight load; paper themes can still be changed while loading.
- Preview limits and authorization/session requests retain their existing contracts. Premium routing is deferred until the full-screen reader is dismissed so the existing destination can be presented normally.
- SHA-256 comparison against the task's initial baseline found **161 protected files unchanged**, including purchase source/configuration, backend, shared API/repositories and reading-sync components. No API/backend deployment or purchase operation was performed.

## Executed validation

| Check | Result | Local evidence |
|---|---|---|
| `Scripts/swift-test-windows.ps1` | **287 XCTest tests passed**, including 14 new decoder/progress tests | `.codex-artifacts/reader-experience/core-tests.log` |
| Fresh-scratch `swift build -c release` for `EkitapligimCore` | Passed; Windows emitted a convenience symlink warning after compilation | `.codex-artifacts/reader-experience/core-release.log` |
| Swift frontend parse of 13 changed Apple-platform source/test files | Passed in DEBUG and production conditions; syntax only, not iOS SDK type checking | `.codex-artifacts/reader-experience/syntax.log` |
| Optimized production decoder, synthetic 100 MiB envelope | Exact streaming byte comparison and independent SHA-256 passed | `.codex-artifacts/reader-experience/decoder-stress-report.md` |
| `Scripts/validate-workspace.ps1` | Passed, including source/accessibility checks, basic secret scan, configuration/contracts and PHP syntax | `.codex-artifacts/reader-experience/workspace-audit.log` |
| Protected-file hash comparison | 161 files unchanged | `.codex-artifacts/reader-experience/protected-check.log` |
| `git diff --check` | Passed | Git working tree |

The 14 new core tests cover supported root/inner envelopes, buffer boundaries, escaped whitespace, malformed JSON/base64, cleanup, existing-file preservation, cancellation, known/unknown transfer totals, percentage clamping and localized phase descriptions. Existing reading progress, auth, downloads and routing tests ran in the same suite.

The separate stress run compiled the unchanged production decoder with `-O -whole-module-optimization`. It streamed a 139,810,509-byte JSON envelope into a 104,857,617-byte binary (100 MiB plus 17 bytes), then compared every byte and independently matched SHA-256. Decoding took 7.78 seconds; the separate Windows decode process had an observed peak working set of 15.52 MiB (50 ms sampling, including its Swift/Foundation runtime). These numbers describe that host/process, not iPhone memory or PDF rendering performance. The synthetic content has a PDF signature and is not a renderable book. All three large generated files were removed after verification; the harness, logs and report remain locally available.

Readium API compatibility was reviewed against the pinned **3.9.0** source: [EPUBPreferences](https://github.com/readium/swift-toolkit/blob/3.9.0/Sources/Navigator/EPUB/Preferences/EPUBPreferences.swift), [color types](https://github.com/readium/swift-toolkit/blob/3.9.0/Sources/Navigator/Preferences/Types.swift), and [navigator configuration/preferences](https://github.com/readium/swift-toolkit/blob/3.9.0/Sources/Navigator/EPUB/EPUBNavigatorViewController.swift). This source review does not replace a native build.

## Native validation still required

This Windows host has no Xcode, iOS SDK or iOS Simulator. No iOS build, device screenshot, live large-PDF rendering or native UI test is claimed as passed. This report is not App Store readiness evidence.

New tests are already included by the existing `project.yml` source directories:

- `ValidatedBookFileTransferTests`: 5 tests for HTTPS source-link responses, oversized/insecure responses, Drive normalization, late progress events and nested disk-full errors.
- `PDFReaderAppearanceTests`: theme changes must preserve the live PDFView, PDFDocument, page 40, zoom and saved-position events after restoring page 25.
- `ReaderExperienceUITests`: 6 UI tests for restored/full-screen reading, page-preserving themes, measured percentage, unknown totals, large text and landscape; each includes screenshot attachments.

`-reader-ui-fixture` enables a DEBUG-only offline 60-page PDF using the production PDF view and controls. It starts at page 25. `READER_FIXTURE_MODE` accepts `reading`, `download-known`, `download-unknown`, `authorizing`, `restoring` and `opening`; `READER_FIXTURE_THEME` accepts `sepia`, `white` and `night`. The fixture is excluded from production behavior.

Before release, execute clean Development and Production iOS builds and all native unit/UI tests on macOS. Run the existing `PDFReadingResumeTests`, `PDFReaderPerformanceTests` and `EPUBReaderPositionTests` alongside the new tests. Check the actual screen on iPhone/iPad, VoiceOver, dynamic text, landscape, double-tap/pinch zoom, PDF links/selection, theme changes, settings/preview dismissal, reopen/continue reading and background/foreground. Exercise a real large PDF and EPUB over public HTTPS with both known and unknown response sizes, interrupted downloads and low storage. Inspect night-mode illustrations and the first/last page without treating the synthetic decoder test as rendering evidence.

## Configuration and documentation

`project.yml` already discovers the new app/test files; SwiftPM processes `Reader.strings`. The existing UserDefaults privacy reason covers the local theme. No dependency, entitlement, StoreKit product, production endpoint or privacy-manifest category changed. Parity, API, privacy inventory, App Store metadata draft and checklist were updated to describe the current behavior and the outstanding native checks.
