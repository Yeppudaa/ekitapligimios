# App Store Metadata Draft

## App Information
- App name: Ekitaplığım
- Subtitle: PDF ve EPUB Kitap Okuyucu
- Primary category: Books
- Secondary category: Social Networking
- Age rating planning assumption: 13+ on iOS 26+ because the app contains user-generated forum content and private messaging. Complete the current App Store Connect questionnaire; Apple calculates global and regional ratings, so this draft is not final rating evidence.

## Promotional Text
Kitapları keşfedin, PDF ve EPUB okuyun, kaldığınız yeri eşitleyin ve Ekitaplığım okur topluluğuna katılın.

## Description
Ekitaplığım, Ekitapligim.com kitap kataloğunu ve okur topluluğunu iPhone ve iPad’e taşıyan native bir uygulamadır.

Kitap, yazar, yayınevi, kategori veya ISBN ile arama yapabilir; liste ve ızgara görünümleri arasında geçebilir; kitap ayrıntılarını, yorumları ve benzer kitapları inceleyebilirsiniz. Desteklenen içerikleri PDF veya EPUB biçiminde okuyabilir, okuma ilerlemenizi hesabınızla eşitleyebilir ve izin verilen kitapları çevrimdışı kullanım için indirebilirsiniz.

Kitaplığınızda okuduğunuz, okumakta olduğunuz ve favori kitapları takip edebilirsiniz. Yazar ve yayınevi dizinlerini gezebilir, kitap isteği oluşturabilir ve mevcut isteklere oy verebilirsiniz.

Topluluk bölümünde forumları ve konuları görüntüleyebilir, kullanım şartlarını kabul ettikten sonra yetkiniz dahilinde cevap yazabilir, özel mesajlarınızı yönetebilir, uygunsuz içeriği bildirebilir ve kullanıcıları engelleyebilirsiniz.

Premium abonelikler daha yüksek veya sınırsız okuma ve indirme hakları sağlayabilir. Satın alma ve geri yükleme Apple In-App Purchase ile yapılır; entitlement yalnız Apple işlemi sunucuda doğrulandıktan sonra etkinleşir.

Uygulama içinden hesap oluşturabilir, şifrenizi sıfırlayabilir, profil ve güvenlik bilgilerinizi yönetebilir ve tüm hesabınızın silinmesini başlatabilirsiniz. Hesap silme talepleri genellikle 30 gün içinde tamamlanır ve sonuç kayıtlı e-posta adresine bildirilir.

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
Ekitaplığım is a native SwiftUI iOS/iPadOS app, not a website wrapper. The catalog, PDF/EPUB reader, library, downloads, account, StoreKit, forum, messaging, reporting, blocking, and account-deletion surfaces are native.

Reviewer account:
- Username/email: [CREATE_REVIEWER_ACCOUNT]
- Password: [STORE_IN_APP_STORE_CONNECT_ONLY]
- Environment: [PUBLIC_HTTPS_REVIEW_ENVIRONMENT]
- Safe member to follow/block: [REVIEW_SAFE_MEMBER]
- Safe conversation recipient: [REVIEW_SAFE_RECIPIENT]
- Rights-cleared PDF book ID: [REVIEW_PDF_BOOK_ID]
- Rights-cleared EPUB book ID: [REVIEW_EPUB_BOOK_ID]

Suggested review flow:
1. Log in with the reviewer account or use Sign in with Apple.
2. Open Kitaplar, search/filter, switch list/grid, and open book details plus a related book.
3. Read the provided PDF and EPUB; verify progress and a PDF bookmark.
4. Download the rights-cleared book and verify it under Kitaplığım > İndirilenler.
5. Create/vote on the reviewer-safe book request.
6. Open Topluluk, view a forum/thread, accept community terms if prompted, and post the supplied reviewer-safe reply.
7. Report the supplied post/comment and block/unblock the supplied member.
8. Open Mesajlar, reply to the safe conversation, and create a message to the safe recipient.
9. Open Hesap > Profilim, edit safe profile fields, then inspect Giriş ve Güvenlik without changing the shared reviewer password.
10. Open Hesap > Ekitaplığım Premium, purchase or restore with Apple Sandbox if IAP is submitted.
11. Open Hesap > Hesap silme talebi başlat and verify the 30-day disclosure and confirmation UI. Do not submit unless a disposable reviewer account is provided.

Account deletion is initiated entirely in-app. Manual processing is expected within 30 days and completion is sent to the account email. Deletion operations must remove/anonymize associated user content as legally permitted and revoke Sign in with Apple tokens where applicable.

Do not submit until every placeholder is replaced, MobileApi `1.0.82` or newer is on the public HTTPS environment, and the reviewer flow has been executed there.

## In-App Purchase Review Notes
Subscription group: `ekitapligim.premium`

Product IDs:
- `ekitapligim.premium.monthly`
- `ekitapligim.premium.yearly`

The app displays localized names and prices returned by StoreKit. It provides purchase, restore, Manage Subscriptions, Terms, Privacy Policy, and auto-renewal disclosure. A verified Apple transaction JWS is sent to the backend; premium is not granted for unverified or server-rejected transactions.

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
