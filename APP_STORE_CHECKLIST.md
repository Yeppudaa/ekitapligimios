# App Store Checklist

## Purchase/API audit gate (2026-10-01)

- [x] Production AdminCP shows IosApi 1.0.29 and MobileApi 1.0.148; authenticated live purchase preparation returned an account UUID. A permitted reader session and native PDF source returned HTTP 200 and a `%PDF-` header. These checks do not exercise Apple payment or restore.
- [x] App Store Connect shows the bundle-prefixed monthly product approved at ₺100 in Türkiye. Version 1.0.7 build 40 is in TestFlight and submitted for App Review (Waiting for Review); version 1.0.6 build 39 does not contain these fixes.
- [x] Codemagic Production build #49 from `c11799b` passed native tests, signed an IPA and uploaded build 40. The tester reported successful monthly purchase/restore and successful 3-, 6-, 12-month and lifetime access on build 40. These device outcomes are tester-reported, not automated transaction evidence.

- [x] Source fixes and regression tests for account isolation, unfinished purchases, restore cancellation, expiry, signed event ordering, refund replay, early notifications and XenForo Premium delivery. See [PURCHASE_AND_API_AUDIT.md](PURCHASE_AND_API_AUDIT.md).
- [x] Local 1.0.27 server archive reconciled into 1.0.28 source, preserving group reconciliation and reader preview metadata; MobileApi 1.0.145+ dependency retained.
- [ ] Verify that every production IosApi 1.0.29 file matches the audited source and that upgrade/data preservation and entitlement group delivery pass in staging. The version label and live API probes alone do not prove full source identity.
- [x] GitHub CI run #157 passed on commit `7e0f1d1`: iPhone/iPad simulator unit and UI tests, Production build, API/source validation and App Store screenshots. Codemagic Production build #49 and native tests also passed. Physical-device accessibility and all StoreKit edge cases remain unverified.
- [ ] Complete legacy restores and interruption, second-device, wrong-account, grace, expiry, refund and notification-retry scenarios. The five current product outcomes were reported from TestFlight, and App Store Connect product availability was checked for the ₺100 monthly product.
- [ ] Verify operational recovery for lost Apple notifications and deletion/retention of account-linked purchase records. Local membership cron alone does not reconcile Apple history.

## General review follow-up (2026-09-28)

- [x] Session isolation, notification retry invalidation, download lifecycle/progress and stale search-result corrections implemented; 293 portable XCTest tests and workspace audit passed.
- [ ] Execute the eight new native regressions and iOS/device checks in [GENERAL_APP_REVIEW.md](GENERAL_APP_REVIEW.md). Windows validation does not establish release readiness.

## Reader experience release gate (2026-09-28)

- [x] Android-referenced full-screen reader, local sepia/white/night themes and actual download progress implemented; existing continue-reading/progress contracts retained.
- [x] `Scripts/swift-test-windows.ps1`: **287 XCTest tests passed (14 new)**; workspace audit passed. Earlier dated test counts below describe earlier builds.
- [x] DEBUG-only native reader fixture and native reader test coverage added for execution on macOS.
- [ ] Execute current iOS clean/release builds and native unit/UI tests; the new fixture/tests have not run on this Windows host.
- [ ] Capture iPhone/iPad full-screen and theme screenshots; verify VoiceOver, large text, landscape, zoom, page controls and preview/settings dismissal without losing the reading position.
- [ ] Verify large PDF/EPUB files over public HTTPS, known/unknown response sizes, interrupted downloads, timeout/storage errors, and reopen/continue-reading against the real service.

See [READER_EXPERIENCE_VALIDATION.md](READER_EXPERIENCE_VALIDATION.md). This update has no App Store readiness or device visual sign-off yet; existing release blockers still apply.

## Gift wheel release gate (2026-09-27)

- [x] Separate PremiumWheel transport and native screen; no MobileApi/backend/purchase-source changes.
- [x] Core request/decoding/error/idempotency/account/motion tests executed; static secrets and accessibility checks passed.
- [ ] iOS clean/release builds and UI tests on macOS; native iPhone/iPad screenshot comparison, ten-second recording, VoiceOver/large-text/Reduce Motion checks.
- [ ] Authenticated public HTTPS staging spin/recovery/quota/permissions and server account-deletion retention verified with reviewer account.
- [ ] Gift-wheel AASA paths deployed and verified on a device.

See `GIFT_WHEEL_VALIDATION.md`. Windows core results do not establish App Store readiness.

## Release Blockers
- Public HTTPS staging API is required.
- Standalone `Ekitapligim/IosApi` 1.0.13 must pass staging auth, objectionable-content, report, block, instant-hide and 20/24-hour SLA tests before the identical SHA-256 ZIP is installed in production. `MobileApi` 1.0.136 and Android routes must remain unchanged.
- StoreKit backend verification is required for iOS premium/digital purchases.
- The review build uses first-party username/email and password authentication only. The incomplete Sign in with Apple client surface and entitlement were removed after App Review reproduced a failure; re-enable it only after a Developer key, server token exchange, signed-device login, and deletion-time revocation are proven end to end.
- Visible report and block-and-report controls exist on every social UGC card; physical iPhone/iPad evidence and staging verification are still required.
- Reviewer account must be created on public staging/production.
- Xcode project generation, signing team, bundle ID, screenshots, and TestFlight validation must be completed on macOS. A branded opaque AppIcon set is generated from the current user-provided artwork; rights-holder visual approval remains required.
- Current repository has XcodeGen source scaffolding, not a verified `.xcodeproj` archive.

## Compliance Notes
- Native screens only for core app.
- WKWebView permitted only for legal/static rich pages.
- Account deletion flow: Settings > Account > Delete Account. The request is stored server-side and supports Apple/no-password accounts.
- After a deletion request is accepted, the app stops StoreKit observation, clears its Keychain session, transitions to signed out, and prevents duplicate submission from the success screen.
- Manual account deletion is disclosed as generally completing within 30 days, duplicate pending requests are idempotent, and operations must provide completion notice plus Sign in with Apple token revocation evidence.
- UGC: pre-auth EULA/community acceptance, pre-persistence managed filtering, XenForo report queue, immediate local hiding, server-side ignore filtering, support contact and blocked-user management.
- `ekIosUgcModeratorEmails` and `ekIosUgcBlockedTerms` must be non-empty and `php cmd.php ekitapligim-ios:release-audit` must pass on staging and production.
- Payments: StoreKit 2 for digital subscriptions/access. Authenticated `Transaction.updates` observation handles pending/out-of-app completions; unverified or backend-unsynced transactions remain unfinished for redelivery.
- App Store Connect, checked 2026-09-27: approved/on-sale auto-renewing monthly is currently ₺99.99, with ₺100 scheduled for 2026-09-28 and existing subscribers' price preserved. Approved/on-sale auto-renewing yearly is currently ₺999.99, with a Türkiye-only decrease to ₺750 scheduled for 2026-09-28, including existing subscribers. This legacy yearly product is still in the distributed app and renews automatically. The new non-renewing `three_months` (₺239.99, Apple ID 6816677090), `six_months` (₺400, 6816677130), `yearly_once` (₺750, 6816677700), and non-consumable `lifetime` (₺2,500, 6816678261) are Waiting for Review and are not live. All new IDs use the `com.ekitapligim.app.premium.` prefix. Apple has no exact ₺240 price point; the owner approved ₺239.99.
- The original unprefixed product records remained unavailable to StoreKit in TestFlight Sandbox through build 14.
- 2026-09-27 premium update: the four new products have Turkish localizations, availability, pricing, and product-level review screenshots in App Store Connect; all four were submitted for review with iOS 1.0.6 (38). The owner supplied three native iPhone Premium screenshots through Telegram, and they were uploaded to the four new product records. The screenshots show USD StoreKit prices because the capture device uses a US storefront; Türkiye prices are configured separately in App Store Connect. The 1.0.6 version has ten new iPhone App Store screenshots. Apple requires the first non-renewing/non-consumable products to accompany a new app version. Codemagic build #45 from `c6ac174` passed 63 iOS unit and 15 UI tests, produced a signed IPA with Production APNs, and uploaded 1.0.6 (38) to TestFlight. App Store Connect shows build 38 Waiting for Review, assigned to the two-person internal testing group with What to Test notes saved. Build 37 was removed from Beta Review because it included an unrelated AI styling change; build 38 restores the original styling. Windows Swift package tests (273), release package build, static workspace checks, and 17 standalone PHP policy scenarios also passed earlier. The live IosApi add-on is 1.0.27 while this repository packages 1.0.24; the repository ZIP must not overwrite that newer server version. New-plan server verification and Apple Sandbox purchases remain unverified.
  New bundle-prefixed records are used for new purchases; the client and backend retain the original IDs only for
  transaction restoration and entitlement verification.
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
- Build 17 must not be resubmitted. Version 1.0.6 build 38 is uploaded to TestFlight above the distributed 1.0.5 build 36. Build 38 and the four new Premium purchases were submitted together for production App Review on 2026-09-27 at 20:35 TRT (submission `94cd6323-0d01-4f8e-ab8a-ab7bb4a4f60d`); all five items show Waiting for Review. The version's reviewer notes describe the gift wheel and Premium plans, and automatic release after approval is selected. On 2026-09-27, `Scripts/appstore-preflight.ps1` and `Scripts/public-release-audit.ps1 -TeamId QA67383767` passed. Authenticated new-plan StoreKit Sandbox purchases, server entitlement verification, gift-wheel staging scenarios, and physical-device release checks remain unverified. Do not claim these tests passed or that the version is live before Apple approval and distribution status confirm it.
- Capture physical iPhone and iPad recordings showing pre-login acceptance, report, block-and-report and immediate content removal.
- App Store preflight script exists at `Scripts/appstore-preflight.ps1`; it must pass without placeholders before submission.
- Opaque AppIcon files and source/hash evidence exist. Confirm brand approval and inspect the rendered icon on real devices before submission.

## Official References Checked
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple account deletion support: https://developer.apple.com/support/offering-account-deletion-in-your-app/
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
- App Store Server Notifications: https://developer.apple.com/documentation/appstoreservernotifications

## AI Assistant release gate

- [ ] Final native AI assistant iPhone/iPad tests, screenshots and accessibility audit passed on macOS.
- [ ] Real guest/member/Premium/VIP/admin quota and cross-platform usage verified.
- [ ] AI history is covered by server account deletion and disclosed retention behavior.
- [ ] Enabled weekly digest preferences verified against actual iOS notification delivery.

See AI_ASSISTANT_VALIDATION.md for executed evidence and outstanding checks. No new StoreKit product or entitlement is required.
## Chat/profile release gate (2026-10-03)

- [ ] Run iOS clean/Production builds, `ChatModelTests`, `ProfileReadingRefreshTests`, chat UI tests and existing native regression suites on macOS.
- [ ] Verify full messages, avatar navigation, reply/reaction controls and keyboard on a narrow iPhone, landscape, iPad and accessibility text sizes.
- [ ] Install the reviewed IosApi 1.0.31 package in staging and prove two-account APNs reply/reaction delivery. Prove zero chat pushes for ordinary messages, mentions, self-interactions and Siropu private/external chat; verify existing non-chat notifications.
- [ ] With the shipped older app, verify safe quote-only and quote/reply messages remain visible after installing 1.0.31. With the updated app, verify quotes render once and logout during token registration leaves no old-account token registered.
- [ ] Produce the appropriate iOS test artifact (IPA/TestFlight). This SwiftUI iOS project does not generate Android APKs.

See `CHAT_PROFILE_STABILITY_VALIDATION.md`. Purchase implementation and configuration are unchanged.
