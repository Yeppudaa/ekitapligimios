# APNs 410 Unregistered düzeltmesi — 12 Ekim 2026

Ek derin eski sürüm incelemesi: [IOS_API_1_0_34_COMPATIBILITY.md](IOS_API_1_0_34_COMPATIBILITY.md). 1.0.4–1.0.8 Core ile 20 XCTest, eski serializer ile 15 senaryoda bütün eski alanların eşitliği, gerçek XF upgrade runner ve APNs transport/imza kontrolü geçti. Public `auth/refresh` yolunun MobileApi'ye delegasyonu raporda ayrıca netleştirildi; doğrudan standalone session testleri public route kanıtı değildir.

## Bulgular

Paylaşılan kayıt, `Service/ApnsPush.php` dosyasındaki `sendToUser` → `logFailure` yolundan geliyor. Önceki kod, bütün 200 dışı APNs yanıtlarını XenForo sunucu hatası olarak kaydediyor, ardından geçersiz tokenı siliyordu. Bu nedenle olağan `HTTP 410, reason=Unregistered` yanıtı yönetim panelinde ErrorException olarak görünüyordu. Arka plan `/job.php` işi kullanıcı oturumu taşımadığından kayıttaki “Bilinmeyen hesap” ifadesi üyeye ait hesabın silindiğinin veya girişin bozulduğunun kanıtı değildir.

Apple'ın [APNs yanıtları belgesi](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) 410 `Unregistered` için cihaz tokenının ilgili uygulama topic'i açısından aktif olmadığını açıklar. APNs `timestamp` değeri geçersizliğin doğrulandığı zamanı Epoch milisaniyesi olarak taşır. Bildirim tokenı, API giriş/refresh tokenından farklıdır. Bu tek kayıt tüm kullanıcıların bildirimlerinin çalışmadığını veya APNs anahtarının bozuk olduğunu göstermez. Cihazda uygulamanın kaldırılması/yeniden kurulması gibi token yaşam döngüsü nedenlerinden hangisinin gerçekleştiği bu kayıttan kesin çıkarılamaz.

## Değişiklik

IosApi **1.0.34 / 1000034**:

- 410 `Unregistered` yanıtı teslim edilemeyen bildirim olarak sayılır; eski token kaydı sessizce temizlenir. `failed`/`removed` özeti gerçek durumu korur; normal token yaşam döngüsü artık XenForo sunucu hatası üretmez.
- Temizleme, okunan kayıt ID'si, token, kullanıcı ID'si ve kayıt zamanı eşleşmesini gerektirir. Gecikmiş yanıt yeniden kaydedilen, başka hesaba taşınan veya silinip yeniden oluşturulan kaydı silmez.
- Apple'ın milisaniyeli geçersizlik zamanı dikkate alınır. Mevcut `created_at` alanı saniye hassasiyetinde olduğundan aynı saniyedeki/yeni kayıtlar tedbirli olarak tutulur. Timestamp yoksa gönderimin başlangıç zamanı esas alınır. Silinemeyen aynı-saniye kayıtlar sonraki gönderimde tekrar değerlendirilir.
- APNs topic/kimlik doğrulama, yapılandırma, 429, sunucu ve transport hataları görünür kalır. cURL hatası bir kez sayısal koduyla kaydedilir; cihaz tokenı içerebilen ham URL/hata metni günlüğe yazılmaz.

Public device-token endpoint'i, istemci yanıtları, kayıt şeması, mobil oturumlar, satın alma/geri yükleme, premium hakları, ürünler ve izinler aynı kaldı. Uygulama bildirim tokenını mevcut kayıt endpoint'inden göndermeye devam eder. Bu sunucu düzeltmesi için iOS uygulama güncellemesi gerekmez. Önceki native okuyucu/kapak/sohbet düzeltmeleri yine yeni uygulama derlemesine bağlıdır. Manifest, entitlements, `project.yml` ve StoreKit ayarlarında değişiklik gerekmez; yeni veri kategorisi/SDK yoktur.

## Çalıştırılan kontroller

Kanıt dizini: `artifacts/apns-20261012/`.

- `php Tests/Backend/ApnsDeliveryTest.php`: gerçek `sendToUser` ile çevrimdışı senaryolar geçti. Geçerli cihazlara devam, sessiz token temizliği, sonraki denemeden çıkarma, APNs timestamp, eksik/hatalı timestamp, aynı-saniye sınırı, yeniden kayıt/hesap değiştirme/yeni row, hata görünürlüğü ve token/payload gizliliği kontrol edildi. Sahte transport ve bellek içi DB kullanır; Apple'a istek veya gerçek DB bağlantısı yapılmadı.
- `php Tests/Backend/ApnsPushPolicyTest.php` ve PHP lint geçti.
- `Scripts/build-ios-api-addon.ps1 -CreateZip -OutputDirectory artifacts/apns-20261012/server-package` geçti. Chat/session/reader/APNs/privacy/account ve mevcut App Store crypto/ledger/membership testleri geçti. Sınırlı ortamda OpenSSL testinde random-state yazma uyarısı çıktı; ES256 testleri yine geçti. Üretim anahtarı kullanılmadı.
- `Scripts/mobileapi-release-audit.ps1 -AddonZip artifacts/apns-20261012/server-package/Ekitapligim-IosApi.zip` geçti; APNs guards ve önceki route/purchase sözleşmeleri doğrulandı.
- `Scripts/validate-workspace.ps1` geçti: config/JSON/plist, PHP lint, statik erişilebilirlik ve secret taraması. Bu bir native iOS derlemesi değildir.
- ZIP, önceki 1.0.33 ZIP ile karşılaştırıldı: **132/135 dosya tamamen aynı**. Yalnızca `Service/ApnsPush.php`, `addon.json` ve README değişti. 1.0.33 ZIP korunmuştur.
- `Scripts/legacy-client-compatibility-test-windows.ps1 -AddonZip artifacts/apns-20261012/server-package/Ekitapligim-IosApi.zip` geçti: önceki 1.0.32 sunucu kaynaklarıyla paket karşılaştırması, eski servisle oluşturulmuş sentetik oturumun yeni servisle yenilenmesi ve önceki iOS Core ile yeni sohbet yanıtları için **4 XCTest**. Sınırlı ortamdaki ilk denemede Swift başlatılamadı; dış derleyici önbellekleri erişimiyle tekrar çalıştırılan son koşu başarılıdır. Kanıt: `legacy-client-compatibility.log`. Gerçek eski uygulama binary'siyle staging testi değildir.

## Hazırlanan paket

`artifacts/apns-20261012/server-package/Ekitapligim-IosApi.zip`

- Sürüm: **1.0.34 / 1000034**; 135 dosya.
- SHA-256: `9C98ECE68B1C6E760EB329BC3AA8FC0CA5F7E554900B458B9CCF8E23362DABA9`.
- 1.0.33'ün oturum/sohbet güncellemelerini içerir; yalnızca APNs düzeltmesi bunlara eklenir.
- MobileApi bağımlılığı 1.0.145+; Android kaynakları ve `/mobile-api/` yolları değiştirilmedi.

Paket sunucuya kurulmadı. XenForo'nun normal eklenti yükseltme işlemiyle 1.0.32 veya 1.0.33 üzerinden uygulanabilir; önce mevcut dosya/DB yedeği alınmalıdır. Yeni toplu oturum iptali, yeni migration veya zorunlu istemci güncellemesi eklenmez. Eski hata kaydı kendiliğinden yönetim panelinden silinmez; düzeltme yeni olayların davranışını değiştirir.

Canlı APNs uçtan uca teslimatı ve gerçek MySQL eşzamanlı kayıt davranışı bu çevrimdışı testlerden kanıtlanmış sayılmaz. Staging'de mevcut geçerli bir cihazın bildirim alması ve token kaydının korunması kontrol edilmelidir. Kullanıcının verdiği özel hesap/cihazla gerçek bildirim gönderilmedi; canlı tabloya, ayarlara veya hata kayıtlarına müdahale edilmedi.
