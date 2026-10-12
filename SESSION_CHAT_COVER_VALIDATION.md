# Oturum, sohbet ve kapak düzeltmeleri — 12 Ekim 2026

## Yapılan değişiklikler

- Oturum: genel HTTP 401/403, geçici ağ/sunucu hataları ve erişilemeyen Keychain artık kayıtlı oturumu silmez. Sunucunun açık geçersiz/süresi dolmuş/iptal edilmiş refresh-token yanıtı mevcut oturumla karşılaştırılarak işlenir. Hesap değiştirdikten veya çıkış yaptıktan sonra eski yenilemenin sonucu/hatası iptal edilir. Yanıtta eksik/boş refresh token önceki değeri silmez; yanlış hesaba ait ya da boş erişim tokenı kaydedilmez.
- Güncelleme sonrası oturum: Keychain servis adı, `session` anahtarı, erişilebilirlik sınıfı ve bundle ID aynı kaldı. Önceki sürümün kayıt formatı okunur; isteğe bağlı kullanıcı ID'si yeni kayıtlarda hesap ayrımını güçlendirir. Geçici Keychain okuma hatasından sonra uygulama yeniden öne gelince geri yükleme tekrar denenir.
- Kitap okuma: korumalı dosya isteği 401 aldığında API ile aynı token yenileme koordinatörünü kullanarak bir kez tekrar edilir. Harici dosya sunucusu/yetki hatası token yeniletmez. Yalnızca aynı HTTPS API kökenine bearer eklenir; farklı port ve URL içindeki kullanıcı bilgileri reddedilir. Hesap değişikliği eski dosya tekrarını durdurur. Dosya doğrulama, okuma kotası ve sunucu izinleri korunur.
- Sunucu oturumu kaynak kodu: Android referansındaki kaybolmuş refresh yanıtını kurtarma mantığı bağımsız IosApi `MobileSession` servisine aktarıldı. Ancak derin route incelemesi, 1.0.32–1.0.34 public `auth/refresh` yolunun hâlâ ortak **MobileApi** servisine yönlendiğini doğruladı. IosApi paketini kurmak tek başına public yol için bu mantığı etkinleştirmez; davranış kurulu MobileApi koduna bağlıdır. Doğrudan IosApi servis testi public route testi değildir. Bu ayrım önceki raporda eksikti. 120 saniyelik sınırlı kurtarma mantığında yalnızca aynı aktif sonraki token çifti geri verilir; yeni kayıt/ek süre verilmez. Ham token saklanmaz, şema değişikliği yoktur.
- Sohbet: normal premium üyeler için altın arka plan, taç ve ayırıcılı native kullanıcı adı eklendi. İsimler mevcut native profil sayfasını açar. Güvenilir premium yükseltme duyurusundaki kişi bağlantısı sunucuda doğrulanmış `announcement_member` kimliğinden gelir; bot/serbest metinden kişi uydurulmaz. Yönetici/moderatör ve eski API yanıtları korunur.
- Kapak: boş, geçersiz veya yüklenemeyen kapaklar için yerel sitedeki krem/petrol yeşili, kitap adı ve yazar içeren native görünüm ortak bileşene taşındı. Katalog, detay, ana sayfa, kütüphane, profil ve diğer kitap kartlarında kullanılır. Yazılar resource dosyasında yerelleştirildi.

## Referans ve korunan alanlar

Android kaynağı `C:\Users\Monster\Downloads\startdesign (1)` salt okunur incelendi. Kapak, kullanıcının verdiği yerel `sosyolojik-dusunmek.4326` sayfasında görsel olarak doğrulandı; sohbet stili yerel ChatStyle kaynakları ve Android `ChatPremiumUsername.kt` ile karşılaştırıldı. Bu sohbette ekli görsel erişilebilir değildi; yerel site/kaynaklar esas alındı.

StoreKit satın alma/geri yükleme, ürünler, fiyatlar, premium hak verme/yenileme, ödeme doğrulama ve üyelik uzlaştırma kaynakları değiştirilmedi. Mevcut satın alma sunucu testleri regresyon kontrolü olarak çalıştırıldı. Android projesine, kurulu yerel XenForo dosyalarına veya canlı sunucuya değişiklik yapılmadı. Testler gerçek satın alma, gerçek oturum iptali veya sohbet gönderimi yapmaz.

`project.yml` kaynak klasörlerini otomatik kapsadığı için yeni Swift dosyaları zaten hedefe dahildir. iOS 17 hedefi, 1.0.8/41 sürüm değerleri, HTTPS üretim ayarları, entitlements, StoreKit konfigürasyonu ve privacy manifest aynı kaldı. Yeni izleme/SDK/izin/veri kategorisi yoktur. API, gizlilik envanteri, parity ve App Store taslakları güncellendi.

## Çalıştırılan kontroller

Kanıt dizini: `artifacts/stability-20261012/`.

| Kontrol | Sonuç / kapsam |
|---|---|
| `Scripts/swift-test-windows.ps1` | 346 XCTest geçti; Swift 6.3.3 Windows. İlk koşudaki eski hesaptan gecikmiş hata testi düzeltilerek üç ek regresyon eklendi; son koşuda hata yok. |
| `Scripts/swift-test-windows.ps1 -Clean -Release` | Temiz Release derlemesi ve 346 XCTest geçti; `swift-core-release.log`. Native iOS derlemesi değildir. |
| `Scripts/reader-transfer-test-windows.ps1` | Gerçek transfer koduyla 11 XCTest geçti. Test transport enjeksiyonu ve yalnızca Windows kopyasında FoundationNetworking/file-protection uyumluluk tanımları kullanır. |
| `Scripts/chat-state-test-windows.ps1` | Gerçek ChatModel ile 13 XCTest geçti; test-only Combine saklama sarmalayıcısı Apple yayınlama/UI davranışını doğrulamaz. |
| `Scripts/validate-workspace.ps1` | Geçti: kaynak/config, JSON/plist, PHP syntax, gizli bilgi taraması ve statik erişilebilirlik denetimi. |
| `Scripts/build-ios-api-addon.ps1 -CreateZip -OutputDirectory artifacts/stability-20261012/server-package` | Geçti: API route sözleşmesi, PHP lint, chat/session/reader/account/privacy/APNs testleri ve mevcut App Store crypto/ledger/ownership/membership testleri. |
| `Scripts/mobileapi-release-audit.ps1 -AddonZip artifacts/stability-20261012/server-package/Ekitapligim-IosApi.zip` | IosApi 1.0.33 / 1000033, 135 dosya; geçti. |
| `Tests/Backend/ReaderDriveSourceTest.php` | Gerçek kurulu `ExternalEbook.php` validator yolu verilerek geçti. İlk toplu çalıştırmada gerekli yol verilmediği için kullanım hatası alınmıştı. Veritabanına bağlanmaz. |
| `Tests/Integration/ChatReactionSyncTest.php` + `ChatRouteTest.php` | 27 + 53 kontrol geçti; gerçek XF sınıfları, bellek içi depolama, sıfır ağ isteği/veritabanı bağlantısı. |
| `Scripts/appstore-entitlement-policy-test.php` | Mevcut beş aktivasyon ve süre dolumu senaryosu geçti. |
| `swiftc -frontend -parse -D DEBUG` | Değişen/yeni 23 native Swift dosyası sözdizimi denetiminden geçti; iOS typecheck/derleme değildir. |
| `git diff --check` | Geçti. |

Bağımsız kod incelemeleri: oturum/reader değişikliklerinde ek engelleyici bulgu yok. IosApi MobileSession, ad alanı dışında Android referansıyla aynı; hash-only saklama ve sınırlı tekrar kuralları kontrol edildi. Bellek içi PHP testleri gerçek MySQL kilit eşzamanlılığını kanıtlamaz.

## Hazırlanan sunucu paketi

`artifacts/stability-20261012/server-package/Ekitapligim-IosApi.zip`

- Sürüm: 1.0.33 / 1000033.
- SHA-256: `33714ADABDF6B916D57CA2F6AC58CDE9BC0B149BD7564911C0661B5298E353B7`.
- MobileApi minimum bağımlılığı 1.0.145 olarak kaldı; `/mobile-api/v1/` değiştirilmez.
- Paket bu çalışma sırasında sunucuya kurulmadı. Staging kontrolünden sonra normal XenForo yükseltme akışı kullanılmalı; önceki paket/sunucu yedeği tutulmalı.
- Sohbetin yeni premium/duyuru alanları için sunucu güncellemesi gerekir. Native görünüm ve reader retry için yeni iOS derlemesi gerekir. Kayıp refresh yanıtı kurtarma, public auth yolunda kurulu MobileApi servisinin bu özelliği taşımasına bağlıdır; IosApi upgrade tek başına yeterli değildir.

## Kalan doğrulamalar

### 1.0.32 kullanan eski uygulama uyumluluğu — ek kontrol

Kullanıcı kurulu sunucu sürümünü 1.0.32 olarak doğruladı. Hazırlanan ZIP, 1.0.32 kaynağıyla karşılaştırıldı: 135 dosyanın 131'i aynı; yalnızca `addon.json`, README, `ChatSerializer.php` ve `MobileSession.php` farklı. Giriş, okuyucu, satın alma/geri yükleme controller'ları, ürün/hak mantığı, yollar ve Setup değişmemiştir. 1.0.33 yükseltmesinde oturumları topluca silen yeni bir migration yoktur.

`Scripts/legacy-client-compatibility-test-windows.ps1` çalıştırıldı ve geçti. 1.0.32'nin gerçek servis koduyla üretilen sentetik oturum, yeni servisle geçerli kaldı; erişim süresi dolunca aynı kullanıcı için yenilendi. Önceki 1.0.8 uygulamasının gerçek Core kodu ayrı bir pakette derlendi; yeni sunucunun ürettiği normal/premium mesajlar, alıntılı yanıt, tam duyuru metni ve mesaj sayfası için **4 XCTest geçti**. Yeni JSON alanları eski uygulamada yok sayılır, mevcut metin/kimlik alanları korunur. Kanıt: `artifacts/stability-20261012/legacy-client-compatibility.log`.

Bu kontroller, güncellemeyi zorunlu kılan bir sözleşme değişikliği göstermedi. Yeni native kapak/premium görünümü ve istemcinin oturum/reader düzeltmeleri eski uygulamaya sunucu kurulumu yoluyla aktarılmaz. Gerçek eski iOS binary'siyle HTTPS staging üzerinde giriş, okuma ve satın alma testi henüz çalıştırılmadığından bütün işlevler için canlı ortam garantisi verilmez.

Bu Windows bilgisayarda Xcode/XcodeGen yok. Native clean/Production build, gerçek Keychain testleri, iPhone/iPad UI testleri, VoiceOver/Dynamic Type görsel kontrolü çalıştırılamadı. `KeychainSessionPersistenceTests`, `SessionInvalidationTests` ve yeni premium sohbet UI testleri kaynakta hazırdır; çalıştırılmış sayılmaz.

Yayın öncesi, mevcut imzalı uygulamanın üstüne güncelleme kurarak oturumun korunduğu, bir saatlik token süresi sonrası okumanın devam ettiği, kesilen yenilemenin kısa sürede toparlandığı ve gerçek çıkış/hesap değişiminin korunduğu doğrulanmalı. Public HTTPS staging üzerinde iki hesapla sohbet profil hedefleri, premium görünümü, okuyucu izinleri ve değişmemiş satın alma/geri yükleme akışı kontrol edilmeli. 120 saniyelik kurtarma penceresi dışındaki kayıp yenileme veya gerçekten iptal edilmiş/süresi dolmuş oturum yeniden giriş gerektirebilir.

Bu rapor App Store hazır oluşu veya canlıya alınmış düzeltme iddiası değildir.
