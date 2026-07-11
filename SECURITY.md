# Security Review

## Current Findings
- Android reads `EKITAPLIGIM_API_KEY` from `.env` and may call keyed XenForo `/api` routes. iOS must not ship privileged API keys.
- The legacy Google Play controller is Android-only and must never be used by the iOS purchase flow. iOS uses StoreKit 2 and the App Store JWS endpoints.
- Mobile authentication now issues random one-hour access tokens and 30-day rotating refresh tokens. Only SHA-256 token hashes are stored server-side; logout and refresh revoke the previous session row.
- Legacy `xf_user:{id}` bearer values are rejected by the public mobile API.
- Apple login verifies RS256 identity tokens against Apple's JWKS. Real signed-device and Apple sandbox evidence is still required.
- App Store transaction and Server Notification controllers verify Apple JWS certificate chains and fail closed until the Apple root CA is configured.
- Reader source URLs must be signed and short-lived. Do not expose permanent protected book URLs.
- Book-request creation enforces server-side field limits and a per-user cooldown; client-side limits are only an additional UX guard.

## Required Controls
- HTTPS only for staging/production.
- Keychain for tokens.
- Redacted logs.
- Token refresh loop protection.
- Server-side permission checks.
- Rate limiting for auth, report, comment, message, and account-deletion endpoints.
- Download validation and path traversal prevention.
- Backup exclusion for downloaded books.
- No private content in notification previews.

## Secret Scan Scope
Scan for:
- `XF-Api-Key`
- `Authorization`
- `password`
- `purchaseToken`
- `.p8`
- `.jks`
- `BEGIN PRIVATE KEY`

No release build should contain local URLs, debug keys, or test credentials.

Automated local scan:

```powershell
.\Scripts\validate-workspace.ps1
```

This script checks obvious committed secrets in app, core, tests, backend scaffolds, package manifest, and project spec. It does not replace a full secret-scanning service in CI.
