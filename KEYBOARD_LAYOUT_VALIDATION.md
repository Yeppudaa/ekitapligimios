# Klavye sonrası yarım ekran incelemesi — 18 Ekim 2026

## Bulgular ve uygulanan düzeltme

Paylaşılan görüntüde alt gezinme çubuğu ekranın ortasında, alt bölüm ise boş. Kaynakta ana sayfa, gezinme yığını, mini oynatıcı ve alt çubuk aynı `VStack` içinde SwiftUI klavye güvenli alanına birlikte tepki veriyordu. Bu yapı görüntüdeki belirtiyle uyumlu. Uygulamada saklanan manuel klavye yüksekliği, `UIScreen.main` tabanlı ölçüm veya klavyeye eşit padding bulunmadı. Görüntüdeki sorunun aynı cihazdaki yeniden üretimi bu Windows ortamında yapılamadı.

`RootView` artık tam pencere boyutunda kalır. `WindowKeyboardLayoutReader`, kendi penceresindeki UIKit `keyboardLayoutGuide` ölçüsünü okuyarak klavye için tek bir alt güvenli alan ayırır. Ölçen görünüm bu alanın dışında tutulduğu için ölçüm kendi sonucundan etkilenmez. Açılma/kapanma bildirimlerinden tutulan iki durumlu bayrak kaldırıldı. Ekran yüksekliği veya önceki klavye boyutu cihazlar arasında saklanmaz. Klavye kapanınca gerçek geometri sıfır ek boşluk verir; alt çubuk geri gelir. Klavye açıkken alt çubuk, mini oynatıcı ve yüzen yardımcı gizlenir. Klavye kapatma işlemi yalnız ilgili pencereye uygulanır.

Apple'ın [keyboard layout guide belgesine](https://developer.apple.com/documentation/uikit/uikeyboardlayoutguide/followsundockedkeyboard) göre `followsUndockedKeyboard=false` iken kılavuz kenetlenmiş klavyeyi izler; ekran dışı/yüzen klavyede güvenli alan alt kenarına döner. Bu nedenle yüzen iPad klavyesi için tam genişlikte boş bir bölüm ayrılmaz. [Safe-area inset](https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)-4s51l) sayfa içeriğine iletilir; global `ignoresSafeArea(.keyboard)` tek başına kullanılarak editörlerin klavye altında bırakılması amaçlanmaz. Native sheet sunumları kendi güvenli alanını yönetmeye devam eder.

Forum ve özel mesaj yanıt editörleri kısa görünümde aynı editör kimliğini koruyarak gönder düğmesiyle yan yana gelir. Yükseklikleri güncel görünür alana göre sınırlandırılır; editör içindeki uzun metin kaydırılabilir. Gönder hedefi en az 44×44 pt, erişilebilir adı yerelleştirilmiştir. Gündem yorumu kısa görünümde tek satır ve ikon düğmesine geçer; görünür yükseklik değişince odaklı alana yeniden kaydırılır. Büyük yazı ve yatay ekranda gereksiz başlık/sayaçlar yazma alanını tüketmez.

Forum, özel mesaj, sohbet ve kitap yorumu kaydırmalarına etkileşimli klavye kapatma eklendi. Sayfadan çıkışta odak temizlenir, taslak silinmez. Sohbet ve kitap yorumunda klavye kapatma düğmeleri bulunur. Forum konu açma/düzenleme ve yeni özel mesaj editörleri kaydırılabilir ve sınırlı yükseklikte tutulur. API, kimlik doğrulama, satın alma, gizlilik verileri ve entitlements bu değişiklik için değişmez.

## Çalıştırılan doğrulama

- `Scripts/swift-test-windows.ps1`: **440 XCTest geçti**, buna yeni **16 klavye geometri testi** dahil. Portre, home indicator olmayan cihaz, yatay ekran, yeniden boyutlanan pencere, Split View genişliği, yüzen/kenetlenmemiş/ekran dışı klavye, güvenli alan, geçersiz ölçüler ve kısa editörler sınanır. İlk koşuda sonsuz CGRect kontrolü başarısız oldu; açık `isInfinite` reddi eklendikten sonra tüm paket geçti.
- 15 ilgili Swift kaynak/test dosyası için `swiftc -frontend -parse -D DEBUG`: geçti. Bu iOS SDK typecheck veya SwiftUI uygulama derlemesi değildir.
- `Scripts/swift-static-audit.ps1`, `Scripts/ui-accessibility-audit.ps1`: geçti. Erişilebilirlik kontrolü kaynak taramasıdır; VoiceOver veya native accessibility audit yerine geçmez.
- `Scripts/validate-workspace.ps1`: geçti; API yol sözleşmeleri, üretim HTTPS, gizli bilgi taraması ve PHP sözdizimi dahil.
- `Scripts/keyboard-layout-macos.sh` için Git Bash `-n`: geçti; Xcode komutları Windows üzerinde çalıştırılmadı.

Çıktılar `artifacts/keyboard-layout-core-tests.log` ve `artifacts/keyboard-layout-workspace.log` altında. Swift ve Git Bash sandbox içinde başlayamadığından onaylanan yerel test işlemleri sandbox dışında çalıştırıldı; gerçek hesap verisi veya sunucu mutasyonu kullanılmadı.

## Hazır olan native testler ve kalan doğrulama

`KeyboardLayoutUITests` gerçek `RootView` içinde, tüm istekleri yerel URLProtocol ile kesilen DEBUG fixture kullanır. Tek başına bir `NavigationStack` açıp ana ekran sorununu atlamaz. **10 native senaryo** hazırdır: ilk tam yükseklik, tekrarlanan aç/kapat, interaktif kaydırarak kapatma, klavye açıkken geri/sekme değişimi, büyük yazıda gündem yorumu, gündem sheet kapatma, özel mesaj/sohbet sheet kapatma, kitap yorumu, portre/yatay dönüş ve iPad penceresi. Gerçek yazılım klavyesi yoksa test başarısız olur. Başarı için gerçek geometri birkaç ardışık örnekte sabit kalmalı; kapanışta alt çubuk başlangıç koordinatına dönmeli, editör ve gönder düğmesi klavyenin dışında kalmalıdır. Hatalarda gerçek uygulama/ekran görüntüleri ve erişilebilirlik ağacı eklenir.

Mac'te, Xcode/XcodeGen ve simulator bağımlılıkları hazırken:

```sh
bash Scripts/keyboard-layout-macos.sh
```

Betik en yeni kurulu iOS runtime'ında iPhone SE (3. nesil), iPhone 11, iPhone 13, en yeni kurulu iPhone ve iPad'i seçer; ayrıca iOS 17 taban koşumu ister. Eksik cihaz/runtime'ı başarı saymaz, eksik kapsamı JSON'a kaydeder. Telefonlarda iPad'e özgü durum açıkça dışlanarak 9, iPad'de 10 başarılı/sıfır hatalı/sıfır atlanmış test bekler. Gerçek XCTest sonuçları ve ekler `build/keyboard-layout-<UTC>` altında saklanır. Simulator hardware keyboard tercihi koşum süresince kapatılıp sonunda önceki değerine geri getirilir.

**Bu bilgisayarda Xcode, iOS SDK ve simulator yok; native testler ve iOS uygulama derlemeleri henüz çalıştırılmadı.** iPad Split View/Stage Manager pencere küçültme, floating/split keyboard, fiziksel klavye bağlama/çıkarma, üçüncü taraf klavyeler, gerçek cihazda arka plan/ön plan geçişi ayrıca denenmelidir. Betik bu manuel durumları otomatik doğruladığını iddia etmez. Temiz Development/Production derlemeleri, iOS 17 ve güncel iOS çalıştırmaları ile gerçek cihaz kanıtı olmadan “tüm cihazlarda sorunsuz” veya yayına hazır sonucu verilmez. Canlı uygulamaya/TestFlight'a dağıtım yapılmadı.
