# Satın alma ve cihaz anahtarı düzeltmeleri — 12 Ekim 2026

Sunucu paketi: IosApi 1.0.35 (`artifacts/purchase-fix-20261012/server-package/Ekitapligim-IosApi.zip`). Üretime kurulmadı. Native uygulama henüz gönderilmedi.

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

Native StoreKitTest testleri eklendi; Windows üzerinde Xcode çalıştırılamaz. iPhone/iPad temiz/Production derleme, unit/UI testleri ve HTTPS staging/Sandbox üzerinde eski kurulu uygulamayla satın alma/geri yükleme yapılmadan tüm satın alma akışları için sorunsuzluk garantisi verilemez.

`codex/purchase-device-safety-20261012` doğrulama dalı oluşturuldu. İlk aktarım denetimi sonrasında kullanıcı açıkça aynı GitHub deposu/dalına gönderimi onayladı; push tamamlandı. Bu dal Codemagic'in App Store/TestFlight yükleme dalı eşlemesine dahil değildir.

CI #162: kaynak denetimi ve backend/reader sözleşmeleri geçti; native işler Readium 3.9.0 etiketi uzak Git deposunda bulunamadığından testlere ulaşmadan durdu. Resmî 3.9.0 sürüm sayfasındaki imzalı `de07026e9f825a5791f27a7ac4cd6bb1a784ab8d` commit'i GitHub API ile doğrulandı (`3.9.0 (#795)`, 12 Mayıs 2026). `project.yml` aynı sürümün bu değişmez commit'ine sabitlendi, CI çözümleme kontrolü tam SHA'yı doğrular. Kitap okuyucu farklı sürüme yükseltilmedi. Kaynak: https://github.com/readium/swift-toolkit/releases/tag/3.9.0 .

Canlı App Store Connect'te aylık v2 seviye 2, eski yıllık v2 seviye 3 olarak gözlendi. Aynı haklara rağmen seviye farklılığı sürüyor. Bu oturumda fiyat veya canlı ürün ayarı kaydedilmedi. Bu yapılandırma ve gerçek plan geçişi ayrıca doğrulanmalıdır. Apple bildirim geçmişinden otomatik toparlama eksikliği önceki incelemedeki sınır olarak devam eder; bu değişiklikte genişletilmedi.

Kurulum: mevcut dosya/veritabanı yedeği alındıktan sonra XenForo eklenti yükseltmesiyle aynı ZIP HTTPS staging'e kurulmalı; kontroller geçince aynı paket üretime alınmalıdır. Daha eski pakete düşürmek yeni devredilmiş süre hesabını geri alabilir; sorun halinde dosyaları rastgele düşürmek yerine bu sürümün kayıtlarıyla incelenmelidir.
