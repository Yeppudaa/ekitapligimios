# App Store Checklist

## Release Blockers
- Public HTTPS staging API is required.
- StoreKit backend verification is required for iOS premium/digital purchases.
- The review build uses first-party username/email and password authentication only. The incomplete Sign in with Apple client surface and entitlement were removed after App Review reproduced a failure; re-enable it only after a Developer key, server token exchange, signed-device login, and deletion-time revocation are proven end to end.
- User blocking must exist for UGC/community features. Client surface and backend scaffold now exist; staging install/test still required.
- Reviewer account must be created on public staging/production.
- Xcode project generation, signing team, bundle ID, screenshots, and TestFlight validation must be completed on macOS. A branded opaque AppIcon set is generated from the Android brand source; rights-holder visual approval remains required.
- Current repository has XcodeGen source scaffolding, not a verified `.xcodeproj` archive.

## Compliance Notes
- Native screens only for core app.
- WKWebView permitted only for legal/static rich pages.
- Account deletion flow: Settings > Account > Delete Account. The request is stored server-side and supports Apple/no-password accounts.
- After a deletion request is accepted, the app stops StoreKit observation, clears its Keychain session, transitions to signed out, and prevents duplicate submission from the success screen.
- Manual account deletion is disclosed as generally completing within 30 days, duplicate pending requests are idempotent, and operations must provide completion notice plus Sign in with Apple token revocation evidence.
- UGC: report content, block user, moderation process, terms, support contact.
- UGC terms acceptance is enforced client-side and server-side before forum replies. Staging install/test is still required before enabling posting in review builds.
- Payments: StoreKit 2 for digital subscriptions/access. Authenticated `Transaction.updates` observation handles pending/out-of-app completions; unverified or backend-unsynced transactions remain unfinished for redelivery.
- App Store Connect must contain subscription group `ekitapligim.premium` with monthly
  `ekitapligim.premium.monthly` and yearly `ekitapligim.premium.yearly` products at the same service level.
- App Store Connect was reconciled on 2026-08-25: both products are at Level 1, the previous review
  submission was removed so the corrected build can replace it, and both products currently show
  `Developer Rejected` until they are added to the replacement submission.
- App Store Server Notifications V2 must target `/ios-api/v1/billing/app-store/notifications` for both
  production and sandbox. Production must allow only `Production`; staging must allow only `Sandbox`.
- App Store Connect production and sandbox notification URLs are currently configured to
  `https://ekitapligim.com/ios-api/v1/billing/app-store/notifications`. Split the sandbox URL to a public
  staging host when one is available, then restrict each deployment to its matching Apple environment.
- Billing Grace Period is enabled for Production and Sandbox with Apple's minimum 3-day duration and all renewals.
  The production setting was enabled after IosApi 1.0.7 returned a successful real Apple Sandbox signed-notification test.
- The Staging build intentionally uses `com.ekitapligim.app` because Apple Sandbox subscriptions belong
  to the production App Store Connect app record; only its API endpoint/environment differs.
- Subscription purchase, Ask to Buy, restore, disabled auto-renew, expiration, refund/revocation,
  billing retry, and billing grace period must be executed with StoreKit Test and then Apple Sandbox.
- Privacy labels must match actual collection.
- Privacy manifest exists at `App/Ekitapligim/Support/PrivacyInfo.xcprivacy` and must be reconciled with final App Store labels, including purchase history if premium remains enabled.
- Review metadata draft exists at `APP_STORE_METADATA.md`.
- Local validation script exists at `Scripts/validate-workspace.ps1`; it must pass before macOS archive work.
- API smoke test script exists at `Scripts/api-smoke-test.ps1`; it must pass against public HTTPS staging before App Review.
- Public release audit at `Scripts/public-release-audit.ps1` must pass with the real Apple Team ID; it verifies legal/support pages, production API JSON, and the deployed AASA app identifier.
- UGC safety smoke test script exists at `Scripts/ugc-safety-smoke-test.ps1`; it must pass against public HTTPS staging before App Review.
- App Store preflight script exists at `Scripts/appstore-preflight.ps1`; it must pass without placeholders before submission.
- Opaque AppIcon files and source/hash evidence exist. Confirm brand approval and inspect the rendered icon on real devices before submission.

## Official References Checked
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple account deletion support: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- App Store Server Notifications: https://developer.apple.com/documentation/appstoreservernotifications
