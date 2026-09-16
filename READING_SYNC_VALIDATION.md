# Okuma konumu düzeltmesi — 6 Eylül 2026

## Uygulanan değişiklik

PDF sayfası ve EPUB CFI konumu, siteyle aynı `xf_codex_book_reader_progress` kaydından okunur. Okuyucu başlamadan önce güncel konum alınır; ilk yüklemenin geçici sayfa/konum olayları kaydedilmez. Ana sayfa ve profil aynı kütüphane durumunu kullanır; EPUB kartı yanıltıcı bir PDF sayfa numarası göstermez.

Konum değişiklikleri hesaba özel, korumalı ve yedekleme dışı yerel dosyaya hemen yazılır. İstekler sırayla gönderilir; ağ geri geldiğinde, uygulamaya dönüldüğünde ve okuyucudan çıkışta yeniden denenir. Arka plana geçişte son EPUB metin konumu da alınır. Sunucu revizyonu değişmişse eski bekleyen kayıt sunucu kaydını ezmez. Raf/favori işlemleri okuma konumunu değiştirmez.

Readium 3.9.0 ve mevcut native okuyucular korunmuştur. EPUB köprüsü yalnızca Readium içindeki kitap DOM'una erişir; site sarmalayıcısı eklenmemiştir. Android MobileApi kaynakları, satın alma ve abonelik akışları değiştirilmemiştir.

## Çalıştırılan kontroller

| Kontrol | Sonuç |
|---|---|
| `Scripts/swift-test-windows.ps1` | 211 XCTest testi geçti. Sayfa 25 → 40 → 12, diskten geri yükleme, hesap izolasyonu/silme, eski yanıtlar, kayıp HTTP onayı ve çatışmalar dahil. |
| `php Tests/Backend/ReaderProgressTest.php` | Ortak kayda yazma/okuma, aynı saniyedeki değişiklik çatışması, geri okuma, hata/rollback ve EPUB CFI testleri geçti. |
| `php Tests/Backend/ReaderProgressControllerTest.php` | Oturum/izin kontrolleri, yanlış hesap adına gönderim, rafsız kitapların dahil edilmesi ve raf işlemlerinin ilerlemeye dokunmaması geçti. |
| `Tests/Reader/EPUBCFIBridgeTests.cjs` | EPUB.js 0.3.93 ile iki yönlü DOM/CFI uyumluluğu, Türkçe, emoji ve biçimlendirilmiş metin testleri geçti. Readium 3.9.0 domRange alanını kaydırmada dikkate almadığından köprü, CFI karakter aralığının geometrisini Readium scrollToPosition işlevine verir; metni değiştirmez. Bu davranış da test edildi. jsdom geometriyi taklit eder; gerçek ekran düzeni doğrulaması değildir. |
| `Scripts/validate-workspace.ps1` | Kaynak, JSON/XML/plist, rota, statik erişilebilirlik, gizli bilgi taraması ve PHP sözdizimi kontrolleri geçti. |
| Swift frontend parse | Değişen native okuyucu/servis dosyaları ve PDF testleri sözdizimi kontrolünden geçti; iOS tür denetimi/derlemesi yerine geçmez. |
| `Scripts/build-ios-api-addon.ps1 -CreateZip -OutputDirectory release-archive/reading-sync-1.0.24` | IosApi 1.0.24 paketi oluşturuldu; rota ve PHP kontrolleri geçti. |
| Başlangıç dosya hash'leri | İzlenen 8 satın alma/StoreKit/App Store dosyası aynı kaldı. Önceden mevcut değişiklikler korunmuştur. |
| `git diff --check` | Geçti. |

Test günlükleri: `.codex-temp/reading-sync-start/`. Yeni native PDF geri yükleme ve Readium EPUB fixture testleri iPhone/iPad CI test hedefine dahil edildi; PHP/EPUB.js kontrolleri ayrıca CI'a bağlandı.

## Paket ve gerekli son doğrulama

### “Okumaya devam et” sonrası 1. sayfa bildirimi için ek düzeltme

PDFKit geri yüklemesi daha önce pencereye eklenmemiş/sıfır boyutlu PDF görünümünde çalışabiliyor ve gerçek `currentPage` doğrulanmadan tamamlanmış sayılıyordu. `ResumePDFView` artık pencereye bağlanma ve yerleşim olaylarını koordinatöre bildirir. Koordinatör, geçerli ekran boyutunda kayıtlı sayfaya gider ve PDFKit'in gerçekten o sayfayı gösterdiğini doğrulamadan konum kaydını açmaz. Eksik/geçersiz `currentPage`, 1. sayfa kabul edilmez; kapatılan okuyucunun bekleyen geri yüklemesi iptal edilir. Sonraki yerleşimler kullanıcıyı başlangıç konumuna döndürmez.

Native PDF testleri gerçek `currentPage` kontrolüyle güçlendirildi: geç pencereye bağlanma, sıfır boyuttan görünür boyuta geçiş, sürekli/sayfalı okuma, 25 → 40 → 12, gerçek sayfa sayısına sınırlama, başarısız gezinme ve hemen kapatma. Bu 6 native test Windows'ta **çalıştırılamadı**; macOS/iOS doğrulaması halen gereklidir.

Ek düzeltme sonrasında Swift frontend parse, workspace kaynak kontrolleri ve `git diff --check` geçti; izlenen 8 satın alma dosyasının hash'i değişmedi. İlk çekirdek test denemesi, çalışma alanındaki diğer devam eden değişikliklerde eksik `AIL10n` yüzünden derlenemedi. İlgili dosya çalışma alanına eklendikten sonra tekrar çalıştırılan **211 çekirdek test geçti** (`swift-tests-resume-verified.log`). Windows test betiği ayrıca derleyici hata kodunu denetleyecek şekilde düzeltildi; derlenemeyen bir test koşusu artık başarılı sayılmaz. Günlükler yine `.codex-temp/reading-sync-start/` altındadır.

Bu ek değişiklik uygulama kaynaklarındadır; aşağıdaki backend ZIP'inin içeriğini değiştirmez. Cihazdaki kurulu uygulamaya veya sunucuya bu oturumda dağıtım yapılmadı.

Paket: `release-archive/reading-sync-1.0.24/Ekitapligim-IosApi.zip`

SHA-256: `8BB54BC2FECD94C083B5EB68E550B20711D59E868E503B1341504090DDB57C0C`

**Canlı sorunun tamamen çözüldüğü henüz doğrulanmadı.** Bu Windows ortamında Xcode/xcodegen bulunmuyor; GitHub CLI oturumu açık değil. macOS temiz/Production derlemeleri, iPhone/iPad arayüz testleri ve gerçek cihazdaki EPUB yerleşim kontrolü çalıştırılamadı. Sunucu paketi bu oturumda dağıtılmadı; HTTPS üzerinde oturumlu site–uygulama uçtan uca testi de çalıştırılmadı.

1. Önce IosApi 1.0.24 paketini HTTPS test ortamına yükleyip XenForo eklenti yükseltmesini çalıştırın. Veritabanı şeması değişmez. Yeni uygulama GET ilerleme sözleşmesini gerektirdiği için eski backend ile yayınlanmamalıdır.
2. macOS CI'da temiz/Production derlemesi ve iPhone/iPad testlerini çalıştırın. EPUB test dosyasının test paketinde, `EPUBCFIBridge.js` dosyasının uygulama kaynaklarında bulunduğunu doğrulayın.
3. Aynı hesap ve aynı PDF ile sitede 25, uygulamada 40, ardından 12. sayfaya dönün. Her geçişte diğer okuyucu, ana sayfa ve profil aynı kaydı göstermelidir.
4. EPUB'da iki yönde aynı metin aralığını; bölüm/yazı boyutu değişimini; ağ kesintisi, hemen kapatma ve yeniden açmayı doğrulayın. Ekran sayfa numarası değil metin konumu karşılaştırılmalıdır.
5. İki hesapla bekleyen kayıtların karışmadığını ve raf/favori değişiminin ilerlemeyi koruduğunu kontrol edin. Eksik/geçersiz eski EPUB konumu otomatik olarak başlangıç konumuyla ezilmemelidir.

Bu adımlar geçmeden App Store veya canlı yayın hazır olma iddiası yoktur.
