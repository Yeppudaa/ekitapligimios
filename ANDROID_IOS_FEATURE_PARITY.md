# Android To iOS Feature Parity

## Executive gap report (2026-08-24)

Automated gate (2026-08-26): `.\Scripts\parity-audit.ps1` → **PASS=303, WARN=1, FAIL=0** (133 Swift tests, 62/62 routes, prod smoke + auth mutations). IosApi **v1.0.5** live. Only remaining WARN: Mac visual screenshots.

| Core UGC/library flow | iOS code | ios-api/v1 contract | Prod verification | Blocker |
|---|---|---|---|---|
| Book requests create/vote | ✅ | ✅ `book-requests` | Unauth POST **401**; auth create + vote **PASS** | — |
| Forum topic create | ✅ guest sheet matches Android | ✅ `forums/:id/threads` POST | Unauth POST **401**; auth create **PASS** | — |
| Forum reply | ✅ | ✅ `threads/:id/posts` POST | GET **200**; unauth POST **401**; auth reply **PASS** | — |
| Chat send | ✅ | ✅ `chat/rooms/:id/messages` | Unauth POST **401**; auth send **PASS** | — |
| Book agenda post | ✅ | ✅ `book-agenda` POST | Unauth POST **401**; auth post **PASS** (429 retry) | — |
| Book comments | ✅ | ✅ `books/:id/comments` POST | Unauth POST **401**; auth create **PASS** | — |
| Shelf sync | ✅ | ✅ `me/library` PUT | Unauth PUT **401**; auth PUT **PASS** | — |
| Screen appearance | ✅ in-repo (heroes, copy, gold-trim forum cards, library meta, vote controls) | N/A | No screenshot evidence | Mac/Xcode side-by-side |

### Prod UGC write-route probes (no auth)

Public smoke probes every scoped write route without credentials. Expected: **HTTP 401/403** (route exists, auth enforced).

| Route | Prod status |
|---|---|
| `POST book-requests` | ✅ 401 |
| `POST book-agenda` | ✅ 401 |
| `POST books/:id/comments` | ✅ 401 |
| `PUT me/library/:id` | ✅ 401 |
| `POST chat/rooms/:id/messages` | ✅ 401 |
| `POST threads/:id/posts` | ✅ 401 |
| `GET threads/:id/posts` | ✅ 200 |
| `POST forums/:id/threads` | ✅ 401 |

### Next actions (in order)

1. **Visual (only blocker):** On Mac, capture side-by-side screenshots for all 10 scoped screens (see `.\Scripts\visual-parity-checklist.ps1`).
2. Save PNGs under `release-archive/visual-parity/ios/` and `release-archive/visual-parity/android/`.
3. Copy `release-archive/visual-parity/manifest.example.json` → `manifest.json`, set each screen `"pass": true`, run `.\Scripts\verify-visual-parity-evidence.ps1` then `.\Scripts\parity-audit.ps1` (expect **WARN=0**).
4. **Status:** `.\Scripts\parity-completion-report.ps1` prints GOAL STATUS when manifest verifies.

### In-repo locks (2026-08-24)

- Chat composer matches Android `ChatScreen`: read-only/no-permission keep title **Bu oda okuma modunda**; `canSend == false` still shows the field.
- Library cards: VoiceOver hint **Kitap detayını aç**, cover **… kapağı**; avatars **… profil resmi**.
- Copy tests lock remaining scoped Android strings: chat **Önceki mesajları göster** / **YÖNETİCİ** / **MODERATÖR** / edited suffix, forum **Forum görseli**, shelf **Okuyorum** / **Okudum**, agenda **Doğrulanmış**, agenda composer validation, book-request **Yazar**.
- Copy tests also lock Android **Kitap Künyesi** / **Benzer Kitaplar**, agenda tabs (**Sana Özel**), chat hero/welcome, and forum report description.
- Book detail share matches Android: 48pt gold-bordered round back/share in a custom top bar; payload is `pdfUrl` or `https://ekitapligim.com/threads/{id}/` plus `title — author`.
- Forum thread list error retry matches Android: **Yeniden dene** (`commonRetryAgain`).
- Agenda guest tabs match Android: locked tabs stay tappable, subtitle **Giriş gerekli**, tap opens login; sign-in switches to the personal tab.
- Agenda composer prompt matches Android: 42pt teal edit glyph in a mint circle and a trailing forward arrow, not the profile avatar.
- Agenda comments match Android: 38pt mint avatar, white 15pt card, purple reaction score, trailing reply submit, teal guest Giris yap.
- Agenda composer sheet matches Android: 22pt heavy title, type chips, outlined book picker, full-width purple Paylas with send glyph, no navigation toolbar.
- Book request and forum topic create match Android AlertDialog: compact sheet, rounded fields, trailing Iptal/Gonder (or Olustur), no Form navigation stack.
- Chat read-only/no-permission composer matches Android: 42pt teal visibility tile and inline ChatInk/ChatMuted copy, not a cream announcement card.
- Chat composer bar matches Android: white 22pt top-rounded surface with full ChatBorder, not a 1pt hairline divider.
- Chat welcome ready fill matches Android `ChatWelcomeNote` (`0xEAF8F7`), avatars are 35pt, and load-older uses a History glyph on 12pt corners.
- Chat loading/empty states match Android: spinner card with live-connection subtitle, Forum-icon empty card, and empty rooms no longer reuse the reconnect error chrome.
- Forum empty states match Android: 48pt Forum glyph on the thread list and centered muted empty-post copy without card chrome.
- Agenda empty/error cards use Android AutoStories 34pt chrome; load-more is 14pt purple; load-more failures show the cream Yeniden dene inline error.
- Book comments omit an empty-state string; Android `PremiumCommentsSection` shows none.
- Run gate: `.\Scripts\parity-audit.ps1`.

### Completion audit (2026-08-26)

**Goal remains open** until Mac visual checklist is executed with side-by-side screenshots.

| Requirement | Evidence | Status |
|---|---|---|
| iOS code parity for 7 scoped flows | `parity-audit.ps1` static checks **303 PASS** | **Done** |
| ios-api/v1 route contracts | 62/62 PASS (same gate run) | **Done** |
| Public prod smoke (UGC routes fail closed) | All scoped writes → **401**; `GET threads/1/posts` → **200** | **Done** |
| Auth mutation smoke (create/vote/post/send/PUT/reply) | `parity-audit.ps1` **exit 0**, ExerciseMutations PASS | **Done** |
| Automated unit tests | 133 PASS (same gate run) | **Done** |
| Visual screen parity | `visual-parity-checklist.ps1` not executed on Mac | **Not verified** |

Latest gate: **PASS=303 WARN=1 FAIL=0** (only WARN = Mac visual manifest). When complete: copy `release-archive/visual-parity/manifest.example.json` → `manifest.json` with PNGs and `pass: true` → audit **WARN=0**.


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
- PDF and EPUB reader sources are quota-authorized through the existing Android-compatible reader session API, downloaded to protected temporary storage, signature-validated, and opened natively with PDFKit/Readium. Google Drive preview/share URLs are resolved to binary downloads. PDF supports continuous/paged layouts, page scrubbing, thumbnails, bookmarks, and saved-position restore.
- Ekitapligim includes user-generated forum content through XenForo.
- Premium affects online reading/download quotas and may be a digital subscription on iOS.
