# Codemagic yayın kontrolü

Kontrol dalı: `codex/release-review-20261103`. Workflow: **ios-release-review**.
Bu akış elle başlatılır; TestFlight/App Store yüklemesi, imzalama profili değişikliği veya canlı sunucuya yazma yapmaz.

Sürüm kontrolü için ayrıca **ios-release-version-check** vardır. Bu kısa, salt okunur akış Apple'daki App Store sürümlerini ve her iki kanalın en yüksek build numarasını sorgular. `project.yml` içindeki sürüm ve build alt sınırından `version-plan.json` üretir; hiçbir sürüm yüklemez veya numara rezerve etmez. İmzalama anında sorgular tekrarlanır. TestFlight ve yayın adayı aynı pazarlama sürümünü kullanır; yeni yüklemeler ayrı ve artan build numarası alır.

3 Kasım 2026 tarihli [Codemagic kontrolü](https://codemagic.io/app/6a5221a644ecae83eeea61ec/build/6ae9cd9957e81944fbc19941) başarılıdır: App Store ve TestFlight son sürümü **1.1.1 (49)**, sıradaki aday **1.1.2 (50)**. Kullanılan mevcut entegrasyonun adı **Ekitapligim Codemagic**. Eski `... 3` adı hesapta bulunmadığı için düzeltilmiştir. Bu sonuç yalnızca sürüm denetimidir; tam yayın kontrolünün yerine geçmez.

Codemagic'te aynı commit için dört çalışma başlatın; `review_group` alanında sırayla `native-unit`, `iPhone-compact`, `iPhone-large`, `iPad` seçin. Seçenek alanı [Codemagic build inputs](https://docs.codemagic.io/knowledge-codemagic/build-inputs/) biçimini kullanır.

| Grup | Kontrol |
| --- | --- |
| native-unit | Core testleri, temiz Development ve imzasız Production derlemeleri, tüm native birim testleri |
| iPhone-compact | Küçük iPhone simülatöründe tüm UI testleri |
| iPhone-large | Büyük iPhone simülatöründe tüm UI testleri |
| iPad | iPad simülatöründe tüm UI testleri |

Xcode 26.3 seçilir. Cihazlar kurulu simülatörlerden belirlenir. Gerekli cihaz veya sonuç paketi eksikse kontrol başarısız olur; testler atlanıp başarılı gösterilmez.

Her çalışmada `modern-parity-evidence.zip`, ayrıntılı `.xcresult.zip` paketleri ve `packaging-status.json` saklanır. ZIP içindeki `revision.txt` dosyaları aynı commit'i göstermeli; `result-code.txt` sıfır olmalı. İlgili grup dışında `not-run` görülen alanlar diğer üç çalışmada doğrulanır. Ekran görüntüleri ayrıca gözden geçirilir.

Bu dört kontrolün geçmesi gerçek iPhone'da APNs popup, Google oturumu, fotoğraf/iCloud seçimi, Sandbox satın alma/geri yükleme veya canlı sunucu fotoğraf yüklemesini doğrulamaz. Açık koşullar `RELEASE_REVIEW_20261103.md` içindedir. Bu koşullar kapanmadan yayın hazır kabul edilmez.

Mevcut `ios-production` ve `ios-testflight-reviewed` dağıtım akışları ayrıdır. Kontrol çalışması için bunları seçmeyin.

Kullanıcının 3 Kasım tarihli açık TestFlight gönderim isteği için **ios-testflight-beta** eklendi. Elle başlatılır; mevcut Apple bağlantısını ve imzalama profillerini kullanır. Tüm Core ve native testleri, ardından gündem fotoğrafları, okuyucu açılışı, premium profil, profil/dizin ve topluluk ekranları için 25 UI testi çalışır. Başarısız veya atlanan testte gönderim durur. Sürüm tekrar sorgulanır, Production IPA üretilir ve gerçek imza/entitlements/sürüm kontrolünden sonra yalnızca TestFlight'a yüklenir. App Store incelemesi ve otomatik e-posta bildirimi yoktur. Bu beta akışı tam yayın matrisinin veya fiziksel cihaz/sunucu doğrulamasının geçtiğini iddia etmez.
