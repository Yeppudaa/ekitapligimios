# Privacy Data Inventory

## Reader experience update (2026-09-28)

The sepia/white/night paper choice is stored locally in UserDefaults under `reader.paperTheme`. It is an app-wide preference, remains across sign-out, and is not sent to the server or associated with an account. It adds no collected-data category; the existing UserDefaults required-reason declaration covers this local preference.

Loading percentages and byte counts exist only in memory for the active transfer and are not analytics. Reading downloads continue to use protected, backup-excluded reader-session storage; large base64 envelopes are decoded to temporary disk files in bounded chunks. Reader-owned presentations preserve the active document rather than starting a new reading session. Existing account-scoped reading progress retention and deletion behavior remain unchanged. No new tracking, SDK, entitlement or privacy-manifest category is introduced. See [READER_EXPERIENCE_VALIDATION.md](READER_EXPERIENCE_VALIDATION.md).

## Gift wheel addition (2026-09-27)

PremiumWheel receives the existing Keychain bearer session, random per-spin idempotency key and configuration revision. Account-associated quota, prize history, gift seconds and publicly listed winner names are read from this same first-party service. These are covered by existing UserID and ProductInteraction/AppFunctionality declarations; no tracking, third-party SDK or additional required-reason API category is introduced.

The separate ephemeral URLSession disables cookies, credential storage and disk caching. Responses are held in memory and discarded on sign-out/account change. Only pending request key/revision is saved atomically in Application Support, scoped by encoded account name (encoding is not encryption); it contains no token or purchase entitlement. It survives interruption/sign-out for safe recovery, is removed after reveal or explicit rejection, and is cleared on account deletion. Server retention/deletion of gift history requires a live release check. No new privacy manifest or StoreKit entries are necessary.

| Data | Purpose | Linked To User | Tracking | Retention |
|---|---|---:|---:|---|
| Username/email | Account login/profile | Yes | No | Until account deletion/legal retention |
| Google account name/subject/profile image | Google authentication, account linking, suggested forum identity/avatar | Yes | No | Until account deletion/account unlinking |
| Optional profile location | Profile display; user-entered, no device GPS | Yes | No | Until changed/account deletion |
| Optional profile website | Profile display/contact | Yes | No | Until changed/account deletion |
| Password | Login only, sent to backend | Yes | No | Not stored in app |
| Auth tokens | Session | Yes | No | Keychain until logout/expiry |
| IP address/user agent/session security records | Authentication, fraud prevention, account security | Yes | No | Backend security retention policy |
| Reading progress (book ID, PDF page or EPUB CFI, percent, server date, pending revision; cached title/author/cover URL) | Continue reading and two-way site sync | Yes | No | Server account retention; local account-scoped Application Support cache until account deletion or app removal. Logout preserves pending records for that account only. |
| Library/favorites | User library | Yes | No | Until user deletes/removes |
| Comments/posts/messages | Community | Yes | No | Per XenForo moderation/retention |
| Safety reports, report reason, reporter/target/content IDs and moderation timestamps | Community safety, abuse handling and 24-hour SLA | Yes | No | Per XenForo moderation/security retention; moderator email excludes content bodies and credentials |
| Terms acceptance version/time | Legal and community-rule consent | Yes | No | Account lifetime/legal retention |
| Blocked-user relationships | User safety and server-side content filtering | Yes | No | Until user unblocks/account deletion |
| Purchase transactions | Entitlements | Yes | No | Per App Store/legal retention |
| Notification activity | In-app notification center | Yes | No | Per XenForo alert retention |
| Offline book files | User-requested offline reading | No additional identifier | No | App sandbox until user removes download/app. A user-confirmed Files export copies the book to the chosen Files location. |

## App Store Privacy Label Draft
Likely data types:
- Contact Info: email address.
- Contact Info: name supplied by Google when Google authentication is used.
- Contact Info: other user contact info for optional profile website.
- Location: coarse location for optional user-entered profile location; the app does not access device location services.
- User Content: posts/comments/messages, if enabled.
- User Content: Google profile image used as the initial forum avatar when Google registration is used.
- Identifiers: user ID.
- Purchases: subscription or premium transactions, if StoreKit is enabled.
- Usage Data: reading progress/library activity.
- Other Data: retained IP address, user agent/device-session and security records described by the published policy.
- No analytics, advertising, tracking, ATT prompt, crash SDK, or push-token collection exists in the current binary.

## Privacy Manifest
Initial manifest location: `App/Ekitapligim/Support/PrivacyInfo.xcprivacy`.

It declares no tracking, app-functionality collection for email/user ID/product interaction/purchase history/user content, and required-reason API usage for file timestamps and UserDefaults. Reconcile before submission with the final dependency list and any analytics/crash SDKs.

Offline book files remain in Application Support, are excluded from iCloud/device backup, and use complete-until-first-authentication file protection. The client validates safe identifiers and PDF/EPUB file signatures before retaining a download. If the user confirms the Files export sheet after a permitted download, a copy is written to the user-chosen Files location and is no longer under the app backup-exclusion policy.

Reader progress JSON uses the same backup exclusion and file protection. It contains no credentials or ebook text. The existing Product Interaction/App Functionality declaration covers this synchronization; no new tracking, purchase data, entitlements, or required-reason API categories are introduced.

Do not declare tracking unless tracking is actually implemented. Do not request ATT unless tracking exists.

## AI Assistant privacy addition (2026-09-06)

- AI prompts and answers are user content processed by the existing server-side AI service. The app does not connect directly to an AI vendor or embed provider credentials. The assistant explains this processing before the user sends a prompt.
- Member conversations and personalization are associated with the server account. Anonymous history and daily usage use a random installation key stored separately in Keychain and sent only to the AI API. It is not an advertising identifier and is not used for tracking.
- Conversation content is held only in app memory; AI URLSession disables cookies and persistent caching. The server controls retention, history deletion, and quota. The current bootstrap publishes retention constraints; the client does not silently extend them.
- Sign-out/account changes discard in-memory AI state and cancel stale operations. Deleting history does not rotate anonymous identity or grant extra usage. Existing server account-deletion behavior must be checked for AI conversation cleanup before release.
- Existing privacy-manifest UserID, OtherUserContent and ProductInteraction categories cover these behaviors. Add DeviceID for the persistent anonymous installation identifier. No new tracking domain, entitlement, billing product or required-reason API is introduced.
