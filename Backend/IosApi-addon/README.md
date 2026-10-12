# Ekitapligim iOS API XenForo Add-on

## 1.0.35 — backwards-compatible purchase duration repair (2026-10-12)

Also fixes the reported `MeDeviceToken` POST/DELETE TypeError: missing input returns HTTP 400 with the existing error code. Valid device-token registration and user-scoped deletion are unchanged; an empty request cannot remove all tokens.

Fixed three/six/twelve-month App Store purchases now retain unused time across distinct purchases. Delivery is derived from verified signed transactions under both original-transaction and per-account locks, so replays/restores never accumulate time twice. Out-of-order events and signed refunds/reversals rebuild only their account's fixed-term delivery. Production and Sandbox schedules are separate. Existing Apple subscription periods retain Apple expiry; overlapping fixed-term time is carried forward. Opaque pre-ledger grants are preserved, not guessed or migrated.

Existing purchase/restore routes, product IDs, ownership, signature checks, field types and optional legacy request fields remain supported. `prepare_purchase` still returns the same successful UUID response, with optional `has_lifetime`, `has_active_subscription`, and `has_fixed_term` advice for new clients. Already-paid transactions are never rejected merely because the account has another premium plan. No new table, destructive migration, auth/session change, Android edit or price change is part of this purchase repair.

Install this server package before the matching app update. Older apps receive carried expiration dates without an app update. New pre-purchase warnings and prevention of unnecessary payments require the native update; Apple subscription cancellation always remains a user action in Apple's subscription management. The package itself does not install or submit anything. See `PURCHASE_FIX_VALIDATION.md` for tests and release limits.

## 1.0.34 — APNs Unregistered cleanup (2026-10-12)

APNs HTTP 410 `Unregistered` indicates an inactive device-notification token. It is now handled as quiet cleanup while remaining counted in the delivery summary. Configuration, topic, provider-authentication, rate-limit and transport/server failures continue to appear in the server error log. Raw cURL diagnostics are omitted because they may contain a device-token URL.

Cleanup compares the selected token row, account and registration time, and honors APNs's invalidation timestamp in milliseconds. A new registration or account reassignment is not removed by a late failure. Since registrations use second precision, registrations within the invalidation/request-start second are conservatively retained. Missing timestamps fall back to the send-start time. No schema or public API changes are required; old iOS apps use the same device registration endpoint.

Includes all 1.0.33 changes. No app update is required for this server logging/cleanup correction. The earlier native reader/chat/cover fixes still require an app update. Package preparation does not install it on the server. See `APNS_UNREGISTERED_VALIDATION.md` in the repository for executed tests and deployment notes.

## 1.0.34 — APNs Unregistered cleanup (2026-10-12)

APNs HTTP 410 `Unregistered` indicates an inactive device-notification token. It is now handled as quiet cleanup while remaining counted in the delivery summary. Configuration, topic, provider-authentication, rate-limit and transport/server failures continue to appear in the server error log. Raw cURL diagnostics are omitted because they may contain a device-token URL.

Cleanup compares the selected token row, account and registration time, and honors APNs's invalidation timestamp in milliseconds. A new registration or account reassignment is not removed by a late failure. Since registrations use second precision, registrations within the invalidation/request-start second are conservatively retained. Missing timestamps fall back to the send-start time. No schema or public API changes are required; old iOS apps use the same device registration endpoint.

Includes all 1.0.33 changes. No app update is required for this server logging/cleanup correction. The earlier native reader/chat/cover fixes still require an app update. Package preparation does not install it on the server. See `APNS_UNREGISTERED_VALIDATION.md` in the repository for executed tests and deployment notes.

## 1.0.33 — session retry and chat presentation (2026-10-12)

Ports the Android reference's bounded 120-second recovery into the standalone IosApi `MobileSession` service. **Public-route clarification:** the existing `auth/refresh` and logout routes remain delegated to MobileApi, so installing IosApi alone does not activate the standalone service on those public routes. The local MobileApi reference has the same recovery logic; deployed behavior depends on its installed code. The exact still-active successor is returned without extending session lifetimes when that implementation is routed; logout, revoked/expired successors, disabled users and later rotations remain rejected. Token hashes remain the only stored token representation; there is no schema migration.

Chat serialization adds display-only `is_premium`, `role_type`, and validated `announcement_member` metadata for native premium styling and upgrade-recipient profile navigation. Existing fields and old-client message text are preserved. Purchase verification, membership reconciliation, StoreKit products, shared MobileApi routes and Android source are unchanged.

Install through the normal XenForo archive upgrade flow after staging verification; this repository change does not install or deploy the add-on. Keep the previous package and a server backup for rollback. The matching iOS app is needed for native display/download changes. See the repository's `SESSION_CHAT_COVER_VALIDATION.md` for evidence and remaining device gates.

## 1.0.29 — reader Drive source validation (2026-10-01)

Reject missing or invalid Drive URLs with `ebook_unavailable` before calling the shared fetcher. Valid sources retain the existing access and preview pipeline. This full add-on package includes the 1.0.28 changes below; back up the installed add-on and database before upgrading through XenForo's add-on archive installer. Invalid book source records still require correction by an administrator.

## 1.0.28 — purchase and restore reliability (2026-10-01)

This source merges the saved 1.0.27 server baseline with the native app's five current products and three legacy restore IDs. It retains reader preview metadata, `IosMembershipSynchronizer`, the `appStoreEntitlement-*` group-change keys, and the five-minute reconciliation cron. Minimum MobileApi remains 1.0.145, as in the server archive. No Android files are changed.

Transactions are stored separately and updates are ordered by Apple's signed dates. A delayed notification or old receipt cannot undo a newer refund. Verified notifications received before an account claims the purchase are retained without granting guest access. A new additive `xf_ekitapligim_ios_appstore_state` table stores only the verified fields needed for entitlement calculation. Original transaction ownership is serialized; database and Premium permission-delivery failures return HTTP 503 for retry.

**Deploy this server version before the new iOS build.** The client first posts `prepare_purchase=1` with `account_name` to the verification route. A stable random UUID in the additive `xf_ekitapligim_ios_appstore_account` table binds the XenForo user ID to Apple's `appAccountToken` before the payment sheet opens. The server enforces the signed UUID even before the first verification and can deliver early notifications to the correct owner. A username change does not change this mapping. Back up this table with the entitlement tables; unknown signed UUIDs fail closed. Tokenless purchases from previous app versions retain first-verified-account ownership.

Monthly and legacy yearly subscriptions use Apple expiry/grace; three/six/twelve-month non-renewing plans use purchase-date calendar periods with month-end clamping; lifetime requires a non-consumable product. JWS checks include ES256/P-256, Apple trust anchoring, App Store signing OIDs, and certificate validity at the signed date, so old legitimate purchases can be restored.

All public `/ios-api/` requests ignore browser-cookie authentication, including controllers shared with MobileApi. Use a valid mobile bearer. The existing `ekGooglePlayPremiumGroupId` option remains the shared Premium group configuration for compatibility; no Google billing flow is added to iOS.

See `PURCHASE_AND_API_AUDIT.md` for executed tests, archive provenance, deployment order and remaining device/Sandbox gates. Local Xcode StoreKit receipts must use injected test verifiers; they are not Apple-signed production evidence.

## 1.0.24 — reader progress synchronization

Install this upgrade before the matching iOS build. The GET/POST reader-progress and library routes now use IosApi controllers while sharing the website's existing reader-progress table. No Android source changes or database migration are required. Shelf updates no longer overwrite reader positions. POST acknowledgements contain the stored position/date/revision and report conflicts or storage failures explicitly. See `API_DOCUMENTATION.md` in the iOS repository for the wire contract.

Run `php Tests/Backend/ReaderProgressTest.php` and the iOS reader tests before rollout. Verify PDF 25 → 40 → 12 and EPUB text anchors in both directions on authenticated HTTPS staging before claiming completion. Billing, purchases, access checks, entitlements and StoreKit configuration are unchanged.

Standalone XenForo add-on for the native iOS app. Public routes live under `/ios-api/v1/` and do not share a route prefix with the Android `Ekitapligim/MobileApi` add-on (`/mobile-api/v1/`).

## Architecture

- **Depends on** `Ekitapligim/MobileApi` 1.0.145+ for shared catalog, reader preview metadata, and library controllers.
- **Owns** Apple Sign In, App Store billing/notifications, account deletion, blocking, reporting, and terms acceptance.
- **Owns** all iOS social write/filter wrappers (forum, book comments, Book Agenda, chat, and private conversations) under `/ios-api/v1/`; `/mobile-api/v1/` is never modified.
- **Extends** `AbstractMobileController` through XenForo class extensions so App Store entitlements grant premium access without modifying MobileApi source files.

## Build

```powershell
.\Scripts\build-ios-api-addon.ps1
.\Scripts\build-ios-api-addon.ps1 -CreateZip
```

Regenerate routes after MobileApi reference updates:

```powershell
.\Scripts\generate-ios-api-routes.ps1
```

## Install

1. Ensure `Ekitapligim/MobileApi` is installed and active on XenForo.
2. Upload and install `Ekitapligim/IosApi` from Admin → Add-ons.
3. Rebuild routes/caches if prompted.
4. Configure Apple server secrets (see below).
5. Configure XenForo options `ekIosUgcBlockedTerms` and `ekIosUgcModeratorEmails`; neither may be empty for release.
6. Run `php cmd.php ekitapligim-ios:release-audit` and verify forum topic create responds (401/403 without auth, not 404):

```powershell
.\Scripts\parity-audit.ps1 -BaseUrl "https://ekitapligim.com/ios-api/v1/"
```

6. Run smoke tests:

```powershell
.\Scripts\api-smoke-test.ps1 -BaseUrl "https://ekitapligim.com/ios-api/v1/"
```

## iOS-Owned Endpoints

- `POST /ios-api/v1/auth/apple`
- `POST /ios-api/v1/billing/app-store/verify`
- `POST /ios-api/v1/billing/app-store/notifications`
- `POST /ios-api/v1/me/account-deletion-request`
- `GET /ios-api/v1/me/reading-stats`, `POST /ios-api/v1/me/reading-stats`
- `POST /ios-api/v1/me/avatar`, `POST /ios-api/v1/me/banner`
- `POST /ios-api/v1/book-agenda-follow/{user_id}`
- `GET /ios-api/v1/me/blocked-members`
- `POST /ios-api/v1/members/{user_id}/block|unblock`
- `GET|POST /ios-api/v1/me/terms`, `POST /ios-api/v1/me/terms/accept`
- `POST /ios-api/v1/posts/{post_id}/report`
- `GET /ios-api/v1/me/notifications`, `GET /ios-api/v1/me/notifications/counts`, `POST /ios-api/v1/me/notifications/{alert_id}/mark`, `POST /ios-api/v1/me/notifications/mark-all` — XenForo site alerts for the signed-in member (requires 1.0.15+)
- `POST /ios-api/v1/me/conversations/{conversation_id}/read` — idempotently marks an owned conversation read and returns authoritative alert/conversation counts (requires 1.0.23+)
- `POST|DELETE /ios-api/v1/me/device-token` — register or remove the signed-in member's APNs token (requires 1.0.22+)
- `POST /ios-api/v1/posts/{post_id}/edit` — edit forum post (XenForo Post Editor; requires 1.0.14+)
- `POST /ios-api/v1/posts/{post_id}/delete` — soft-delete forum post (POST, not HTTP DELETE; requires 1.0.14+)
- `GET /ios-api/v1/legal/terms`
- `POST /ios-api/v1/safety/reports`
- `POST /ios-api/v1/auth/login|register` with mandatory `accepted_terms_version`
- `POST /ios-api/v1/forums/{node_id}/threads` — create forum topic (IosApi `ForumThreads::actionPost`; requires v1.0.4+ deploy)
- `GET|POST /ios-api/v1/threads/{thread_id}/posts` — list/reply (IosApi `ThreadPosts` + Pub wrapper; requires v1.0.5+ deploy)
- `POST /ios-api/v1/me/presence` — mobile presence heartbeat (requires 1.0.16+)
- `POST /ios-api/v1/member-visit/{user_id}` — record profile visit alert (requires 1.0.16+)

IosApi 1.0.13 wraps every social create/edit action with a managed objectionable-content filter, Unicode/punctuation normalization, and XenForo spam checks before persistence. It returns `422 content_policy_violation` without saving rejected text. Authenticated social reads remove ignored users; one-to-one conversations with blocked members are refused while group conversations retain other participants and hide blocked messages. Forum posts expose edit/delete when XenForo permits it (`POST /posts/{id}/edit` and `POST /posts/{id}/delete`).

Reports use XenForo's report queue and an additive `xf_ekitapligim_ios_ugc_event` table. A queued job sends moderator email without private bodies or secrets. The SLA cron runs every 15 minutes, reminds at 20 hours, escalates at 24 hours, and tracks report, action, and closure timestamps.

## Apple Server Configuration

Set these environment/config values on the server (never commit secrets):

- `EKITAPLIGIM_IOS_BUNDLE_ID` — iOS app bundle identifier
- `EKITAPLIGIM_IOS_PRODUCT_IDS` — comma-separated App Store product allowlist. Set it to
  `com.ekitapligim.app.premium.monthly,com.ekitapligim.app.premium.three_months,com.ekitapligim.app.premium.six_months,com.ekitapligim.app.premium.yearly_once,com.ekitapligim.app.premium.lifetime,com.ekitapligim.app.premium.yearly,ekitapligim.premium.monthly,ekitapligim.premium.yearly`.
  The monthly, three-month, six-month, yearly-once, and lifetime IDs are used for new purchases; the previous yearly and unprefixed IDs remain accepted for restoration.
  IosApi 1.0.9+ always retains these source-controlled shipped IDs and merges any configured IDs into the list,
  so an outdated server value cannot reject an active App Store product.
- `EKITAPLIGIM_APPSTORE_ENVIRONMENT` — `Production` for production-only traffic, `Sandbox` for sandbox-only staging, or `Both` when TestFlight and production use the same API. An unset value also accepts only Production/Sandbox. Apple JWS verification is always required; local Xcode receipts must use test doubles rather than a public-server verification bypass.
- `EKITAPLIGIM_APPLE_ROOT_CA_FILE` or `EKITAPLIGIM_APPLE_ROOT_CA_PEM` — optional trusted Apple root override. IosApi 1.0.7+ falls back to the bundled official Apple Root CA - G3 certificate used by current App Store JWS chains.
- `EKITAPLIGIM_APPLE_CLIENT_SECRET` — valid Apple client-secret JWT (rotate before expiry)
- `EKITAPLIGIM_APPLE_TOKEN_ENCRYPTION_KEY` — base64-encoded 32-byte key for refresh-token encryption

Configure App Store Server Notifications V2 in App Store Connect as
`https://ekitapligim.com/ios-api/v1/billing/app-store/notifications` (and the staging URL for Sandbox).
The verifier binds an Apple `originalTransactionId` to the first Ekitapligim account that verifies it;
a different account cannot claim the same subscription during restore.

Sign in with Apple returns a service error when this configuration is incomplete.

## APNs Push Configuration

In XenForo Admin CP, configure `ekitapligimApnsKeyId`, `ekitapligimApnsTeamId`,
`ekitapligimApnsKeyPath`, `ekitapligimApnsTopic=com.ekitapligim.app`, and
`ekitapligimApnsEnvironment=production`. Store the `.p8` key outside the public web root
with read access limited to the PHP process. After a signed-in device has opened the app,
run `php cmd.php ekitapligim-ios:push-test USER_ID`. The command prints counts only and
never prints a device token.

## Account Deletion CLI

Inspect:

`php cmd.php ekitapligim-ios:complete-account-deletion 123`

Execute (irreversible):

`php cmd.php ekitapligim-ios:complete-account-deletion 123 --execute --confirm=DELETE-123`

## Migration From MobileApi Patch

The legacy `Backend/MobileApi-addon` patch and `Scripts/apply-mobileapi-ios-patch.ps1` are deprecated. All future iOS backend work happens in this add-on only. Android MobileApi and the Android app are not modified.
## 1.0.30 live-room chat patch

Adds native iOS quote/reaction routes, configured reaction serialization, safe structured web quote metadata, and room-only interaction APNs. Generic Siropu chat alerts, including private/external chat, are excluded from APNs. Existing XenForo conversation notifications, non-chat alerts and purchase code are preserved. No schema migration is added. Import the new version's routes, phrases, class extensions and entity listeners through the normal XenForo add-on upgrade; uploading PHP alone is insufficient. Staging/device delivery validation remains required. See the repository's `CHAT_PROFILE_STABILITY_VALIDATION.md`.

## 1.0.32 shared chat reaction refresh

- Fix internal route priority so single-message and reaction addresses resolve before the general messages route. Public URLs stay the same. Run a normal add-on upgrade to import the route changes.
- Keep reactions in XenForo's existing `siropu_chat_room_message` store, shared with web/Android. Clear the cached `Reactions` relation after a changed API write so add/change/remove responses return the saved selection.
- Include additive `sprite_mode`/`sprite_params` for configured web reaction images. Emoji and existing response fields remain unchanged.
- This version retains the 1.0.31 old-client quote behavior below. No schema migration, purchase behavior or Android route changes. The new ZIP is a local candidate, not an executed production upgrade.

## 1.0.31 old-client compatibility repair

Supersedes the previously prepared 1.0.30 ZIP. `message` retains safe visible quote text for existing clients; the additive `message_body` supports the updated native quote view without duplication. Nested, inline, malformed and unavailable structured quote references are filtered before either output, including both-direction blocks. Ordinary messages and existing response field types are preserved. No purchase code or schema changes were made. Server-only installation intentionally applies the room-only APNs rules immediately; screen layout/profile refresh fixes still require the native app update. Old-app, two-account and physical-device staging tests remain required before production rollout.
