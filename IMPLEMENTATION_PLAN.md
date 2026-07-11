# Implementation Plan

## Backend
1. Deploy `MobileApi-addon` to a public HTTPS staging environment.
2. Replace `xf_user` pseudo tokens with signed access/refresh tokens.
3. Add Sign in with Apple backend endpoint. JWKS/RS256 verification, authorization-code exchange, encrypted refresh-token storage, and deletion-time revocation are implemented; signed-device evidence remains.
4. Add StoreKit transaction verification and App Store Server Notifications. Client and endpoint contract exist; production App Store Server API verification remains.
5. Add user block/unblock/list endpoints. Scaffold exists in `Backend/MobileApi-addon`.
6. Confirm post reporting and abuse moderation workflows. Scaffold exists in `Backend/MobileApi-addon`.
7. Install and test terms acceptance before UGC posting. Scaffold exists in `Backend/MobileApi-addon`.
8. Add automated API tests for auth, catalog, reader, UGC, account deletion, and billing.

## iOS Core
1. Create Xcode iOS app target on macOS.
2. Import `EkitapligimCore`.
3. Add build configurations: Development, Staging, Production. Source `.xcconfig` files now exist under `App/Ekitapligim/Config`.
4. Wire API base URL through `.xcconfig`, not source literals.
5. Add Keychain token storage and redacted logging. Initial source is present and still requires macOS build verification.

## Authentication
1. Implement login/register/forgot password.
2. Implement session restoration and refresh.
3. Implement Google login only with Sign in with Apple. Initial Apple client button and backend contract exist.
4. Add logout and account-disabled/expired-session states.

## Library
1. Implement home/catalog/search/book detail vertically.
2. Implement authors/publishers directories.
3. Implement library shelves, favorites, continue reading. Initial shelf UI exists; continue-reading shortcut still needs final polish.

## Reader
1. Implement reader access/session.
2. Implement PDFKit reader.
3. Sync progress and bookmarks.
4. Validate download URLs and corrupted files.
5. Review EPUB dependency before adding EPUB support.

## Downloads
1. Add download queue/cancel/resume. Initial single-file manager exists; cancellation/resume still required.
2. Store files with file protection and iCloud backup exclusion. Initial implementation and downloads view exist.
3. Reconcile progress after reconnection.

## Community
1. Implement forums/topic/reply. Initial native forum list, thread list, post detail and reply views exist.
2. Implement comments and reports. Initial report sheet exists for books/posts.
3. Implement block user UX. Initial block/unblock/list views exist.
4. Implement conversations only after privacy and permission checks.

## Payments
1. Define product IDs in App Store Connect.
2. Implement StoreKit 2 product loading, purchase, pending, failed, cancel, restore. Initial client service exists.
3. Verify transactions server-side. Endpoint contract exists; production verification still required.
4. Sync entitlement to XenForo premium state.

## Privacy
1. Finalize data inventory. Initial inventory and native privacy settings scaffold exist.
2. Update privacy policy.
3. Prepare App Store privacy labels.

## Accessibility
1. Add Dynamic Type and VoiceOver labels to all critical controls.
2. Test login, catalog, detail, reader, report/block, and deletion flows.

## Testing
1. Expand Swift unit tests.
2. Add API integration tests against staging.
3. Add XCUITest journeys.
4. Run release build and archive on macOS.

## Release
1. Prepare reviewer account and review notes.
2. Prepare screenshots, app metadata, age rating, privacy labels.
3. Submit TestFlight build.
4. Fix TestFlight/App Review findings before production release.
