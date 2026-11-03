# Native personal audiobook comments — 2026-10-18

## Behavior

Profile's `profile.audio.comments` action previously opened the website's filtered member page. It now pushes `MyAudioCommentsView` in the current native navigation stack. Each comment opens its own native audiobook detail. The view preserves readable wrapping at large text sizes with no fixed text height or line truncation. Loading, empty, connection failure, unavailable endpoint, refresh and pagination are explicit states. The model injects a repository, deduplicates post IDs, retries the failed page/mode, rejects unexpected pages, and clears content/rejects delayed responses on account changes. Profile destination identity also follows the session revision.

The dedicated authenticated `GET /ios-api/v1/me/audio-comments` endpoint uses the site's AudioBooks `ProfileLibrary::comments` selector. Generic forum history is never substituted. Ownership, reply position, visible post/thread and their XenForo view permissions are checked before sorting/counting/pagination. A `scope: audio` response and valid pagination/IDs are required by the client. No purchase, posting, token storage or reader/playback behavior was changed for this fix.

## Executed evidence

- Windows full Core XCTest suite: 463 tests passed, including 7 new authenticated endpoint/DTO tests; log `artifacts/audio-comments-20261018/core-tests.log`.
- Exact model source: all 8 state tests passed in a Windows harness with only Combine publication removed; log `artifacts/audio-comments-20261018/model-state-tests.log`. This validates state behavior, not SwiftUI or Combine rendering.
- Actual PHP endpoint controller: 52 authentication, audiobook boundary, ownership, visibility, ordering, pagination, empty-history and read-only checks passed. Separate missing-Catalog and missing-ProfileLibrary scenarios pass 2 checks each. Empty pagination is normalized to one page to match the client contract.
- `Scripts/build-ios-api-addon.ps1 -CreateZip -OutputDirectory artifacts/audio-comments-20261018` passed the public route contract (74 paths), PHP lint, public-controller wrapper audits and existing offline backend regressions. Produces IosApi 1.0.38 (`1000038`); no server deployment.
- Swift source static and accessibility audits passed. All 11 changed Swift source/test files passed frontend parsing with DEBUG enabled. This is a syntax check only; it cannot type-check SwiftUI using the Windows SDK. Route regeneration into a separate evidence file retains exactly one new endpoint and leaves the reviewed routes untouched.

## Pending native and server checks

`App/EkitapligimUITests/MyAudioCommentsUITests.swift` contains four offline native UI scenarios: profile → both correct audiobook IDs → Back → profile with selected tab retained, accessibility3 horizontal bounds and scrollability, empty history, and HTTP 503 with an honest error. Execute on iPhone SE, iPhone 11 and iPhone 13 with Xcode. For example, after `xcodegen generate`:

```sh
xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim \
  -configuration Development -destination 'platform=iOS Simulator,name=iPhone 13' \
  -only-testing:EkitapligimUITests/MyAudioCommentsUITests
xcodebuild test -project Ekitapligim.xcodeproj -scheme EkitapligimModernUnit \
  -configuration Development -destination 'platform=iOS Simulator,name=iPhone 13' \
  -only-testing:EkitapligimTests/MyAudioCommentsModelTests
```

Repeat native navigation and screenshot review on iPhone 11 and SE. The local package must be installed through the normal XenForo add-on upgrade before this app feature can load real history. Then verify with an authorized staging account containing both audio and other forum comments, hidden/permission-denied posts and multiple audio-history pages. This task did not deploy the server, run Xcode, execute UI tests, produce an IPA or establish App Store readiness.
