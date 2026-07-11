# Android To iOS Feature Parity

| Area | Android Evidence | iOS Target | Status |
|---|---|---|---|
| Home | `HomeScreen.kt`, stats API | Native SwiftUI home | Native navigation plus live book/author/publisher/category statistics, refresh and retry states implemented |
| Catalog | `CatalogScreen.kt`, `GET /mobile-api/v1/books` | Native list/grid, paging, sort | Native searchable/paginated list and adaptive grid, persistent display preference, HTTPS cover loading, category/author/publisher/ISBN/premium filters and latest/popular/rated sorting implemented |
| Book detail | `BookDetailScreen.kt` | Metadata, comments, related books, report | Native detail/read/download/comment/rating/report and related-book navigation implemented |
| Reader | `ReaderScreen.kt` | PDF/EPUB reader, progress, bookmarks | Native PDFKit reader with persistent page bookmarks plus Readium 3.9 EPUB reflowable/fixed-layout reader and XenForo progress synchronization implemented |
| Downloads | Android cache download | Native download manager, validation, offline | Secure validated storage and iOS test target implemented |
| Library | `LibraryScreen.kt`, `/me/library` | Shelves, favorites, progress | Native shelves and progress implemented |
| Search/filter | API query support | Native search/filter | Catalog and directory search plus advanced catalog filters implemented |
| Authors/publishers | `SiteDirectoryScreen.kt`, directory routes | Native directories and books | Native searchable/paginated directory and books flow implemented |
| Book requests | `SocialScreen.kt`, `/book-requests` | Request/vote flow | Native list/create/vote flow and backend limits implemented |
| Forum | Forum screens and XenForo routes | Forum list/topic/detail/reply | Native forum list, thread list/detail, reply, terms gate and reporting implemented |
| Members | `MembersScreen.kt`, member/follow routes | Directory/profile/follow/block | Native searchable directory, profile, follow and block implemented |
| Messages | `MessagesScreen.kt`, conversation routes | Conversations | Native list/detail/new conversation/reply implemented |
| My comments | `MyCommentsScreen.kt`, `/me/comments` | Authenticated comment history and thread navigation | Native paginated comment history with forum-thread navigation implemented |
| Notifications | Notifications controllers and `AppRoutes.routeForNotification` | Native notification center and target routing | Native list/read actions plus trusted book/thread/forum/directory/request navigation implemented |
| Profile/settings | Profile and identity screens | Profile edit/settings/privacy/account access | Native profile/settings/privacy, registration, password reset, re-authenticated email change, and re-authenticated password change with mobile-session rotation implemented |
| Account deletion | MobileApi endpoint exists | Settings flow using endpoint | Re-auth confirmation UI added |
| Premium | Google Play Billing | StoreKit 2 + server verification | StoreKit 2 and verified backend implemented; Apple sandbox evidence remains |
| Google login | `AuthGoogle.php` | Sign in with Apple parity requirement | Sign in with Apple implemented; signed-device evidence remains |
| Blocking users | Not found as complete mobile route | Required UGC feature | iOS UI + backend scaffold added |
| Reporting content | Book issue report exists; post report appears Android-side | Required UGC feature | iOS UI + backend scaffold added |
| Terms acceptance | XenForo terms expected for UGC | Native terms acceptance before posting | iOS UI + backend scaffold added |

## Assumptions
- Main e-book file format is PDF, with possible EPUB support based on Android reader code.
- Ekitapligim includes user-generated forum content through XenForo.
- Premium affects online reading/download quotas and may be a digital subscription on iOS.
