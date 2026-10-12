# Satın alma ve cihaz anahtarı düzeltmeleri — 12 Ekim 2026

Sunucu paketi: IosApi 1.0.35 (`artifacts/purchase-fix-20261012/server-package/Ekitapligim-IosApi.zip`). 12 Ekim'de canlı XenForo kurulum-tamamlandı sayfası (batch 539) başarılı 1.0.35 kurulumunu gösterdi; kullanıcı da kurulumu doğruladı. Native 1.0.9/build 42 Codemagic 53 ile TestFlight'a yüklendi; mevcut test grubuna bağlı, Waiting for Review. Kullanıcının son talebiyle önce TestFlight testi yapılacak; public App Store incelemesine gönderilmedi. CI #167 exact release source `3ebafec` için tamamen başarılı. Fiziksel eski uygulama/Sandbox satın alma matrisi hâlâ ayrıca yapılmalıdır.

## Düzeltilen davranışlar

- Üç/altı/on iki aylık doğrulanmış App Store paketlerinde kalan süre korunur. Tekrar gönderilen aynı işlem süreyi ikinci kez eklemez. İade, geri yükleme, sıra dışı bildirim sırası, ayrı hesaplar ve Sandbox/Production ayrımı test edilir. Apple aboneliklerinin kendi bitiş tarihleri değişmez.
- Yeni native istemci ödeme açılmadan önce mevcut yenilenen abonelik için açıklama gösterir; ömür boyu üyelik etkinse gereksiz ek ödemeyi engeller. Ömür boyu hak süreli bir bitiş tarihiyle gösterilmez. Ürün kimlikleri, fiyatlar, imza doğrulaması ve sahiplik denetimi korunur.
- `MeDeviceToken` POST/DELETE, boş anahtarda XenForo `apiError` üçüncü parametresine tamsayı veriyordu. İki çağrı da `null, 400` olarak düzeltildi. Ek neden: eski uygulama `application/x-www-form-urlencoded; charset=utf-8` gönderirken yerel XenForo `Request.php:1039` yalnız tam MIME eşleşmesinde DELETE gövdesini ayrıştırıyor. Controller artık yalnız form MIME türünde, en fazla 8192 baytlık gövdeden metin anahtarı okuyabiliyor. Boş/dizi/uygunsuz MIME istekleri HTTP 400 üretir; geçerli kayıt/silme ve kullanıcı sınırı korunur. Bu hata satın alma hatası değildir. Canlı hata logunda ham gövde bulunmadığından o tek isteğin içeriği kesinleştirilemez.

## Geriye uyumluluk

Önce sunucu paketi kurulmalıdır. Eski uygulamaların satın alma/geri yükleme yolu ve yanıt alanlarının türleri korunur. Yeni hazırlık bayrakları isteğe bağlıdır; eski uygulamalar bunları yok sayabilir. Önceden ödenmiş işlem, başka premium hakkı olduğu gerekçesiyle reddedilmez. Cihaz anahtarı düzeltmesi de sunucudadır.

Süre düzeltmesi bir işlem doğrulaması/bildirimi sırasında aynı hesabın doğrulanmış geçmişinden hesaplanır; kurulurken bütün canlı hesapları değiştiren toplu geçiş yoktur. Önceden var olan ve imzalı geçmişi bulunmayan kayıtlar korunur. Sunucu güncellemesi eski uygulamaya yeni uyarı ekranı ekleyemez; yenilenen Apple aboneliğini kullanıcı Apple üzerinden yönetir.

## Çalıştırılan kontroller

- Swift Core: 353 XCTest geçti (`artifacts/purchase-fix-20261012/swift-core.log`).
- Paket oluşturma: PHP söz dizimi, imza/sertifika, controller, işlem defteri, üyelik eşitleme, süre devri ve eski istek sözleşmesi dahil testler geçti (`package-build.log`).
- MySQL: gerçek üye tablolarına yazmadan, yalnız bağlantıya özel TEMPORARY tablolarla süre devri ve eski satın alma controller sözleşmeleri geçti (`mysql-terms.log`, `mysql-legacy.log`). SQLite kontrolleri de geçti.
- Cihaz anahtarı testi: boş/boşluk POST ve DELETE, geçerli kayıt, kullanıcıya sınırlı silme ve yetkisiz istek geçti (`Tests/Backend/MeDeviceTokenTest.php`).
- Çalışma alanı doğrulaması, statik erişilebilirlik ve sır taraması geçti (`workspace-validation.log`).
- Değişen 26 native Swift dosyası sözdizimi ayrıştırmasından geçti (`native-syntax.log`); bu typecheck, build veya StoreKitTest değildir. İlk sandbox denemesi derleyici çalıştırma hatası verdi; izinli tekrar geçti.
- 1.0.4, 1.0.5, 1.0.6, 1.0.7 ve 1.0.8 eski istemci kaynaklarının her birinde altı uyumluluk testi geçti. Testler gerçek Git kaynaklarından derlenir; yeni controller tarafından üretilmiş süreli/ömür boyu satın alma yanıtlarını ve ek alanları okur. `client-*.log` dosyalarının son satırı ilgili sürüm sonucudur. Bu, telefonda kurulu eski binary testi değildir.

## Yayın için kalan doğrulama

Native StoreKitTest testleri CI üzerinde çalıştırıldı. CI #166'da iPhone ve iPad'in her birinde 114 native unit testi (20 satın alma testi ve gerçek Keychain testi dahil), 26 UI testi ve 353 Core testi geçti. Temiz Production derleme ve Google Sign-In plist kontrolü de geçti. HTTPS staging/Sandbox üzerinde eski kurulu uygulamayla satın alma/geri yükleme ve gerçek plan geçişi henüz yapılmadığından tüm canlı akışlar için sorunsuzluk garantisi verilemez.

`codex/purchase-device-safety-20261012` doğrulama dalı oluşturuldu. İlk aktarım denetimi sonrasında kullanıcı açıkça aynı GitHub deposu/dalına gönderimi onayladı; push tamamlandı. Bu dal Codemagic'in App Store/TestFlight yükleme dalı eşlemesine dahil değildir.

CI #162: kaynak denetimi ve backend/reader sözleşmeleri geçti; native işler Readium 3.9.0 etiketi uzak Git deposunda bulunamadığından testlere ulaşmadan durdu. Resmî 3.9.0 sürüm sayfasındaki imzalı `de07026e9f825a5791f27a7ac4cd6bb1a784ab8d` commit'i GitHub API ile doğrulandı (`3.9.0 (#795)`, 12 Mayıs 2026). `project.yml` aynı sürümün bu değişmez commit'ine sabitlendi, CI çözümleme kontrolü tam SHA'yı doğrular. Kitap okuyucu farklı sürüme yükseltilmedi. Kaynak: https://github.com/readium/swift-toolkit/releases/tag/3.9.0 .

CI #163: Readium SHA kontrolü, 353 Core testi, backend/source kontrolleri ve iki cihazın ekran testleri geçti. iPhone'da 20 `PremiumPurchaseTests` ve 26 UI testi geçti. 114 native testte yalnız yeni Keychain kalıcılık testi iki hata bildirdi: imzasız simülatör hostunda `SecItemAdd`/okuma `-34018` (eksik entitlement). Test atlanmadı; yalnız CI iPhone/iPad test komutları ad-hoc simülatör imzası ve `Scripts/ci-simulator.entitlements` ile çalışacak şekilde düzeltildi. Üretim imzası, Keychain grubu ve entitlement dosyası değiştirilmedi. Tekrar CI sonucu ayrıca kaydedilmelidir. Kaynak: https://developer.apple.com/documentation/security/errsecmissingentitlement .

CI #164'te göreli entitlement yolu paket hedeflerinin klasörüne göre çözüldü ve dosya bulunamadı. Yol mutlak çalışma alanı yoluna düzeltildi. CI #165'te her iki cihazda 114 native test (20 satın alma testi ve gerçek Keychain testi dahil) geçti. iPhone'da 26 UI testi geçti. iPad UI auditinde yalnız `checkmark.shield.fill` dekoratif ikonunun teknik erişilebilirlik adı hata verdi; yanındaki durum metni aynı anlamı sunduğundan iki dekoratif durum ikonu VoiceOver'dan gizlendi. Audit/test atlanmadı.

Son doğrulamada iPhone ve iPad aynı tam test kapsamını ayrı CI işleriyle çalıştırır; biri başarısız olursa diğeri iptal edilmez. Production temiz derleme iPhone işinde bir kez çalışır. Bu, iki platformun seri test süresinin 45 dakikalık iş sınırını tüketmesini önler; test sayısı/kapsamı azaltılmaz. Artefaktlar cihaz adıyla ayrı kaydedilir.

CI #166 tamamı başarılı: https://github.com/Yeppudaa/ekitapligimios/actions/runs/38286777279 . Test edilen native kaynak commit'i `cfbcc62`; sonuç ve loglar `artifacts/purchase-fix-20261012/ci-166-*` dosyalarında. Ekran yakalama işi başarılı olsa da geliştirme ortamındaki boş/hata ekranları App Store görselleri olarak yayımlanmadı.

12 Ekim 2026'da kullanıcı Apple girişini tamamladıktan sonra canlı App Store Connect abonelik grubu 22334120'de aylık v2 (6805877014) seviye 2'den ve yıllık v2 (6805880467) seviye 3'ten aynı seviye 1'e alındı. Kaydedilmiş tabloda ikisi de seviye 1 / Approved olarak doğrulandı; eski Developer Rejected ürünler seviye 1'de kaldı. Bu, yerel StoreKit dosyasındaki aynı Premium haklarıyla uyumludur. Fiyat, ürün kimliği, satış durumu ve mevcut kullanıcı üyelikleri düzenlenmedi. Kanıt: `artifacts/purchase-fix-20261012/apple-subscription-levels.jpg`. Gerçek Sandbox plan geçişi ayrıca doğrulanmalıdır. Apple bildirim geçmişinden otomatik toparlama eksikliği önceki incelemedeki sınır olarak devam eder; bu değişiklikte genişletilmedi.

Kurulum: mevcut dosya/veritabanı yedeği alındıktan sonra XenForo eklenti yükseltmesiyle aynı ZIP HTTPS staging'e kurulmalı; kontroller geçince aynı paket üretime alınmalıdır. Daha eski pakete düşürmek yeni devredilmiş süre hesabını geri alabilir; sorun halinde dosyaları rastgele düşürmek yerine bu sürümün kayıtlarıyla incelenmelidir.
