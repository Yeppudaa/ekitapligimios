# Native book-opening transition — 2026-11-03

Book detail's signed-in **Kitap Oku** action now presents the native reader through the Android cover-opening sequence. The reference is `C:/Users/Monster/Downloads/startdesign (1)/app/src/main/java/com/ekitapligim/app/ui/components/ReaderOpeningTransition.kt`, SHA-256 `BE43B65CB53FB32C110E02B0F21CA8B91E7F28A79A0F5391B9DE068CD4DD9394`. The Android reference images at `deliverables/reader-opening-20261102/screenshots/02-kapak-ortada.png`, `03-kapak-aciliyor.png` and `04-sayfa-buyuyor.png` were inspected. Those are Android evidence, not iOS screenshots.

| Stage | Android timing reproduced in native source |
|---|---|
| Backdrop | 0–420 ms; `#111113` at 82%, Bezier `(0.42, 0, 1, 1)` |
| Lift | 0–560 ms; actual visible cover to screen center, 12 pt above midpoint; Bezier `(0.3, 0.7, 0.2, 1)` |
| Left hinge | 560–1380 ms; 0° to −178°, 1400 pt camera; Bezier `(0.45, 0.05, 0.25, 1)` |
| Paper | Visible at 560 ms, expands 1120–1640 ms to full window bounds |
| Reader handoff | 1640 ms, while paper completely covers the screen |
| Reveal | Quadratic fade at 1920–2160 ms |

The target cover uses Android's 220 pt reference width, width/390 scale capped at 1.15, physical/logical pixel rounding and phone/tablet/landscape size caps. Paper uses the existing local sepia/white/night preference. SwiftUI renders the artwork; a native geometry effect supplies the perspective. No web rendering or new dependency is involved.

`ReaderOpeningSource` captures the presenting window and visible cover once on tap, using that window's coordinates even inside a sheet. It keeps the exact currently displayed cover during the transition and avoids another image request when capture succeeds. A partially clipped/offscreen cover uses a centered fallback. Captured pixels exist only in memory and are released at completion, cancellation, dismissal or account replacement. Snapshot capture failure falls back to the existing native cover component.

The ordinary modal slide is disabled for this presentation. The current reader/session/file/progress flow begins behind opaque paper at the handoff. Its measured download progress and real errors remain authoritative; animation time is never shown as loading percentage. A close control and VoiceOver escape cancel the presentation. A cancellable, presentation-scoped sequence prevents later handoff after dismissal. Account replacement closes the presentation. Reduce Motion uses only a 180 ms paper crossfade; enabling it mid-transition, backgrounding or changing the presentation width (rotation/resizing) settles the presentation immediately. Existing continue-reading/deep-link routes retain their current presentation.

## Executed on Windows

The second source review corrected a handoff lifecycle issue: a reader-owned full-screen notice or cancellation of the transition task after handoff could remove the already mounted reader. Disappearance/task interruption now settles the artwork while retaining the same reader; explicit dismissal still cancels. Cancellation before handoff closes the presentation once instead of leaving an empty modal. The DEBUG opening fixture's close action now dismisses its parent, allowing its reopen assertion to exercise the intended flow.

Cover/paper geometry moved into the portable Core module and is now compiled and executed in the Windows suite. Zero/nonfinite viewports, invalid/clipped cover rectangles and unknown display scales are guarded before rendering. Phone/tablet/landscape source alignment, Android pixel rounding, scale caps and paper bounds have executable coverage. The native suite now includes an early reader-owned full-screen notice regression.

| Check | Result | Local evidence |
|---|---|---|
| `Scripts/swift-test-windows.ps1 -Jobs 4` | 495 Core XCTest cases passed, including 23 animation/layout/sequence tests | `.codex-artifacts/reader-opening-review-20261103/core-tests.log` |
| `Scripts/swift-test-windows.ps1 -Clean -Release -Jobs 4` | 495 optimized Core XCTest cases passed after clean build | `.codex-artifacts/reader-opening-review-20261103/core-release-tests.log` |
| `Scripts/validate-workspace.ps1` | Passed, including static source, API contracts, accessibility-label checks, basic secret scan and PHP syntax | `.codex-artifacts/reader-opening-review-20261103/workspace-audit.log` |
| Swift frontend parse in normal and DEBUG conditions | Passed; syntax only, without Apple SDK type checking | `.codex-artifacts/reader-opening-review-20261103/syntax.log` |

Core cases cover measured stage boundaries, monotonic Bezier motion, full paper before reveal, quadratic fade, invalid clock/geometry inputs, normal/reduced-motion timing, explicit cancellation versus child-presentation interruption before/after handoff, repeated appearance and background settlement. The optimized Core build is **not** an iOS Production build.

## Native validation pending

Windows has no Xcode, Apple SDK or iOS Simulator. The iOS application has not been type-checked, built, run or visually approved for this change. Two native `ReaderOpeningLayoutTests` and four `ReaderOpeningUITests` are authored but unexecuted. Native tests capture all seven reference times in three paper themes on phone/tablet, check window-coordinate cover capture and clipping fallback, exercise cancellation/reopening/reduced motion/reader-owned full-screen presentation, and verify the real offline PDF reader restores page 25. The extracted geometry tests now run in Core rather than being duplicated in the native target.

On macOS with Xcode, XcodeGen, Python 3, two installed iPhone simulators and an iPad simulator:

```bash
bash Scripts/reader-opening-macos.sh
```

The script runs a clean Development simulator build, unsigned Production iOS build, focused native/UI suites plus existing reader-experience/resume tests on three devices, and exports result bundles and image attachments under a unique `build/reader-opening-*` directory. The script was syntax-checked on Windows; its native commands have not executed here. Inspect exported hinge/paper frames next to the Android images. Also check actual book detail in its normal sheet, a loaded/failed cover, PDF/EPUB, public HTTPS loading/failure, VoiceOver, large text, rapid repeated taps, background/foreground, rotation, account replacement and close/reopen on device. Geometry/model tests do not establish actual device frame rate or visual equivalence.

`project.yml` already includes the new app and test directories; SwiftPM processes the updated reader resource. API payloads, token storage, purchases, entitlements, StoreKit products, privacy-manifest declarations and production endpoints need no configuration change. App Store draft/checklist and privacy/API/parity notes describe this addition. No App Store/TestFlight upload or backend deployment was performed.

API references consulted: Apple's [presentationBackground](https://developer.apple.com/documentation/swiftui/view/presentationbackground(_:)) and [Transaction.disablesAnimations](https://developer.apple.com/documentation/swiftui/transaction/disablesanimations).
