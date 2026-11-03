# Premium design refresh — 18 October 2026

## Scope and reference

Native SwiftUI presentation now follows the Android `PremiumScreen.kt` in the user-provided `Downloads/startdesign (1)` project and its `deliverables/premium-visual-refresh-20261017` screenshots:

- Teal scenic hero, cream serif heading, gold copy and a gold shortcut that scrolls to plans.
- Illustrated audio benefit, two illustrated daily reading/download cards, and three benefit rows.
- Android light/dark palette, 22-point card corners, 16-point page insets and 24-point section spacing.
- Content-led text height and stacked quota cards below 340 points of available width or above the iOS extra-large text category. Reduce Motion disables the shortcut animation.
- Plan surfaces, annual emphasis, supporting actions and legal rows use the same palette.

The three existing iOS artwork assets (`catalog_scenic_reading`, `audio_shelf_continue`, `audio_story_landscape`) match the decoded Android source images exactly. No images or dependencies were added.

## Purchase boundary

StoreKit product names, localized prices, product order and IDs still come from the existing service/catalog. Product buttons retain their original purchase handlers and login/busy gates. Preparation, purchase confirmation, errors, restore, subscription management, entitlement/expiration calculations, cancellation and renewal disclosures, and legal links are unchanged.

Android radio selection and its separate purchase action were not ported because that would change the authorized iOS purchase flow. Each existing product button retains its purchase label and action. Annual visual emphasis is a display treatment, not a selection state or a price-saving claim.

Android's priority-voting promise is replaced with the existing book-request capability: the iOS backend gives each vote a weight of one. Reader copy mentions the implemented sepia/night modes without claiming premium exclusivity or paper textures. Daily 10-read/10-download copy follows the existing iOS premium copy; authorization and actual quota enforcement remain on the server.

All new copy is in Turkish/English `PremiumDesign.strings` resources. Nine color assets supply light/dark variants. Existing recursive XcodeGen source/resource inclusion already includes these files; project configuration, StoreKit configuration, entitlements, privacy manifest and App Store purchase disclosures require no behavioral changes.

## Executed validation

- `swiftc -frontend -parse App/Ekitapligim/Features/PremiumView.swift App/Ekitapligim/Design/PremiumDesign.swift` — passed (syntax only).
- `Scripts/swift-static-audit.ps1` — passed.
- `Scripts/ui-accessibility-audit.ps1` — passed (source audit only).
- `Scripts/premium-contract-audit.ps1` — passed.
- Turkish/English resources — 25 matching, unique keys; valid string syntax.
- Nine asset JSONs — valid universal default/light and luminosity/dark sRGB definitions.
- Exact comparison against the original `PremiumView.swift` — purchase/state/restore/legal actions unchanged.
- `Scripts/swift-test-windows.ps1` — failed before any tests ran: Swift process exit `-1073741795` (`0xC000001D`). No passing core-suite result is claimed for this change.

## Native validation still required

This host is Windows and has no Xcode or iOS SDK. Syntax parsing does not type-check SwiftUI or render an iPhone screen. iPhone/iPad screenshots, interactive VoiceOver/Dynamic Type checks, native unit/UI tests and a Production build remain unexecuted for this change. The repository's macOS CI workflow contains those build/test routes. This document does not assert App Store readiness or pixel-perfect runtime parity.

## Narrow-width and readability follow-up

The user requested another review specifically for text shifting, clipping and narrow devices. Source review and numerical color checks identified and addressed these risks:

- Quota image badges were overlays inside a fixed 96-point image. Their text now participates in layout, with a minimum image height of 96 points that grows when the badge wraps. Badges and the hero eyebrow now use the native, scalable 11-point caption style instead of 8/9-point base sizes.
- Hero body copy increased from 13 to 15 points, audio body from 12 to 13, and quota/benefit descriptions use the 13-point footnote style. Text retains its full content and can grow vertically.
- Shared action labels remove decorative icons above `.xLarge`, preserving width for wrapped text. Accessibility-size benefit rows stack their icons above the description. The shared quota layout stacks below 340 points of actual content width or above `.xLarge`.
- Disabled product cards no longer fade their prices and descriptions to 50% opacity. Only the CTA surface changes to show its disabled state, with readable theme-aware text; existing `.disabled` conditions and all purchase callbacks are unchanged.
- Stronger hero/audio image overlays and a slightly darker light-mode secondary text color protect small text over bright artwork and the annual-plan surface.

The reproducible standard-library audit in `artifacts/premium-layout-20261018/premium-contrast-audit.py` reads the source colors and asset definitions. All **69** checks passed. Conservative minimum ratios over bright artwork/surfaces are:

| Checked role | Minimum contrast |
| --- | ---: |
| Hero text | 4.949:1 |
| Audio card text | 4.700:1 |
| Light-mode secondary text | 4.849:1 |
| Disabled CTA text | 7.197:1 |

The associated JSON records the input hashes and individual calculations. These are numerical color checks, not screenshots or native accessibility results.

`App/EkitapligimTests/PremiumLayoutTests.swift` adds hosted native rendering tests for real card components at **320/375/393 points**, `.large`/`.xLarge`/`.accessibility3`/`.accessibility5`, and light plus dark/disabled states. It checks finite fitting bounds, width containment, vertical growth, long Turkish/English plan titles, and prepares five UIKit screenshot attachments, including the production two-column quota layout. No StoreKit service or purchase is involved. Syntax parsing passed; **these native tests and their screenshot review have not run on this Windows host**. Fitting bounds alone cannot establish that every internal text glyph is unclipped.

Swift syntax parsing, the Swift static audit, accessibility source audit, premium contract audit and whitespace checks were rerun after the follow-up edits and passed. Native iPhone/iPad verification remains the limitation described above.
