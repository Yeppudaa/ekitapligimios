# Ekitapligim iOS

Native iOS implementation plan and starter code for Ekitapligim.com.

This repository currently contains the audited architecture documentation and a testable Swift core package. It is intentionally not a website wrapper. The final App Store app should be an Xcode iOS application target that imports `EkitapligimCore` and implements native SwiftUI screens.

## Current Status
- Android project inspected from `C:\Users\Monster\Downloads\startdesign (1)`.
- XenForo MobileApi addon inspected from `MobileApi-addon`.
- Swift core package scaffolded with typed configuration, API endpoint construction, DTOs, auth state, reading progress, and deep-link parsing.
- Native SwiftUI app source scaffold added under `App/Ekitapligim`.
- StoreKit 2 client purchase service scaffold added. Server-side App Store verification is still required before release.
- Backend MobileApi scaffold patches for Apple auth, App Store verification, user blocking, blocked members, and post reporting added under `Backend/MobileApi-addon`.
- Terms acceptance and App Store Server Notifications backend scaffolds added under `Backend/MobileApi-addon`.
- Native forum list/thread/post/reply scaffolding and secure offline download manager added.
- Native library shelves, downloads list, and re-authenticated account deletion flow added.
- Native profile, notifications, and privacy settings scaffolds added.
- XcodeGen `project.yml`, entitlements, privacy manifest, StoreKit config, universal link instructions, and App Store metadata drafts added.
- Backend patch apply script and AASA template added for staging deployment preparation.
- Branded AppIcon asset catalog generated from the Android `app_logo_round.png` source, plus launch screen color. Rights-holder visual approval remains required before submission.
- Xcode is not available in this Windows workspace, so iOS app archive/build verification must be run on macOS with current Xcode.

## Setup
Required environment values for local development:

```text
EKITAPLIGIM_DEVELOPMENT_API_BASE_URL=https://staging.example.com/mobile-api/v1/
EKITAPLIGIM_STAGING_API_BASE_URL=https://staging.ekitapligim.com/mobile-api/v1/
EKITAPLIGIM_PRODUCTION_API_BASE_URL=https://ekitapligim.com/mobile-api/v1/
```

Do not place secret values in this repository.

## Build On macOS

EPUB support uses Readium Swift Toolkit `3.9.0` through Swift Package Manager. Use Xcode 16.4 or newer so the pinned package can resolve and build, then retain the generated `Package.resolved` with release evidence.
Windows/source validation:

```powershell
.\Scripts\validate-workspace.ps1
.\Scripts\swift-test-windows.ps1
.\Scripts\api-smoke-test.ps1 -BaseUrl "https://staging.ekitapligim.com/mobile-api/v1/"
.\Scripts\appstore-preflight.ps1
.\\Scripts\\apply-mobileapi-ios-patch.ps1 -AddonPath "C:\\path\\to\\MobileApi-addon" -CreateZip
.\\Scripts\\generate-branded-appicon.ps1 -SourcePath "C:\\path\\to\\app_logo_round.png"
```

```bash
swift test
open Package.swift
```

Generate the Xcode project with XcodeGen:

```bash
brew install xcodegen
xcodegen generate
```

Then build:

```bash
xcodebuild -scheme Ekitapligim -configuration Debug build
xcodebuild -scheme Ekitapligim -configuration Release -destination generic/platform=iOS build
xcodebuild test -scheme Ekitapligim -destination 'platform=iOS Simulator,name=iPhone 15'
```

See `XCODE_PROJECT_SETUP.md` for target setup.
See `VALIDATION.md` for validation gates.

## Important Release Notes
- App Review cannot use localhost. A public HTTPS staging environment and reviewer account are mandatory.
- Premium access and paid digital content on iOS require StoreKit and server-side App Store transaction verification.
- Google login exists on Android; iOS must also implement Sign in with Apple if third-party login remains available.
