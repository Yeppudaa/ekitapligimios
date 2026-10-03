# App Store Metadata Draft

## Version 1.0.8 App Store submission (2026-10-04)

At the user's explicit request, version 1.0.8/build 41 was submitted to App Review after the Codemagic/TestFlight upload. App Store Connect confirms **Waiting for Review** for submission `3df94232-e3e6-4c46-a788-09d540c0c6bd`. **Automatically release this version** is selected, with immediate availability after approval. This is submission evidence, not Apple approval or current public availability of 1.0.8. Existing screenshots, reviewer sign-in information, purchase products, pricing and entitlements were preserved. The IosApi 1.0.32 server installation and physical cross-device reply/reaction notification delivery remain unconfirmed; the user was asked about installation.

Turkish What's New saved: “Canlı sohbet görünümü yenilendi. Uzun mesajların tamamının görünmesi, dar ekranlarda metin düzeni ve profil fotoğrafından kişi profiline geçiş iyileştirildi. Profilde kaldığınız yerden devam et bilgisi için güncelleme sorunları giderildi.”

Review Notes saved: “Version 1.0.8, build 41 updates the native SwiftUI live chat layout and profile reading progress. Sign in with the existing reviewer account above. Open live chat to inspect full multiline messages, narrow-screen and large-text layout, and tap a member avatar to open their profile. Open a permitted book, advance the reading position, close the reader and revisit Profile to inspect Continue Reading. Reply and reaction controls use the server-provided chat API. Existing StoreKit 2 purchase/restore implementation, products and entitlements are unchanged in this update. Codemagic Production build and 102 native unit plus 24 UI tests passed with zero failures. API: https://ekitapligim.com/ios-api/v1/ Support: https://ekitapligim.com/diger/iletisim”

Evidence: `artifacts/testflight-20261004/appstore-1.0.8-waiting-review.jpg` and `APPSTORE-GONDERIMI.md` in that directory.

## Version 1.0.8 TestFlight candidate (2026-10-04)

Turkish testing note: “Canlı sohbette uzun mesaj görünümü, profil bağlantıları, alıntılı yanıtlar ve ifadeler iyileştirildi. Profilde kaldığın yerden devam et bilgisi güncellenir.” Version 1.0.8/build 41 at aacc7fa was uploaded successfully by Codemagic build 52 after 102 native unit and 24 UI tests passed with zero failures. App Store Connect shows TestFlight Waiting for Review and the existing Ekitapligim Internal Testers group (2 invites). App Store public submission remained disabled. Purchase implementation, products and entitlements are unchanged; only version/build metadata changed in configuration. Actual cross-device notification delivery remains a separate device check. Local evidence: artifacts/testflight-20261004/TESTFLIGHT-RAPORU.md.

## Version 1.0.7 (2026-10-01)

Turkish What's New saved in App Store Connect: “Kitap okuma bağlantıları ile Premium satın alma ve geri yükleme işlemlerinde güvenilirlik iyileştirmeleri.” Version 1.0.7 build 40 was uploaded to TestFlight and submitted to App Review; App Store Connect shows Waiting for Review. Codemagic Production build and native tests passed; GitHub CI #157 passed iPhone/iPad simulator tests, Production build, API/source checks and screenshot generation. The tester reported successful monthly purchase/restore and the four other current products in TestFlight. This report does not cover second-device, wrong-account, refund, expiry or notification-retry scenarios.

## Purchase reliability draft (2026-10-01; pending native/Sandbox validation)

Proposed Turkish release note after validation: “Satın alma ve satın almaları geri yükleme işlemlerinde bağlantı kesintisi sonrası toparlanma ve hesap eşitleme iyileştirildi.”

Review the five current products and legacy restore IDs with the same Ekitapligim account on a second device. A purchase linked to another app account must show the localized account explanation. Local StoreKit tests inject a verifier; TestFlight must exercise the public server with Apple-signed transactions. Do not publish this reliability claim until the gates in `PURCHASE_AND_API_AUDIT.md` pass.

## Reader draft addition (2026-09-28; pending native validation)

Turkish copy: “Tam ekran okuma alanında sepya, beyaz veya gece görünümünü seç. Kitabın yüklenirken aktarılan dosya boyutunu, sunucu toplam boyutu bildirdiğinde yükleme yüzdesini takip et. Kaldığın yerden okumaya devam et.”

Reviewer steps for the next validated binary: open a permitted PDF or EPUB from book detail or continue reading; inspect full-screen/tools and paper themes, advance the reading position, close and reopen the book. Check that settings and preview notices preserve the current position. With a large PDF, verify transfer progress, the separate preparation stage and retry behavior after a failed connection. Themes are stored only on the device. The DEBUG-only reader fixture is for development tests and is not a production feature or review-account substitute. Publish this copy only after the native gates in [READER_EXPERIENCE_VALIDATION.md](READER_EXPERIENCE_VALIDATION.md) pass; Windows core tests do not establish device appearance or App Store readiness.

## Gift wheel draft addition (pending device validation)

Turkish copy: “Hediye Çarkı'nı ücretsiz çevir, 30 güne kadar Premium süre sürprizini keşfet. Kazandığın hediye sürelerini ve son çevirişlerini uygulamada takip et.”

Reviewer steps: open **Hediye Çarkı** in the side menu. Guests can inspect the wheel and sign in; the server determines member eligibility and available spins. A successful request runs a ten-second animation before showing the server result. Test cooldown, gift wallet, history and recovering an interrupted response. This feature adds no purchase flow or external digital-purchase link. Publish this copy only after the gift-wheel release gate in `GIFT_WHEEL_VALIDATION.md` passes.

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
GUIDELINE 1.2 RESUBMISSION — v1.0.1 (build 24)

- Before Sign In / Create Account: Apple Standard EULA + community rules must be accepted (controls stay disabled until accepted). Accepted terms version is recorded by the server with successful authentication.
- Visible ellipsis safety menus on UGC: forum topic rows, individual forum posts, book comments, Book Agenda posts/comments, chat messages, private messages, and book requests → Report / Block & Report.
- Forum post actions now follow XenForo's server-provided edit/delete permissions; successful moderation and deletion responses update the visible thread immediately without exposing unauthorized actions.
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
- `com.ekitapligim.app.premium.three_months`
- `com.ekitapligim.app.premium.six_months`
- `com.ekitapligim.app.premium.yearly_once`
- `com.ekitapligim.app.premium.lifetime`

Turkey prices: ₺100 monthly, ₺239.99 three months, ₺400 six months, ₺750 one year, and ₺2,500 lifetime. Apple does not offer the website's exact ₺240 price point; ₺239.99 was approved by the owner. The monthly product renews; the three-month, six-month, and yearly products do not. Lifetime is a non-consumable purchase. The previous auto-renewing yearly product remains recognized for restoration.

App Store Connect status on 2026-09-27: the approved monthly and legacy auto-renewing yearly products are on sale at ₺99.99 and ₺999.99, respectively. Their Türkiye prices are scheduled to become ₺100 and ₺750 on 2026-09-28. The three new fixed-term products and lifetime product are still Prepare for Submission; only a new approved app version can make those available to customers.

The app displays localized names and prices returned by StoreKit. It provides purchase, restore, Manage Subscriptions, Terms, Privacy Policy, and auto-renewal disclosure. A verified Apple transaction JWS is sent to the backend; premium is not granted for unverified or server-rejected transactions.

## App Review Reply Draft (Resolution Center)

Hello App Review Team,

Thank you for your review and for the clear guidance under Guideline 1.2 – Safety – User-Generated Content.

We have revised the app and our backend moderation controls, and we are resubmitting a new binary (version 1.0.1, build 24).

How we address Guideline 1.2:

1. EULA / Terms before login or registration
Users must view and accept the Apple Standard EULA and our community rules before Sign In or Create Account can continue. Acceptance is required in the login/register UI, and the accepted terms version is recorded by our server with a successful authentication request.

2. Filtering objectionable content
New and edited user-generated content is checked against an administrator-managed blocked-terms list and XenForo spam checks before it is saved. Rejected content returns an error to the user (HTTP 422) and is not published.

3. Flagging / reporting
Visible Report controls are available on user-generated content surfaces, including forum topic rows, individual forum posts, book comments, Book Agenda posts and comments, chat messages, private messages, and book requests. Reports are sent to our moderation queue with a reason.

The latest binary also uses XenForo's server-provided permissions for individual forum post actions and updates the visible thread immediately after a successful moderation or deletion response.

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

Guideline 1.2 resubmission — v1.0.1 (build 24).
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

## AI Assistant draft addition (pending release validation)

Turkish feature copy: “AI Asistan ile kitap keşfet, okuma tercihlerine uygun öneriler al ve kitaplar hakkında sorular sor. Kullanım hakları üyelik durumuna göre sunucu tarafından belirlenir.”

Reviewer steps: open AI Asistan in the side menu or floating launcher; verify remaining daily quota; send a book question; open a recommended book and return; inspect/delete history. Test a guest, standard member and entitled member. Confirm server-disabled features remain hidden and exhausted quota blocks suggested prompts as well as the composer. Any data-changing AI proposal must show a preview and require confirmation. No external digital purchase prompt is added.

Do not submit this addition until SwiftUI build/UI/accessibility evidence and live account/group checks in AI_ASSISTANT_VALIDATION.md pass.
## Live chat/profile draft addition (2026-10-03, pending native/staging checks)

“Canlı sohbette mesajları alıntılayarak yanıtlayın, sitenin ifadeleriyle tepki verin ve profil fotoğrafından okurun profilini açın. Sohbet etkileşimi bildirimleri yalnızca mesajınıza verilen yanıt ve ifadelere yöneliktir. Profilinizde güncel okuma konumundan devam edin.”

Reviewer checks: use two accounts in a live room, verify multiline text and narrow/large-text layout, quote/cancel/send, select/change/remove a configured reaction, and follow the avatar/profile route. Verify exactly the intended author receives reply/reaction APNs, while ordinary messages, mentions and Siropu private/external chat do not create chat APNs. Verify current profile reading progress after closing/reopening the reader and account changes. Existing purchase flow/configuration is unchanged. Do not publish this copy until the gates in `CHAT_PROFILE_STABILITY_VALIDATION.md` pass.
