# App Store Metadata Draft

## App Information
- App name: Ekitaplığım
- Subtitle: PDF ve EPUB Kitap Okuyucu
- Primary category: Books
- Secondary category: Social Networking
- Age rating planning assumption: 13+ on iOS 26+ because the app contains user-generated forum content and private messaging. Complete the current App Store Connect questionnaire; Apple calculates global and regional ratings, so this draft is not final rating evidence.

## Promotional Text
Kitapları keşfedin, PDF ve EPUB okuyun, kaldığınız yeri eşitleyin ve Ekitaplığım okur topluluğuna katılın.

## What's New
- Giriş ve kayıt öncesine EULA ile topluluk kuralları onayı eklendi.
- Forum, kitap yorumu, Kitap Gündemi, sohbet ve özel mesajlarda görünür bildirme ve engelleme işlemleri eklendi.
- Engellenen kullanıcıların içerikleri tüm topluluk ekranlarından anında kaldırılıyor.
- Topluluk Güvenliği ekranı ve 24 saatlik moderasyon taahhüdü eklendi.

## Description
Ekitaplığım, Ekitapligim.com kitap kataloğunu ve okur topluluğunu iPhone ve iPad’e taşıyan native bir uygulamadır.

Kitap, yazar, yayınevi, kategori veya ISBN ile arama yapabilir; liste ve ızgara görünümleri arasında geçebilir; kitap ayrıntılarını, yorumları ve benzer kitapları inceleyebilirsiniz. Desteklenen içerikleri PDF veya EPUB biçiminde okuyabilir, okuma ilerlemenizi hesabınızla eşitleyebilir ve izin verilen kitapları çevrimdışı kullanım için indirebilirsiniz.

Kitaplığınızda okuduğunuz, okumakta olduğunuz ve favori kitapları takip edebilirsiniz. Yazar ve yayınevi dizinlerini gezebilir, kitap isteği oluşturabilir ve mevcut isteklere oy verebilirsiniz.

Topluluk bölümünde forumları ve konuları görüntüleyebilir, kullanım şartlarını kabul ettikten sonra yetkiniz dahilinde cevap yazabilir, özel mesajlarınızı yönetebilir, uygunsuz içeriği bildirebilir ve kullanıcıları engelleyebilirsiniz.

Premium abonelikler daha yüksek veya sınırsız okuma ve indirme hakları sağlayabilir. Satın alma ve geri yükleme Apple In-App Purchase ile yapılır; entitlement yalnız Apple işlemi sunucuda doğrulandıktan sonra etkinleşir.

Uygulama içinden hesap oluşturabilir, şifrenizi sıfırlayabilir, profil ve güvenlik bilgilerinizi yönetebilir ve tüm hesabınızın silinmesini başlatabilirsiniz. Hesap silme talepleri genellikle 30 gün içinde tamamlanır ve sonuç kayıtlı e-posta adresine bildirilir.

Kullanım Koşulları (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Gizlilik Politikası: https://ekitapligim.com/yardim/gizlilik-politikasi/

## Keywords
ekitap,kitap,pdf,epub,okuyucu,kütüphane,yazar,yayınevi,forum,türkçe

## URLs
- Support URL: https://ekitapligim.com/diger/iletisim
- Marketing URL: https://ekitapligim.com/
- Privacy Policy URL: https://ekitapligim.com/yardim/gizlilik-politikasi/
- Terms of Service URL: https://ekitapligim.com/yardim/kurallar/

## Copyright
© Ekitapligim.com. All rights reserved.

## Review Notes Draft
GUIDELINE 1.2 RESUBMISSION — BUILD 1.0.0 (18)

- The reviewer must accept the Apple Standard EULA and our community rules before login or registration can continue. The acceptance version is recorded by the server with the successful authentication transaction.
- Every user-generated-content surface has a visible ellipsis safety button: forum topic lists and posts, book comments, Book Agenda posts/comments, chat messages, and private-conversation messages.
- “Report Content” sends the selected content and reason to the XenForo moderation queue. “Block User and Report” creates the report, blocks the author, and removes that author’s content from the current screen immediately.
- The authenticated user’s ignore list is also enforced server-side on forum, book-comment, Book Agenda, chat, and private-message responses. A blocked member cannot start or continue a one-to-one conversation; group conversations remain available while the blocked member’s messages are hidden.
- New and edited community content is normalized and checked against an administrator-managed objectionable-content list and XenForo spam checks before persistence. Rejected content returns HTTP 422 and is not saved.
- Moderators receive queued email notifications without private-message bodies or tokens. Open reports trigger a reminder at 20 hours and escalation at 24 hours.
- Topluluk > Topluluk Güvenliği shows prohibited-content guidance, support contact, blocked users, and the 24-hour moderation commitment.

Ekitaplığım is a native SwiftUI iOS/iPadOS app, not a website wrapper. The catalog, PDF/EPUB reader, library, downloads, account, StoreKit, forum, messaging, reporting, blocking, and account-deletion surfaces are native.

Reviewer account:
- Username/email: stored only in the App Store Connect Sign-In Information fields.
- Password: stored only in the App Store Connect Sign-In Information fields.
- Environment: production public HTTPS API at `https://ekitapligim.com/ios-api/v1/`.
- Safe member to follow/block: supplied in the prepared reviewer account's demo data.
- Safe conversation recipient: supplied in the prepared reviewer account's demo data.
- Rights-cleared PDF book: supplied in the prepared reviewer account's library.
- Rights-cleared EPUB book: supplied in the prepared reviewer account's library.

Suggested review flow:
1. Open the login screen. Verify the EULA, community terms and privacy links are visible and the login button remains disabled until acceptance is enabled.
2. Log in using the reviewer credentials stored only in App Store Connect.
3. Open Topluluk > Topluluk Güvenliği and inspect the prohibited-content summary, support link, blocked-users list and 24-hour commitment.
4. Open the supplied forum. On the topic list, tap the visible ellipsis, report the supplied topic, then use “Block User and Report”; its author’s topics disappear immediately.
5. Repeat the visible report/block flow on the supplied book comment and Book Agenda post/comment.
6. Open Okur Sohbeti and use the ellipsis on the supplied chat message. Open Mesajlar and use the same controls on the supplied private message.
7. Attempt the supplied prohibited test phrase in each composer. The app shows rejection and the content does not appear after refresh.
8. Open Engellenenler and remove the demo block to reset the reviewer account.
9. Continue with catalog, reader, library and StoreKit purchase/restore tests using the rights-cleared demo content.

Account deletion is initiated entirely in-app. Manual processing is expected within 30 days and completion is sent to the account email. Deletion operations must remove/anonymize associated user content as legally permitted.

Do not submit until standalone IosApi `1.0.12` is validated on public HTTPS staging, the same SHA-256 ZIP is installed in production, moderator/filter options pass the release audit, and the reviewer flow is recorded on physical iPhone and iPad.

## In-App Purchase Review Notes
Subscription group: `ekitapligim.premium`

Product IDs:
- `com.ekitapligim.app.premium.monthly`
- `com.ekitapligim.app.premium.yearly`

The app displays localized names and prices returned by StoreKit. It provides purchase, restore, Manage Subscriptions, Terms, Privacy Policy, and auto-renewal disclosure. A verified Apple transaction JWS is sent to the backend; premium is not granted for unverified or server-rejected transactions.

## App Review Reply Draft
Hello App Review Team,

Thank you for your review. We addressed Guideline 1.2 in a new binary, version 1.0.0 build 18.

Before login or registration, users must view and accept the EULA and community rules. All community surfaces now show a visible ellipsis menu with “Report Content” and “Block User and Report.” Reports enter our XenForo moderator queue and blocking removes the author’s content immediately, with server-side filtering on subsequent responses. New and edited content is screened before storage; violations are rejected and never published.

Our moderation workflow sends privacy-safe moderator notifications, a 20-hour reminder and a 24-hour escalation. The in-app Community Safety screen explains prohibited content, support contact, blocked-user controls and the 24-hour commitment.

The App Review Notes provide a prepared reviewer account and safe content on which every report/block flow can be exercised. Physical iPhone and iPad recordings showing pre-login acceptance, reporting, blocking and immediate content removal will be attached before submission.

Thank you.

## Screenshot Checklist
- Home with live catalog statistics.
- Catalog grid with real covers and filters.
- Book detail with related books and comments.
- PDF reader with progress/bookmark.
- EPUB reader with progress.
- Library shelves and secure downloads.
- Community forum/thread and report/block actions.
- Profile and Giriş ve Güvenlik.
- Premium plans with real localized StoreKit prices.
- Account deletion disclosure and confirmation.

## App Privacy Draft
- Tracking: No.
- Contact Info / Email Address: linked, app functionality.
- Contact Info / Other User Contact Info: linked, app functionality; optional profile website.
- Location / Coarse Location: linked, app functionality; optional user-entered profile location, not device GPS.
- Identifiers / User ID: linked, app functionality.
- Purchases / Purchase History: linked, app functionality.
- Usage Data / Product Interaction: linked, app functionality; library, progress, downloads, notification activity.
- User Content / Other User Content: linked, app functionality; profile text, comments, posts, requests, reports, and private messages.
- Other Data: linked, app functionality/security; retained IP address, user-agent/device-session and security records described by the published privacy policy.
- Diagnostics: not collected by an app analytics/crash SDK in the current binary.
