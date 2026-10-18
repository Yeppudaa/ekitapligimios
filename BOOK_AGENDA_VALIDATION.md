# Kitap Gündemi düzeltmeleri — 18 Ekim 2026

Yorum başlığı artık yorum alanına odaklanan bir düğme. Çok satırlı alanın dolgusu dahil dokunma yüzeyi açık odak yönetimi kullanır; dekoratif çizgiler dokunma yakalamaz. Detay sayfası odaklanan yorum alanını görünür tutar ve klavyede kapatma düğmesi sunar. Yorum düğmesinin üstüne gelebilen yüzen yardımcı bu sayfada gizlenir. Gerçek iOS klavye açılışı bu Windows ortamında yeniden üretilemedi; aşağıdaki native testler eklenmiştir ve macOS çalıştırması bekler.

## Kaynakta düzeltilen diğer hatalar

- Yorum yükleme hatası boş liste olarak sunulmuyor; tekrar deneme gösteriliyor.
- Hatalı gönderimde taslak korunuyor; eşzamanlı gönderim tek istek oluşturuyor. Gönderim sırasında yazılan yeni taslak silinmiyor.
- Yorum ekleme/silme sunucunun toplamını değiştiriyor; kısmi veya engellenmiş yorum listesi toplamın yerine yazılmıyor.
- Beğeni/kaydet/yeniden paylaş sonrası yenileme başarısız olursa mevcut gönderi ekranda kalıyor.
- Detaydaki takip düğmesi sunucu işlemine bağlı; silinen gönderi ana akıştan kaldırılıyor.
- Sekme/filtre değişimi ve sayfalama eski yanıtları yeni seçime karıştırmıyor; aynı gönderi tekrar eklenmiyor.
- Çıkış/hesap değişimi eski içerik, yetki ve istek sonuçlarını geçersiz kılıyor. Düzenleme/gönderim eski hesaptan yeni hesaba sonuç uygulamıyor.
- iOS API adaptörü gerçek XenForo izin retlerini oturum veya sahiplik gerekçesiyle ezmiyor. İstemci yönetim düğmeleri sunucu izinlerine bağlı.
- Kitap seçiminde eski arama yanıtları yeni sorguyu ezmiyor.

## Çalıştırılan kontroller

- `Scripts/agenda-state-test-windows.ps1`: 18 XCTest geçti. Gerçek model kaynakları derlendi; testlere özel Combine modülü yalnızca property saklamayı taklit eder. Apple Combine yayınlama ve SwiftUI davranışı bu testin kapsamında değildir.
- `php Tests/Backend/BookAgendaViewerPermissionsTest.php`: 33 izin, alias, yorum, engelleme ve hata kontrolü geçti.
- `php -l Backend/IosApi-addon/Api/Controller/UgcControllerTrait.php`: geçti.
- `swiftc -frontend -parse` ile değişen Swift kaynakları ve yeni UI testleri: geçti. Bu kontrol native SDK ile typecheck/build yerine geçmez.
- Swift statik kaynak ve erişilebilirlik taramaları: geçti.
- `Scripts/swift-test-windows.ps1`: mevcut çekirdek paketin 424 XCTest testi geçti.
- `Scripts/validate-workspace.ps1`: geçti; 73 API yol şablonu, PHP sözdizimi, gizli bilgi taraması, üretim HTTPS yapılandırması ve statik erişilebilirlik kontrolleri dahil.
- Değiştirilen izlenen dosyalar için `git diff --check`: geçti.

Başarı özetleri `artifacts/agenda-state-tests.log`, `artifacts/agenda-core-tests.log` ve `artifacts/agenda-workspace-validation.log` altında saklanır. PowerShell `Write-Host` ile basılan ayrıntılar sohbetin komut çıktılarında yer alır. Windows sandbox içinde SwiftPM test başlamadan kapandığından Swift testleri aynı makinede sandbox dışındaki yerel test ortamında çalıştırıldı; sunucu bağlantısı veya gerçek hesap mutasyonu yapılmadı.

## macOS / cihaz doğrulaması bekliyor

`project.yml` klasör bazlı kaynak topladığı için yeni modeller ve testler XcodeGen hedeflerine otomatik dahil edilir. XcodeGen ile proje üretildikten sonra Development test şemasında `EkitapligimTests/BookAgendaFeedModelTests`, `EkitapligimTests/BookAgendaDetailModelTests` ve `EkitapligimUITests/BookAgendaUITests` çalıştırılmalıdır. iPhone SE, güncel iPhone ve iPad ile normal/büyük yazıda test edilmeli; simulator hardware keyboard bağlantısı kapatılmalıdır. Temiz Development ve Production uygulama derlemeleri henüz çalıştırılmadı.

UI testleri yalnızca yerel URLProtocol fixture kullanır; gerçek sunucuya yorum göndermez. Başlığa dokunma, alanın alt dolgusuna dokunma, metin girişi, klavye kapatma, başarısız gönderim, izin reddi, misafir ve yorum yükleme hatası senaryoları kapsanır.

Backend değişikliği yalnızca çalışma alanındaki kaynakta hazırlanmıştır; canlı sunucuya veya TestFlight'a dağıtım yapılmadı. Gizlilik envanteri, proje yetkileri ve satın alma yapılandırması değişmez; yeni veri veya izin eklenmez. App Store hazır olma iddiası yoktur.
