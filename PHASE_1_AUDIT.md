# Phase 1 Audit

## Inspected
- Android source: `C:\Users\Monster\Downloads\startdesign (1)\app`.
- XenForo mobile addon: `C:\Users\Monster\Downloads\startdesign (1)\MobileApi-addon`.
- Local app workspace: `C:\Users\Monster\Documents\IOS App`.
- Local XenForo site: `http://localhost/ekitapligim/`.
- Official Apple references for review guidelines, account deletion, privacy labels, and App Store Server Notifications.

The local XenForo URL responded with HTTP 200 and identifies as XenForo 2.3, Turkish, public forum list, logged out. `http://localhost/ekitapligim/mobile-api/v1/books?page=1` returned HTTP 404, including through `Scripts/api-smoke-test.ps1 -AllowInsecure`, so the local MobileApi public route is not currently reachable at that path or the addon/routes are not enabled in the local site.

## Feature Inventory
- Authentication: username/password, registration, forgot password, Google auth, logout, token refresh route.
- Catalog: books list, book detail, popular/latest ordering, search filters, authors, publishers, related books.
- Library: shelf state, progress percent, last read page, downloads, favorites.
- Reader: access check, reader session, source retrieval, progress sync, PDF/EPUB-like handling.
- Community: forums, topic lists, topic detail, replies, members, follow/unfollow.
- Private community: conversations, messages, replies.
- Notifications: notification list, counts, mark read, mark all read.
- Premium: daily read/download quotas, premium screen, Google Play verify endpoint.
- Safety: account deletion request endpoint, book issue report endpoint.

## Risk Report
- Release blocker: no public staging URL was provided.
- Release blocker: Android billing verification is Google Play-specific and placeholder-like.
- Release blocker: iOS needs StoreKit server verification and App Store Server Notifications for paid digital access.
- Release blocker: user blocking endpoint was not found in mobile routes.
- Release blocker: Google auth on iOS triggers Sign in with Apple requirement if used as a primary auth option.
- High risk: Android fallback uses cookies/`xf_user:{id}` behavior. iOS should not depend on that for production.
- High risk: offline download rights are unverified.
- Medium risk: EPUB reader dependency requires license/privacy review.
- Medium risk: UGC moderation/reporting needs full native UX and backend enforcement.

## API Gap Analysis
- Add `POST /mobile-api/v1/auth/apple`.
- Replace pseudo token behavior with signed short-lived access tokens and refresh tokens.
- Add `POST /mobile-api/v1/billing/app-store/verify`.
- Add App Store Server Notifications endpoint.
- Add `POST /mobile-api/v1/members/{user_id}/block` and unblock/list endpoints.
- Add explicit forum post reporting endpoint if not already available.
- Add terms acceptance/status endpoint if posting remains available.

## Proposed Architecture
Use native SwiftUI with a shared `EkitapligimCore` package for configuration, API endpoints, DTOs, auth state, reading progress, deep links, and testable business logic. The app target should layer feature modules on top: Auth, Library, Reader, Downloads, Community, Purchases, Settings.

## Assumptions
- Book reading is primarily PDF, based on Android reader code and MobileApi reader source naming.
- Premium grants digital read/download benefits, so iOS must use StoreKit unless the product is redesigned as a reader app with externally purchased content only.
- XenForo forums/messages/comments are UGC and require App Store UGC safeguards.
