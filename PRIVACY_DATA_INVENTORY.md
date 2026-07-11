# Privacy Data Inventory

| Data | Purpose | Linked To User | Tracking | Retention |
|---|---|---:|---:|---|
| Username/email | Account login/profile | Yes | No | Until account deletion/legal retention |
| Optional profile location | Profile display; user-entered, no device GPS | Yes | No | Until changed/account deletion |
| Optional profile website | Profile display/contact | Yes | No | Until changed/account deletion |
| Password | Login only, sent to backend | Yes | No | Not stored in app |
| Auth tokens | Session | Yes | No | Keychain until logout/expiry |
| IP address/user agent/session security records | Authentication, fraud prevention, account security | Yes | No | Backend security retention policy |
| Reading progress | Continue reading/sync | Yes | No | Until user deletes account/library data |
| Library/favorites | User library | Yes | No | Until user deletes/removes |
| Comments/posts/messages | Community | Yes | No | Per XenForo moderation/retention |
| Purchase transactions | Entitlements | Yes | No | Per App Store/legal retention |
| Notification activity | In-app notification center | Yes | No | Per XenForo alert retention |
| Offline book files | User-requested offline reading | No additional identifier | No | App sandbox until user removes download/app |

## App Store Privacy Label Draft
Likely data types:
- Contact Info: email address.
- Contact Info: other user contact info for optional profile website.
- Location: coarse location for optional user-entered profile location; the app does not access device location services.
- User Content: posts/comments/messages, if enabled.
- Identifiers: user ID.
- Purchases: subscription or premium transactions, if StoreKit is enabled.
- Usage Data: reading progress/library activity.
- Other Data: retained IP address, user agent/device-session and security records described by the published policy.
- No analytics, advertising, tracking, ATT prompt, crash SDK, or push-token collection exists in the current binary.

## Privacy Manifest
Initial manifest location: `App/Ekitapligim/Support/PrivacyInfo.xcprivacy`.

It declares no tracking, app-functionality collection for email/user ID/product interaction/purchase history/user content, and required-reason API usage for file timestamps and UserDefaults. Reconcile before submission with the final dependency list and any analytics/crash SDKs.

Offline book files remain in Application Support, are excluded from iCloud/device backup, and use complete-until-first-authentication file protection. The client validates safe identifiers and PDF/EPUB file signatures before retaining a download.

Do not declare tracking unless tracking is actually implemented. Do not request ATT unless tracking exists.
