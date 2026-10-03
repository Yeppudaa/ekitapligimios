# Sohbet, profil ve kararlılık — yeniden inceleme, 3 Ekim 2026

> Güncel takip raporu: `CHAT_CROSS_PLATFORM_VALIDATION.md` (4 Ekim). Güncel yerel sunucu adayı 1.0.32'dir; aşağıdaki 1.0.31 sonuçları geçmiş doğrulamadır.

Bu çalışma native SwiftUI iOS projesinin yerel kaynaklarına uygulanmıştır. Üretim sunucusuna yükleme yapılmadı, Android kaynakları değiştirilmedi. **Düzeltilmiş IosApi 1.0.31, daha önce hazırlanan 1.0.30 ZIP’inin yerine kullanılmalıdır.**

## Bulunan ve çözülen sorunlar

- **Eski uygulamada alıntı kaybı:** Mevcut `message` alanı güvenle görüntülenebilir alıntı ve yanıtı birlikte korur. Yeni `message_body` sadece yanıtı içerir; güncel uygulama bu alanı boşken de tercih eder ve alıntıyı iki kez göstermez. Sadece alıntı içeren web mesajları eski uygulamada boş görünmez.
- **İç içe/ara alıntı gizliliği:** Yapılandırılmış referanslar güncel aynı-oda erişimi, yazar ve iki yönlü engellemeye göre filtrelenir. Silinmiş, erişilemeyen veya geçersiz referansların metni iki çıktı alanında da gizlenir. İsme dayalı eski alıntıların mevcut okunabilirliği korunur; bildirim alıcısı uydurulmaz.
- **Kayıp okuma yanıtı ve yeni sayfa:** Sunucu ilk kaydı kabul edip yanıt kaybolurken kullanıcının geçtiği yeni sayfa artık yeniden denemede kaybolmaz. Gönderim denemesi korunan hesap önbelleğine yazılır; yeniden başlatmada da uzlaştırılır. Farklı web konumu yine sunucu otoritesiyle benimsenir. Eski önbellekler yeni alan olmadan okunur.
- **Gizli sohbetin yeniden sorgulanması:** Profil ekranına geçildikten sonra uygulama aktif olduğunda gizli sohbet sorguları yeniden başlamaz. Başka odaya ait yanıtlar mesajlara veya sayfalama imlecine uygulanmaz.
- **Bildirim kaydı sırasında çıkış:** Çıkış, başlamış cihaz kaydının bitmesini geçerli oturumla bekleyip kaydı kaldırır. Yanıtı kaybolmuş olabilecek kayıt için de kaldırma denenir. Geç yanıt eski hesabın yerel kayıt durumunu yeniden etkinleştirmez. Eşzamanlı çıkışlar aynı kaldırma işini bekler.

Önceki düzeltmeler korunur: tam çok satırlı mesajlar, avatar/kullanıcı adı profil bağlantısı, alıntı/cevap, sunucudaki etkin ifadeler, çift gönderim koruması, oda/hesap izolasyonu, geç sorguların ifade seçimini geri almaması, ara mesajları atlamayan imleç, engellenen kullanıcıların sorguyla geri gelmemesi ve güncel “kaldığın yerden devam et” kartı. Dar ekranda sohbet/profil/ana sayfa metinleri mevcut genişlikte satırlara ayrılır.

## Satın alma korunması

Satın alma, StoreKit, ürün, makbuz, Premium üyelik, geri yükleme, App Store sunucu bildirimi ve kurulum kodları değiştirilmedi. Korunan 34 kaynak/test/yapılandırma dosyası Git HEAD ile normalize edilmiş içerik hash’leri üzerinden karşılaştırıldı; aynı bulundu. Tam liste `purchase-protection.log` içindedir. Paylaşılan endpoint/repository farkları yalnızca sohbet, AppContainer farkları yalnızca okuma/kütüphane bölümlerindedir. Mevcut satın alma regresyonları değişmeden geçti.

## Genel değerlendirme ve çalıştırılan doğrulamalar

Oturum yenileme/hesap değişimi, API hata ve çözümleme, güvenli indirme/dosya yolları, okuma konumu ve yazma sırası, bağlantı/bildirim yönlendirmesi ve hesap silme yolları kaynakları ve mevcut regresyonlarıyla değerlendirildi. Kanıtlanmış yeni sorun bulunmayan çalışan alanlar değiştirilmedi.

| Kontrol | Sonuç / kanıt |
|---|---|
| Çekirdek testleri | 320 XCTest geçti; `core-tests.log` |
| Temiz Release çekirdek derlemesi/testleri | 320 XCTest geçti; `core-clean-release.log`. Native iOS uygulama derlemesi değildir. |
| Gerçek ChatModel, Windows durum testleri | 11 test geçti; `chat-state-harness.log`. Test Combine modülü yalnızca depolamayı sağlar. |
| Gerçek PushNotificationManager, enjekte edilen taşıma testleri | 7 test geçti; `notification-state-harness.log`. Test Apple modülleri gerçek izin arayüzünü/APNs teslimini sınamaz. |
| Sunucu testleri | 17 PHP test dosyası geçti; `backend-final.log`. Eski/yeni istemci serializer sözleşmesi, iç içe/engellenmiş alıntılar, bildirim hedefi/izolasyonu, oturum/okuma/silme ve mevcut satın alma regresyonları dahil. |
| Strict çalışma alanı denetimi | Rota, PHP sözdizimi, HTTPS/yapılandırma, temel gizli bilgi ve statik erişilebilirlik geçti; `workspace-audit.log`. |
| Swift DEBUG/Release ayrıştırma | 93 uygulama/test, 71 Release kaynak dosyası geçti; `swift-app-syntax.log`, `swift-release-syntax.log`. Apple SDK tip denetimi değildir. |
| IosApi oluşturma/denetimi | 1.0.31 eski/yeni istemci alanları ve mevcut satın alma kontrolleriyle denetlendi; `backend-package.log`, `package-audit.log`. |
| Fark/bütünlük | `git diff --check` ve korunan dosya karşılaştırması; `diff-check.log`, `purchase-protection.log`. |

Kanıtlar `.codex-artifacts/chat-profile-recheck` ve teslim paketinin `evidence` klasöründedir. Önceki çalışmada canlı HTTPS profil, kütüphane, okuma ve sohbet okumaları doğrulandı. Bu yeniden incelemede üretimde içerik yazma, ödeme veya sunucu yükseltmesi yapılmadı.

## Eski uygulamayla kurulum davranışı

Temel sohbet okuma/gönderme alanları korunmuştur. Eski uygulamayla staging testi yapılmadan üretimde sorunsuz çalışma garantisi verilmez. Normal XenForo eklenti yükseltmesiyle rota, phrase, class extension ve listener kayıtları içe alınmalıdır; yalnız PHP kopyalamak yeterli değildir. XF 2.3+ ve MobileApi 1.0.145+ gereksinimleri korunur; bu sohbet güncellemesi yeni şema geçişi eklemez.

Kurulumla bildirim kuralları **hemen** değişir: sadece kanıtlanmış canlı oda alıntısı/ifadesi asıl yazara sohbet APNs işi oluşturur. Düz mesaj, mention, kendine etkileşim ve Siropu özel/harici sohbet bu yolu tetiklemez. Mevcut forum ve XenForo özel konuşma bildirimleri korunur. Web/Android oda olayları ortak entity listener’ından geçebilir; Android REST rotaları değiştirilmez. Ekran/profil düzeltmeleri native uygulama güncellemesi gerektirir.

## Tamamlanmamış cihaz/dağıtım doğrulamaları

Windows ortamında Xcode/iOS SDK/Simulator yoktur. Native temiz/Production derlemesi, gerçek SwiftUI/Apple Combine, ProfileReadingRefreshTests/ChatUITests ve fiziksel cihaz izin/APNs/görsel erişilebilirlik kontrolleri çalıştırılmadı. Windows testleri ve ayrıştırma bunların yerine geçmez. Uygulamanın tamamının hatasız veya App Store’a hazır olduğu iddia edilmez.

macOS üzerinde mevcut project.yml yeni kaynak/test klasörlerini otomatik içerir:

```bash
xcodegen generate
xcodebuild clean build -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Production -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Ekitapligim.xcodeproj -scheme Ekitapligim -configuration Development -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Staging’de eski uygulamada alıntı/yanıt ve sadece alıntı; güncel uygulamada tek alıntı, 320 pt/büyük yazı, klavye/yatay/iPad/VoiceOver ve profil güncellemesi kontrol edilmelidir. İki hesapla gerçek bildirim teslimi/izolasyonu, kayıt sırasında çıkış, mevcut diğer bildirimler ve değişmeyen satın alma davranışı mevcut release planıyla doğrulanmalıdır. Kurulu eklenti/veritabanı yedeği geri dönüş prosedürü için korunmalıdır.

Bu native iOS projesi APK üretemez. IPA/TestFlight için macOS ve uygun imzalama gerekir. Kaynak ZIP’i kurulabilir mobil uygulama değildir.
