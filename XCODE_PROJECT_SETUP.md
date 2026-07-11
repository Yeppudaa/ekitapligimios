# Xcode Project Setup

This Windows workspace cannot generate or verify a signed iOS archive. On macOS, use `project.yml` with XcodeGen to create the Xcode project.

The checked-in GitHub Actions workflow can also run the unsigned Xcode build/test gate on `main`, `master`, `codex/**`, pull requests, or manual `workflow_dispatch`. A Git remote and committed repository contents are required before that runner can be used.

```bash
brew install xcodegen
xcodegen generate
xcodebuild -resolvePackageDependencies -project Ekitapligim.xcodeproj -scheme Ekitapligim -clonedSourcePackagesDirPath .build/xcode-packages
open Ekitapligim.xcodeproj
```

## Target
- Product name: `Ekitapligim`
- Interface: SwiftUI
- Language: Swift
- Minimum deployment: iOS 17
- Bundle identifier:
  - Development: `com.ekitapligim.app.dev`
  - Staging: `com.ekitapligim.app.staging`
  - Production: `com.ekitapligim.app`

## Add Sources
`project.yml` adds `App/Ekitapligim`, links the local `EkitapligimCore` package, and resolves Readium Shared/Streamer/Navigator exactly at `3.9.0`. Use Xcode 16.4 or newer and preserve the generated `Package.resolved` as release evidence.

## Build Configurations
Create or map Xcode configurations to:
- `App/Ekitapligim/Config/Development.xcconfig`
- `App/Ekitapligim/Config/Staging.xcconfig`
- `App/Ekitapligim/Config/Production.xcconfig`

## Capabilities
Required:
- Associated Domains for universal links.
- Sign in with Apple if Google login remains available.
- In-App Purchase if premium/digital access is sold in app.

Do not add push notifications until server/device-token handling is implemented and the permission prompt is contextual.

The entitlement file intentionally does not include push notifications or Apple Pay.

## Validation Commands
```bash
swift test
xcodebuild -scheme Ekitapligim -configuration Development -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme Ekitapligim -configuration Production -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build
xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -resultBundlePath TestResults.xcresult CODE_SIGNING_ALLOWED=NO
```

The `Ekitapligim` scheme includes `EkitapligimTests` and `EkitapligimUITests`. A build-only command is not test evidence; release validation requires a successful `xcodebuild test` result bundle, including the offline primary-navigation UI smoke test.

For the real App Store archive, remove `CODE_SIGNING_ALLOWED=NO`, set `APPLE_TEAM_ID`, use the Production configuration, and archive from Xcode or `xcodebuild archive` with a valid Apple Developer signing identity.
