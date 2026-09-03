# iOS API Documentation

The native iOS app consumes the standalone XenForo add-on `Ekitapligim/IosApi` at:

Android continues to use `https://{host}/mobile-api/v1/` through `Ekitapligim/MobileApi`. The route paths below are identical; only the base URL prefix differs for iOS.

Base URL must be public HTTPS:

```text
https://{host}/ios-api/v1/
```

Production iOS builds must not use `localhost`, private IPs, or HTTP.

## Authentication

Successful password, registration, Google, and Apple authentication returns a random `ms_at_` access token and `ms_rt_` refresh token. Access tokens expire after one hour. Refresh tokens expire after 30 days and rotate on every successful refresh. The server stores only SHA-256 token hashes. Send access tokens as `Authorization: Bearer {token}`; never send a refresh token in that header.

### POST `/auth/register`
Auth: none.
Body: `username`, `email`, `password`.
Response: auth payload with user.
Client behavior: the native registration form requires password confirmation plus explicit Terms of Service and Privacy Policy acceptance before this request can be submitted. A successful response is stored through the same Keychain-only session path as login.

### POST `/auth/refresh`
Auth: none; the refresh token is accepted only in the request body.
Body: `refresh_token`.
Response: new auth payload. The previous access and refresh tokens are revoked atomically.

### POST `/auth/google`
Auth: none.
Body: `id_token`.
Response: auth payload.
iOS note: if Google login remains available, add Sign in with Apple and a matching backend endpoint.

### POST `/auth/apple`
Auth: none.
Body: `identity_token`, `authorization_code`, raw one-time `nonce`.
Response: auth payload.
Permission behavior: validates the Apple JWS signature and SHA-256 nonce, exchanges the code before creating/linking a XenForo user, and rejects subject mismatches between the original and exchanged Apple identity tokens.

### POST `/auth/logout`
Auth: user token.
Response: success. The presented access-token session is revoked server-side.

### POST `/auth/forgot-password`
Auth: none.
Body: `email`.
Response: empty success.
Privacy behavior: the backend returns the same generic success response whether or not the address exists, preventing account enumeration. The native client mirrors that wording.

## Books

### GET `/book-stats`
Auth: none.
Response: site totals for books, authors, publishers, categories, downloadable books, books with covers/summaries, and the last statistics rebuild timestamp. The native home screen uses the four primary totals and supports refresh/retry states.

### GET `/books`
Auth: optional.
Query: `page`, `per_page`, `q`, `category`, `author`, `publisher`, `isbn`, `order` (`latest`, `popular`, `rated`), and `premium_only` (`0` or `1`). If the installed BookThreads schema has no premium-book field, `premium_only=1` fails closed with an empty result instead of returning non-premium books.
Response: paged books.

### GET `/book-detail/{thread_id}`
Auth: optional.
Response: book detail with up to eight visible same-category books in `book.similar_books`/`book.similarBooks`; the current book is excluded.

### GET/POST `/books/{thread_id}/comments`
Auth: POST requires login.
GET query: optional `page`; returns visible non-first posts with post ID, username, cleaned message, image URLs, rating, timestamp, and pagination.
POST body: `message`, optional `rating` from 1 through 5; XenForo enforces thread reply/rating permissions, spam checks, validation, per-user post flood limits, and normal reply notifications.
Response: comments or created comment. A comment can be reported through `POST /posts/{post_id}/report`; reporting enforces XenForo's `canReport` permission, report flood limit, validation, persistence, and moderator notifications.

### POST `/books/{thread_id}/issue-report`
Auth: login required.
Body: `type`, `message`.
Response: empty success.

### GET `/books/{thread_id}/reader/access`
Auth: optional.
Response: read/download permission and quota status.

The signed-in iOS reader sends its bearer token on this request so the response reflects the member tier and current daily quotas.

### POST `/books/{thread_id}/reader/session`
Auth: login required.
Body: `purpose`.
Response: temporary reader token, source URL, file type.

The client must create a purpose-specific session before opening content, including when a validated offline copy exists. This keeps read/download quota enforcement on the server. Remote PDF/EPUB responses are downloaded to protected local storage and validated by file signature before native rendering; Google Drive sharing URLs are converted to binary download URLs without exposing the underlying URL to the reader UI.

### POST `/books/{thread_id}/reader/progress`
Auth: login required.
Body/query: `position_type`, `position_value`, `progress_percent`.
Response: empty success.

### GET `/books/{thread_id}/reader/source`
Auth: login/session token required.
Response: signed/temporary source URL.

## Authors And Publishers

### GET `/authors` and GET `/publishers`
Auth: optional.
Query: `page`, optional `q`.
Response: `authors` or `publishers` array plus pagination. Each item includes `id`, `name`, `slug`, `book_count`, and `kind`.

### GET `/authors/{slug}/books` and GET `/publishers/{slug}/books`
Auth: optional.
Query: `page`.
Response: paged books using the standard books payload.

## Library

### GET `/me/library`
Auth: login required.
Response: library items.

### PUT `/me/library/{thread_id}`
Auth: login required.
Body: `shelf_state`, `progress_percent`, `last_read_page`.
Response: empty success.

## Book Requests

### GET `/book-requests`
Auth: optional.
Response: public request list with title, author, requester, status, and vote count.

### POST `/book-requests`
Auth: login required.
Body: required `title`; optional `author`, `isbn`, `note`.
Controls: server-side field limits and a 30-second per-user creation interval.
Response: created request envelope.

### POST `/book-requests/{request_id}/vote`
Auth: login required.
Behavior: toggles the current user's support vote and returns `voted` plus the committed `vote_count`. The request row is locked and the support relation/count are changed in one transaction to prevent stale or racing counts.

## Community
- `GET /forums`
- `GET /forums/{forum_id}/threads`
- `GET /threads/{thread_id}/posts`
- `POST /threads/{thread_id}/posts`
- `POST /posts/{post_id}/edit` (edit own/permitted post; persists through XenForo Post Editor)
- `POST /posts/{post_id}/delete` (soft-delete own/permitted post; XenForo-compatible POST, not HTTP DELETE)
- `GET /members`
- `GET /members/{user_id}`
- `POST /members/{user_id}/follow`
- `POST /members/{user_id}/unfollow`
- `POST /members/{user_id}/block`
- `POST /members/{user_id}/unblock`
- `GET /me/blocked-members`
- `POST /posts/{post_id}/report`
- `GET /conversations` (authenticated paged list)
- `POST /conversations` (create with `recipient`, `title`, `message`)
- `GET /conversation-detail/{conversation_id}` (collision-free iOS detail route)
- `POST /conversation-reply/{conversation_id}` (collision-free iOS reply route)

Authenticated forum replies require the current community terms, XenForo reply permission, native message validation, XenForo's configured spam/content checks, and its per-user post flood limit. Flooded requests return HTTP 429 and do not create a post. Successful replies use the standard XenForo notification service.

Conversation controllers resolve the XenForo visitor from the revocable mobile session and enforce `canView`, `canStartConversation`, and `canReply`. Message bodies must never be logged or included in notification previews.

The collision-free conversation reply and member follow/unfollow routes use XenForo action-prefix method names directly; deployment requires MobileApi `1.0.79` or newer so these routes do not fall through to a public 404.

The iOS member UI uses collision-free routes because the original dynamic `members/{id}` public route collides with XenForo's web route family:

- `GET /members` with `page`, `q`, and `sort` (`alphabetical`, `newest`, `active`).
- `GET /member-detail/{user_id}`.
- `POST /member-follow/{user_id}`.
- `POST /member-unfollow/{user_id}`.
- `POST /members/{user_id}/block` and `/unblock`.

The backend filters valid/viewable users and applies XenForo profile privacy, online-status, follow, and block permissions.

## Account

### GET `/me`
Auth: login required.
Response: profile payload including `about`, `location`, `website`, `activity_visible`, and `can_edit`.

### POST `/me`
Auth: login required; XenForo `canEditProfile()` permission required.
Body: `about` (maximum 5,000 characters), `location` (maximum 100), `website` (maximum 200; HTTP/HTTPS only), and `activity_visible` (`0` or `1`).
Response: updated profile payload.
Security: XenForo profile validation and about-text spam checks are enforced server-side. Email and password changes are intentionally excluded from this endpoint.

### POST `/me/email`
Auth: login required.
Body: `current_password`, `email`.
Response: success, normalized email, and `confirmation_required`.
Security: re-authenticates the current password and uses XenForo `EmailChangeService` for permission, uniqueness, validation, confirmation mail, old-address notification, and IP logging.

### POST `/me/password`
Auth: login required.
Body: `current_password`, `new_password`.
Response: a rotated mobile auth payload for the current device.
Security: re-authenticates the existing password and uses XenForo `PasswordChangeService`. After a successful change, all active mobile sessions are revoked and a fresh access/refresh pair is issued for the current device.

### GET `/me/notifications`
Auth: login required.
Response: XenForo alert page (`items`/`notifications`) with unread/unviewed/conversation counts. IosApi `1.0.15+` serializes the same site alerts the website shows (forum replies, private messages, chat, Kitap Gündemi, profile visits, and related types), skips a single broken alert instead of failing the whole list, and includes native `app_route` values.

### GET `/me/notifications/counts`
Auth: login required.
Response: unread/unviewed alert counts plus `conversations_unread`.

### POST `/me/notifications/{alert_id}/mark`
Auth: login required.
Body: `unread`.
Response: empty success.

### POST `/me/notifications/mark-all`
Auth: login required.
Response: empty success. The XenForo action-prefix route requires MobileApi `1.0.81` or newer.

### GET `/me/terms`
Auth: login required.
Response: required/accepted community terms version.

### POST `/me/terms/accept`
Auth: login required.
Body: `version`.
Response: empty success.

### GET `/legal/terms`
Auth: public read.
Response: current terms version, Apple Standard EULA URL, community terms URL, privacy URL, support URL, and the 24-hour moderation SLA.

### POST `/auth/login` and `/auth/register`
Body addition: `accepted_terms_version` is mandatory and must equal the current `/legal/terms` version. Successful authentication and acceptance are recorded together; stale or missing versions return `403 terms_acceptance_required`.

### POST `/safety/reports`
Auth: login required.
Body: `content_type` (`forum_post`, `book_comment`, `agenda_post`, `agenda_comment`, `chat_message`, `conversation_message`), `content_id`, `reason_code`, optional `details`.
Response: `success`, XenForo `report_id`. Reports enqueue a privacy-safe moderator email job and are tracked for 20-hour reminder and 24-hour escalation.

### POST `/members/{user_id}/block`
Auth: login required.
Optional context: `source_type`, `source_id`, `reason_code`, `details`. With context, the endpoint verifies that the target owns the content, creates a XenForo report idempotently, blocks the member and returns `blocked_user_id` plus `report_created`.

All iOS social create/edit endpoints run the shared administrator-managed UGC policy and XenForo spam checks before persistence. Violations return `422 content_policy_violation`; rejected text is not written. Authenticated reads filter the visitor's ignored users across forum, book comments, Book Agenda, chat and private conversations.

### POST `/me/account-deletion-request`
Auth: login required.
Body: optional `current_password`, optional `reason`.
Response: idempotent accepted deletion request with request ID, `already_pending`, and `estimated_completion_days` (currently 30). An existing pending/processing request is returned instead of creating duplicates.
Client behavior: requires an explicit `SIL` confirmation, explains the expected 30-day manual-processing window, and warns that Apple subscriptions are managed separately.
Security behavior: password accounts require `current_password`; Apple-authorized accounts may omit it. The request is durably stored and mobile sessions are revoked before remote Apple revocation is attempted. A temporary Apple outage returns a successful request with `apple_revocation_pending=true` so deletion remains accessible and operations can retry.
Completion behavior: operations must delete/anonymize associated account/user content as legally permitted, notify the user, and successfully revoke Sign in with Apple authorization before deleting the user.

## Billing

Android uses Google Play verification; iOS uses the following StoreKit 2 endpoints:

### POST `/billing/app-store/verify`
Auth: login required.
Body: `signed_transaction`, `product_id`, `original_transaction_id`, and optional
`signed_renewal_info`. Renewal JWS is required to preserve access during an Apple billing grace period.
Response: subscription entitlement, transaction expiration, and optional grace-period expiration.
Security: both JWS chains are anchored to a configured Apple root, bundle/product/environment are
allowlisted, and each `originalTransactionId` is atomically bound to its first Ekitapligim account.

### POST `/billing/app-store/notifications`
Auth: server-to-server from Apple.
Response: 200 after verification and entitlement update.
Current backend behavior: verifies the outer, transaction, and renewal JWS certificate chains; rejects bundle/product/environment mismatches; records the verified notification hash; preserves Apple billing grace periods; and atomically updates the matching existing entitlement by transaction/original transaction ID. Public sandbox verification is still required.

## Required Deployment Work Before iOS Release
- Deploy standalone IosApi `1.0.13` (SHA-256 verified; MobileApi 1.0.136 unchanged) to public HTTPS staging, configure moderator emails and managed filter terms, run `php cmd.php ekitapligim-ios:release-audit`, then promote the identical ZIP to production.
- Configure the Apple root CA and verify StoreKit sandbox transactions and App Store Server Notifications.
- Exercise Apple login, identity changes, blocking, reporting, terms acceptance, account deletion, reader access, and subscription state with the App Review account.
