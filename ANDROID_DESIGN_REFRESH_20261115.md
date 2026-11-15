# Android → native iOS design refresh — 15 November 2026

Historical first-pass record. The subsequent [deep review](DEEP_REVIEW_20261115.md) supersedes the message-field, private-attachment and pagination limitations below and expands the native runner from eight to 38 checks. Neither pass has executed that runner on macOS.

## Scope

Reference chat `01a1de46-fd34-73e3-a45a-3bf9f37ab07f` was read. The current Android `HomeAgendaWelcome.kt`, `HomeAgendaIosCard.kt`, `BookRequestAccessScreen.kt`, `ConversationPreviewContent.kt` and their delivered phone screenshots supplied the design reference. Android sources were not edited.

| Surface | Implemented in SwiftUI |
|---|---|
| Home / Book Agenda | One continuous cream panel containing the reader illustration, serif introduction, real agenda action and recent posts. Cards have an image/book/scenic header, reader identity, three-line preview, counts and the existing detail action. Standard rails use equal 368 pt heights scaled with text; accessibility sizes use natural-height stacked cards. |
| Book request information | Green/gold membership introduction, four illustrated benefits, separate exhausted-allowance presentation, server-provided remaining/limit and renewal timezone. Actions dismiss the information sheet before opening existing Premium/catalog/audio destinations. |
| Messages | Book embeds become book-cover cards with live metadata and native details. Clean captions, link cards and public first-party image previews replace raw markup. Message title/metadata still open the conversation; card actions are separate controls. |
| Accessibility | Turkish/English resources, adaptive columns, 44 pt or larger primary actions, dynamic text, scoped light/dark palette, decorative images excluded from VoiceOver. |

## Purchase and backend isolation

- SHA-256 comparison checks 241 pre-existing protected files: purchase/StoreKit/premium/subscription files, backend files, AppContainer, project configuration, privacy manifest and entitlements. All unchanged at verification.
- No product identifiers, prices, purchase verification, receipt handling, restore flow, membership calculations, billing endpoints or server files changed.
- The request sheet is informational. It only reads optional `request_quota` from the existing endpoint. If unavailable, the old form remains; no allowance or renewal date is invented.
- `project.yml` already discovers app source/assets recursively and the Core package processes its Resources directory. No configuration, new entitlement or dependency is needed.
- The three new PNG illustrations are lossless format conversions of existing Android WebP artwork. Their source pixels and composition were not redesigned.

## Verification

- Windows Core Debug: **550/550 XCTest cases passed**, including 12 new request/link/markup/security/compatibility tests. The separate Swift Testing runner reports zero tests because this package's cases use XCTest.
- Windows Core clean Release build and tests: **550/550 passed**. Existing Windows SDK test-stub Sendable warnings and a `.build/release` symlink warning remain; neither prevented compilation or test execution.
- `validate-workspace.ps1`: passed, including Swift/project audit, static accessibility checks, basic secret scan, resource parsing and backend PHP syntax checks.
- Swift `-frontend -parse` with and without `-D DEBUG`: passed for changed/new Swift sources. This is syntax validation, not Apple SDK type checking.
- macOS runner: Bash syntax passed; the script itself was not executed on macOS. It requires exactly eight passing native/UI cases per device and exports attachments for visual review.
- Protected-file check: **241 checked / 0 changed**.
- Evidence logs and hash manifest: `artifacts/android-design-20261115/`.

## Native verification still required

Windows has no `xcodebuild` or `xcodegen`. The SwiftUI target has not been compiled or rendered in this session. No new iOS screenshot, signed IPA or TestFlight build was produced. App Store readiness and actual device smoothness are not claimed.

`Scripts/reading-room-macos.sh` prepares clean Development/unsigned Production builds and targeted native/UI checks on two iPhones plus an iPad, exporting screenshots. It covers the welcome layout at narrow/wide widths and large text, the inbox/native-book action, membership-sheet dismissal, exhausted allowance in large dark text, existing conversation composer, equal agenda-card dimensions, both orientations and agenda photo navigation. Execute and inspect its XCTest screenshots before shipping.

The Android work also included backend message attachment/pagination changes and a web-only premium-member sidebar. Those are not part of this visual iOS pass. Public first-party image links are supported; authenticated private attachments have not been added. No deployment or real purchase was attempted.
