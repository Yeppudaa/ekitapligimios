# Directory letter-selection latency — 2026-11-03

## Changes

The first directory response previously awaited optional site statistics before publishing rows. Statistics now run in a separate view task: the first matching rows and list-loading completion are independent of those counters. Subsequent candidate pages still publish progressively, preserving the existing matching-batch and complete-pagination behavior.

The index requests `per_page=100`, which both current MobileApi author/publisher controllers support (maximum 100). The previous server default was 30. This reduces candidate-page round trips without increasing concurrency or changing endpoints. The optional page-size argument leaves other repository callers' defaults unchanged. The server's returned pagination remains authoritative.

Up to six successful selections are cached in the directory model for 120 seconds, keyed by the exact normalized query/initial. Returning to one restores rows and the next-page cursor without a network request. Snapshots larger than 2,000 rows are not retained; this is a cache limit, not a visible-result limit. Pull-to-refresh bypasses the cache. Changing directory kind clears it, and the existing view identity scopes the model to the current account/session. Nothing is persisted to disk.

Owned request tasks are cancelled when a letter changes or the view disappears, including button-created pagination work. Cancellation propagates through the existing async URLSession transport; late-response guards remain. The 300 ms typing debounce now applies only to changed query text, not to a letter switch while query text is present or to a cached selection.

The scenic directory design, text, cards and book navigation are unchanged. No Android/backend deployment, API credential change, SDK, entitlement, StoreKit or permission change is included.

## Executed checks

Evidence: `.codex-artifacts/directory-speed-20261103/`.

- **511 Core tests passed**, including page-size bounds and preservation of default directory request construction.
- **32 actual-model portable tests passed**: 22 directory tests and 10 existing profile regressions, using the test-only Combine storage shim.
- New deterministic tests hold statistics or a later candidate page indefinitely behind a gate and confirm that first rows are already available. Repeated-letter selection makes zero new page requests and resumes the correct next cursor. Expiration, explicit refresh, six-entry eviction, directory-kind isolation and cancellation of a suspended old transport are checked.
- Existing 67-result, whole-page overflow, partial failure/retry and Turkish-initial regressions still pass. The speed change introduces no total-result cap.
- Normal/DEBUG Swift syntax checks, workspace static/API/accessibility-label/basic-secret checks and a hash comparison of the directory design passed.

These are controlled transport/state results, not measured live-device timings. The deployed server's query time, network latency and cache misses can still affect initial loading. No millisecond or percentage improvement is claimed for real users.

## Native validation

This Windows host has no Xcode/iOS Simulator. Run the existing `bash Scripts/directory-design-macos.sh` on macOS for native builds, updated model tests and directory UI/layout screenshots. On a signed test build, measure cold C/D/İ/Z selections, repeat a letter within two minutes, switch rapidly during loading, pull to refresh, and change accounts. Check both authors and publishers, first-row display and continued access to all results. No native build or live latency result is claimed here.
