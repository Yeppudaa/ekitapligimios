# Premium avatar çerçevesi — 3 Kasım 2026

iOS kendi profilinde, üyeler listesinde ve ziyaret edilen premium üye profilinde ortak `PremiumAvatarFrame` kullanır. Altın halka, üstte açık kitap, sürekli dönen iki ışık izi ve altı küçük parıltı Android çiziminden native SwiftUI Canvas'a aktarıldı. Premium onay ikonu kullanıcı adının sonuna eklenir. Uzun adlarda ikon metinle birlikte satır kırar. Altın Premium etiketi kimlik alanını tamamlar.

## Referans ve REA

Referans kaynak `C:/Users/Monster/Downloads/startdesign (1)/app/src/main/java/com/ekitapligim/app/ui/components/PremiumAvatarFrame.kt` ve tamamlanmış Android profil ekranlarıdır. Android teslimindeki `visited-premium-profile.png` incelendi.

REA/JADX ile APK'da `com.ekitapligim.app.ui.components.PremiumAvatarFrameKt` bulundu. `drawPremiumBookFrame(DrawScope, float, float)` metodu smali olarak tamamen çözümlendi. Java çözümleyicisinin bu metottaki geri dönüşü raporlandı. APK SHA256 değeri `2f99e1e7d25a36a68ce9318ad5332f53b8f5801e15aaf79b604c5b2cf41d157c`.

Kanıtlar `.codex-artifacts/premium-avatar-20261103/rea-android-evidence.json` dosyasına aktarıldı ve REA oturumu kapatıldı. Statik APK/kaynak incelemesi yapıldı. Vesperis'in BlueStacks üzerinde canlı animasyonu bu çalışmada yeniden kaydedilmedi. Android'in mevcut Vesperis analiz notları tarihsel referans olarak okundu. iOS için piksel düzeyinde birebir eşitlik henüz doğrulanmadı.

## Ölçüler ve davranış

- 100 birimlik çizimde fotoğraf/halka merkezi `(50, 53)`, fotoğraf çapı `%83`, halka yarıçapı `43`, altın kalınlığı `4,5`. Fotoğraf altın kenarın altına taşarak alt piksel boşluklarını örter.
- Doğrusal ışık turu `4,8` saniye, parıltı fazı `3,4` saniye. Fotoğraf ve kitap sabit durur.
- En fazla 30 fps. Hareketi Azalt, arka plan veya görünüm kaybında TimelineView kaldırılır ve `0,32` fazındaki sabit çerçeve gösterilir.
- Ziyaret edilen üyenin mevcut `is_premium` veya `role_type=premium` verisi kullanılır. Nested `role` desteklenir. Kullanıcı adı/özel unvan/onay rozeti premium hakkı üretmez. Kendi profili mevcut abonelik/profil durumunu kullanır.
- Premium onay ikonu adın sonunda ve VoiceOver değerinde sunulur. Premium olan yönetici/moderatörün rol etiketi de gösterilir.

## Çalıştırılan kontroller

| Kontrol | Sonuç |
| --- | --- |
| `Scripts/swift-test-windows.ps1 -Jobs 4` | **535 XCTest geçti**, 7 yeni premium avatar regresyon testi dahil |
| `swiftc -frontend -parse` ve `-D DEBUG` | **317 Swift dosyası** geçti |
| `Scripts/validate-workspace.ps1` | Kaynak/yapılandırma/API/temel güvenlik/erişilebilirlik etiketi ve PHP kontrolleri geçti |
| `git diff --check` | Geçti |
| `bash -n Scripts/premium-avatar-macos.sh` | Geçti |

Testler farklı üyelikleri, eksik/eski alanları, staff/onaylı normal üyeyi, takip iznini, çerçeve-fotoğraf örtüşmesini, kesintisiz döngüyü ve hareket durdurma koşullarını kapsar. Loglar `.codex-artifacts/premium-avatar-20261103/` içindedir.

## Bekleyen native kontroller

Windows'ta Xcode ve iOS Simulator bulunmadığı için iOS derlemesi ve gerçek SwiftUI görüntü/animasyon testleri çalıştırılamadı. `PremiumAvatarLayoutTests` çerçevenin hareketli piksellerini, sabit fotoğraf açıklığını/kitabı, küçük/büyük ölçüleri ve uzun kullanıcı adını denetler. `PremiumAvatarUITests` kendi profilini, ziyaret edilen premium/normal üyeyi ve üyeler listesinden profil geçişini kapsar.

macOS'ta `bash Scripts/premium-avatar-macos.sh` temiz Development ve unsigned Production derlemesini, iki iPhone ve iPad'de bu testleri çalıştırıp ekran görüntülerini dışa aktarır. Görsel sonuçlar, VoiceOver, Hareketi Azalt ve ön/arka plan geçişi cihazda incelenmelidir.

Mevcut HTTPS üye/profil/abonelik verileri kullanılır. Yeni ağ isteği, veri toplama, satın alma veya izin kategorisi eklenmediği için mevcut privacy manifest, entitlements ve StoreKit yapılandırması geçerlidir. `project.yml` klasör kaynak keşfi yeni Swift dosyalarını kapsar. Bu görevde sunucu kurulumu veya mağaza yayını yapılmadı.
