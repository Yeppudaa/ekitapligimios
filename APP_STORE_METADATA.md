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
- Ana sayfa, katalog ve kitaplık Android uygulamasının görsel kimliğiyle uyumlu olacak şekilde yenilendi.
- Yeni Ekitaplığım renk sistemi, marka logosu, kart düzenleri ve uygulama menüsü eklendi.
- Katalog liste/ızgara görünümü ile kitaplık rafları ve okuma ilerlemesi daha anlaşılır hale getirildi.
- Erişilebilirlik etiketleri ve Türkçe yerelleştirmeler güncellendi.

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
GUIDELINE 2.1(b) AND 3.1.2(c) RESUBMISSION UPDATE

- Build 1.0.0 (15) is the validated binary for the subscription fix. It loads the bundle-prefixed StoreKit identifiers, while the production backend continues to accept the legacy identifiers only for restoration and entitlement verification. The bundle-prefixed products still require Review Information screenshots before they can be added to this submission.
- The prepared reviewer account has no active Premium entitlement. Sign in, then open Account > Ekitaplığım Premium to test the monthly or yearly purchase and Restore Purchases.
- The Premium screen displays the StoreKit product title, localized price, monthly or yearly duration, automatic-renewal disclosure, Restore Purchases, Manage Subscriptions, Terms, and Privacy links.
- The Turkish App Description now includes the functional Apple Standard EULA link: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- The App Store Privacy Policy field and App Description include the functional privacy-policy link: https://ekitapligim.com/yardim/gizlilik-politikasi/
- A real-device TestFlight recording is required before resubmission; no such recording is present in the current workspace, so it must be captured from TestFlight on a physical iPhone or iPad.

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
1. Log in with the reviewer account using the username/email and password supplied only in App Store Connect.
2. Open Hesap > Ekitaplığım Premium and purchase or restore either bundle-prefixed subscription with Apple Sandbox after the products have been added to the submission. The prepared account intentionally starts without an active Premium entitlement, so this step must precede reader and download testing.
3. Open Kitaplar, search/filter, switch list/grid, and open book details plus a related book.
4. Read the provided rights-cleared PDF and EPUB after the Sandbox entitlement becomes active; verify progress and a PDF bookmark.
5. Download the rights-cleared book and verify it under Kitaplığım > İndirilenler.
6. Create/vote on the reviewer-safe book request.
7. Open Topluluk, view a forum/thread, accept community terms if prompted, and post the supplied reviewer-safe reply.
8. Report the supplied post/comment and block/unblock the supplied member.
9. Open Mesajlar, reply to the safe conversation, and create a message to the safe recipient.
10. Open Hesap > Profilim, edit safe profile fields, then inspect Giriş ve Güvenlik without changing the shared reviewer password.
11. Open Hesap > Hesap silme talebi başlat and verify the 30-day disclosure and confirmation UI. Do not submit unless a disposable reviewer account is provided.

Account deletion is initiated entirely in-app. Manual processing is expected within 30 days and completion is sent to the account email. Deletion operations must remove/anonymize associated user content as legally permitted.

Do not submit until every placeholder is replaced, MobileApi `1.0.84` or newer is on the public HTTPS environment, and the reviewer flow has been executed there.

## In-App Purchase Review Notes
Subscription group: `ekitapligim.premium`

Product IDs:
- `com.ekitapligim.app.premium.monthly`
- `com.ekitapligim.app.premium.yearly`

The app displays localized names and prices returned by StoreKit. It provides purchase, restore, Manage Subscriptions, Terms, Privacy Policy, and auto-renewal disclosure. A verified Apple transaction JWS is sent to the backend; premium is not granted for unverified or server-rejected transactions.

## App Review Reply Draft
Hello App Review Team,

Thank you for your review. We addressed both subscription-related issues in this submission.

For Guideline 2.1(b), build 1.0.0 (15) loads both submitted auto-renewable subscriptions from StoreKit. A real-device TestFlight recording should be attached showing the monthly and yearly products, localized StoreKit prices, subscription durations, automatic-renewal disclosure, purchase/restore controls, and the functional Terms and Privacy links.

For Guideline 3.1.2(c), we updated the Turkish App Description to include the functional Apple Standard EULA link:
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

The functional Privacy Policy link is also present in the App Store Privacy Policy field and App Description:
https://ekitapligim.com/yardim/gizlilik-politikasi/

No additional binary change was required for the metadata issue. Please review version 1.0.0, build 15, together with the real-device recording once it is captured.

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
