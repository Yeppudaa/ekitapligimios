# AI Assistant validation

## Implemented

Native SwiftUI assistant, server-owned quota/feature checks, persistent anonymous Keychain identity, shared iOS bearer refresh, conversation/history/preferences/collections/book profiles, explicit action confirmation, secure links, and localized accessible controls. Existing primary navigation and billing products remain intact. Android and server quota code were not modified.

Source integration points are limited to the application container, menu/launcher presentation, book-detail entry, hiding the launcher in reader/auth/premium flows, and existing API request routing. A pre-existing Readium compile blocker in `EPUBPositionAdapter` was repaired: `Link.href` is already a `String`, so the invalid `.string` access was removed.

## Executed evidence (2026-09-06)

- Windows: `swift test --scratch-path .build/ai-assistant`; core tests passed, including the AI policy/model/transport contract tests. Detailed output: `.codex-artifacts/ai-assistant/core-tests.log`.
- `Scripts/validate-workspace.ps1` passed, including the repository secret scan and backend syntax checks. Output: `.codex-artifacts/ai-assistant/workspace-validation.log`.
- Swift syntax parse passed for new assistant app, security, unit-test and UI-test files. Syntax parsing alone is not an iOS build.
- Live HTTPS guest smoke test passed: create disposable conversation, send one synthetic book prompt, read answer/history, delete the test conversation. Server usage advanced **0 → 1** and stayed **1** after deletion; reported limit was **2**. No key or conversation content is saved in the report. Evidence: `.codex-artifacts/ai-assistant/guest-smoke.json`.
- The test conversation was removed. `Scripts/test-ai-assistant-guest.ps1` deliberately consumes one guest request when manually run; normal CI uses offline fixtures.

## macOS validation

Validation snapshots run on the isolated `codex/ai-assistant-validation-20260906` branch. The user's checkout branch and normal Git index are preserved. Snapshots include the existing in-progress reader source needed to build this workspace; they are not a merge or an App Store release.

- First run: source checks, core tests and reader backend tests passed; iOS compile stopped on the pre-existing Readium `Link.href.string` error, now repaired.
- Second run: the new transport test exposed Darwin's use of an HTTP body stream. The test now reads either `httpBody` or `httpBodyStream`; production form encoding was unaffected.
- Final iOS build, simulator tests, Production build, screenshots and accessibility results: pending completion of the corrected CI run.

## Remaining release gates

- Run the complete macOS/iPhone/iPad checks on the final source revision and inspect AI XCTest screenshot attachments.
- Verify real standard-member, Premium/VIP and administrator accounts, including shared Android/iOS usage and group changes. No such test credentials were present in the inspected environment; requested separately without asking for passwords in chat.
- Verify server-side AI history cleanup when a user deletes their account. No account deletion or server rule changes were performed as part of this client addition.
- Verify actual weekly digest notification delivery on a registered iOS device if enabled for release.

This record does not claim App Store readiness while any required evidence is pending.
