# Scripts

## `validate-workspace.ps1`

Runs the checks available in this Windows workspace:

- Required file presence.
- XML/plist parsing.
- JSON parsing.
- Production URL guard.
- Entitlement scope guard.
- Swift release-marker scan and static app/project audit.
- SwiftUI accessibility audit for icon-only buttons and multi-line editors.
- Basic secret scan.
- PHP syntax check for backend API and public bridge controllers, when PHP is installed.
- Optional tool availability for Swift, Xcode, and XcodeGen.

Usage:

```powershell
.\Scripts\validate-workspace.ps1
```

Use `-Strict` in CI-like environments where PHP must be installed:

```powershell
.\Scripts\validate-workspace.ps1 -Strict
```

## `swift-test-windows.ps1`

Loads the installed Visual Studio C++ environment and official Swift for Windows SDK, then builds `EkitapligimCore` and runs its unit tests:

```powershell
.\Scripts\swift-test-windows.ps1
```

This validates the portable core package. Xcode is still required for the SwiftUI app target, Readium, StoreKit, PDFKit, Keychain, simulator, and UI tests.

## `swift-static-audit.ps1`

Runs Swift/project checks that are useful before Xcode is available:

- Unsafe force operation and release-marker scan.
- UIKit import checks for UIKit-backed SwiftUI wrappers.
- Swift package target/resource path checks.
- `project.yml` reference checks for app support resources.
- Runtime source/config guard against accidental local or insecure URLs.

Usage:

```powershell
.\Scripts\swift-static-audit.ps1
```

## `ui-accessibility-audit.ps1`

Runs lightweight SwiftUI accessibility checks before Xcode UI testing is available:

- Icon-only `Button` blocks must provide an accessibility label or equivalent.
- `TextEditor` controls must provide explicit accessibility labels.
- `Localizable.xcstrings` must be present and populated.

Usage:

```powershell
.\Scripts\ui-accessibility-audit.ps1
```

## `api-smoke-test.ps1`

Checks that a staging or production Mobile API is reachable. The public checks include books, forums, a forum thread list, a thread post list, and book stats:

```powershell
.\Scripts\api-smoke-test.ps1 -BaseUrl "https://staging.ekitapligim.com/mobile-api/v1/"
```

## `public-release-audit.ps1`

Checks the public HTTPS legal/support pages, Mobile API JSON contract, and Apple App Site Association file before TestFlight or App Review:

```powershell
.\Scripts\public-release-audit.ps1 -TeamId "YOUR_APPLE_TEAM_ID"
```

The command is expected to fail until the MobileApi add-on and `Web/.well-known/apple-app-site-association` are deployed publicly.

## `prepare-public-deployment.ps1`

Creates an immutable deployment directory containing the latest verified MobileApi XenForo ZIP, SHA-256 manifest, deployment instructions, and an AASA file with the real Team ID:

```powershell
.\Scripts\prepare-public-deployment.ps1 -TeamId "YOUR_APPLE_TEAM_ID"
```

The Team ID must be ten uppercase letters or digits. Existing output directories are never overwritten.

For local development only:

```powershell
.\Scripts\api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -AllowInsecure
```

Pass a current random `ms_at_` access token to `-BearerToken` to include authenticated endpoints. Legacy `xf_user:*` bearer values are rejected.

```powershell
.\Scripts\api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -BearerToken $env:EKITAPLIGIM_SMOKE_ACCESS_TOKEN -AllowInsecure
```

Use `-ExerciseMutations` only with a disposable demo account. It writes a low-impact reader progress and library update for the selected or first visible book:

```powershell
.\Scripts\api-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -BearerToken $env:EKITAPLIGIM_SMOKE_ACCESS_TOKEN -AllowInsecure -ExerciseMutations
```

## `session-rotation-smoke-test.ps1`
Uses `EKITAPLIGIM_SMOKE_LOGIN` and `EKITAPLIGIM_SMOKE_PASSWORD` for a disposable account. It verifies refresh rotation, old-token rejection, refreshed access, logout, and post-logout rejection without printing tokens.

```powershell
.\Scripts\session-rotation-smoke-test.ps1 -BaseUrl "https://staging.ekitapligim.com/mobile-api/v1/"
```

## `ugc-safety-smoke-test.ps1`

Checks App Review-critical community safety flows: block/unblock, blocked members visibility, terms acceptance, and rejection of unauthenticated replies.

For local development:

```powershell
.\Scripts\ugc-safety-smoke-test.ps1 -BaseUrl "http://localhost/ekitapligim/mobile-api/v1/" -BearerToken $env:EKITAPLIGIM_SMOKE_ACCESS_TOKEN -BlockedUserId 4 -ThreadId 1 -AllowInsecure
```

Use a disposable normal-member token and a safe demo target user on staging. The script attempts cleanup by unblocking the target user at the end.

## `appstore-preflight.ps1`

Checks App Store metadata and reviewer-note readiness:

```powershell
.\Scripts\appstore-preflight.ps1
```

During development, placeholders can be allowed explicitly:

```powershell
.\Scripts\appstore-preflight.ps1 -AllowPlaceholders
```

## `apply-mobileapi-ios-patch.ps1`

Applies the iOS MobileApi backend scaffold to an existing XenForo addon checkout and can create an upload zip:

```powershell
.\Scripts\apply-mobileapi-ios-patch.ps1 -AddonPath "C:\path\to\MobileApi-addon" -CreateZip
```

The script also regenerates public route bridge controllers so XenForo public routes such as `/mobile-api/v1/books`, `/mobile-api/v1/forums/{id}/threads`, and `/mobile-api/v1/threads/{id}/posts` dispatch to the API-style controller methods and render JSON. After route merging, it audits every `action_prefix` and fails if the corresponding XenForo `actionX` controller method is missing.

Use `-BumpVersion` when routes or controller surface changes need a XenForo add-on upgrade/import cycle:

```powershell
.\Scripts\apply-mobileapi-ios-patch.ps1 -AddonPath "C:\path\to\MobileApi-addon" -BumpVersion -CreateZip
```

## `api-route-contract-audit.ps1`

Compares every Swift `APIEndpoint` path template with `Backend/MobileApi-addon/public-route-contract.txt`. When the local XenForo addon exists, it also verifies that contract against the installed public route XML.

```powershell
.\Scripts\api-route-contract-audit.ps1
```

## `generate-placeholder-appicon.ps1`

Generates a placeholder `AppIcon.appiconset` so Xcode project generation has a complete icon asset catalog:

```powershell
.\Scripts\generate-placeholder-appicon.ps1
```

The generated icon is not final brand artwork. Replace it before App Store submission.

## `generate-branded-appicon.ps1`

Generates every iPhone/iPad AppIcon PNG from the approved square Android brand source, flattening onto white as opaque RGB and recording source SHA-256 evidence in `APP_ICON_SOURCE.md`:

```powershell
.\Scripts\generate-branded-appicon.ps1 -SourcePath "C:\path\to\app_logo_round.png"
```

Do not run the placeholder generator after branded assets have been produced. Rights-holder visual approval and real-device inspection remain release gates.
