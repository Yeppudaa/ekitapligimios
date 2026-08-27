# Ekitapligim iOS API XenForo Add-on

Standalone XenForo add-on for the native iOS app. Public routes live under `/ios-api/v1/` and do not share a route prefix with the Android `Ekitapligim/MobileApi` add-on (`/mobile-api/v1/`).

## Architecture

- **Depends on** `Ekitapligim/MobileApi` for shared catalog, community, reader, and library controllers.
- **Owns** Apple Sign In, App Store billing/notifications, account deletion, blocking, reporting, and terms acceptance.
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
5. Verify forum topic create route responds (401/403 without auth, not 404):

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
- `POST /ios-api/v1/forums/{node_id}/threads` — create forum topic (IosApi `ForumThreads::actionPost`; requires v1.0.4+ deploy)
- `GET|POST /ios-api/v1/threads/{thread_id}/posts` — list/reply (IosApi `ThreadPosts` + Pub wrapper; requires v1.0.5+ deploy)

All other iOS app endpoints are registered under `/ios-api/v1/` but delegate to existing `Ekitapligim\MobileApi` controllers. Reading stats, profile media uploads, and book-agenda follow are owned by IosApi so they work even when MobileApi route import is incomplete on the server.

## Apple Server Configuration

Set these environment/config values on the server (never commit secrets):

- `EKITAPLIGIM_IOS_BUNDLE_ID` — iOS app bundle identifier
- `EKITAPLIGIM_IOS_PRODUCT_IDS` — comma-separated App Store product allowlist. Set it to
  `com.ekitapligim.app.premium.monthly,com.ekitapligim.app.premium.yearly,ekitapligim.premium.monthly,ekitapligim.premium.yearly`.
  The bundle-prefixed IDs are used for new purchases; the original IDs remain accepted only for restoration.
  IosApi 1.0.9+ always retains these source-controlled shipped IDs and merges any configured IDs into the list,
  so an outdated server value cannot reject an active App Store product.
- `EKITAPLIGIM_APPSTORE_ENVIRONMENT` — use `Production` in production, `Sandbox` in staging, and `Xcode` only for local StoreKit testing
- `EKITAPLIGIM_APPLE_ROOT_CA_FILE` or `EKITAPLIGIM_APPLE_ROOT_CA_PEM` — optional trusted Apple root override. IosApi 1.0.7+ falls back to the bundled official Apple Root CA - G3 certificate used by current App Store JWS chains.
- `EKITAPLIGIM_APPLE_CLIENT_SECRET` — valid Apple client-secret JWT (rotate before expiry)
- `EKITAPLIGIM_APPLE_TOKEN_ENCRYPTION_KEY` — base64-encoded 32-byte key for refresh-token encryption

Configure App Store Server Notifications V2 in App Store Connect as
`https://ekitapligim.com/ios-api/v1/billing/app-store/notifications` (and the staging URL for Sandbox).
The verifier binds an Apple `originalTransactionId` to the first Ekitapligim account that verifies it;
a different account cannot claim the same subscription during restore.

Sign in with Apple returns a service error when this configuration is incomplete.

## Account Deletion CLI

Inspect:

`php cmd.php ekitapligim-ios:complete-account-deletion 123`

Execute (irreversible):

`php cmd.php ekitapligim-ios:complete-account-deletion 123 --execute --confirm=DELETE-123`

## Migration From MobileApi Patch

The legacy `Backend/MobileApi-addon` patch and `Scripts/apply-mobileapi-ios-patch.ps1` are deprecated. All future iOS backend work happens in this add-on only. Android MobileApi and the Android app are not modified.
