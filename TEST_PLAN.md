# Test Plan

## Unit Tests
- API endpoint construction.
- API response decoding.
- Site statistics endpoint construction and current XenForo payload decoding.
- Error mapping.
- Auth state transitions.
- Token refresh loop prevention.
- Reading progress calculations.
- Reader bookmark add/remove, per-book separation, ordering and persistence encoding.
- Download state transitions.
- Search filter request building.
- Deep-link parsing.
- Account deletion state.
- Purchase state mapping.

## Integration Tests
- Login against public staging.
- Run `Scripts/api-smoke-test.ps1` against public staging.
- Session restoration.
- Book list/detail/search.
- Mobile book detail route `GET /mobile-api/v1/book-detail/{thread_id}`.
- Reader access/session/progress.
- Reader progress and library mutation smoke checks with a disposable authenticated staging account.
- Reader and offline download flows must use `reader/session` source URLs, not persistent web `pdfUrl` values.
- Download and corrupted download handling.
- Forum permission checks.
- Content reporting and user blocking.
- StoreKit sandbox purchase/restore.
- App Store signed transaction verification with Apple root certificate configured.
- App Store Server Notification v2 signed payload verification with Apple root certificate configured.
- Account deletion request.

## UI Tests
- Launch/login.
- Register with password confirmation and required legal acceptance; verify invalid and duplicate account errors do not leave authentication loading.
- Request password reset for both existing and unknown addresses and verify the same privacy-preserving success text.
- Browse catalog.
- Toggle catalog list/grid presentation, relaunch, and verify the preference persists; verify HTTPS covers and missing-cover placeholders in both modes.
- Verify home statistics load, pull-to-refresh, compact number formatting and retry state.
- Search.
- Open book detail.
- Read PDF.
- Open representative reflowable and fixed-layout EPUB files, navigate across chapters, rotate the device, background/foreground the app, and verify XenForo progress updates.
- Reject an HTML/error response disguised as EPUB, an invalid ZIP, an HTTP source URL, and an unsupported reader-session file type.
- Resume reading.
- Bookmark.
- Confirm page number and percentage update while scrolling.
- Add multiple bookmarks, reopen the reader, and verify they persist only for that book.
- Select a bookmark and verify the reader jumps to the saved page; swipe-delete one and verify removal.
- Offline state.
- Report/block.
- Logout.
- Start account deletion.
- Purchase/restore if applicable.

## Manual Device Matrix
- Small iPhone.
- Standard iPhone.
- Large iPhone.
- iPad only if supported.
- Portrait, dark mode, large Dynamic Type, VoiceOver, poor network.
- Turkish localization review for every visible screen before App Store screenshots are captured.

## Commands
On macOS:

```bash
./Scripts/validate-workspace.ps1
./Scripts/swift-static-audit.ps1
./Scripts/api-smoke-test.ps1 -BaseUrl https://staging.ekitapligim.com/mobile-api/v1/
./Scripts/api-smoke-test.ps1 -BaseUrl https://staging.ekitapligim.com/mobile-api/v1/ -BearerToken "$EKITAPLIGIM_REVIEW_BEARER_TOKEN"
./Scripts/api-smoke-test.ps1 -BaseUrl https://staging.ekitapligim.com/mobile-api/v1/ -BearerToken "$EKITAPLIGIM_REVIEW_BEARER_TOKEN" -ExerciseMutations
./Scripts/appstore-preflight.ps1
swift test
xcodegen generate
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim -clonedSourcePackagesDirPath .build/xcode-packages
xcodebuild -scheme Ekitapligim -configuration Debug build
xcodebuild -scheme Ekitapligim -configuration Release -destination generic/platform=iOS build
xcodebuild test -scheme Ekitapligim -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Current Workspace Verification
- `Localizable.xcstrings` JSON validation passed in this Windows workspace.
- Swift 6.3.3 and Visual Studio Build Tools are installed in this workspace. `Scripts/swift-test-windows.ps1` built the portable core package and passed all 72 tests on `x86_64-unknown-windows-msvc`.
- `xcodebuild` is not installed in this workspace, so simulator, archive, and UI tests were not executed here.
- Executed unit tests cover endpoint construction, authenticated request headers, form body construction, redacted logging, reading progress, deep links, release URL validation, DTO decoding, download policy, bookmarks, and content safety.
- Added catalog endpoint coverage for category, author, publisher, ISBN, rated ordering, and premium-only query construction. Native catalog pagination de-duplicates appended books.
- Added unit test sources for Apple auth endpoint construction, UGC safety endpoint construction, and App Store verification endpoint construction.
- Added unit test sources for forum endpoint construction and download state behavior.
- Added unit test sources for library update and account deletion re-auth request construction.
- Added unit test sources for profile read/update and notification endpoint construction, including the authenticated profile form body.
- Added unit test source coverage for reader-progress backend parameter names.
- Added unit test source coverage for the dedicated mobile book-detail route.
- Added model decoding coverage for reader session source URLs.
- Added unit test source coverage for persistent per-book reader bookmarks, duplicate removal, sorting and JSON round trips. Native PDFKit page-change observation now drives live progress and bookmark navigation.
- Added book-detail envelope decoding coverage for `similar_books`, plus native navigation to each decoded related book.
- Added required String Catalog key checks for reader, book-detail, tab bar, home, login, settings/account, catalog, library, downloads, community, block/unblock, notifications, profile, forum threads/detail, account deletion, privacy, content reporting, and community-terms visible strings.
- Added unit test sources for terms endpoint construction and basic UGC content-safety filtering.
- Added unit test sources for book list, forum list/thread/post JSON decoding, including legacy responses without optional iOS fields and pagination fallback from nested `pagination`.
- Added unit test sources for direct profile responses, auth, terms, success envelopes, billing verification, blocked members, and forum reply envelope decoding against current backend response shapes.
- Success-envelope decoding now covers empty JSON object fallback for older or minimal backend success responses.
- `Scripts/validate-workspace.ps1` now falls back to `C:\xampp\php\php.exe` when `php` is not on `PATH`; recursive PHP syntax lint passed for all `Backend/MobileApi-addon/**/*.php` scaffold files in this Windows workspace.
- `Backend/MobileApi-addon/routes-fragment.xml` XML parsing passed in this Windows workspace.
- `App/Ekitapligim/Support/Info.plist` XML parsing passed in this Windows workspace.
- Static text scan found local/HTTP strings only in documentation, negative release-guard tests, and `AppConfig` release validation logic; not in production `.xcconfig` values.
- `App/Ekitapligim/Support/Ekitapligim.entitlements` XML parsing passed in this Windows workspace.
- `App/Ekitapligim/Support/PrivacyInfo.xcprivacy` XML parsing passed in this Windows workspace.
- `App/Ekitapligim/StoreKit/Ekitapligim.storekit` JSON parsing passed in this Windows workspace.
- `xcodegen` is not installed in this Windows workspace, so `xcodegen generate` was not executed here.
- `Scripts/validate-workspace.ps1` executed successfully in this Windows workspace. It checked required files, XML/plist parsing, JSON parsing, production URL safety, entitlement scope, Swift release markers, Swift static audit, SwiftUI accessibility audit, obvious secrets, backend PHP syntax, and optional tool availability.
- Release configuration validation now normalizes Xcode `.xcconfig` URL escaping before checking the Production API URL, and both workspace validation and App Store preflight reject broad App Transport Security arbitrary-load exceptions.
- After adding terms acceptance, App Store Server Notification scaffolds, and the XAMPP PHP fallback, `Scripts/validate-workspace.ps1` executed successfully again. PHP syntax passed for every backend scaffold PHP file.
- `Scripts/swift-static-audit.ps1` is included for Xcode-free checks of unsafe force operations, UIKit-backed imports, package paths, project resource references, and accidental local/insecure runtime URLs.
- `Scripts/ui-accessibility-audit.ps1` is included for Xcode-free checks of icon-only button labels, multi-line text editor labels, and populated localization resources.
- `Scripts/generate-placeholder-appicon.ps1` executed successfully and generated `App/Ekitapligim/Assets.xcassets/AppIcon.appiconset`.
- `Scripts/appstore-preflight.ps1 -AllowPlaceholders` executed successfully; placeholders remain for Apple Team ID and reviewer account and must be replaced before strict preflight.
- `Scripts/apply-mobileapi-ios-patch.ps1` executed successfully against the local XenForo `Ekitapligim/MobileApi` addon, upgraded it to `1.0.74`, imported route and CLI data, passed PHP syntax checks, and created `Backend/packages/Ekitapligim-MobileApi-iOS-1.0.74.zip`.
- Disposable account deletion runtime test: local registration created user 32, the app API created request 2, dry-run changed no data, guarded execution deleted the user, revoked all active sessions, scrubbed request username/email/reason/password evidence, marked it completed, and drained the XenForo cleanup job. Local SMTP was unavailable, so completion-mail delivery remains a staging test.
- Premium UI tests must cover StoreKit product loading, localized price display, purchase pending/cancel/success, backend rejection, no-entitlement restore, verified restore, Manage Subscriptions, and Terms/Privacy links.
- Purchase verification policy tests reject backend-inactive and expired entitlements while accepting active renewable/lifetime responses. MobileApi `1.0.82` defaults to the exact shipped product allowlist; disposable user `55` proved an unlisted product is rejected with HTTP 400 before JWS verification and no test account/session/PII remains.
- The StoreKit service starts `Transaction.updates` observation only for an authenticated app session and cancels it on logout. Verified supported updates are synchronized with XenForo before `finish()`; inactive server-verified updates are recorded and finished, while signature/network/backend failures remain unfinished for StoreKit redelivery. Ask to Buy and background-completion execution still require Apple sandbox.
- MobileApi `1.0.83` notification tests exercise entitlement mutation below the already-audited JWS layer: a matching revoke transaction deactivated a temporary entitlement, an unlisted product was rejected, exact/newest-row targeting avoided duplicate transaction IDs, and cleanup left zero test entitlement rows. Real signed Apple Server Notification delivery remains required on sandbox staging.
- Account deletion tests must confirm the 30-day disclosure and that a second request returns the existing pending request instead of creating a duplicate.
- Read-only catalog runtime checks passed for author, ISBN, category, popular ordering, and premium-only filtering. Premium filtering now fails closed with zero results when the optional backend premium column is absent.
- Related-book runtime validation passed for a local catalog detail: eight visible same-category books were returned, the current book was excluded, and the iOS detail envelope accepts both snake_case and camelCase field names.
- Profile editing runtime checks passed locally: authenticated GET returned all editable fields, a no-op authenticated POST preserved values, and unauthenticated, invalid-URL, and oversized submissions were rejected without mutating stored profile data. The public bridge currently maps unauthenticated controller exceptions to HTTP 400 rather than 401.
- Revocable-session runtime smoke checks passed: access/refresh issuance, authenticated profile access, refresh rotation, rejection of both old tokens, acceptance of the refreshed access token, rejection of legacy `xf_user` bearer values, logout revocation, and rejection after logout.
- API client test source covers refresh endpoint construction; authenticated 401 handling coordinates one refresh, saves the rotated pair through `SessionTokenManaging`, retries once, and clears an invalid session to prevent loops. Execution still requires Xcode/Swift.
- Download policy tests cover safe names, path traversal rejection, unsupported formats, PDF signature validation, disguised HTML rejection, and EPUB ZIP signatures. The iOS app test target covers Application Support backup exclusion and unsafe local paths; execution still requires Xcode.
- EPUB rendering uses Readium Swift Toolkit pinned to `3.9.0`. The reader downloads the temporary signed source over HTTPS, checks the HTTP status and ZIP signature, applies iOS file protection, excludes the session directory from backup, and removes the temporary publication when the reader model is released.
- Directory endpoint tests cover author/publisher query construction and nested book routes. Model tests cover the current XenForo directory/pagination payload, while the local API smoke test passed author and publisher list-to-books traversal.
- Book-request tests cover public list decoding, create/vote authentication requirements, vote response decoding, oversized-input rejection, and unauthenticated write rejection. Public list smoke passed locally; authenticated create/vote mutation remains for the dedicated reviewer test account to avoid altering production-like local data.
- Conversation tests cover authenticated list/detail/create/reply endpoint construction and current detail/message decoding. Local list/detail smoke passed with private bodies suppressed from output; empty and unauthenticated write attempts were rejected.
- My-comments tests cover authenticated `me/comments` page construction and decoding of the current XenForo payload, including numeric `thread_id` compatibility. The native screen supports paging, refresh, empty/error states, and thread navigation; local unauthenticated access returned HTTP 401 as required.
- Disposable local user `51` proved the authenticated empty-history response and pagination contract. Guarded deletion request `21` then removed the user, revoked all active sessions, marked the request completed, and scrubbed retained PII/password evidence; local SMTP delivery remains a staging-only check.
- Disposable local user `53` proved the populated history path: after terms acceptance, forum reply `15609` appeared in `me/comments` with thread `11177` and total `1`. XenForo services then hard-deleted the post and account; database verification found no post, user, active session, or disposable-account residue, and deletion request `22` retained no PII/password evidence.
- Notification routing tests cover trusted native routes, same-host web URL fallback, content-ID fallback for forum alerts, and rejection of foreign hosts/unknown routes. The native notification row marks unread alerts, refreshes counts, and opens book, thread, forum, directory, or request destinations.
- Universal-link tests cover `ekitapligim.com` and `www.ekitapligim.com` book, thread, forum, author, publisher, and request URL families plus foreign-host rejection. Static validation requires `RootView.onOpenURL`, `DeepLinkParser`, and centralized `AppContainer.open(route:)` wiring; signed-device associated-domain resolution remains an Xcode/TestFlight gate.
- Member tests cover list/search/sort construction, collision-free profile/follow routes, current list decoding, public list/profile smoke, and unauthenticated follow rejection.
- Book-comment tests cover list/create endpoint construction, current pagination/comment decoding, public list smoke, and rejection of unauthenticated or empty writes. Each rendered comment exposes the existing authenticated post-report flow.
- `Scripts/api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -AllowInsecure` passed locally: `books?page=1`, selected `book-detail/{id}`, `forums`, a selected `forums/{id}/threads?page=1`, a selected `threads/{id}/posts?page=1`, and `book-stats` returned successfully; authenticated endpoints were skipped without a bearer token.
- Authenticated local smoke with a disposable account and random `ms_at_` token passed forum traversal, profile, library, subscription, terms, notification counts, conversations, reader progress/session, and library mutation.
- A disposable account passed successful profile editing and password rotation: both old tokens and the old password were rejected, while the returned session and new password authenticated; account deletion then left zero active sessions.
- A disposable account passed successful email mutation with the local confirmation-disabled configuration: the new address persisted, IP auditing was recorded, login/profile loading continued, and both old/new notice attempts reached the unavailable local SMTP transport.
- Refresh rotation returned a new token pair; both old tokens returned HTTP 401, while the refreshed access token remained valid.
- Local negative billing check passed: malformed App Store JWS input was rejected with HTTP 400, proving the endpoint fails closed instead of granting premium for unverifiable purchases.
- Local entitlement wiring check passed: a temporary active iOS entitlement row for non-premium `xf_user:3` changed `me/subscription` to premium with expiration, and cleanup returned the user to member.
- Local negative Apple login check passed: JWT-shaped input with unknown Apple `kid` was rejected with HTTP 400.
- Local account deletion request check passed: authenticated request created a pending server-side deletion request row and the test row was cleaned up.
- Local UGC terms gate check passed: reply posting was rejected with HTTP 403 when the authenticated user had not accepted the current community terms.
- UGC safety smoke previously verified block/unblock, blocked-members visibility, terms acceptance, and unauthenticated reply rejection. Its next staging run must use a random `ms_at_` token; legacy bearer values are no longer accepted.
- `.github/workflows/ios-ci.yml` now runs Windows source validation, App Store preflight with placeholders allowed, XcodeGen generation, `swift test`, and unsigned Development/Production iOS builds on macOS.
- The macOS CI job explicitly selects Xcode 16.4, resolves packages once, verifies Readium is exactly `3.9.0` in `Package.resolved`, disables automatic resolution during test/build, executes both unit and UI test targets, performs a clean Production build, and uploads XCTest/package-resolution evidence.
- Privacy manifest validation now checks no-tracking declaration, App Store data type coverage, and required-reason API entries for UserDefaults and file timestamps.
