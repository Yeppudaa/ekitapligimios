# Secrets And Environment

Do not commit secret values.

## iOS Build Settings
- `APPLE_TEAM_ID`: Apple Developer Team ID, supplied in Xcode or CI secret store.
- `EKITAPLIGIM_API_BASE_URL`: set by `.xcconfig`.
- `EKITAPLIGIM_ENVIRONMENT`: development, staging, or production.

## Backend Environment
- `EKITAPLIGIM_IOS_BUNDLE_ID`: `com.ekitapligim.app`.
- `EKITAPLIGIM_IOS_PRODUCT_IDS`: comma-separated StoreKit product IDs.
- `EKITAPLIGIM_APPSTORE_ENVIRONMENT`: `Production`, `Sandbox`, `Xcode`, or `Both`; production servers should use `Production`.
- `EKITAPLIGIM_APPLE_ROOT_CA_FILE` or `EKITAPLIGIM_APPLE_ROOT_CA_PEM`: Apple root certificate used to anchor App Store JWS certificate-chain verification. Keep the PEM file outside the web root.
- App Store Server API issuer ID, key ID, bundle ID, and private key must live only on the server secret store.
- Apple Sign in keys and JWKS cache must live only on the server.
- The web server must forward `Authorization` to PHP for mobile bearer tokens. On Apache/XenForo, enable `RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]` or the equivalent virtual-host/FastCGI setting.

## Reviewer Account
Never commit reviewer credentials. Store them only in App Store Connect review notes.

## Forbidden In App Bundle
- XenForo database credentials.
- XenForo privileged API keys.
- App Store Server API private keys.
- Apple Sign in private keys.
- Reviewer account password.
