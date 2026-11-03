# IosApi 1.0.37 — favoriler ve kitap rafları

Bu klasör yerel yükseltme paketidir. Canlı sunucuya yükleme veya XenForo yükseltmesi çalıştırılmadı.

- Paket: `Ekitapligim-IosApi.zip`
- Sürüm: `1.0.37` / `1000037`
- SHA-256: `de46e68120d9bc8685e4a0703d289a16ba8f8fe6a1654e8f421f1c9dd462cc75`
- Paket düzeni: `upload/src/addons/Ekitapligim/IosApi/`

## Kurulum

1. Sunucunun mevcut dosya/veritabanı yedeğini ve önceki IosApi paketini saklayın.
2. Önce HTTPS test ortamında XenForo yönetim panelinin normal eklenti arşivi yükleme/yükseltme akışıyla ZIP'i yükleyin. Yükleme tamamlandıktan sonra IosApi sürümünün `1.0.37` olduğunu doğrulayın. Yalnızca PHP dosyalarını kopyalamak yerine eklenti yükseltmesini tamamlayın.
3. Mevcut XenForo, BookThreads ve MobileApi bağımlılıklarını koruyun. Bu değişiklik ek veritabanı geçişi veya Android uygulama değişikliği gerektirmez.
4. Eşleşen iOS sürümünde favoriye ekleme/kaldırma, Okuyacağım → Okuyorum → Okudum geçişleri, uygulamayı kapatıp yeniden açma ve canlı akış kayıtlarını doğrulayın. Favori ile okuma rafı birlikte kalmalı, PDF/EPUB konumu korunmalı, tekrar dokunma aynı kaydı çoğaltmamalıdır.
5. Test ortamı doğrulamasından sonra normal üretim yükseltme sürecini uygulayın. Bu paket hazırlandı; üretim veya iPhone doğrulaması yapıldığı anlamına gelmez.

## Çalıştırılan kontroller

- `Scripts/build-ios-api-addon.ps1 -CreateZip -OutputDirectory artifacts/library-favorites-20261018` başarılı.
- API sözleşmesi denetimi: 73 Swift yol şablonu eşleşti; paketleme sırasında tüm PHP dosyaları sözdizimi kontrolünden geçti.
- 26 backend test dosyası, cURL etkin yerel PHP ile başarılı; kaynak doğrulayıcı testi kurulu `ExternalEbook.php` dosyasını yalnızca okuyarak kullandı.
- Favori/raf regresyon testi: 37 kontrol başarılı; UTF-8 PUT gövdesi, bağımsız favori/raf, okuma konumunun korunması, yetki, tekrar istek ve işlem geri alma davranışları doğrulandı.
- Arşiv: 137 dosya, yedi zorunlu dosyanın içeriği kaynakla SHA-256 üzerinden eşleşti. Özel anahtar/bilinen erişim belirteci desenleri ve hassas dosya adları bulunmadı. Apple'ın herkese açık kök sertifikası paketteki normal kaynaktır.
- Testler ağ isteği, canlı hesap değişikliği veya canlı veritabanı bağlantısı yapmadı.
