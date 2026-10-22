# Catalog search correction — 2026-10-22

The native catalog search field uses an always-visible navigation-bar drawer. The
home search shortcut retains the existing catalog tab route and activates native
search for typing. The shell preserves that requested focus during the tab change.
Switching away clears search presentation. Clearing the query reloads the catalog
using the existing filters, request-generation guards, and pagination behavior.

The existing catalog API contract and localized search prompts are reused.
No permissions, data collection, purchase behavior, or project configuration changed.

Executed on Windows:

- `Scripts/swift-test-windows.ps1 -Jobs 4`: all 467 core XCTest tests passed.
- `swiftc -frontend -parse` for the five changed Swift sources and new UI test: passed.
- `Scripts/swift-static-audit.ps1`: passed.
- `Scripts/ui-accessibility-audit.ps1`: passed (static checks only).
- `git diff --check`: passed.
- Before/after hashes match for the purchase service, Premium view/design, project
  configuration, entitlements, privacy manifest, and StoreKit configuration.

Added offline `CatalogSearchUITests` scenarios for initial search visibility,
submission and clearing, home-to-search activation, and accessibility text with tab
switching. The DEBUG catalog fixture now honors the search query so an unfiltered
response cannot satisfy the submission assertion.

Pending on macOS/Xcode: compile the iOS app and execute `CatalogSearchUITests` on
iPhone and iPad, including iOS 17 and the current supported iOS version. Native UI
behavior and runtime accessibility have not been verified on this Windows host.
