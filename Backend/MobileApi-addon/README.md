# MobileApi iOS Backend Extension

These files extend the existing XenForo `Ekitapligim/MobileApi` add-on for the native iOS app. The extension is installed and runtime-tested against the local XenForo environment through version `1.0.81`; production installation is still required. Use `Scripts/apply-mobileapi-ios-patch.ps1` to merge it into a full add-on checkout and create the XenForo upload ZIP.

## Endpoints Added
- `POST /mobile-api/v1/auth/apple`
- `GET /mobile-api/v1/book-detail/{thread_id}`
- `POST /mobile-api/v1/billing/app-store/verify`
- `POST /mobile-api/v1/members/{user_id}/block`
- `POST /mobile-api/v1/members/{user_id}/unblock`
- `GET /mobile-api/v1/me/blocked-members`
- `POST /mobile-api/v1/posts/{post_id}/report`
- `GET /mobile-api/v1/me/terms`
- `POST /mobile-api/v1/me/terms/accept`
- `POST /mobile-api/v1/billing/app-store/notifications`

## Release Notes
- `GET /mobile-api/v1/book-detail/{thread_id}` provides a collision-free public mobile book-detail route for the iOS app. It avoids the public web book URL route family while returning the existing `Book` controller JSON payload.
- `AuthApple.php` verifies Apple identity tokens with RS256 signature and SHA-256 nonce validation, exchanges the single-use authorization code before creating/linking a user, and confirms both Apple tokens carry the same subject.
- `Service/AppleAuthorization.php` encrypts Apple refresh tokens at rest with AES-256-GCM and revokes them through Apple's server endpoint when account deletion is requested.
- `AccountDeletionRequest.php` verifies a current password when one is supplied, revokes Apple authorization and mobile sessions, then stores an idempotent deletion request.
- `ekitapligim-mobile:complete-account-deletion` inspects one request by default. With explicit `--execute --confirm=DELETE-{request-id}`, it uses XenForo's `DeleteService`, anonymizes retained content ownership, scrubs request PII, and sends a completion email.
- `AppStoreVerify.php` verifies StoreKit signed transactions as ES256 JWS payloads, checks the Apple certificate chain against a configured Apple root certificate, validates bundle/product/environment fields, and records verified entitlement state.
- `Service/IosEntitlement.php` exposes active iOS entitlement checks for XenForo premium decisions. The patch script wires this into subscription, reader access, reader permission, and role payload checks in the target addon.
- Blocking uses XenForo's ignored users table pattern where available.
- Reporting uses XenForo report service when available and falls back to moderator log/error log only as a development safety net.
- Terms acceptance stores the accepted community-rules version in `xf_ekitapligim_mobile_terms_acceptance`; forum replies are rejected until the current terms version is accepted.
- App Store Server Notifications verify the outer v2 `signedPayload` JWS and nested transaction JWS when provided, then record the verified notification hash and transaction identifiers.

## Apple Server Configuration
- Set `EKITAPLIGIM_IOS_BUNDLE_ID` to the app bundle ID.
- Set `EKITAPLIGIM_APPLE_CLIENT_SECRET` to a currently valid server-generated Apple client-secret JWT and rotate it before expiry.
- Set `EKITAPLIGIM_APPLE_TOKEN_ENCRYPTION_KEY` to a base64-encoded 32-byte random key. Preserve this key across deployments or stored refresh tokens cannot be revoked.
- Never commit these values. Sign in with Apple intentionally returns a service error when this configuration is incomplete.

## Production Package

After creating the MobileApi ZIP, generate a deployment directory with the real Apple Team ID:

```powershell
.\Scripts\prepare-public-deployment.ps1 -TeamId "ABCDEFGHIJ"
```

The directory contains the verified XenForo ZIP, its SHA-256 manifest, a Team-ID-specific AASA file, and deployment instructions. Run `Scripts/public-release-audit.ps1` after publishing it.

## Completing Account Deletion
Inspect without modifying data:
`php cmd.php ekitapligim-mobile:complete-account-deletion 123`

After independently verifying the request and retention obligations, perform the irreversible operation:
`php cmd.php ekitapligim-mobile:complete-account-deletion 123 --execute --confirm=DELETE-123`

Run XenForo's queued jobs after completion so ownership anonymization and cleanup finish. Retain operational evidence by request ID only; do not copy the user's email, reason, or tokens into tickets or logs.
