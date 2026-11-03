# Canlı sohbet ve profil kararlılık incelemesi — 3 Ekim 2026

Bu çalışma `C:\Users\Monster\Documents\IOS App` içindeki yerel SwiftUI iOS uygulamasına uygulanmıştır. Android referansı yalnızca mevcut sohbet sözleşmesini incelemek için okunmuştur; Android uygulaması veya çalışan sunucu kodu değiştirilmemiştir. Satın alma işlemlerinin uygulama/sunucu kodu, ürün yapılandırması, StoreKit dosyası, entitlements ve gizlilik manifesti korunmuştur.

## Düzeltmeler

- Sohbet baloncuklarında yatay `fixedSize` nedeniyle tek satıra zorlanıp kesilen metinler, mevcut genişlik içinde çok satırlı ve yükseklikleri içeriğe göre değişen şekilde düzenlendi. İşlem düğmeleri mesajın altında, en az 44 pt dokunma alanıyla yerleştirildi. Ana sayfanın sohbet önizlemesindeki aynı genişlik hatası da giderildi.
- Profil fotoğrafı ve kullanıcı adı geçerli üye profiline gider. Sohbet içindeki bağlantılar VoiceOver tarafından ayrı erişilebilir öğeler olarak algılanır.
- Alıntı bağlamı olan, iptal edilebilen yanıt alanı ve sunucudaki etkin XenForo ifadelerini kullanan seçim/geri alma işlemleri eklendi. Eski sunucuda alıntı/ifade yetki alanları bulunmazsa bu işlemler kapalı kalır; mevcut sohbet çalışmaya devam eder.
- Sohbet istekleri `ChatModel` içinde oda/hesap sürümüyle korunur. Eski yanıtlar yeni oda veya hesaba aktarılmaz. Gecikmiş sorgular yeni ifade seçimini geri alamaz. Tekrarlanan gönderim engellenir; gönderim sürerken yazılan yeni taslak korunur. Gönderilen mesaj ve son mesajları yenileme sorgusu, henüz çekilmemiş ara mesajları atlayacak şekilde sayfalama imlecini ilerletmez.
- IosApi 1.0.30, yalnızca kanıtlanabilir canlı oda alıntısı/ifadesi için asıl mesaj sahibine APNs işi oluşturur. Genel mesajlar, mention olayları, kişinin kendisine verdiği ifadeler, Siropu özel/harici sohbet olayları ve kaldırılmış/geçersiz etkileşimler bu yolu tetiklemez. Diğer mevcut forum ve XenForo özel konuşma bildirimleri korunur.
- Bildirim alıcısı istemciden alınmaz; sunucu oda, içerik, kullanıcı, engelleme ve işlem izinlerini oluşturma/gönderme sırasında tekrar doğrular. Yeni web alıntılarına asıl mesaj/üye referansı eklenir. Eski, yalnızca isim içeren web alıntıları okunabilir; güvenilir alıcı belirlenemediği için bildirim oluşturulmaz.
- Profilde eski kütüphane yanıtının yeni okuma konumunu geri alması engellendi. Kitap metadata'sı kaydolunca, kitap raf listesinde bulunmasa bile geri yüklenen konum karta yansır. Aynı hesapta token yenilenmesi okuma durumunu sıfırlamaz. Profil yeniden görünür olduğunda, hesap değişiminde ve uygulamaya dönüldüğünde yenilenir. Profil/ana sayfa okuma metinleri dar genişlikte satırlara ayrılır.

## Çalıştırılan doğrulamalar

| Kontrol | Sonuç ve kanıt |
|---|---|
| `Scripts/swift-test-windows.ps1` | 315 XCTest testi geçti; `.codex-artifacts/chat-profile-review/core-tests.log` |
| `Scripts/swift-test-windows.ps1 -Clean -Release` | Temiz Release çekirdek derlemesi ve 315 XCTest testi geçti; `core-clean-release.log`. iOS uygulama derlemesi değildir. |
| `Scripts/chat-state-test-windows.ps1` | Gerçek `ChatModel` ve testleri için 9 sohbet durum/yarış testi geçti; `chat-state-harness.log`. Test amaçlı Combine modülü yalnızca özellik depolamasını taklit eder; Apple Combine yayın davranışını ve SwiftUI çizimini doğrulamaz. |
| `Tests/Backend/*Test.php` | 16 PHP test dosyası geçti; `backend-final.log`. Alıntı/ifade izinleri, hedef alıcı, özel/harici sohbet izolasyonu, güncel engelleme, silinmiş ifadeler, mevcut oturum/okuma/silme ve satın alma regresyonları dahildir. Drive kaynak testi kurulu URL doğrulayıcı dosyasıyla çalıştırıldı. |
| `Scripts/validate-workspace.ps1 -Strict` | Kaynak, rota, PHP sözdizimi, temel gizli bilgi taraması ve statik erişilebilirlik kontrolleri geçti; `workspace-audit.log`. Cihaz erişilebilirlik denetimi değildir. |
| Swift frontend DEBUG/Release ayrıştırması | 93 uygulama/test kaynağı ve 71 Release uygulama kaynağı sözdizimi kontrolünü geçti; `swift-app-syntax.log`, `swift-release-syntax.log`. Apple SDK tip denetimi değildir. |
| `git diff --check` | Geçti; `diff-check.log`. |
| Satın alma/yapılandırma dosya karşılaştırması | HEAD ile korunan 23 dosya aynı; `purchase-protection.log`. Paylaşılan endpoint/repository dosyalarında yalnızca sohbet bölümleri değişti. |
| Genel HTTPS API okumaları | Kitaplar, sohbet odaları ve yasal bilgiler 200 JSON; oturumsuz korunan profil/kütüphane bildirim okumaları 401; `public-readonly.log`. |
| Yetkili, içerik değiştirmeyen API okumaları | Profil, kütüphane, okuma istatistikleri, sohbet mesajları, mevcut okuma konumu ve uygulamanın doğru `/me/notifications/counts` rotası 200; `authenticated-readonly.log`. Test oturumu kapatıldı, kimlik bilgileri/tokenlar çıktı veya pakete yazılmadı. İlk bildirim sorgusunda denetim komutundaki yanlış yol düzeltildi; uygulama rotası doğruydu. |
| IosApi paket oluşturma/denetimi | 1.0.30 ZIP oluşturuldu, mevcut satın alma denetimleri dahil paket kontrolü geçti; `backend-package.log`, `package-audit.log`. Sunucuya yüklenmedi. |

## Tamamlanmamış cihaz ve dağıtım kontrolleri

Windows ortamında Xcode/iOS SDK/Simulator yoktur. GitHub CLI oturumu bulunmadığından macOS CI de bu çalışma tarafından başlatılmamıştır. iOS uygulamasının temiz/Production derlemesi, gerçek Apple Combine/SwiftUI testleri, `ProfileReadingRefreshTests`, `ChatUITests`, fiziksel cihaz APNs ve görsel kontrol çalıştırılmamıştır. Uygulamanın tamamının hatasız olduğu veya App Store'a hazır olduğu iddia edilmez.

Canlı HTTPS API'de yeni `can_quote`/ifade metadata'sı henüz yoktur. Yeni etkileşimler ve bildirimler, incelenen IosApi 1.0.30'un staging üzerinde normal XenForo add-on yükseltmesiyle kurulmasını gerektirir. Yalnızca PHP dosyalarını kopyalamak yeterli değildir; XML rotaları, ifadeler, class extension ve entity listener kayıtları içe alınmalıdır. Veritabanı şeması değişikliği yoktur. Android API'si değiştirilmez.

macOS doğrulaması için mevcut `project.yml` yeni kaynak/test klasörlerini otomatik içerir:

```bash
xcodegen generate
xcodebuild clean build -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Production -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

`ChatUITests` gerçek sohbet görünümünü DEBUG fixture ile 320 pt genişlikte ve erişilebilirlik yazı boyutunda sınar; avatar geçişi, alıntı iptali, ifade seçimi/kaldırılması ve ekran görüntüsü kanıtları içerir. iPad, yatay ekran, klavye, VoiceOver ve uzun mesajları ayrıca cihazda kontrol edin. İki hesapla staging üzerinde tam bir alıntı/ifade için yalnızca asıl yazarın bildirim aldığını; normal mesaj, mention, kendine ifade ve Siropu özel/harici sohbette sıfır sohbet APNs olduğunu doğrulayın. Mevcut satın alma işlemini değişmeden, normal release test planıyla doğrulayın.

Bu proje APK üretemez: APK Android, bu çalışma iOS içindir. IPA/TestFlight için macOS derlemesi ve uygun imzalama/dağıtım erişimi gerekir. Hazırlanan kaynak arşivi ve IosApi ZIP, kurulum veya çalıştırılabilir mobil test paketi yerine geçmez.
