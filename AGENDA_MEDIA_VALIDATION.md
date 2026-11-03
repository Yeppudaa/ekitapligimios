# Kitap Gündemi fotoğraf düzeltmesi — 2026-11-03

Mevcut SwiftUI sayfaları, gezinme ve Gündem sekme sırası korunarak fotoğraf gösterimi ve paylaşımı eklendi. Android kaynakları değiştirilmedi. Bu dosya kaynak/offline test kanıtını, canlı sunucu ve cihaz doğrulamasından ayrı kaydeder.

## Düzeltilen nedenler ve davranış

- Ana sayfadaki `HomeAgendaCard` paylaşım eklerini hiç çizmediği için fotoğraflar görünmüyordu. İlk fotoğraf ve çoklu fotoğraf sayısı eklendi; fotoğraflı rayda kartlar eşit, daha geniş bir yüksekliği paylaşır. Büyük yazılardaki mevcut dikey düzen korunur.
- Liste/detay, kitap kapağı bileşenini küçük/boş thumbnail adresiyle kullanıyordu. Ortak `AgendaPhotoView` orijinal fotoğrafı oranını bozmadan gösterir; yükleme, hata ve yeniden deneme durumları vardır. Çoklu ekler kaydırılabilir. Bozuk/tekrarlı ek satırları paylaşımın tamamını düşürmez.
- Mevcut composer'a native PhotosPicker, önizleme, değiştirme ve kaldırma eklendi. Hazırlanırken gönderim durur; seçim hatası açıkça gösterilir. Kullanıcının kaldırdığı/değiştirdiği fotoğraf geç gelen iCloud sonucu ile geri dönmez. Başarısız gönderimde fotoğraf/metin taslağı ekranda kalır.
- Seçilen fotoğraf ImageIO ile yönü uygulanarak en fazla 2048 piksele küçültülür ve kaynak EXIF/GPS metadatası kopyalanmadan gerçek JPEG üretilir. Hazırlama işlemi ana iş parçacığı dışında yapılır. Native ImageIO davranış testleri yazıldı, Windows'ta çalıştırılmadı.
- Fotoğraf ve metin aynı multipart POST içindedir. Destek sürümü/izin/dosya sınırı yayınlama öncesi kontrol edilir; eski API fotoğrafı sessizce atlayıp metni yayımlayamaz. Standart paylaşım sadece fotoğraf içerebilir.

## Sunucu ve erişim

IosApi **1.0.40 / 1000040**, mevcut iki Gündem rotasını genişletir. Ek şema/gezinme/billing değişikliği yoktur. UGC kabul/metin kontrolleri, flood kontrolü, kitap gereksinimi, Social moderasyonu ve create/view/upload izinleri korunur. Native attachment handler dosya türünü/boyutunu ve diğer XenForo kısıtlarını doğrular. Geçici hash sunucuda üretilir; Creator dosyayı paylaşım işlemi içinde ilişkilendirir. Paylaşım kaydı başarısızsa bekleyen dosya silinir.

Fotoğraf okumada paylaşım görünürlüğü, engellenen yazar, attachment ID/content ID/content type ve bekleyen dosya durumu kontrol edilir. Yanıt `private, no-store` olur. iOS yalnızca sabit birinci taraf API rotasına bearer gönderir; dış HTTPS inline görsellere kimlik bilgisi veya çerez göndermez. HTTP yönlendirmesi izlenmez; veri MIME/boyut/eksik gövde kontrolünden geçer. Boyut sınırları: kaynak seçim 40 MiB, hazırlanmış JPEG 8 MiB veya daha düşük sunucu sınırı, indirilen görsel 20 MiB. Fotoğraf yükleme/okuma gerçek sunucuda henüz denenmedi.

Yerel inceleme paketi: [.codex-artifacts/agenda-media-20261103/package/Ekitapligim-IosApi.zip](.codex-artifacts/agenda-media-20261103/package/Ekitapligim-IosApi.zip)

SHA256: `591a880afa12ef12560e1e3a49d48d42a5711f70662f90eb8013bae19887792a`

Arşiv manifesti ve beş medya PHP dosyası kaynakla birebir karşılaştırıldı. Paket 161 dosya içerir; mevcut IosApi çalışma ağacındaki önceki düzenlemeleri de korur. Canlıya kurulmadı.

## Çalıştırılan kontroller

| Kontrol | Sonuç |
| --- | --- |
| `Scripts/swift-test-windows.ps1 -Jobs 4` | **528 XCTest geçti**, medya için 17 yeni çekirdek test dahil |
| `Scripts/agenda-state-test-windows.ps1` | **24 test geçti**, 6 yeni gerçek `AgendaPhotoModel` testi dahil; Combine depolama shim'i, Apple UI kanıtı değil |
| `Tests/Backend/AgendaMediaTest.php` | **51 kontrol geçti**, gerçek upload trait/serializer/image guard; izole XF sınırları |
| `Tests/Backend/BookAgendaViewerPermissionsTest.php` | **33 kontrol geçti**, mevcut izinler/engellenmiş kullanıcı/error davranışı |
| `Scripts/build-ios-api-addon.ps1 -CreateZip ...` | PHP sözdizimi, mevcut backend regresyonları, rotalar, sürüm/paket kontrolleri ve ZIP üretimi geçti |
| `Scripts/validate-workspace.ps1` | Yapılandırma, kaynak/API/temel güvenlik/erişilebilirlik etiketi ve PHP kontrolleri geçti |
| `swiftc -frontend -parse` ve `-D DEBUG` | **312 Swift dosyası** sözdizimi kontrolünden geçti; Apple SDK type-check/build yerine geçmez |
| `bash -n Scripts/agenda-media-macos.sh` ve `git diff --check` | Geçti |

Loglar: `.codex-artifacts/agenda-media-20261103/`. Çekirdek testler multipart alanları/Unicode, gerçek izin destek sürümü, eski sunucuda POST yapılmaması, dosya sınırı, fotoğraf-only POST, güvenli URL/ID, bearer izolasyonu, yönlendirme reddi, HTML/büyük/eksik görsel yanıtlarını kapsar. PHP testleri izin reddi, yükleme/kayıt hatası ve dosya temizliği, native gereksinimler, inline görsel ayıklama, feed/detail dekorasyonu ve ek ilişki/erişim denetimlerini kapsar.

## Bekleyen gerçek ortam kontrolleri

Bu bilgisayarda Xcode, Apple iOS SDK ve Simulator yok. iOS uygulamasının temiz/Production derlemesi, SwiftUI/ImageIO/XCTest UI çalıştırması, görsel ekran incelemesi ve fiziksel cihaz testleri **çalıştırılmadı**. App Store hazırlığı veya canlı uçtan uca başarı iddiası yoktur.

macOS'ta `bash Scripts/agenda-media-macos.sh` çalıştırılmalı. Komut temiz Development ve unsigned Production derlemesi, iki iPhone ve iPad'de seçili native testleri, xcresult ve ekran görüntüsü dışa aktarımını hazırlar. Eklenen native testler: `AgendaPhotoProcessorTests`, `AgendaMediaLayoutTests`, `AgendaMediaUITests`. UI fixture yalnızca DEBUG/opt-in çalışır, gerçek ekranları ve yerel engellenmiş ağı kullanır; gerçek fotoğraf galerisi seçiminden yüklemeye kadar cihaz testi yerine geçmez.

Yetkili HTTPS staging üzerinde 1.0.40 kurulup JPEG/PNG/HEIC ve iCloud seçimi, fotoğraf-only ve metin+fotoğraf, kayıt/bağlantı hatası sonrası taslak, moderasyon ve görünürlük, çıkış/hesap değişimi, VoiceOver/büyük yazı, ana sayfa→detay görüntüsü ve fotoğraf oranı doğrulanmalı. API/privacy/parity/metadata/checklist güncellendi; mevcut `PhotosorVideos` manifest bildirimi geçerli. Proje klasör kaynak keşfi yeni dosyaları kapsar; yeni entitlement, StoreKit davranışı veya geniş fotoğraf erişim izni gerekmez.
