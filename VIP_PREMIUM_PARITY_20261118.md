# VIP Premium iOS eşleşmesi — 18.11.2026

Android 1.2.76 ve Mobile API 1.0.162 ile gelen VIP Premium ve profil değişikliklerinin iOS karşılığı.

## Uygulama
- **Üyelik kimliği:** `MembershipTier` sunucudaki `vip_supporter` / `premium` değerlerini Android ile aynı kurallarla okur (💎 VIP, 👑 Premium). Yalnızca görünüm içindir, erişim vermez.
- **VIP profil kartı (`VipProfileHero`):**
  - Gece kütüphanesi görseli 3:2 oranında, tam olarak gösterilir. Altında görselin gece gölündeki yansıması yer alır.
  - Avatar, lila–turkuaz sekizgen çerçeveyle su çizgisinin üstünde durur. Çerçevedeki parıltı "Hareketi azalt" ayarına uyar.
  - Bu kart hem kendi profilde hem üye profilinde kullanılır.
  - Üye profili, yalnızca üyenin yüklediği afişi gösterir; sunucudaki varsayılan site afişi gösterilmez.
- **Premium profil:** Adın önüne 👑 eklendi.
- **Sohbet:**
  - VIP üye adı "💎 VIP ad" biçiminde, lila–turkuaz zeminde gösterilir ve sekizgen avatar çerçevesi kullanılır.
  - VIP yükseltme duyuruları ayrı renktedir.
  - Ana sayfadaki sohbet önizlemesi de aynı görünümü kullanır.
- **Kitap Gündemi, ana sayfa gündem önizlemesi ve Canlı Akış:**
  - Paylaşanın adının önüne üyelik emojisi gelir.
  - Avatarda VIP üyeler için sekizgen, Premium üyeler için altın halka çerçeve kullanılır.
  - Canlı Akış'ta "VIP" etkinlik türü ve "Son Premium üyeler" şeridi var.
- **Yan menü:** VIP üyeler için "💎 VIP Premium" kartı gösterilir.

## Satın alma (App Store)
- **Ürün:** VIP, `com.ekitapligim.app.premium.vip` kimlikli, tek seferlik (non-consumable) bir üründür.
- **Mevcut paketlerden ayrı tutulur:**
  - `productIDs` listesine girmez.
  - Ayrı bir sorguyla yüklenir. App Store'da bulunmaması mevcut paketlerin yüklenmesini, sıralamasını ve hata durumlarını etkilemez.
- **Satın alma koşulları.** VIP düğmesi ancak şu üç koşul birlikte sağlandığında açılır:
  - App Store ürün için bir fiyat döndürmüş olmalı.
  - Sunucu `supported_product_ids` listesinde VIP'yi göndermiş olmalı.
  - Kullanıcı giriş yapmış olmalı.
- **Uyarılar:**
  - Hesapta Apple aboneliği varsa, aboneliğin otomatik iptal edilmediğini belirten mevcut uyarı gösterilir.
  - VIP sahibine hiçbir ürün tekrar satılmaz (`alreadyVip`).
- **Süresiz doğrulama:** Sunucu doğrulamasında VIP, Sınırsız Premium gibi süresiz kabul edilir (`PremiumProductCatalog.isLifetime`).

## Sunucu (IosApi 1.0.41)
- Canlıdaki 1.0.40 temel alındı. Depodaki `Backend/IosApi-addon` canlıyla yeniden eşitlendi; 12 ve 17 Kasım bildirim değişiklikleri artık depoda.
- **`AppStoreProducts`:**
  - VIP, Premium ve VIP Destekçi gruplarını verir.
  - Her alımın grup anahtarı ayrıdır. VIP iadesi, başka bir alımla kazanılmış Premium hakkını korur.
- **Doğrulama:**
  - VIP her zaman doğrulanır, böylece ödenmiş bir VIP alımı reddedilmez.
  - Uygulamaya ancak iki grup da tanımlıysa "satılabilir" denir.
- **`has_vip_supporter`:** Web veya Google Play'den VIP alan üyeler de "zaten VIP" sayılır.
- **Sohbet:** `is_vip_supporter` ve `is_vip_announcement` alanları eklendi.

## Hata düzeltmesi: "Daha fazla göster" tıklanmıyordu
- **Neden:** Sağ altta yüzen AI asistan düğmesi, listelerin son satırını ve "Daha fazla göster" düğmesini örtüyordu. Dokunuşlar asistan düğmesine gidiyordu.
- **iOS:** Sekme içindeki ana listelere `floatingLauncherClearance()` ile 76 pt kaydırma payı eklendi. Pay `RootView` üzerinden yalnızca yüzen düğmenin bulunduğu içeriğe verilir.
- **Android:** `AppChrome.AiLauncherClearance` (76 dp) Kitap Gündemi, Canlı Akış, Forum konuları, Üyeler, Mesajlar ve Rehber listelerinin alt boşluğuna eklendi. `LoadMoreLauncherClearanceInstrumentedTest` bu durumu ölçerek doğrular.

## Doğrulama
- `swift test`: 575 çekirdek testi geçti; 15'i yeni VIP testi.
- `Scripts/appstore-entitlement-policy-test.php`: 7 yeni VIP kontrolü geçti.
- Windows durum testleri geçti: canlı akış, sohbet, profil ve rehber, bildirim, kitaplık, gündem.
- SwiftUI ekranlarının derlenmesi ve iOS arayüz testleri macOS CI'da çalışmalı.
- App Store Connect'te `com.ekitapligim.app.premium.vip` ürünü (tek seferlik, 5.000 TL) oluşturulmalı.
