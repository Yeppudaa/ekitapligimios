# Satın alma incelemesi — 12 Ekim 2026

Sonuç: Normal satın alma doğrulamasında genel bir arıza tespit edilmedi. Ancak erken tekrar satın alma ve paket geçişlerinde kullanıcıyı etkileyen sorunlar bulundu. Bu inceleme sonucunda yeni sürüm yayına gönderilmedi. Satın alma/premium kaynak kodu, canlı üyelikler ve App Store Connect ayarları değiştirilmedi.

Kapsam: Swift StoreKit servisi, Premium ekranı, API istek/yanıt modelleri, hesap bağlama, sunucu imza doğrulaması, işlem kayıtları, XenForo grup eşitleme, iade/yenileme bildirimleri ve canlı Apple ürün yapılandırması. Sunucu kaynak sürümü 1.0.34. İncelenen sekiz temel satın alma dosyası, 1.0.8 yayınını belgeleyen `d1dd139` kaynak sürümüyle aynı: bu bulguları son oturum/sohbet/APNs değişiklikleri getirmedi. Canlı sunucudaki dosyaların bu kaynakla birebir aynı olduğu ayrıca doğrulanmadı.

## 1. Yüksek öncelik: süreli paketler erken yeniden satın alınınca süreler çakışıyor

Premium ekranı mevcut premium hakkı varken de tüm ürünlerin satın alma düğmelerini etkin tutuyor. Servis yalnız oturum/işlem meşguliyetini kontrol ediyor. Sunucu üç, altı ve on iki aylık paketlerin bitişini yeni işlemin satın alındığı tarihten hesaplıyor; mevcut kullanılmamış süreyi eklemiyor. Bu davranış hakkında satın alma öncesinde özel açıklama yok.

Gerçek sunucu kayıt ve süre hesaplama koduyla, sahte işlemler ve bellek içi SQLite kullanılarak tekrarlandı:

| Senaryo | Mevcut sonuç | Etki |
| --- | --- | --- |
| 1 Ocak 2026 üç aylık paket, 1 Şubat 2026 aynı paketi tekrar alma | Son bitiş 1 Mayıs 2026 | Süre taşınsaydı 1 Temmuz olacaktı; 61 gün çakışıyor. |
| 1 Ocak 2026 yıllık paket, 1 Şubat 2026 üç aylık paket alma | Son bitiş yine 1 Ocak 2027 | Yeni işlem etkin kabul edildiği halde ek erişim günü sıfır. |

Bu, Apple'ın ödeme ekranının iki kez kendi kendine açılması veya aynı işlemin iki kez kaydedilmesi değildir. Kullanıcının başlattığı ikinci bağımsız satın alımın sürelerinin mevcut hakla çakışmasıdır. Gerçek para tahsilatı yapılmadı; süre ve kayıt davranışı çevrimdışı test edildi.

Kanıt:

- `App/Ekitapligim/Features/PremiumView.swift:224` — mevcut hak durumunu dikkate almayan düğme koşulu.
- `App/Ekitapligim/Purchases/StoreKitPurchaseService.swift:208` — satın alma ön koşulları.
- `Backend/IosApi-addon/Service/AppStoreEntitlementPolicy.php:28` — satın alma tarihinden süre hesabı.
- `Backend/IosApi-addon/Service/IosEntitlement.php:22` — mevcut kayıtlar arasındaki en ileri bitiş; süreleri toplamaz.
- `artifacts/purchase-audit-20261012/OverlapDiagnostic.php` ve `overlap-results.json` — tekrar çalıştırılabilir kanıt.

Önerilen çözüm: yeni ödeme öncesi mevcut haklarla çakışmayı denetlemek; uygulanacak kurala göre satın almayı engellemek veya kullanılmamış süreyi güvenli ve idempotent biçimde devretmek. Bu incelemede ücret/süre politikası değiştirilmedi.

## 2. Yüksek öncelik: ömür boyu pakete geçince mevcut aylık aboneliğe özel uyarı yok

Ömür boyu ürün ayrı bir Non-Consumable satın alımdır. Aylık abonelikten bu ürüne geçiş, aynı abonelik grubu içindeki bir plan değişikliği değildir. Uygulama bu alımı başlatmadan veya tamamladıktan sonra mevcut otomatik yenilemeyi özellikle hatırlatmıyor; genel “Abonelikleri yönet” düğmesi ve iptal açıklaması mevcut.

Sonuç: aylık aboneliği bulunan kullanıcı ömür boyu paket aldıktan sonra aylık aboneliğini ayrıca iptal etmezse yenileme devam edebilir. Benzer şekilde ömür boyu hakkı bulunan bir kullanıcı yeni süreli paket almaya yönlendirilebiliyor. Bu bir canlı kullanıcıda gözlenmiş tahsilat iddiası değil; mevcut bağımsız ürün yapılandırması ve koruma/uyarı eksikliğidir.

Kanıt: `StoreKitPurchaseService.swift:208`, `PremiumView.swift:194`, `PremiumView.swift:303`. Çevrimdışı kayıt testi de ömür boyu kayıttan sonra gelen bağımsız aylık yenilemenin kabul edildiğini gösteriyor. İptal kullanıcı tarafından Apple abonelik yönetiminde yapılmalıdır; uygulama kendi kendine iptal ettiğini söylememelidir.

Apple ürün davranışı: [In-App Purchase ürünleri ve otomatik yenileme](https://developer.apple.com/documentation/StoreKit/original-api-for-in-app-purchase).

Önerilen çözüm: mevcut yenilenen abonelik varken ömür boyu/sabit süreli ürün geçişinde açık uyarı ve Apple abonelik yönetimine erişim; ömür boyu hak mevcutsa faydasız ek satın alımı engellemek.

## 3. Orta öncelik: canlı Apple abonelik seviyeleri yerel test yapılandırmasıyla uyuşmuyor

App Store Connect'te salt okunur olarak doğrulandı:

- `com.ekitapligim.app.premium.monthly`: Approved, seviye **2**.
- `com.ekitapligim.app.premium.yearly`: Approved, seviye **3**.
- Her ikisi de `ekitapligim.premium` grubunda. Eski yıllık ürün uygulamada yeni satış listesinde değil, geri yükleme için tanınıyor.
- Yerel `.storekit` dosyasında bu iki ürün aynı seviyede (**1**); mevcut `premium-contract-audit.ps1` da aynı seviyede olmalarını bekliyor.

Aynı premium içeriğini veren yıllık paketten aylığa geçiş, canlı Apple ayarında daha yüksek seviyeye yükseltme sayılır. Bu işlem hemen yürürlüğe girer, kalan eski dönem için oransal iade yapılır ve yenileme tarihi değişir. Aynı seviyedeki farklı süreler arasında geçiş ise sonraki yenilemede olur. Dolayısıyla yerel testler canlı plan geçiş davranışını temsil etmiyor.

Kanıt: [Canlı abonelik grubu](https://appstoreconnect.apple.com/apps/6789584323/distribution/subscription-groups/22334120), `App/Ekitapligim/StoreKit/Ekitapligim.storekit:93`, `:118`, `app-store-observations.json`.

Apple kuralı: [Subscription levels, upgrades, downgrades and crossgrades](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information/).

Önerilen çözüm: aynı hakları sunan aktif/korunan ürünlerin seviyelerini aynı hizmet düzeyiyle tutarlı hale getirmek ve Sandbox'ta eski yıllıktan aylığa geçişi doğrulamak. Canlı sıralama bu incelemede değiştirilmedi.

## Ek bulgular ve sınırlar

- **Ömür boyu üyelikte yanıltıcı bitiş tarihi:** `PremiumView.swift:373` ömür boyu hakkın `nil` bitişini “bilgi yok” olarak ele alıp abonelik yanıtındaki süreli bitişe düşebiliyor. Ömür boyu + süreli hak birlikteyken ekranda bir son tarih görülebilir; bu satır ömür boyu hakkı iptal etmez. Kod incelemesi bulgusu; iOS ekranında çalıştırılmadı.
- **Kaçırılan Apple bildirimi için otomatik geri toplama yok:** beş dakikalık `Cron/AppStoreReconcile.php` yalnız eldeki kayıtları eşitliyor, Apple bildirim geçmişini/abonelik durumunu sorgulamıyor. Uzun sunucu kesintisinde kaybolan yenileme/iade, istemci güncel işlemi tekrar göndermedikçe eksik kalabilir. Canlı kayıp bildirim tespit edildiği anlamına gelmez. Apple [bildirim geçmişi ve güncel durum sorgularını](https://developer.apple.com/documentation/AppStoreServerNotifications/responding-to-app-store-server-notifications) bu durum için sunuyor.

## Sorunsuz geçen kontroller

- Swift çekirdek paketi: **346 XCTest geçti**, bunların 15'i doğrudan satın alma hazırlığı, doğrulama politikası ve premium hak modeline ait. Log sonunda görülen “0 tests” ayrı Swift Testing koşucusudur; XCTest listesi 346/346 tamamlandı.
- Beş PHP App Store test dosyası başarıyla çalıştı: controller, süre politikası, üyelik eşitleme, gerçek ES256/sertifika doğrulaması, işlem defteri/hesap bağlama.
- Tekrarlanan aynı işlem idempotent; başka hesaba bağlı işlem reddediliyor; eski makbuzla kaydedilmiş iade geri alınamıyor; veritabanı/yetki eşitleme hataları yeniden denenebilir; manuel premium hakkı testte korunuyor.
- Yerel premium ürün/sözleşme kontrolü geçti. Bu kontrol yalnız dosyaları okur; canlı Apple seviye uyuşmazlığını yakalamıyor.
- Canlı Apple'da uygulamanın sattığı beş ürün de **Approved**. Üç aylık ürün detayında tüm ülkeler/bölgeler seçili; satıştan kaldırılmamış.
- Üretim ve Sandbox bildirim adresleri ikisi de `https://ekitapligim.com/ios-api/v1/billing/app-store/notifications`. Adres kontrol edildi; Apple'dan imzalı test bildirimi gönderilmedi.
- Canlı uygulama **1.0.8, build 41, Ready for Distribution**. Yeni sürüm oluşturulmadı/gönderilmedi.

İlk Swift denemesi sandbox içinde derleyici çalıştırma hatası verdi; gerekli önbellek erişimiyle tekrar çalıştırıldı ve başarıyla tamamlandı. Bu çalışma Windows üzerindedir. StoreKitTest/iOS simülatörü bu incelemede çalıştırılmadı; gerçek iPhone/TestFlight üzerinden uçtan uca satın alma/geri yükleme ve canlı sunucu kayıt teslimi doğrulanmadı. Testlerin geçmesi bu son kontrollerin yerini tutmaz.

## Kanıt dosyaları

Tümü `artifacts/purchase-audit-20261012/` altında:

- `swift-core.log`
- `AppStoreControllerTest.log`, `AppStoreEntitlementPolicyTest.log`, `AppStoreMembershipTest.log`, `AppStoreSignatureTest.log`, `AppStoreTransactionStoreTest.log`
- `premium-contract.log`
- `OverlapDiagnostic.php`, `overlap-results.json`
- `app-store-observations.json`
- `released-source-comparison.json`

Tekrar üretim: `C:\xampp\php\php.exe artifacts/purchase-audit-20261012/OverlapDiagnostic.php`. Bu tanılama yalnız sentetik verilerle SQLite belleğinde çalışır; canlı veya yerel XenForo üyeliklerini değiştirmez. Kod düzeltilirse mevcut sorun davranışını bekleyen tanılama da yeniden değerlendirilmelidir; bu dosya ürün davranışını onaylayan bir regresyon testi değildir.
