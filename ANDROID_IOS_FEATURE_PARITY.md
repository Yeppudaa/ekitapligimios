# Android To iOS Feature Parity

| Area | Android Evidence | iOS Target | Status |
|---|---|---|---|
| Home | `HomeScreen.kt`, stats API | Native SwiftUI home | Hero card, stats, continue reading, Keşif Merkezi, Kitap Gündemi rail, daily/newest/popular rails, chat preview, live activity card, and request center implemented |
| Kitap Gündemi | `BookAgendaScreen.kt`, `/book-agenda` | Native feed, composer, comments, reactions | Native tabs/filters, post types, detail/comments, create/edit/delete, graceful follow-route fallback |
| Okur Sohbeti | `ChatScreen.kt`, `/chat/rooms` | Native room tabs and message bubbles | Native rooms, 5s poll, guest read-only mode, admin/mod badges |
| Canlı Akış | `LiveActivityScreen.kt`, `/live-activity` | Native activity feed | Native cursor pagination and type-colored activity rows |
| Navigation shell | `AppMobileMenu.kt`, 6-tab bottom bar | Matching menu and tabs | 6-tab bar (Ana Sayfa, Katalog, Yazarlar, İstekler, Forum, Profilim) plus 14-item drawer with unread badges |
| Profile | `ProfileScreen.kt`, hero/stats/tabs/quota cards | Android-identical Profilim | Hero, stat band, 6 tabs, reading goal, quota cards, action grid, premium card, membership info, logout/delete |
| Library | `LibraryScreen.kt`, `/me/library` | Shelves matching Android tab indices | 5 tabs (Okuyorum, Okuyacağım, Okudum, Favoriler, İndirmeler) with `library/{tab}` routing |
| Search/filter | API query support | Native search/filter | Catalog and directory search plus advanced catalog filters implemented |
| Authors/publishers | `SiteDirectoryScreen.kt`, directory routes | Native directories and books | Native searchable/paginated directory and books flow implemented |
| Book requests | `SocialScreen.kt`, `/book-requests` | Request/vote flow | Native list/create/vote flow and backend limits implemented |
| Forum | Forum screens and XenForo routes | Forum list/topic/detail/reply | Native forum list, thread list/detail, reply, terms gate and reporting implemented |
| Members | `MembersScreen.kt`, member/follow routes | Directory/profile/follow/block | Native searchable directory, profile, follow and block implemented |
| Messages | `MessagesScreen.kt`, conversation routes | Conversations | Native list/detail/new conversation/reply implemented |
| My comments | `MyCommentsScreen.kt`, `/me/comments` | Authenticated comment history and thread navigation | Native paginated comment history with forum-thread navigation implemented |
| Notifications | Notifications controllers and `AppRoutes.routeForNotification` | Native notification center and target routing | Native list/read actions plus trusted book/thread/forum/directory/request navigation implemented |
| Universal links | `AppRoutes.routeFromWebUrl` | Associated-domain native routing | `.onOpenURL` validates Ekitapligim URLs and opens native book/thread/forum/directory/request destinations |
| Profile/settings | Profile and identity screens | Profile edit/settings/privacy/account access | Native profile/settings/privacy, registration, password reset, re-authenticated email change, and re-authenticated password change with mobile-session rotation implemented |
| Account deletion | MobileApi endpoint exists | Settings flow using endpoint | Re-auth confirmation UI added |
| Premium | Google Play Billing | StoreKit 2 + server verification | StoreKit 2 and verified IosApi backend at `/ios-api/v1/billing/app-store/verify`; Apple sandbox evidence remains |
| Google login | `AuthGoogle.php` | Sign in with Apple parity requirement | Sign in with Apple implemented; signed-device evidence remains |
| Blocking users | Not found as complete mobile route | Required UGC feature | iOS UI + backend scaffold added |
| Reporting content | Book issue report exists; post report appears Android-side | Required UGC feature | iOS UI + backend scaffold added |
| Terms acceptance | XenForo terms expected for UGC | Native terms acceptance before posting | iOS UI + backend scaffold added |

## Assumptions
- Main e-book file format is PDF, with possible EPUB support based on Android reader code.
- Ekitapligim includes user-generated forum content through XenForo.
- Premium affects online reading/download quotas and may be a digital subscription on iOS.
