# AGENTS.md

Permanent rules for future Codex sessions working on Ekitapligim iOS.

## Architecture Rules
- Build a native SwiftUI app. Do not ship a WKWebView wrapper.
- Keep business logic out of SwiftUI views. Use services/repositories/view models with dependency injection.
- Use URLSession, Codable, async/await, Keychain, PDFKit, StoreKit 2, XCTest/Swift Testing.
- Minimum target is iOS 17 unless product requirements change.
- Production builds must use HTTPS public endpoints only.
- Keep `project.yml`, entitlements, privacy manifest, StoreKit config, and App Store metadata drafts synchronized with source behavior.

## Security Rules
- The app must never connect directly to MySQL.
- Never commit API secrets, database credentials, reviewer passwords, signing keys, or privileged XenForo API keys.
- Store access and refresh tokens only in Keychain.
- Redact Authorization, Cookie, password, token, payment, and private-message values from logs.
- Backend must enforce XenForo permissions for every request.

## Prohibited Practices
- No hardcoded localhost in release configuration.
- No broad ATS arbitrary-load exception.
- No fake production buttons.
- No force unwraps/casts in production paths.
- No Google Play billing code in iOS.
- No external purchase prompts for digital content unless Apple rules and entitlements explicitly permit it.

## Testing Expectations
- Add tests for API request construction, decoding, error mapping, auth transitions, token refresh, reading progress, downloads, deep links, and account deletion.
- Run clean build, release build, unit tests, UI tests, secret scan, and accessibility checks before release.
- Do not claim App Store readiness without evidence from executed commands.

## Naming Conventions
- Module: `EkitapligimCore`.
- App namespace: `Ekitapligim`.
- API DTOs end with `DTO`.
- User-facing strings must be localized in String Catalogs or resource files.

## Definition Of Done
- Native feature parity is documented.
- API documentation is current.
- App Store checklist has no release blockers.
- Privacy inventory matches actual behavior.
- Security review has no release blockers.
- Reviewer account and public HTTPS staging are available.
