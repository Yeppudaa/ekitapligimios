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
- Giriş ve kayıt öncesinde Apple Standard EULA ve topluluk kuralları onayı zorunlu.
- Forum konuları ve tekil mesajlar, kitap yorumları, Kitap Gündemi, sohbet, özel mesajlar ve kitap isteklerinde Report / Block & Report.
- Üye profilinden Block / Unblock ve Block & Report; Engellenenler listesinden kaldırma.
- Engellenen kullanıcıların içerikleri istemci ve sunucu tarafında gizleniyor.
- Uygunsuz terim filtresi kayıt öncesi; moderatör e-posta kuyruğu, 20s hatırlatma / 24s yükseltme.
- Topluluk Güvenliği ekranı ve 24 saatlik moderasyon taahhüdü.

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
GUIDELINE 1.2 RESUBMISSION — v1.0.0 (build 18 or later)

- Before Sign In / Create Account: Apple Standard EULA + community rules must be accepted (controls stay disabled until accepted). Accepted terms version is recorded by the server with successful authentication.
- Visible ellipsis safety menus on UGC: forum topic rows, individual forum posts, book comments, Book Agenda posts/comments, chat messages, private messages, and book requests → Report / Block & Report.
- Member profiles: Block, Unblock, and Block & Report. Blocked Members list supports unblock to reset the reviewer account.
- Report → XenForo moderation queue (book requests → iOS UGC event queue) with reason. Block notifies moderators and hides that author’s content immediately on the current screen; ignore list is also filtered server-side on subsequent API responses.
- One-to-one conversations with a blocked member are refused; in group chat, that member’s messages stay hidden.
- Pre-persistence filtering against administrator-managed blocked terms + XenForo spam checks; rejected content returns HTTP 422 and is never published.
- Moderator email queue (no PM bodies/tokens); 20-hour reminder and 24-hour escalation; human action within 24 hours (remove content / eject offender when required).
- Community > Community Safety: prohibited-content guidance, support contact, blocked users, 24-hour commitment.
- Production API: https://ekitapligim.com/ios-api/v1/ — Sign-In only via App Store Connect reviewer credentials. Demo report/block content is prepared on that account.
- Physical iPhone + iPad recordings of EULA acceptance, report, and block + immediate hide are attached in Notes / Resolution Center.

Ekitaplığım is a native SwiftUI iOS/iPadOS app (not a WKWebView wrapper).

Suggested review flow:
1. Login/Register: confirm EULA + rules links; Sign In stays disabled until acceptance.
2. Log in with App Store Connect reviewer credentials.
3. Community > Community Safety: prohibited content, support, blocked users, 24h SLA.
4. Forum: ellipsis on topic and on an individual post → Report, then Block & Report; author content disappears.
5. Repeat on book comment, Book Agenda, book request, chat message, and private message.
6. Member profile: Block / Block & Report; confirm hide; unblock from Blocked Members.
7. Try a blocked test phrase in a composer → rejection, content not published after refresh.
8. Continue catalog, reader, library, StoreKit with rights-cleared demo books.

Backend prerequisite: IosApi 1.0.13+ on production with non-empty `ekIosUgcModeratorEmails` and `ekIosUgcBlockedTerms`.

## In-App Purchase Review Notes
Subscription group: `ekitapligim.premium`

Product IDs:
- `com.ekitapligim.app.premium.monthly`
- `com.ekitapligim.app.premium.yearly`

The app displays localized names and prices returned by StoreKit. It provides purchase, restore, Manage Subscriptions, Terms, Privacy Policy, and auto-renewal disclosure. A verified Apple transaction JWS is sent to the backend; premium is not granted for unverified or server-rejected transactions.

## App Review Reply Draft (Resolution Center)

Hello App Review Team,

Thank you for your review and for the clear guidance under Guideline 1.2 – Safety – User-Generated Content.

We have revised the app and our backend moderation controls, and we are resubmitting a new binary (version 1.0.0, build 18 or later).

How we address Guideline 1.2:

1. EULA / Terms before login or registration
Users must view and accept the Apple Standard EULA and our community rules before Sign In or Create Account can continue. Acceptance is required in the login/register UI, and the accepted terms version is recorded by our server with a successful authentication request.

2. Filtering objectionable content
New and edited user-generated content is checked against an administrator-managed blocked-terms list and XenForo spam checks before it is saved. Rejected content returns an error to the user (HTTP 422) and is not published.

3. Flagging / reporting
Visible Report controls are available on user-generated content surfaces, including forum topic rows, individual forum posts, book comments, Book Agenda posts and comments, chat messages, private messages, and book requests. Reports are sent to our moderation queue with a reason.

4. Blocking abusive users
Users can Block and Block & Report from content menus and member profiles. Blocking notifies our moderation team and immediately removes that user’s content from the reporting user’s feed. Blocked users are also filtered server-side on subsequent API responses. Users can unblock from the Blocked Members list. One-to-one conversations with a blocked member are refused; in group conversations, the blocked member’s messages remain hidden.

5. Acting within 24 hours
Moderators receive queued email notifications for open reports (without private message bodies or tokens). Open reports trigger a reminder at 20 hours and escalation at 24 hours. We act on objectionable content reports within 24 hours by removing the content and ejecting the user who provided the offending content when required.

Where to verify in the app:
- Login / Register: EULA and community rules acceptance (button remains disabled until accepted)
- Community > Community Safety: prohibited-content guidance, support contact, blocked users, and the 24-hour moderation commitment
- Forum topics and posts, Book Agenda, chat, messages, and Book Requests: ellipsis menu → Report / Block & Report
- Member profile: Block / Unblock and Block & Report
- Blocked Members: unblock to reset the reviewer account

Review environment:
- Public HTTPS API: https://ekitapligim.com/ios-api/v1/
- Reviewer Sign-In credentials are provided only in App Store Connect Sign-In Information
- Prepared demo content for report/block testing is available on the reviewer account

We have attached (or will attach) physical-device screen recordings for iPhone and iPad that demonstrate:
- EULA / terms acceptance before login or registration
- Flagging objectionable content
- Blocking an abusive user and immediate removal of that user’s content from the feed

Please let us know if you need any additional information.

Thank you,
Ekitapligim Team

### App Review Information → Notes (short)

Guideline 1.2 resubmission — v1.0.0 (build 18 or later).
Before login/register: EULA + community rules must be accepted.
UGC: Report and Block & Report on forum topics/posts, comments, Book Agenda, chat, messages, and book requests. Member profile Block / Block & Report. Blocking notifies moderators and hides content immediately (client + server).
Filtering: objectionable terms screened before save (HTTP 422 if rejected).
SLA: moderator emails; 20h reminder / 24h escalation; human action within 24 hours.
API: https://ekitapligim.com/ios-api/v1/
Sign-in: use App Store Connect reviewer credentials.
Physical iPhone + iPad recordings of EULA, report, and block flows are attached in Notes / Resolution Center.

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
