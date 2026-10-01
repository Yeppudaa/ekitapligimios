# Satın alma, geri yükleme ve mobil API incelemesi

Tarih: 1 Ekim 2026. İncelenen çalışma alanı: Ekitapligim iOS / EkitapligimCore / IosApi. Başlangıçta mevcut kullanıcı değişiklikleri korundu. Son kontrolde üretim AdminCP IosApi 1.0.29 ve MobileApi 1.0.148 gösterdi; uygulama kaynak düzeltmeleri henüz yeni bir iOS derlemesine dönüşmedi.

Son canlı kontrollerde oturumlu `prepare_purchase=1` geçerli hesap UUID'si döndürdü. Okunabilir kitap için reader session ve uygulamanın kullandığı `/ios-api/v1/books/37949/reader/source?t=...` kaynağı HTTP 200, `application/pdf` ve `%PDF-` başlığı döndürdü. Oturumun `source_url` alanı web sayfasıdır; native istemci `api_source_url` alanı `/api/` rotasında olduğunda kendi iOS API kaynak rotasını kurar. App Store Connect'te bundle-prefixed aylık ürün Approved, sürüm 1.0.6 build 39 Ready for Distribution görünüyor. Bu yerel düzeltmeler build 39'da bulunmuyor; aday uygulama sürümü 1.0.7'dir. Üretimdeki tüm PHP dosyalarının paket hash'iyle aynı olduğu henüz kanıtlanmadı.

## Sonuç ve kapsam

Satın alma/geri yükleme zincirindeki hesap karışması, tamamlanmamış işlem, bildirim sıralaması, üyelik teslimi, eski makbuzla geri ödeme durumunun bozulması ve süre hesabı sorunları için kaynak düzeltmeleri ve regresyon testleri eklendi. Mobil API'nin çerez/bearer ayrımı, hesap silme tekrarı, log gizliliği ve özel mesaj bildirim önizlemeleri de düzeltildi.

Bu çalışma **App Store'a hazır veya tamamen sorunsuz olduğuna dair onay değildir**. Windows üzerinde çekirdek Swift ve PHP/SQL testleri çalıştırıldı; iOS uygulamasının Xcode derlemesi, StoreKitTest, gerçek Apple Sandbox/TestFlight ödemeleri ve cihaz erişilebilirlik kontrolleri burada çalıştırılamadı. Aşağıdaki açık yayın koşulları kapanmadan ödeme akışı için üretim onayı verilmemelidir.

Genel uygulama kapsamı; mevcut çekirdek testlerinin istek/yanıt, token yenileme ve hesap geçişi, okuma ilerlemesi, indirme, bağlantı yönlendirmesi, silme ve hata eşleme kontrollerini; kaynak/erişilebilirlik/gizli bilgi taramalarını; canlı HTTPS API smoke kontrollerini içerir. Her ekranın gerçek cihazda ve her paylaşılan MobileApi işlevinin tam XenForo ortamında uçtan uca denetlendiği iddia edilmez. Önceki açık cihaz kontrolleri [GENERAL_APP_REVIEW.md](GENERAL_APP_REVIEW.md) ve [READER_EXPERIENCE_VALIDATION.md](READER_EXPERIENCE_VALIDATION.md) içinde geçerliliğini korur.

## Düzeltilen bulgular

| Öncelik | Sorun | Uygulanan düzeltme |
|---|---|---|
| Yüksek | Apple ödemesi tamamlanıp ilk sunucu doğrulaması gelmeden başka uygulama hesabına geçilmesi | Ödeme ekranından önce sunucuda kullanıcı ID'sine bağlı kalıcı rastgele UUID hazırlanıyor. StoreKit satın alımı bu `appAccountToken` ile başlatılıyor; Apple imzalı işlemdeki UUID sunucuda kontrol ediliyor. Bildirim istemciden önce gelirse doğru hesaba teslim edilebiliyor. |
| Yüksek | Askıda kalan doğrulamanın çıkıştan sonra yeni oturumu güncellemesi | Hesap nesli kontrolü, yakalanmış `account_name`, oturum değişiminde gözlemci/yeniden deneme iptali ve gecikmiş yanıtların yok sayılması. |
| Yüksek | Sunucu hatasına rağmen işlemin bitirilmesi veya tekrar denenmemesi | `finish()` başarılı kalıcı sunucu işlemesinden sonra çağrılıyor. Tamamlanmamış işlemler açılışta/ön plana gelişte taranıyor; süreç içinde sınırlı yeniden deneme uygulanıyor. Kesin süresi dolmuş/iptal edilmiş işlemler erişim verilmeden tamamlanıyor. |
| Yüksek | Eski geri ödeme veya yenileme bildiriminin yeni üyeliği ezmesi | Her Apple transaction ID ayrı tutuluyor. İşlem ve yenileme bilgisi kendi `signedDate` değerleriyle birleştiriliyor. Eski aktif makbuz yeni geri ödeme durumunu geri çeviremiyor. |
| Yüksek | Aynı satın alımın birden fazla hesaba bağlanması | Original transaction zinciri için MySQL kilidi ve transaction; ilk gerçek kullanıcı sahipliği korunuyor. Yetim bildirimler misafir üyelik yetkisi vermiyor. |
| Yüksek | “Doğrulandı” yanıtından sonra XenForo Premium yetkisinin verilmemesi | Üyelik grubu eşitlemesi başarısızsa HTTP 503. İstemci/Apple tekrar deneyebiliyor. Var olan grup değişim anahtarları ve beş dakikalık yerel eşitleme korunuyor. |
| Yüksek | Veritabanı kesintisinde Apple bildiriminin kalıcı 400 ile reddedilmesi | İmza/payload hatası 400; kayıt/kilit/yetki teslimi hatası 503. Tekrarlanan bildirim kalıcı kayıtları çoğaltmıyor. |
| Yüksek | CSRF muaf mobil uçların web çereziyle yetkilendirilebilmesi | Hem IosApi sarmalayıcılarında hem paylaşılan MobileApi iOS rotalarında ziyaretçi önce misafir yapılıyor, sonra geçerli bearer uygulanıyor. iOS URLSession istekleri çerez işlemiyor. Android rotasının mevcut davranışı değiştirilmedi. |
| Orta | İptal edilen geri yüklemenin yükleme durumunda kalması, eşzamanlı ödeme/restore | İşlemler seri hale getirildi; iptal sonrası durum temizleniyor. StoreKit yerel doğrulanmış hakları önce deneniyor; sync hata verse de tekrar okunuyor. |
| Orta | Sunucu üyeliği kaldırdığı halde restore ekranının eski Premium'u tutması | Kesin olarak geri yüklenecek hak kalmadığında yerel hak temizleniyor. Geçici ağ hatası son doğrulanmış durumu silmiyor. Bir ürünün iptali diğer aktif ürünü silmiyor. |
| Orta | Süresi dolan yenilenmeyen satın alımların restore'u bozması | Mevcut StoreKit hakları içindeki bitmiş yenilenmeyen işlemler atlanıyor. Aylık/eski yıllık ürünlerde eksik sunucu bitiş tarihi ömür boyu üyelik sayılmıyor; önbellek bitiş tarihi kontrol ediliyor. |
| Orta | 31 Ocak + 3 ay gibi ay sonlarının sonraki aya taşması | Yenilenmeyen 3/6/12 aylık süreler takvim ayıyla, ay sonuna sabitlenerek hesaplanıyor; artık yıl testi eklendi. |
| Orta | Sertifika kontrolünün eski meşru makbuzu veya yanlış sertifika amacını hatalı değerlendirmesi | ES256/P-256, Apple kökü, üçlü zincir, App Store OID'leri ve imza anındaki sertifika geçerliliği kontrol ediliyor. `Both` yalnız Production/Sandbox kabul ediyor. |
| Orta | Hesap silme talebinin tekrarında yeniden açılmış oturumların kalması | Tekrarlanan talep oturumları tekrar iptal ediyor ve bekleyen Apple yetki iptalini yeniden deniyor; yeni talep/e-posta çoğaltmıyor. |
| Orta | Loglarda bearer/imzalı ödeme/özel mesaj değerleri; bildirim önizlemesinde özel bilgi | Tam değer maskelemesi ve app-account UUID alanları eklendi. Özel mesaj bildirimleri genel metin kullanıyor. Çıkışta APNs silme isteği bearer iptalinden önce yapılıyor; DeviceID gizlilik beyanı hesap bağlantısıyla uyumlu hale getirildi. |

## Sunucu sürümü ve paket

Çalışma alanındaki eski IosApi 1.0.24 kaynağı ile mevcut yerel sunucu kopyası/arşivi aynı değildi. `artifacts/IosApi-live-20261001.zip` IosApi **1.0.27**, MobileApi **1.0.145+** bağımlılığı içeriyordu. Arşivin SHA-256 değeri:

`C1E3C42342422D5C4ACC00BF29F7986AA0B9EB65E940AC4D6BEB15ADAEB04A37`

Bu arşivin grup eşitlemesi, cron'u ve reader preview metadata davranışı yeni kaynakta korundu. Arşivdeki yalnız otomatik yenilenen ürün politikası, mevcut beş ürün ve üç eski restore ID'siyle birleştirildi. XML rotaları anlamsal olarak karşılaştırıldı. Bu, uzak canlı sunucunun tüm dosyalarının arşivle birebir aynı olduğunu kanıtlamaz.

Son kontrolde aynı çalışma alanına ayrı bir okuyucu Drive kaynağı doğrulaması ve 1.0.29 sürümü eklendi. Bu değişiklik korunarak satın alma düzeltmelerini de içeren birleşik paket yeniden oluşturuldu. Önceki 1.0.28 arşivi ara test çıktısıdır; dağıtım için güncel paket aşağıdadır.

Güncel paket: [Ekitapligim-IosApi.zip](artifacts/purchase-audit-1.0.29/Ekitapligim-IosApi.zip), sürüm **1.0.29 / 1000029**, bağımlılıklar **XenForo 2.3.0+ / MobileApi 1.0.145+**. Paket 127 dosya, 116904 bayt.

SHA-256: `26E1794C999324A1D3A7862CEF380B5CC087D5D75A7F0CDB2FD47D2339ED8F5E`

Güncel [paket testleri](artifacts/audit-backend-build-final.log), [paket denetimi](artifacts/audit-package-final.log), [kaynak eşitliği](artifacts/audit-package-source.log), [MySQL testleri](artifacts/audit-mysql.log) ve [Drive kaynak testi](artifacts/audit-reader-drive.log) başarılıdır. Aşağıdaki 1.0.28 ifadeleri satın alma değişikliklerinin minimum sürümünü anlatır; staging kurulumu için tümünü içeren 1.0.29 kullanılmalıdır.

Mevcut entitlement tablosu korunuyor. Eklenen tablolar: filtrelenmiş imzalı durum için `xf_ekitapligim_ios_appstore_state`, kullanıcı–satın alma UUID eşlemesi için `xf_ekitapligim_ios_appstore_account`. Ham JWS ve ödeme ayrıntıları bu tablolara yazılmıyor. Hesap eşleme tablosu diğer satın alma tablolarıyla birlikte yedeklenmeli; kaybolan UUID eşlemesi başka kullanıcıya atanarak onarılmamalı.

**Sunucu paketi yeni uygulamadan önce kurulmalı.** Yeni uygulama `prepare_purchase=1` POST yanıtını almadan ödeme ekranını açmaz. Önceki uygulamaların tokensız makbuzları geriye uyumlu olarak ilk doğrulayan hesaba bağlanır; bu eski işlemlerde başlangıç hesabı geriye dönük ispatlanamaz. Aile paylaşımı/hesaplar arası devir tasarlanmış bir özellik değildir.

## Çalıştırılan kontroller

| Kontrol | Sonuç / kanıt |
|---|---|
| Swift çekirdek Debug | Önceki son turda 298 test geçti; [log](artifacts/audit-swift-final.log). UUID hazırlığı eklendikten sonraki güncel kanıt aşağıdaki temiz Release çalışmasıdır. |
| Swift çekirdek temiz Release | `swift-test-windows.ps1 -Clean -Release`: **301 XCTest testi geçti**; [log](artifacts/audit-swift-clean-release.log). Bu bir iOS uygulama derlemesi değildir. Log sonundaki “0 tests”, ayrıca çalışan boş Swift Testing koşucusudur; öncesindeki 301 XCTest sonucu geçerlidir. |
| PHP paket oluşturma | Sözdizimi, 72 Swift API rota şablonu, wrapper/işlem sözleşmeleri, reader, APNs ve satın alma testleri geçti; [log](artifacts/audit-backend-build.log). |
| İşlem sırası/sahiplik/geri ödeme/grace/veritabanı rollback | 18 senaryo + 7 ödeme öncesi UUID/hesap bağlama senaryosu SQLite adaptörü ve yerel MySQL geçici tablolarında geçti. |
| API controller kontrolleri | Hazırlık, auth, hesap/ürün/bundle/type/renewal eşleşmesi, 409/503, tekrar ve eski makbuz testi geçti. JWS payload'ları bu controller testlerinde taklit edilir; kriptografi ayrı test edilir. |
| Gerçek kriptografik fixture | 7 ES256/zincir/OID/kök/imza-tarihi kontrolü iki yerel PHP sürümünde geçti. Test CA'sı yalnız test subclass'ında kullanılır; üretim Apple kökü test imzasını reddeder. Bunlar Apple Sandbox makbuzu değildir. |
| XenForo üyelik eşitlemesi | 11 senaryo geçti. SQL gerçek yerel MySQL ile de çalıştı; XenForo kullanıcı/grup servisi test doubles kullanır. Gerçek forum izinlerinin teslimi staging koşuludur. |
| Bearer izolasyonu / silme / özel bildirim | 10 bearer, 6 silme, 4 özel alert türü + conversation job gizlilik senaryosu geçti. |
| Swift uygulama/test sözdizimi | 88 dosya parse edildi; [log](artifacts/audit-swift-app-parse.log). iOS SDK type checking yapılmadı. 7 yeni native StoreKit regresyon testi eklendi; mevcut satın alma testine UUID aktarımı kontrolü eklendi. **Çalıştırılmadılar.** |
| Kaynak, gizli bilgi, erişilebilirlik taraması | `validate-workspace.ps1 -Strict`; [log](artifacts/audit-workspace-final.log). Erişilebilirlik kontrolü statiktir. |
| App Store yapılandırma preflight | Placeholder izni olmadan geçti; [log](artifacts/audit-preflight.log). Mağaza hesabındaki ürünlerin onay/satış durumunu doğrulamaz. |
| Genel HTTPS/evrensel bağlantı | Canlı legal/destek/API/AASA kontrolü geçti; [log](artifacts/audit-public-release.log). |
| Mevcut canlı API smoke | Katalog, forum, profil, kütüphane, abonelik, bildirim sayısı, konuşma ve yetkisiz yazma kontrolleri geçti; [log](artifacts/audit-api-smoke.log). Script oturum açma, koşul kabulü, presence/ziyaret gibi sınırlı yazmalar içerir; satın alma, hesap silme veya yeni içerik gönderimi yapılmadı. Yeni 1.0.28 kodu bu sunucuda test edilmiş sayılmaz. |
| Canlı billing negatif kontrol | Yetkisiz verify 401, bozuk bildirim JWS 400; [log](artifacts/audit-billing-public.log). Gerçek ödeme doğrulaması değildir. |

Yerel MySQL çalışması `C:/xampp/php/php.exe` ile `APPSTORE_TEST_MYSQL_CONFIG` kullanarak yapıldı. Harness yalnız loopback kabul eder ve bağlantıya özel **TEMPORARY** tablolar oluşturur; gerçek XenForo kullanıcı/ödeme satırları değiştirilmez. Kimlik bilgileri çıktıya yazılmadı. Aynı anda iki gerçek istemciyle yarış testi ve tam XenForo upgrade işlemi bu izole SQL testlerinin kapsamında değildir.

## Yayından önce kapatılacak koşullar

1. **Xcode / cihaz:** Güncel kaynakla clean iOS Production build, iPhone/iPad native unit/UI/StoreKitTest, VoiceOver/large text/landscape kontrolleri. Repodaki macOS CI adımları hazırdır; bu oturumda uzak CI başlatılmadı. Windows Release sonucu bunların yerine geçmez.
2. **Staging upgrade:** MobileApi 1.0.145+ ve yedeklenmiş 1.0.27 verisi üzerinde 1.0.28 kurulumunu çalıştır; yeni tabloları, mevcut sahipleri, `appStoreEntitlement-*` grup değişimlerini ve beş dakikalık cron'u doğrula. Ortak Premium grup ayarı `ekGooglePlayPremiumGroupId` adıyla kalır; bu yalnız ortak grup ayarıdır. Cron geçmişteki Apple olaylarını indirmez.
3. **Gerçek Apple ödeme matrisi:** Beş güncel ürünün satın alımı; üç eski ID'nin restore'u; aynı/ikinci cihaz ve yeniden kurulum; ödeme sonrası internet kesme/uygulamayı kapatma; ödeme penceresi açıkken hesap değiştirme; yanlış hesapta restore; Ask to Buy onayı; iptal; grace/billing retry; süre sonu; refund ve refund reversal; gecikmiş/tekrarlanan bildirim; veritabanı/üyelik servisinin geçici hatası. UUID'nin gerçek Apple JWS'inde taşındığını ve ücret alınıp erişim verilmeyen ara durumda yeniden denemenin tamamlandığını gösteren kanıt tutulmalı.
4. **App Store Connect:** Ürün türleri/ID'leri, satış bölgeleri, sözleşmeler, fiyatlar, build ile ürün ilişkisi ve Production/Sandbox bildirim adresleri kontrol edilmeli. StoreKit yerel dosyası mağaza onayının kanıtı değildir. Yerel Xcode imzaları gerçek sunucuda kabul edilmemeli.
5. **Kayıp bildirim ve eski veri:** Bildirim adresinin erişilebilirliği ve Apple tekrarları doğrulanmalı; kayıp Apple bildirim geçmişini geri alma/uzlaştırma prosedürü oluşturulmalı. Mevcut kod App Store Server API history/status indirmez ve çevrimiçi sertifika iptal kontrolü yapmaz. İmzalı geçmiş olmayan eski pasif kayıtlar eski makbuzla canlandırılmaz; meşru düzeltmede yeni Apple kanıtı gerekir. Geçmişte başka hesaba yanlış bağlanmış satırlar otomatik devredilmez.
6. **Gizlilik/silme:** Satın alma sahipliği ve UUID, APNs ve AI kayıtlarının gerçek hesap silme/retention prosedürü doğrulanmalı. Çevrimdışı çıkış veya bitmiş bearer ile push token silme isteğinin sunucuda tamamlanacağı garanti edilemez; hesap değişimi/silme senaryosunda eski hesaptan bildirim kalmadığı cihazda gösterilmeli. APNs DeviceID ve hesap bağlantısı için mağaza gizlilik yanıtları manifestle eşleştirilmeli.

Yalnız bu koşullar tamamlandıktan sonra aynı hash'e sahip sunucu paketi ve doğrulanmış iOS build'i birlikte yayına alınmalı. Üretim AdminCP'nin 1.0.29 göstermesi kurulum kanıtıdır; dosya eşitliği, gerçek Apple işlemi ve yeni iOS derlemesi ayrıca doğrulanmalıdır.

## Başlıca kaynaklar

- Uygulama: [StoreKitPurchaseService](App/Ekitapligim/Purchases/StoreKitPurchaseService.swift), [satın alma politikası](Sources/EkitapligimCore/PurchaseVerificationPolicy.swift), [API sözleşmesi](API_DOCUMENTATION.md).
- Sunucu: [işlem deposu ve hesap UUID'leri](Backend/IosApi-addon/Service/AppStoreTransactionStore.php), [doğrulama](Backend/IosApi-addon/Api/Controller/AppStoreVerify.php), [bildirimler](Backend/IosApi-addon/Api/Controller/AppStoreNotifications.php), [üyelik eşitlemesi](Backend/IosApi-addon/Service/IosMembershipSynchronizer.php).
- Apple: [appAccountToken](https://developer.apple.com/documentation/storekit/product/purchaseoption/appaccounttoken(_:)), [currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [unfinished](https://developer.apple.com/documentation/storekit/transaction/unfinished), [finish](https://developer.apple.com/documentation/storekit/transaction/finish()). StoreKit hakları ve tamamlanmamış işlem davranışı bu sözleşmelerle karşılaştırıldı.
- Apple'ın [resmî server-library imza doğrulayıcısı](https://github.com/apple/app-store-server-library-python/blob/main/appstoreserverlibrary/signed_data_verifier.py), zincir/OID/imza zamanı kontrolleri için referans olarak incelendi; PHP uygulamasının bu kütüphane ile tam eşdeğerliği iddia edilmez.
