# General iOS app review — 2026-09-28

Review scope: authentication/session refresh, navigation/deep links, notification synchronization, offline downloads/export, catalog/directory/member loading, library/book detail, reader integration, and existing assistant/wheel state handling. Existing reader work was preserved. This was a source review and Windows validation pass, not a complete iOS device audit.

## Confirmed defects corrected

| Trigger and previous failure | Correction |
|---|---|
| A successful token refresh is followed by a resource 403. The client signed the member out unnecessarily. | Refresh failure and resource permission failure are separate. A repeated 401 still expires the matching session. |
| A refresh finishes after sign-out or another account signs in. The old response could restore/overwrite credentials; an old rejection could clear the next account. | Keychain operations are actor-isolated. Refresh commits/clears only if the stored session still matches its initiating session. Superseded responses are canceled; replay stays bound to the rotated session. Parallel requests share refresh work, including late 401 responses. |
| Profile/statistics/count responses arrive after account invalidation/switching and repopulate old information. | Session-generation guards discard stale responses and callbacks. Library refresh checks the session around its existing synchronization wait. Purchase-status fetching gains the same response guard; purchase execution/configuration is unchanged. |
| Notification-read retries wait while the account is cleared, then send remaining old targets under the next account or publish stale counts. | Clearing invalidates the retry generation. Later counts are discarded and remaining old targets are not sent. |
| Logout/removal happens during download; an old completion recreates the removed offline book. | Each download has an operation ID and cancellable task. It writes to a unique staging directory and can become the offline file only while active. Late progress/completions are ignored and staging files are cleaned up. |
| Repeated taps start duplicate downloads; failure deletes the common destination, including a valid existing copy. | One active transfer per book, guarded preparation, isolated staging, and reuse of a validated copy prevent duplicate transfer/removal. Book-detail continuations stop after account changes. |
| DownloadsView observes only AppContainer; child download-state changes do not reliably redraw it and progress remains 0%. | It now observes DownloadManager directly and displays actual progress. Unknown lengths show transferred bytes without an invented percentage. Removed rows disappear immediately. |
| A slow catalog/member/directory query finishes after a newer search/filter request and replaces new results or appends unrelated rows. | Latest-request guards protect results, pagination, errors and loading flags. Additional pages cannot start during a reset. |

## Executed evidence

- `Scripts/swift-test-windows.ps1`: **293 XCTest tests passed**, including six new session-refresh regressions: resource 403, sign-out during refresh, account switching during successful/rejected refresh, repeated 401, and late parallel 401. Existing reading-position, download policy, routing, assistant, wheel and purchase-policy tests ran in the same suite. Log: `.codex-artifacts/general-review/core-tests.log`.
- Fresh-scratch `swift build -c release`: core library compiled successfully. Windows emitted a convenience symlink warning after compilation; this is not an iOS app release build. Log: `.codex-artifacts/general-review/core-release.log`.
- `Scripts/validate-workspace.ps1`: passed, including static Swift/accessibility checks, basic secret scan, API/configuration contracts and PHP syntax. Log: `.codex-artifacts/general-review/workspace-audit.log`.
- Swift frontend parsed all **88 app/native-test Swift sources** with DEBUG enabled. This validates syntax, not Apple SDK types. Log: `.codex-artifacts/general-review/syntax.log`.
- SHA-256 baseline check: **160 protected backend, purchase/configuration and reading-position files unchanged**. Log: `.codex-artifacts/general-review/protected-check.log`.
- `git diff --check`: passed.

Eight native regressions were added: four download lifecycle/progress tests, two notification-read invalidation tests and two delayed session-response tests. They use injected transfers, sessions or response gates; they do not contact production or perform purchases. Existing `project.yml` source directories include them automatically.

## Limits and release checks

Xcode, the iOS SDK and Simulator are unavailable on this Windows host. The eight new native tests, native clean/Production builds and device UI tests have **not** run. Search-result ordering was reviewed in source; visual interaction still requires device checks. No claim is made that the entire application is error-free or App Store-ready.

On macOS, run all native tests, including `SessionResponseIsolationTests`, `NotificationReadSyncServiceTests`, `DownloadManagerTests` and the reader tests in [READER_EXPERIENCE_VALIDATION.md](READER_EXPERIENCE_VALIDATION.md). Verify account switching, token expiry, unread counts, interrupted/removal-during-download, repeated taps, export, rapid filter changes, continue reading, and the existing purchase flow using its unchanged configuration. No release or backend deployment was performed.

MobileApi/IosApi server code and endpoint contracts are unchanged. `APIClient` changes concern iOS-side response/credential lifecycle handling. Tokens remain in Keychain; no new tracking, retained personal-data category, entitlement, dependency or StoreKit setting was added. Temporary download files remain under protected, backup-excluded application storage.
