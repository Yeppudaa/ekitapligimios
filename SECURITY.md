# Security Review

## Purchase/API review (2026-10-01)

Implemented: account-generation isolation in the StoreKit service and account binding on verification requests; transaction-specific, signed-date-ordered entitlement persistence; atomic ownership; retryable storage/permission failures; ES256/P-256, App Store signing OIDs and certificate validity at signing time; and bearer-only public iOS routes, including inherited MobileApi controllers. Raw payment JWS and private-message fields are redacted by the core logger. The bundled Apple root remains the default trust anchor.

New purchases obtain a server-persisted per-user UUID before StoreKit starts and include it as Apple's signed `appAccountToken`. This closes account switching before the first server verification. Legacy tokenless receipts retain first-claim semantics. Preserve the UUID mapping in server backups. Private-message push previews are generic, and logout deregisters the device before revoking its bearer.

Executed cryptographic fixtures, database tests and source scans are recorded in `PURCHASE_AND_API_AUDIT.md`. Remaining security/release gates include real Apple signed transactions, online certificate revocation/Apple history reconciliation strategy, server upgrade validation and account-linked retention/deletion. No production readiness claim is made from static scans.

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
