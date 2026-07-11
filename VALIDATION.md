# Validation

## Local Windows Validation

Run:

```powershell
.\Scripts\validate-workspace.ps1
```

This validates source files that do not require Xcode. It does not prove the iOS app compiles.

Latest local result in this workspace: passed. It includes the Swift static audit, SwiftUI accessibility audit, privacy manifest checks, release-configuration checks, and backend PHP syntax checks. `Scripts/validate-workspace.ps1` falls back to `C:\xampp\php\php.exe` when `php` is not on `PATH`, and it linted all `Backend/MobileApi-addon/**/*.php` scaffold files successfully. Xcode and XcodeGen remain unavailable on Windows.

`Scripts/swift-test-windows.ps1` loaded Swift 6.3.3 with the Visual Studio x64 toolchain, built `EkitapligimCore`, and passed all 72 unit tests. This run exposed and fixed portable compilation issues plus legacy XenForo numeric `nodeId` decoding. It does not compile the SwiftUI app or Apple-only frameworks; those remain macOS/Xcode gates.

Public HTTPS verification on 2026-07-11 confirmed the configured support, privacy-policy, and terms/community-rules pages return HTTP 200. Production `GET /mobile-api/v1/books?page=1` and `GET /.well-known/apple-app-site-association` return HTTP 404, so public backend and universal-link deployment remain release blockers. `Scripts/public-release-audit.ps1` now verifies these surfaces, JSON/content types, and the real Team ID plus bundle ID after deployment.

`Scripts/prepare-public-deployment.ps1` was exercised with a non-production test Team ID. It validated the XenForo archive layout, generated a placeholder-free AASA app identifier, rejected an invalid Team ID and an existing output directory, and reproduced MobileApi `1.0.84` SHA-256 `2490668F8F113C495DFD532A569F6394AAC458713C9B4E34D79B48D6C9D2DA80`. The generated verification directory was removed after inspection.

Android parity review found the authenticated `MyCommentsScreen.kt` flow missing from iOS. Native `MyCommentsView` now loads paginated `GET me/comments`, handles refresh/empty/error states, and opens the corresponding forum thread. The endpoint contract increased to 49 paths, local unauthenticated access returned HTTP 401, and Swift decoding now accepts XenForo's numeric or string post/thread identifiers. All 74 portable core tests pass.

Notification parity now follows Android's target-routing behavior. `DeepLinkParser` accepts only known native routes or same-host Ekitapligim URLs, prefers the backend `app_route`, falls back to `target_url`, and uses `content_id` only for recognized forum alert types. Notification taps mark unread alerts, refresh counts, and open native book/thread/forum/directory/request destinations; foreign hosts and unknown routes fail closed. Together with Universal Link family coverage, the portable core suite now contains 78 passing tests.

Universal Link application handling is now connected rather than entitlement-only. `RootView.onOpenURL` parses recognized Ekitapligim URL families and delegates to the same centralized route presenter used by notifications; base routes select a tab and content routes open a native NavigationStack sheet. The static audit fails if this wiring is removed. Associated-domain delivery itself still requires the public AASA deployment and signed-device evidence.

Authenticated `me/comments` runtime validation used disposable local user `51`: registration issued a random `ms_at_` mobile session, `GET /mobile-api/v1/me/comments?page=1` returned the expected empty `items` collection and pagination page `1`, and account-deletion request `21` was accepted with password re-authentication. The guarded CLI completed deletion; verification found zero user rows, zero active sessions, state `completed`, and zero-length username/email/reason plus cleared password-verification evidence. The completion email reached the mail path but could not be delivered because local SMTP remains unavailable.

Populated comment-history runtime validation then used disposable local user `53`. The user accepted the current community rules, created visible forum reply `15609` in thread `11177`, and `GET me/comments?page=1` returned that exact post/thread with pagination total `1`. Cleanup hard-deleted the post through XenForo `Post\DeleterService`, completed account-deletion request `22`, and verified zero post rows, user rows, active sessions, or matching disposable accounts. The retained request is completed with username/email/reason and password-verification evidence scrubbed. A deliberately selected closed thread rejected an earlier write as expected; its temporary account was also removed with XenForo `User\DeleteService`.

Additional backend-response decoding coverage has been added for books pagination, direct profile responses, auth, terms status, success envelopes, billing verification, blocked members, and forum reply envelopes. Success-response decoding now tolerates `{}`, `{ "success": true }`, detailed success envelopes, and empty HTTP bodies for endpoints that may return 204-style responses. This reduces the risk of a successful HTTP response failing in the iOS data layer.

`Scripts/apply-mobileapi-ios-patch.ps1` was tested against the local XenForo `Ekitapligim/MobileApi` addon at `C:\xampp\htdocs\ekitapligim\src\addons\Ekitapligim\MobileApi`; it upgraded the local addon to `1.0.84`, imported route and CLI data, passed PHP syntax checks, and created `Backend/packages/Ekitapligim-MobileApi-iOS-1.0.84.zip` (SHA-256 `2490668F8F113C495DFD532A569F6394AAC458713C9B4E34D79B48D6C9D2DA80`).

MobileApi `1.0.84` makes account-deletion submission durable across Apple outages and requires password re-authentication for password-only accounts. Disposable user `56` proved a missing password returns HTTP 400 with no request row; after a temporary Apple authorization was attached, passwordless deletion was accepted as request `24` with `apple_revocation_pending=true` and zero active sessions despite unavailable local Apple configuration. After simulating successful revocation, the guarded CLI completed deletion and verification found zero user/session/disposable-account rows plus fully scrubbed request PII/password evidence. Static validation also enforces request-before-remote-revoke and revoke-before-user-delete ordering.

The native deletion success path now mirrors the server-side session revocation immediately. `DeleteAccountView` calls `AppContainer.requestAccountDeletion`; only after the server accepts the durable request, the container stops StoreKit observation, clears the Keychain session, drops any presented route, selects Account, and sets auth state to signed out. The form clears its password and disables duplicate submission while retaining the success notice. Workspace validation fails if this centralized teardown is bypassed.

MobileApi `1.0.83` makes App Store Server Notifications match the documented entitlement behavior. After outer/nested JWS verification it validates bundle, allowlisted product, environment, and transaction identifiers, records the notification and updates only the exact transaction row or newest matching original-transaction row in one database transaction. A temporary entitlement runtime test proved a revoke payload changes `active` from `1` to `0`, an unlisted product is rejected, and zero `ios-notification-*` test rows remain afterward. Real Apple notification delivery/certificate evidence remains a sandbox gate.

MobileApi `1.0.82` makes the App Store product allowlist fail closed: when `EKITAPLIGIM_IOS_PRODUCT_IDS` is absent, only the shipped monthly/yearly identifiers are accepted. Disposable user `55` proved an unlisted product returns HTTP 400 before JWS processing and receives no entitlement; deletion request `23` then removed the user/session and scrubbed all retained PII. The iOS client now also requires backend `success=true`, `isPremium=true`, and a future expiration when present before finishing a StoreKit purchase or displaying premium success. Four policy tests bring the portable suite to 82 passing tests.

StoreKit transaction observation now covers pending approval and out-of-app completions through `Transaction.updates`. Observation starts after a Keychain session is restored or login succeeds and stops before logout token clearing. Supported verified updates are posted to XenForo before finishing; server-verified inactive updates are recorded then finished, while unverified or unsynchronized updates deliberately remain unfinished for redelivery. Static validation requires the observer and both auth-lifecycle hooks; real Ask to Buy delivery remains an Apple sandbox gate.

Native catalog filtering now covers category, author, publisher, ISBN, premium-only, latest, popular, and rated order together with paginated loading. Read-only local runtime checks passed for author and ISBN matching, category node isolation, descending popular view counts, and premium-only filtering. The test exposed and fixed a fail-open backend case: when `ebook_premium_only` is absent, `premium_only=1` now returns an empty result rather than non-premium books.

Native book detail now decodes and displays the backend `similar_books`/`similarBooks` collection with navigation to each related title. Local runtime validation on book `15585` returned eight same-category books, excluded the current book, and stayed within the backend limit.

Native profile editing now covers about, location, HTTP/HTTPS website, and activity visibility. Local runtime checks verified authenticated GET, an authenticated no-op POST, rejection of invalid website and oversized about values, rejection of unauthenticated writes, and preservation of stored values after all negative tests. The public bridge returns HTTP 400 for its unauthenticated controller exception; the request is still denied and no profile data is changed.

Mobile session runtime checks passed locally over HTTP after installing `1.0.60`: random `ms_at_`/`ms_rt_` issuance authenticated `/me`; refresh returned a new pair; the previous access and refresh tokens were rejected; the refreshed access token worked; legacy `xf_user:1` was rejected; logout succeeded; and the logged-out access token was rejected. Tokens were redacted from command output. The iOS API client now performs one coordinated refresh after an authenticated 401, persists the rotated session in Keychain, retries once, and clears invalid sessions to prevent refresh loops.

The backend patch now adds `GET /mobile-api/v1/book-detail/{thread_id}` as the iOS book-detail endpoint. Local route rebuild and runtime checks confirmed it returns the existing `Book` controller JSON payload, while avoiding the web book URL route family that caused `GET /mobile-api/v1/books/{id}` to fall through to an HTML 404 page.

StoreKit transaction and App Store Server Notification controllers include JWS signature and certificate-chain verification logic. Runtime verification requires `EKITAPLIGIM_APPLE_ROOT_CA_FILE` or `EKITAPLIGIM_APPLE_ROOT_CA_PEM`; without that configured, signed purchase verification deliberately fails closed.

Local negative billing check passed: `POST /mobile-api/v1/billing/app-store/verify` with bearer token and malformed `signed_transaction=not.a.validjws` returned HTTP 400 and did not grant premium state.

Local entitlement wiring check passed: a temporary active row in `xf_ekitapligim_mobile_appstore_entitlement` for non-premium `xf_user:3` changed `GET /mobile-api/v1/me/subscription` from `member/isPremium=false` to `premium/isPremium=true` with a 30-day expiration; deleting the row returned the user to `member/isPremium=false`.

Local negative Apple login check passed: a JWT-shaped token with `alg=RS256` and an unknown `kid` returned HTTP 400 `Apple identity token could not be verified`, proving unsigned/unknown-key Apple tokens fail closed instead of logging in.

Local account deletion request check passed: authenticated `xf_user:3` posted `POST /mobile-api/v1/me/account-deletion-request`, received success with a request ID, and `xf_ekitapligim_mobile_account_deletion_request` contained a pending row. The test row was deleted after verification.

Local UGC terms gate check passed: after deleting `xf_user:3` terms acceptance, `POST /mobile-api/v1/threads/1/posts` returned HTTP 403 `Topluluk kurallarını kabul etmeden cevap yazamazsınız.` before any reply was created.

`Scripts/ugc-safety-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -BearerToken "xf_user:3" -BlockedUserId 4 -ThreadId 1 -AllowInsecure` passed locally. It verified block/unblock, `me/blocked-members`, terms acceptance round-trip, and unauthenticated reply rejection.

GitHub Actions workflow `.github/workflows/ios-ci.yml` is configured for Windows source validation and macOS unsigned iOS build/test validation using XcodeGen, `swift test`, and `xcodebuild ... CODE_SIGNING_ALLOWED=NO`. YAML parsing passed locally for `.github/workflows/ios-ci.yml` and `project.yml`.

Privacy manifest coverage check now runs in `Scripts/validate-workspace.ps1`. It verifies no tracking is declared and that email address, user ID, product interaction, purchase history, user content, file timestamp reason API, and UserDefaults reason API entries remain present.

Release configuration checks now normalize Xcode `.xcconfig` URL escaping such as `https:/$()/...` and verify the Production API resolves to `https://ekitapligim.com/mobile-api/v1/`. Both `Scripts/validate-workspace.ps1` and `Scripts/appstore-preflight.ps1` also fail if `Info.plist` enables broad App Transport Security arbitrary-load exceptions.

SwiftUI accessibility coverage check now runs in `Scripts/validate-workspace.ps1`. It verifies icon-only buttons have accessibility labels or equivalent semantics, multi-line text editors have explicit labels, and localization resources remain present.

Visible SwiftUI strings across the current app screens now resolve through `EkitapligimCore.L10n` and `Localizable.xcstrings`, including reader, book detail, tab bar, home, login, settings/account, catalog, library, downloads, community, block/unblock, notifications, profile, forum threads/detail, account deletion, privacy, content reporting, and community terms. `Scripts/ui-accessibility-audit.ps1` verifies representative required localization keys remain present. A final human Turkish copy review is still required before App Store screenshots are captured.

Reader/download safety now runs in `Scripts/swift-static-audit.ps1`. The app must request authorized `reader/session` source URLs for reading and offline download instead of using persistent `book.pdfUrl` web links directly.

The native PDF reader now observes PDFKit page changes, updates visible progress, persists book-scoped bookmarks in local preferences, and supports direct navigation and deletion from a native bookmark sheet. Core bookmark rules have XCTest source coverage; interactive PDFKit behavior still requires the macOS simulator/device gate.

Offline download hardening is now implemented: safe book identifiers prevent path traversal, only PDF/EPUB file types are accepted, downloaded headers are validated before persistence, failed destinations are cleaned up, the directory and files use complete-until-first-authentication protection, and both are excluded from backup. Cross-platform policy tests were added under `Tests/EkitapligimCoreTests/DownloadFilePolicyTests.swift`; iOS sandbox backup-exclusion tests were added under `App/EkitapligimTests/DownloadManagerTests.swift` and wired into the Xcode scheme. These tests still require macOS/Xcode execution.

`Scripts/api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -AllowInsecure` passed locally for public unauthenticated endpoints after the XenForo addon patch, including books, book detail, forums, a forum thread list, a thread post list, and book stats.

The native home screen now consumes `GET /book-stats` through a typed repository. The current local XenForo response was checked directly and returned 14,404 books, 7,131 authors, 1,564 publishers, and 32 categories; endpoint and payload decoding XCTest sources cover the same contract. Interactive loading, pull-to-refresh and retry behavior still require the macOS UI test gate.

Native registration and password-reset modes are now reachable from the login sheet. Registration requires matching passwords and explicit legal/privacy acceptance; failed login, Apple login, or registration restores signed-out state instead of leaving the app authenticating. Local negative runtime checks confirmed an empty registration is rejected with HTTP 400 and a reset request for an unknown randomized address returns a generic success response without account disclosure. A successful reviewer-account registration remains a public HTTPS staging test to avoid creating disposable users in production-like local data.

Re-authenticated email and password routes are installed locally through MobileApi `1.0.66`. Both routes reached their controllers and rejected a deliberately incorrect existing password with HTTP 403; the profile email remained unchanged. Confirmation-link completion and real mail delivery remain public staging tests because local `registrationSetup.emailConfirmation` is disabled and SMTP is unavailable.

A disposable local account now proves the successful profile and password-change path. User `45` updated about, location, HTTPS website, and activity visibility; password change returned a distinct access/refresh pair, the old access and refresh tokens both returned HTTP 401, the rotated access token loaded the persisted profile, the old password was rejected, and the new password authenticated. Account-deletion request `15` removed the user and scrubbed request PII. All three issued mobile sessions had non-zero `revoked_date` values and active-session count was zero after deletion.

Disposable user `50` proves the successful email-change mutation under the current local XenForo configuration. The authenticated endpoint persisted the new unique address, retained `user_state=valid`, returned `confirmation_required=false` because `registrationSetup.emailConfirmation=false`, wrote the `email_change` IP audit, and allowed login/profile loading with the changed address. XenForo attempted notices to both old and new addresses; error-log entries `50` and `52` reached the configured transport and failed only because no SMTP service listens on `localhost:25`. Account-deletion request `20` removed the user, confirmation/IP rows, and active sessions.

The native catalog now supports a persistent list/adaptive-grid preference. Both presentations use stable 2:3 cover geometry, load only HTTPS cover assets, expose missing/failed-image placeholders, retain pagination, and keep icon-only view switching accessible. Interactive layout verification across iPhone/iPad sizes remains part of the macOS simulator screenshot gate.

EPUB support is integrated through Readium Swift Toolkit `3.9.0`, pinned exactly in `project.yml` with only Shared, Streamer, and Navigator products. The reader consumes the authorized `reader/session` source URL, requires HTTPS, downloads to a temporary cache, verifies an EPUB ZIP signature, applies complete-until-first-authentication protection, excludes the cache from backup, renders reflowable/fixed-layout publications through Readium's EPUB navigator, and reports locator progression to XenForo. The dependency API was checked against the official `3.9.0` tag and its Playground/UI-test examples; package resolution, compilation, rendering and rotation evidence still require macOS/Xcode.

The first 50 books returned by the current local catalog did not expose a `file_type` field and no EPUB sample was identifiable from that public payload. A rights-cleared reflowable EPUB and fixed-layout EPUB must therefore be added to the dedicated staging reviewer data before the device matrix can prove real-content rendering.

The macOS CI gate now selects and verifies Xcode 16.4, resolves Swift packages into a fixed clone directory, asserts Readium `3.9.0` from the generated `Package.resolved`, disables automatic package resolution for subsequent test/build commands, runs both unit and UI test targets, performs a clean unsigned Production build, and uploads XCTest plus package-resolution evidence. `EkitapligimUITests` launches without a working API and verifies the five primary tabs plus catalog/account navigation. The workflow parsed successfully as YAML in this Windows workspace; actual execution still requires the repository to run on GitHub Actions or another macOS runner.

The CI workflow now supports manual `workflow_dispatch` and push triggers for the repository's current `master` branch in addition to `main`, `codex/**`, and pull requests. The source tree has an initial local commit, but this workspace has no git remote, so no macOS runner can be dispatched from the current state; that external repository handoff is still required for Xcode evidence.

The placeholder AppIcon was replaced using the Android `drawable-nodpi/app_logo_round.png` brand asset. `generate-branded-appicon.ps1` flattened its alpha onto white, generated all declared iPhone/iPad sizes from one source, and recorded the source SHA-256 in `APP_ICON_SOURCE.md`. Workspace validation now rejects missing dimensions, alpha-channel icons, incomplete provenance, and an unexpectedly small marketing icon. Brand-owner approval and real-device inspection remain external evidence gates.

Live XenForo navigation verified the published support, terms, and privacy routes as `/diger/iletisim`, `/yardim/kurallar/`, and `/yardim/gizlilik-politikasi/`; obsolete draft URLs were removed from app source and metadata. Privacy declarations now include optional user-entered coarse profile location, profile website/contact data, and retained IP/user-agent/session security data. Non-functional analytics and notification-preview toggles were removed because no such SDK/behavior exists.

The Premium screen now exposes actual StoreKit product names/prices, purchase, restore, Manage Subscriptions, Terms, Privacy, login gating, auto-renewal disclosure, and all transaction states. Restore iterates verified `Transaction.currentEntitlements` and re-verifies each supported entitlement with XenForo; `AppStore.sync()` alone cannot produce a successful restored state. Sandbox execution remains an external Apple gate.

MobileApi `1.0.74` adds guarded account-deletion completion, local registration-extension compatibility, and correct HTTP 401 mapping for missing/expired authentication. A disposable local account proved authenticated read and mutation smoke, refresh rotation, old-token 401 rejection, deletion submission, user deletion, session revocation, PII scrubbing, completed state, and cleanup-job draining. Completion email attempted after cleanup but local SMTP was unavailable; delivery remains a public staging gate.

MobileApi `1.0.75` aligns mobile forum replies with XenForo's content-safety path by invoking the native reply spam checker before validation and sending normal reply notifications after save. Workspace validation now rejects removal of either control. A fresh disposable user passed the pre-accept terms gate, block/unblock round-trip, terms acceptance, and unauthenticated-reply rejection against the installed local addon; deletion request `7` then removed user `37` and scrubbed the request PII. Local SMTP remained unavailable for the completion notice.

MobileApi `1.0.77` adds XenForo flood checking to forum replies and fixes two runtime defects exposed by mutation testing: `ReplierService::setUser()` is protected in XenForo 2.3 and must not be called, and custom account-deletion mail must use `Mail::setContent()`. A seeded flood state for a disposable registered user returned HTTP 429 without creating a post. A separate disposable user then created visible post `15607` through the mobile endpoint; the post was removed through XenForo's hard-delete service and deletion request `11` removed user `41`. Users `38` through `41`, their flood rows, and smoke post `15607` were verified absent afterward. Account-deletion mail now reaches the configured transport; local delivery still fails only because no SMTP service is listening on `localhost:25`.

MobileApi `1.0.78` fixes the post-report runtime path and aligns book comments with XenForo safety behavior. Report creation no longer calls the nonexistent public `Report\CreatorService::setUser()` API; it now enforces `canReport`, report flood control, validation, persistence, and notifications. Book comments now run spam checks, post flood control, and notifications around the normal Replier service. Disposable user `42` successfully created report `2` for post `47` and visible book-comment post `15608`; the report/comments and post were deleted through XenForo entities/services, deletion request `12` removed the user, and all test artifacts were verified absent.

MobileApi `1.0.79` fixes XenForo `action_prefix` dispatch for conversation messages/replies and member follow/unfollow routes. The controllers previously exposed `actionPostReply`, `actionGetMessages`, `actionPostFollow`, and `actionPostUnfollow`, while XenForo routed directly to `actionReply`, `actionMessages`, `actionFollow`, and `actionUnfollow`. Disposable users `43` and `44` created conversation `2`, the recipient loaded it and persisted reply message `4`, the sender loaded the reply, and follow/unfollow each changed and then cleared `xf_user_follow`. The conversation master/messages/user rows were deleted and account-deletion requests `13` and `14` removed both users; no test users remained.

MobileApi `1.0.80` makes book-request vote toggles transactional and returns the committed count instead of a stale entity-manager value. The test first exposed a response of `vote_count=0` while SQL correctly held one vote. The replacement locks the request row with `SELECT ... FOR UPDATE`, changes the support relation and exact count in one transaction, then returns that count. Disposable users `46` and `47` created request `14`, a repeated create returned HTTP 429, vote returned/persisted count `1`, and unvote returned/persisted count `0`. The request/support rows were deleted through the entity and deletion requests `16` and `17` removed both users.

MobileApi `1.0.81` fixes the `notifications/mark-all` action-prefix dispatch by exposing `actionMarkAll()` instead of unreachable `actionPostMarkAll()`. Disposable user `48` followed user `49`, producing real unread alert `28`. The recipient's unread list and count included it; the single-alert endpoint set read, restored unread, and mark-all set read again while clearing unread count to zero. Unfollow and account-deletion requests `18` and `19` removed the relation, alert, and both users.

The addon patch process now performs a generic action-prefix audit after merging routes. Every API/public route with `action_prefix` is converted to its expected XenForo `actionX` method name and checked against the target controller source; packaging fails on any missing controller or method. The current installed route table passed for mark-all, follow/unfollow, conversation messages/reply, block/unblock, terms acceptance, email, and password routes.

`Scripts/api-route-contract-audit.ps1` now extracts and normalizes every literal/dynamic path template from `APIEndpoint.swift`. All 48 Swift templates match the checked-in MobileApi public-route contract; when the local XenForo addon is present, all 48 contract templates also match its installed public route XML. Workspace validation runs this audit so an iOS path drift or a stale backend contract fails before Xcode/App Review testing.

`Scripts/session-rotation-smoke-test.ps1` passed with disposable local user 34: rotated access and refresh tokens returned HTTP 401, the refreshed access token loaded the authenticated profile, logout succeeded, and both logged-out tokens returned HTTP 401. The test account was then completed through deletion request 4 and verified absent from `xf_user`; no token values were printed.

The public smoke test now also verifies `authors`, a selected `authors/{slug}/books`, `publishers`, and a selected `publishers/{slug}/books`. The latest local run passed with `agatha-christie` and `pegasus-yayinlari`. Native searchable/paginated SwiftUI directory screens decode these exact backend payloads and route selected books into `BookDetailView`.

The public smoke test now verifies `book-requests` as well. Native iOS list/create/vote endpoints and current backend JSON decoding have test coverage. Runtime negative checks passed: an authenticated 256-character title was rejected with HTTP 400 and an unauthenticated create request was rejected. MobileApi `1.0.61` and later also enforce field limits and a 30-second per-user creation interval server-side.

Authenticated conversation smoke passed without printing message bodies: `GET /conversations?page=1` and the selected `GET /conversation-detail/{id}` returned JSON. Dedicated iOS detail/reply routes avoid XenForo's existing web conversation route collision. Negative runtime checks confirmed empty replies, unauthenticated replies, and empty conversation creation are rejected. Native iOS list/detail/new/reply flows and DTO/endpoint tests are present; successful write mutations remain for a disposable reviewer-safe conversation account.

Member directory smoke passed for `GET /members?page=1&per_page=2&sort=alphabetical` and selected `GET /member-detail/{id}` after importing the collision-free iOS routes in MobileApi `1.0.63`. An unauthenticated follow attempt was rejected. MobileApi `1.0.79` mutation testing then verified follow persisted an `xf_user_follow` relation and unfollow removed it between disposable users `43` and `44`. Native search, sort, paging, profile, follow/unfollow, and block controls use XenForo's permission payload.

Book comment smoke passed for a selected visible book at `GET /books/{id}/comments?page=1`. Native iOS comment paging, 1–5 star selection, text submission, and per-comment reporting are wired to XenForo post IDs. Runtime negative checks confirmed unauthenticated and empty comment submissions are rejected; successful comment/rating/report mutations remain for the disposable reviewer account.

`Scripts/api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -BearerToken "xf_user:1" -AllowInsecure` passed locally for authenticated iOS endpoints: profile, library, subscription, terms status, terms acceptance, and notification counts.

`Scripts/api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -BearerToken "xf_user:3" -AllowInsecure -ExerciseMutations` passed locally. It selected the first visible book from the catalog and verified authenticated reader-progress and library-update mutation endpoints return HTTP 200. During this check, iOS reader-progress query parameters were aligned with the backend contract (`position_type`, `position_value`, `progress_percent`), catalog decoding was aligned with nested `pagination`, and profile loading was aligned with the direct `/me` response shape.

Latest local re-run note: `xf_user:3` now fails `books/{id}/reader/session` with HTTP 400 `Daily read limit or permission denied.` after repeated local smoke executions, which is consistent with daily read-limit enforcement. Re-running the same authenticated mutation smoke path with privileged local `xf_user:1` passed, including `reader/session` source URL generation.

The mutation smoke path also verifies `books/{id}/reader/session` returns a source URL. Against public HTTPS staging/production without `-AllowInsecure`, that source URL must also be HTTPS so the iOS reader/download flow remains App Transport Security compatible.

MobileApi `1.0.85` was exercised end-to-end on the local XenForo installation with a newly registered disposable account. The account received an `ms_at_` session, completed every authenticated API smoke check, persisted reader progress and a library update, and received separately authorized `read` and `download` reader sessions. Refresh rotation rejected both old tokens with HTTP 401; logout rejected the refreshed tokens with HTTP 401. The account then submitted a password-verified deletion request, its mobile sessions were revoked, and XenForo's deletion command completed the request and scrubbed the request PII. The local completion email could not be delivered because the local SMTP service is unavailable; public email delivery remains a staging/reviewer gate. No credentials or token values were recorded.

## macOS Validation

Run on a machine with current Xcode:

```bash
brew install xcodegen
xcodegen generate
swift test
xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme Ekitapligim -configuration Production -destination generic/platform=iOS build
```

## Release Evidence Required

Before submission, archive evidence must include:

- `Scripts/validate-workspace.ps1` output.
- `Scripts/swift-static-audit.ps1` output, if run separately.
- `Scripts/api-smoke-test.ps1` output against public HTTPS staging.
- `Scripts/appstore-preflight.ps1` output after placeholders are replaced.
- `Scripts/apply-mobileapi-ios-patch.ps1` output when preparing the XenForo addon package.
- `swift test` output.
- Debug simulator build output.
- Production generic iOS build/archive output.
- StoreKit sandbox purchase/restore evidence, if premium is enabled.
- Staging API smoke test evidence.
- Accessibility smoke test notes.
