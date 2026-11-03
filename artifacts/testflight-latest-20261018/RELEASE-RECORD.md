# TestFlight 1.1.0 (47) — 18 October 2026

The latest captured application was uploaded successfully and Apple finished processing it.
The existing **Ekitapligim Internal Testers** group (2 testers) shows **1.1.0 (47): Testing**.

- Source: `189765c276ddc160e7d84316c7161abc8ce7f655`
- Branch: `codex/testflight-current-20261018`
- CI: https://codemagic.io/app/6a5221a644ecae83eeea61ec/build/6ad4cb0212cce3cb997c9106
- All 495 captured application/test files match the primary working directory.
- 63 protected purchase, authentication, download and configuration files match the previous uploaded source.
- Current validation: **467 Core tests, 65 native iOS tests, 21 UI tests passed**, with zero failures/skips in the native/UI reports.
- Production archive and IPA export succeeded; the actual bundle signature, profile, production HTTPS origin, push environment and associated domains were verified.
- IPA SHA-256: `0d1f937715bd98c2db28d23203371ef845cb8e81cf3140f92def733521fb3d72`
- Upload result: **UPLOAD SUCCEEDED with no errors**.
- Apple proof: `TestFlight-1.1.0-47-Testing.jpg` and `apple-internal-testing-visible.txt`.
- Downloaded CI reports: `build17-results/build/testflight-reviewed/`.

This release includes the current home/card/genre, agenda, audiobook routing, library/favorite/activity, profile audio-comment and menu changes. Embedded genre catalogs now push the selected native book detail directly; the complete genre → catalog → detail → back UI regression passed.

The Windows workspace/secret scan, Swift static audit and accessibility source audit also passed. Real Apple Sandbox purchases were not performed during this upload; protected purchase implementation was unchanged and the previously executed purchase contract checks remain separate evidence.

Distribution is to TestFlight's existing internal group. No public App Store release, external beta review, or backend deployment was performed.
