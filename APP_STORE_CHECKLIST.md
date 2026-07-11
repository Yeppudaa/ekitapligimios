# App Store Checklist

## Release Blockers
- Public HTTPS staging API is required.
- StoreKit backend verification is required for iOS premium/digital purchases.
- Sign in with Apple is required if Google login is a primary login option. Client surface, backend JWKS/RS256 validation, authorization-code exchange, encrypted refresh-token storage, and deletion-time revocation now exist; real Apple sandbox/device sign-in and deletion must still be tested on a signed iOS build.
- User blocking must exist for UGC/community features. Client surface and backend scaffold now exist; staging install/test still required.
- Reviewer account must be created on public staging/production.
- Xcode project generation, signing team, bundle ID, screenshots, and TestFlight validation must be completed on macOS. A branded opaque AppIcon set is generated from the Android brand source; rights-holder visual approval remains required.
- Current repository has XcodeGen source scaffolding, not a verified `.xcodeproj` archive.

## Compliance Notes
- Native screens only for core app.
- WKWebView permitted only for legal/static rich pages.
- Account deletion flow: Settings > Account > Delete Account. The request is stored server-side and supports Apple/no-password accounts.
- Manual account deletion is disclosed as generally completing within 30 days, duplicate pending requests are idempotent, and operations must provide completion notice plus Sign in with Apple token revocation evidence.
- UGC: report content, block user, moderation process, terms, support contact.
- UGC terms acceptance is enforced client-side and server-side before forum replies. Staging install/test is still required before enabling posting in review builds.
- Payments: StoreKit 2 for digital subscriptions/access.
- Privacy labels must match actual collection.
- Privacy manifest exists at `App/Ekitapligim/Support/PrivacyInfo.xcprivacy` and must be reconciled with final App Store labels, including purchase history if premium remains enabled.
- Review metadata draft exists at `APP_STORE_METADATA.md`.
- Local validation script exists at `Scripts/validate-workspace.ps1`; it must pass before macOS archive work.
- API smoke test script exists at `Scripts/api-smoke-test.ps1`; it must pass against public HTTPS staging before App Review.
- UGC safety smoke test script exists at `Scripts/ugc-safety-smoke-test.ps1`; it must pass against public HTTPS staging before App Review.
- App Store preflight script exists at `Scripts/appstore-preflight.ps1`; it must pass without placeholders before submission.
- Opaque AppIcon files and source/hash evidence exist. Confirm brand approval and inspect the rendered icon on real devices before submission.

## Official References Checked
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple account deletion support: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- App Store Server Notifications: https://developer.apple.com/documentation/appstoreservernotifications
