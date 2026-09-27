# Native gift wheel — 2026-09-27

## Scope and reference

Native SwiftUI/Canvas gift wheel, reached through the side menu after Live Activity and the `gift-wheel` / `/hediye-carki/` routes. Reference: Android `GiftWheelScreen.kt`, `GiftWheelRoute.kt`, `GiftWheel.kt`, `GiftWheelApi.kt` in `C:\Users\Monster\Downloads\startdesign (1)`, plus the rendered localhost web page. No Android or server source was edited.

The drawing copies the Android 560-unit geometry: 12 slices, 232-unit segment radius, violet metallic rim, 96 warm bulbs, fixed gold book hub, fixed pointer, and stars. Colors, Turkish copy, spacing, prize cards, wallet, winners and history follow that reference. iPad uses two columns; narrow screens and accessibility text sizes stack the stage vertically.

## Behavior and isolation

- Separate URLSession client calls only PremiumWheel `hediye-carki-api` status/winners/spin. The allowlisted public HTTPS site root is used; localhost is a read-only reference, never a release endpoint.
- Server controls eligibility, prize ordering, wallet, history and result. No local random award or premium entitlement update.
- Bearer token comes from Keychain. The existing coordinated session-refresh method handles a 401 through iOS auth. No shared API client/endpoint/repository source modifications were required.
- Request key and revision are atomically saved before POST, separately per account. Ambiguous failures retain the key; retry recovers the same server operation. Explicit 400/409 rejection clears it. Sign-out/account changes discard visible state; account deletion clears this account's pending file.
- Motion uses Android cubic-bezier(.12,.7,.12,1), nine full turns plus the exact landing angle, and ten seconds of display-link time from the first frame. Result stays hidden until 10.000 seconds. Background/dismissal pauses visible time; reopening resumes. Reduce Motion retains the ten-second interval with a static wheel and progress indicator.
- No StoreKit calls, purchase screen changes, product changes, MobileApi changes, IosApi changes or backend writes. Existing uncommitted purchase work was preserved.
- `project.yml` already includes the app feature directory and package resources. No dependency, project setting or new entitlement is required. Existing privacy-manifest UserID/ProductInteraction categories cover this feature. StoreKit configuration remains untouched.

## Executed evidence

Local logs are under `.codex-artifacts/gift-wheel/` (ignored build evidence).

- Initial implementation: existing 248 core tests passed.
- Initial wheel suite: 270 core tests passed, including 22 new tests.
- `swiftc -frontend -parse -D DEBUG`: passed for added SwiftUI, changed app wiring and UI tests. Syntax validation only, **not iOS type checking**.
- `Scripts/validate-workspace.ps1`: passed, including obvious-secret scan and configuration/resource checks.
- `Scripts/swift-static-audit.ps1`: passed.
- `Scripts/ui-accessibility-audit.ps1`: passed (static checks only).
- Protected baseline comparison: all 157 backend/purchase/shared API files match their pre-task SHA-256 hashes, including pre-existing uncommitted modifications.
- Unauthenticated GET to localhost and public HTTPS `hediye-carki-api/status`: HTTP 401, JSON `error.code=unauthorized`. Public deployment is reachable and rejects anonymous access; this does not prove authenticated spinning.

- Clean Swift package build and test using a fresh `.build/gift-wheel-clean` scratch directory: **271 XCTest tests passed**, including 23 wheel tests and all 248 existing tests. The additional test verifies account-deletion cleanup is scoped to the current account.
- `swift build -c release --scratch-path .build/gift-wheel-clean`: **passed** (Windows EkitapligimCore release build, not an iOS archive).
- Final suite after adding in-flight account-switch and no-prize coverage: **273 XCTest tests passed**, including 25 gift-wheel tests. Recovery is tested using an actual `URLError.timedOut` failure from the injected service. Evidence: `core-tests-final.log`.
- Final DEBUG and Production Swift syntax parse passed; final protected-file comparison and `git diff --check` passed.
- Toolchain emitted Windows URLProtocol Sendable warnings in test doubles and an inability to create convenience debug/release symlinks; actual build/test artifacts completed successfully in their target directories.

No real prize, quota or purchase mutation was performed.

## Required macOS/device evidence

This Windows host has no Xcode, iOS SDK or Simulator. No iOS build, native screenshot, runtime accessibility audit or authenticated live spin is claimed.

1. Generate with `xcodegen generate`; clean/build Development and Production on macOS.
2. Run `EkitapligimTests` and `EkitapligimUITests/GiftWheelUITests` on iPhone and iPad. DEBUG-only `-gift-wheel-ui-fixture` bypasses bootstrap/network/purchases; modes: guest, ready, quota, error, noPrize. It is excluded from Production.
3. Compare screenshot attachments against Android at matching widths; inspect small iPhone, iPad, large text, VoiceOver and Reduce Motion.
4. Verify ten-second animation with a recording, all prize positions, background/resume, repeated taps, exhausted quota, no-prize result, disconnect/relaunch recovery, and account switching with a review account on public HTTPS staging.
5. Confirm server gift-history/account-deletion retention and existing entitlement display refresh in a real session. Do not change purchases to test the wheel.
6. Deploy repository AASA additions before claiming `/hediye-carki/` Universal Links work outside the app.

App Store readiness and exact device visual parity remain unverified until these checks pass.
