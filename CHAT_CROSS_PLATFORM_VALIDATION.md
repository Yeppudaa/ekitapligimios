# Sohbet ifadeleri ve platformlar arası kontrol — 4 Ekim 2026

Bu rapor önceki `CHAT_PROFILE_STABILITY_VALIDATION.md` raporunu tamamlar. Güncel yerel sunucu adayı **IosApi 1.0.32**'dir; 1.0.30/1.0.31 paketlerinin yerine hazırlanmıştır. Bu sohbetten üretime yükleme yapılmadı. Android projesi yalnızca okundu; satın alma kodu değiştirilmedi.

## Uzak sunucuda doğrulananlar

- HTTPS üzerinden oturum açılıp iOS sohbet API'sinden 40 mesaj ve altı etkin ifade okundu: Like, Love, Haha, Wow, Sad, Angry.
- Aynı yetkili oturumla `/ios-api/v1/` ve `/mobile-api/v1/` üzerinden okunan 40 ortak mesajın ifade listeleri, sayıları ve ziyaretçi seçimi eşleşti: **0 fark**. Son sayfadaki iki mesajda kayıtlı ifade vardı.
- İlk bağımsız MobileApi denemesi HTTP hatasıyla durdu. MobileApi'nin kendi `auth/login` adresiyle yapılan takip kontrolünde ayrı oturum açma ve 40 mesajın tamamında ifade verisi okuma geçti; bu oturum da kapatıldı (`mobile-auth-read.log`). Bu, Android uygulamasının cihazdaki arayüz testinin yerine geçmez.
- Denetim oturumları kapatıldı. Günlüklere parola, token, kullanıcı adı veya mesaj metni yazılmadı. Canlı sohbet kullanıcısına deneme mesajı/ifadesi ya da bildirim gönderilmedi.

Bu sonuç, mevcut ifadelerin uzak sunucuda tutulduğunu ve iki API'den aynı okunduğunu gösterir. Yeni bir canlı ifade yazısının üç cihazda uçtan uca görüntülenmesi ve APNs/FCM teslimi henüz denenmedi; kurulu IosApi sürüm numarası bu okumadan çıkarılamaz.

## Bulunan ve giderilen sorunlar

1. **Yazma yanıtında eski ifade:** XenForo'nun önceden okunmuş `Reactions` ilişkisi değişen kayıttan sonra temizlenir. Ekleme, değiştirme ve kaldırma yanıtları kaydedilmiş seçimi döndürür. Aynı istek tekrar gelince ifade yanlışlıkla kaldırılmaz veya yeniden bildirim oluşturulmaz.
2. **Tek mesaj adresinin yanlış eşleşmesi:** Gerçek XF yönlendirici, eski kısa route adında tek mesajı genel listeye yönlendiriyordu. İç route adları `chat-message-detail` ve `chat-message-reactions` yapılarak özel adresler öne alındı. URL, parametreler, yetkilendirme ve satın alma adresleri korunur. Route üretim betiği eski adları da düzeltir.
3. **Eski mesajdaki web/Android değişikliğinin görünmemesi:** Aktif iOS sohbeti her beş saniyede yeni mesajları ve ekrandaki geçmiş penceresinin ifade durumunu yeniler. Bir geçmiş sayfası sorgulanır; mesaj başına ek istek gönderilmez. Yenileme yeni mesaj imlecini ileri atlatmaz. Eşzamanlı sorgular ve geç yanıtlar tamamlanmış yerel ifade işlemini geri alamaz.
4. **Web ifade görselleri:** Emoji dışındaki HTTPS görseller ve çoklu görsel sayfasından seçilen ifadeler için `sprite_mode`/`sprite_params` desteği eklendi. Kırpma ve ölçek hesapları test edildi; geçersiz veri sohbet çözümlemesini bozmaz.
5. **Sohbet düzeni:** Tam çok satırlı mesajlar ve profil bağlantıları korundu. İfade sayıları dar alanda alt satıra geçebilir. Büyük yazıda alıntı taslağı/giriş alanı daha az yükseklik kullanır; tam mesaj metni kısaltılmaz. İfade seçici tam yüksekliğe büyütülebilir, kaydırmayla klavye kapatılabilir; geniş ekranda okunabilir içerik genişliği sınırlandı.

Mevcut hedefli alıntı/ifade bildirim kuralları korunur. Normal oda mesajı, mention, kendine etkileşim ve Siropu özel/harici sohbet bu sohbet bildirim yolunu tetiklemez. Normal XenForo konuşma ve forum bildirimleri korunur.

## Çalıştırılan doğrulamalar

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Swift çekirdek testleri | 327 geçti | `core-tests.log` |
| Temiz Release çekirdek derlemesi ve testleri | 327 geçti; native iOS derlemesi değildir | `core-clean-release.log` |
| Gerçek ChatModel durum testleri | 13 geçti; test Combine modülü ile | `chat-state-harness.log` |
| PHP sunucu regresyonları | 17 test dosyası geçti | `backend-tests.log` |
| Gerçek XF/Siropu ifade entegrasyonu | 27 kontrol geçti: ortak kayıt, ekle/değiştir/kaldır, tekrar isteği, web `react` olayı, ziyaretçi önbelleği | `real-xf-reaction-sync.json` |
| Gerçek XF yönlendiricisi | 53 kontrol geçti; eski tek mesaj hatası aynı testte yeniden üretildi | `real-xf-chat-routes.json` |
| Route üretimi | Eksik ve eski adla mevcut sohbet adresleri doğrulandı | `route-generation.log` |
| Strict çalışma alanı denetimi | PHP/XML/JSON/rota/HTTPS, temel gizli bilgi ve statik erişilebilirlik geçti | `workspace-audit.log` |
| Swift sözdizimi | DEBUG 93, Release 71 dosya geçti; Apple SDK tip kontrolü değildir | `swift-app-syntax.log`, `swift-release-syntax.log` |
| IosApi 1.0.32 paketi | Oluşturma ve içerik denetimi geçti | `backend-package.log`, `package-audit.log` |
| Satın alma korunması | Korunan 34 kaynak/test/yapılandırma dosyası HEAD içerik hash'leriyle aynı | `purchase-protection.log` |

Gerçek XF entegrasyonları kurulu kaynak sınıflarını yükler; veritabanı bağlantısı, ağ, yapılandırılmış uygulama başlangıcı ve gerçek bildirim gönderimi kapalıdır. Depolama sınırı bellektedir. Önceki rapordaki 7 bildirim kayıt/çıkış testi bu turda değişmeyen kod için geçerli geçmiş kanıttır; yeniden çalıştırılmış gibi sayılmadı.

## Kurulum ve eski uygulama uyumluluğu

Eski istemcinin `message` alanı güvenli alıntı ve yanıtı birlikte korur. Yeni istemci ek `message_body` alanını kullanır. İfade/sprite alanları eklemelidir; eski istemci bunları yok sayabilir. Temel okuma/gönderme sözleşmesi, MobileApi 1.0.145+ bağımlılığı ve veritabanı şeması korunur. Eski uygulamanın yeni arayüz özelliklerini edinmesi için uygulama güncellemesi gerekir.

XenForo'nun normal eklenti yükseltmesiyle **1.0.32** içe alınmalıdır; yalnız PHP dosyalarını kopyalamak route/listener kayıtlarını güncellemez. Bu görev yüklemeyi yapmadı. Eski uygulamayla staging ve gerçek cihaz testi tamamlanmadan üretimde mutlak sorunsuzluk garantisi verilmez.

## Mobil paket ve kalan doğrulamalar

Bu çalışma alanı native SwiftUI iOS projesidir. Windows'ta Xcode/iOS SDK/Simulator bulunmadığından native temiz/Production derlemesi, SwiftUI UI testleri, fiziksel iOS görünüm/VoiceOver/klavye ve APNs teslim testi çalıştırılamadı. iOS kaynak ZIP'i IPA veya APK değildir.

Android için ayrı çalışmada hazırlanmış `C:/Users/Monster/Downloads/startdesign (1)/deliverables/chat-sync-design-20261003/Ekitapligim-1.2.37-test-sohbet.apk` mevcuttur. Bu turda yeniden derlenmedi; SHA-256 değeri kendi teslim manifestiyle tekrar karşılaştırıldı. Android kaynaklarına burada değişiklik yapılmadı; iOS düzeltmeleri bu APK'nın içinde değildir. Android'in ayrı test raporu 414 birim/arayüz testi, 5 emülatör testi ve 320 dp görsel kanıtını içerir; bunlar bu iOS turunda çalıştırılmış testler olarak sayılmadı.

macOS üzerinde mevcut CI veya önceki rapordaki `xcodebuild` komutlarıyla native derleme/UI testleri tamamlanmalıdır. Ardından iki test hesabıyla iOS–Android–web arasında yeni ifade ekleme/değiştirme/kaldırma, eski mesaj yenileme, hedefli alıntı bildirimi ve harici sohbetten bildirim gelmemesi doğrulanmalıdır.

Kanıt dizini: `.codex-artifacts/chat-cross-platform`; teslim dizini: `artifacts/chat-cross-platform-20261004`.
