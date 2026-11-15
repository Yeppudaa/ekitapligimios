# iOS derin inceleme — 15 Kasım 2026

Mesajlar, Kitap Gündemi ve Kitap İstekleri kaynak kodu, mevcut Android/MobileApi sözleşmesi ve uygulama modelleri birlikte incelendi. Bulunan hatalar yerel kaynakta düzeltildi. Genel uygulama için Core, hesap durumu, sohbet, profil, kütüphane, okuyucu, sesli kitap ve bildirim regresyon kontrolleri çalıştırıldı.

Bu rapor, aynı günkü [ilk tasarım çalışmasının](ANDROID_DESIGN_REFRESH_20261115.md) devamıdır. Native SwiftUI ekranları bu Windows ortamında derlenip görüntülenemedi; tam cihaz sorunsuzluğu veya App Store hazırlığı iddia edilmez.

## Düzeltilen sorunlar

| Alan | Bulgu ve yeni davranış |
|---|---|
| Mesaj içeriği | Sunucu zengin metni `message_raw` alanında gönderiyor. İstemci bu alanı öncelikli okur; eski `rich_message`, `message` ve liste `preview` değerleriyle uyum korunur. Kitap bağlantıları gerçek native detaylara gider. |
| Eski mesajlar | Detay uç noktası varsayılan olarak son sayfayı gönderiyor. “Önceki mesajları yükle” eklendi. Sayfa/konuşma kimliği doğrulanır; gelen mesajlar kimliğe göre birleştirilip zaman sırasına alınır. Aynı sayfayı tekrar döndüren sunucu, tüm geçmiş yüklenmiş gibi gösterilmez. |
| Özel mesaj görselleri | `images` ekleri mevcut izin kontrollü `conversation-detail/{id}?image_id=...` uç noktasıyla açılır. Görsel yükleme 20 MiB ile sınırlıdır; yönlendirme, çerez ve kalıcı önbellek kapalıdır. Görüntü işleme ana iş parçacığının dışında yapılır. |
| Mesaj gönderimi | Tekrarlı dokunuşlar tek işlemle sınırlandırıldı. `success=false` başarılı kabul edilmez. Gönderim sırasında yazılan yeni taslak korunur. Eski yenileme cevabı onaylanmış mesajı silemez; hesap değişince eski cevaplar atılır. |
| Mesaj listesi | Yenileme, bekleyen eski sayfalama isteğinin sonucuyla ezilmez. Kart içindeki kitap/görsel eylemleri konuşma açma eyleminden ayrıdır. On kart sınırından sonraki bağlantılar, etiketli bağlantılar dahil, metinde korunur. |
| Kitap İstekleri | Oluşturma ve oy işlemleri aynı anda tekrarlanamaz. Reddedilen oy başarılı gösterilmez. Başarısız istekte form taslağı korunur. Sunucunun aylık kota reddinde gerçek kota tekrar okunur; hak ve yenilenme tarihi uydurulmaz. Üyelik ve kota açıklamaları mevcut bilgilendirme ekranında gösterilir. |
| Kitap Gündemi | Yenileme artık sürmekte olan yorum/işlem kilidini kaldırmaz. Eski cevap yeni yorumu veya düzenlenmiş yorumu geri alamaz. Engellenen kişinin yorumları bekleyen yenilemeyle tekrar görünmez. Detaydan geçici ayrılmak sürmekte olan onayı boşa düşürmez. |
| Genel bağlantılar | Alan adının herhangi bir yerindeki `www.` metnini silen kontrol kaldırıldı. Yalnızca tam `ekitapligim.com` ve `www.ekitapligim.com` alan adları kabul edilir; büyük/küçük harf desteği korunur. |

Mesaj detayının başlığı, kartları ve yazı alanı aynı okuma odası renklerini kullanır. İş mantığı `ConversationModels`, `BookRequestsModel` ve mevcut `BookAgendaDetailModel` içinde tutulur; SwiftUI ekranları bu modelleri kullanır. Türkçe/İngilizce metin kaynakları, API belgesi, gizlilik envanteri ve sürüm notu taslağı güncellendi.

## Çalıştırılmış doğrulama

Kanıt dizini: `artifacts/deep-review-20261115/`.

| Kontrol | Sonuç |
|---|---|
| Core Debug derlemesi ve XCTest | 560/560 geçti |
| Core temiz Release derlemesi ve XCTest | 560/560 geçti |
| Sosyal modeller: mesajlar ve kitap istekleri | 13/13 geçti |
| Gündem akış/detay modelleri | 31/31 geçti |
| Sohbet | 13/13 geçti |
| Profil ve kişi dizinleri | 32/32 geçti |
| Canlı akış | 8/8 geçti |
| Kütüphane işlemleri | 12/12 geçti |
| Okuyucu/aktarım | 11/11 geçti |
| Sesli kitap gezinmesi | 6/6 geçti |
| Sesli kitap yorumları | 8/8 geçti |
| Bildirim durumu | 10/10 geçti |
| Çevrimdışı PHP backend test dosyaları | 27/27 geçti; canlı Drive kaynağı gerektiren `ReaderDriveSourceTest.php` çalıştırılmadı |
| `validate-workspace.ps1` | Başarılı: kaynak/proje denetimi, temel gizli bilgi taraması, statik erişilebilirlik, kaynak dosyaları ve PHP sözdizimi |
| Swift sözdizimi | 332 dosya DEBUG tanımlı ve tanımsız ayrıştırıldı |
| Native çalıştırıcı | Bash sözdizimi ve seçilen 38 testin kaynak sayısı doğrulandı |
| Korunan dosyalar | 241 SHA-256 karşılaştırması / 0 değişiklik |

Core test sayısı gerçek XCTest yürütmesinden alınır. Ayrı Swift Testing çalıştırıcısının “0 tests” mesajı, XCTest sonuçlarını geçersiz kılmaz. Windows SDK/test stub uyarıları native iOS doğrulaması yerine geçmez.

144 uygulama modeli testi gerçek model kaynaklarını kullanır; Windows için Combine yayın davranışı yerine yalnızca değer tutan bir uyumluluk katmanı vardır. Bu testler Apple Combine, UIKit, SwiftUI düzeni veya cihaz etkileşimini doğrulamaz. Sesli gezinme testi de gerçek yönlendirme yöntemlerini kullanır, native geri hareketini çalıştırmaz.

## Canlı, salt okunur kontroller

Genel kitap API'si, yasal/destek sayfaları ve universal-link ilişkilendirmesi kontrol edildi. Kitap istekleri, gündem, gündem medya yetenekleri ve kitap listesi GET istekleri HTTP 200 döndürdü. Gündem medya sözleşmesi artık `image_upload_version=1` bildiriyor. Bu, eski rapordaki eksik yetenek göstergesinin güncel gözlemidir; kimlik doğrulamalı fotoğraf yüklemesinin kanıtı değildir.

Gerçek kullanıcı hesabından mesaj gönderilmedi, kitap isteği oluşturulmadı, oy verilmedi ve paylaşım yapılmadı. Özel mesajların canlı hesap izinleri, gerçek ağda görsel açılması ve kimlik doğrulamalı kota davranışı bu oturumda uçtan uca sınanmadı; bunların yerel sözleşme/taşıma/model testleri geçti.

## Korunan satın alma alanı

Satın alma, StoreKit, Premium, abonelik, backend, AppContainer, proje yapılandırması, entitlement ve privacy manifest dosyalarının başlangıç SHA-256 değerleri karşılaştırıldı: **241 dosyada sıfır değişiklik**. Ürün kimliği, fiyat, makbuz doğrulama, satın almayı geri yükleme ve üyelik hesabı değiştirilmedi. Gerçek satın alma çalıştırılmadı. TestFlight/App Store yüklemesi veya sunucu dağıtımı yapılmadı.

Yeni kaynaklar mevcut dizin tabanlı proje tanımınca kapsanıyor; ek bağımlılık, entitlement veya gizlilik kategorisi gerekmiyor.

## Kalan doğrulama

Bu ortamda `xcodebuild`/XcodeGen yok. GitHub CLI oturumu da açık değil. Güncel SwiftUI hedefinin Apple SDK ile derlenmesi, gerçek ekran görüntüleri, VoiceOver, klavye/geri gezinmesi, iPhone/iPad düzeni ve dokunma akıcılığı henüz doğrulanmadı.

`Scripts/reading-room-macos.sh`, temiz Development ve imzasız Production derlemelerini; iki iPhone ve bir iPad üzerinde cihaz başına 38 native/UI kontrolünü hazırlar. Özel mesaj sayfalaması/görseli, sosyal modeller, gündem yorum yarışları, kitap önizlemesi, kota ekranları, büyük yazı ve gündem kartlarını kapsar. Eksik, atlanan veya başarısız testi başarı saymaz ve görsel inceleme için ekran görüntülerini dışa aktarır. **Bu script macOS'ta çalıştırılmış değildir.**

Önceki genel yayın kontrol listesindeki cihaz, oturum açma ve APNs kapıları bu yerel incelemeyle kapanmış sayılmaz. Satın alma alanı kullanıcının talebi doğrultusunda korunmuştur.

## İkinci inceleme turu (aynı gün, ayrı oturum)

Bugünkü tüm değişiklikler (Core, uygulama modelleri, SwiftUI ekranları, test ve belge güncellemeleri) satır satır yeniden okundu; iOS sunucu eklentisinin kalıtım zinciri (`IosApi\Conversations` → `MobileApi\Conversations`) ve ham görsel yanıtının `filterConversationReply`/`PublicEndpointTrait` içinden bozulmadan geçtiği doğrulandı.

- Düzeltme: Mesaj detayında tek uyarı penceresi hem yanıt hatasını hem "önceki mesajları yükle" hatasını gösteriyordu; başlık her durumda "Mesaj gönderilemedi" idi. Başlık artık hatanın türüne göre seçiliyor.
- App hedefi Windows'ta derlenemediği için değişen/yeni 12 uygulama dosyasında kullanılan `L10n` üyeleri, `ReadingRoom/CommunityDesign/CommunityRefresh/AgendaMedia` anahtarları (tr/en birebir), görsel varlık adları, `AppContainer` üyeleri, özel görünüm değiştiricileri ve proje tipleri betikle çapraz kontrol edildi: eksik yok.
- Canlı salt-okunur kontrol: `ios-api/v1/book-requests` artık `request_quota` döndürüyor; `conversation-detail/{id}?page=`/`?image_id=` uçları yetki istiyor (401 JSON), yani yönlendirme çalışıyor. Mesaj görseli/sayfalama için MobileApi 1.0.160'ın canlıda kurulu olması gerekir; kurulu değilse uygulama görsel yerine "yüklenemedi" gösterir ve sayfalama düğmesi görünmez.
- Yeniden çalıştırılan doğrulama: Core XCTest, `swift-static-audit.ps1`, sosyal ve gündem Windows model harness'leri, 151 backend PHP dosyası sözdizimi, korunan 241 satın alma/yapılandırma dosyası SHA-256 (0 değişiklik).
- Satın alma: `StoreKitPurchaseService`, Core satın alma politikaları, `AppStoreVerify`, `AppStoreNotifications`, `AppStoreTransactionStore`, `AppStoreEntitlementPolicy`, `IosEntitlement` ve `IosMembershipSynchronizer` okundu; hata bulunmadı, değişiklik yapılmadı.

## Profilim derin incelemesi (aynı gün)

İncelenen: `ProfileView`, `ProfileEditView`, `ProfileEditorModel`, `ProfilePhotoLoader`, `ProfileSharedComponents`, `ModernProfileBooksSection`, `AccountSecurityView`, `DeleteAccountView`, `SettingsView`, `PrivacySettingsView`, `BlockedMembersView`, `MyCommentsView`, `MyAudioComments*`, `StatsView`, `GuestProfilePrompt`; sunucuda `MobileApi\Me` (canlı `ios-api/v1/me` rotası buna gider), `IosApi\MeMedia`, `MeReadingStats`, `AccountDeletionRequest`.

| Bulgu | Etki | Düzeltme |
|---|---|---|
| Profilim'deki "Hesap silme talebi" isteği şifresiz gönderiyordu; sunucu şifreli hesaplarda `current_password_required` döndürür | Şifreyle giriş yapan kullanıcılarda talep her zaman başarısız | Buton artık şifre + onay metni isteyen `DeleteAccountView` ekranını açıyor (Ayarlar'daki akışla aynı) |
| "Gönderiler" sekmesi hesap değişince temizlenmiyordu | Başka hesapla girişte önceki kullanıcının forum gönderileri görünebiliyordu | Oturum değişince sekme verisi sıfırlanıyor; geç gelen yanıt yeni oturuma yazılmıyor |
| Gönderi yükleme hatası "gönderi yok" olarak gösteriliyordu | Yanıltıcı boş durum | Hata ve "Tekrar dene" gösteriliyor |
| Etkinlik sekmesi yalnızca ilk açılışta yükleniyordu | Hesap değişince önceki üyenin etkinliği kalıyordu | Liste üye kimliğine bağlandı |
| Profil kaydında web sitesi şemasız gönderiliyordu; sunucu `profile_website_invalid` ile reddediyor | "www.site.com" yazan kullanıcının tüm profil değişiklikleri kaydedilmiyordu | Şemasız alan adına `https://` ekleniyor; birim testi eklendi |
| Yorumlarım ham BBCode/HTML ve İngilizce teknik hata metni gösteriyordu | Okunaksız içerik | Düz metin + yerelleştirilmiş hata |
| Engel kaldırma hatası tüm listeyi hata ekranına çeviriyordu; çift dokunma korunmuyordu | Liste kayboluyordu | Hata uyarı penceresinde; işlem sürerken buton kapalı |

Doğrulanan ve doğru çalışanlar: profil düzenleme/fotoğraf yükleme parametreleri (`about`, `location`, `website`, `activity_visible`, `image`), e-posta/şifre değiştirme (`current_password`, `email`, `new_password`), günlük hedef (`daily_goal_minutes`, 10–240), hesap değişiminde düzenleyici/sesli yorum oturum korumaları, istatistik kaydırıcısının kayıt sırasında kilitlenmesi.

Çalıştırılan: `profile-directory-state-test-windows.ps1` 33/33 (yeni web sitesi testi dahil), değişen 5 dosya için Swift ayrıştırma (DEBUG'lı/DEBUG'sız), sembol/anahtar çapraz kontrolü (0 eksik), korunan 241 satın alma/yapılandırma dosyası (0 değişiklik). Native SwiftUI derlemesi ve cihaz testi macOS gerektirir.

## Kitap detayı, okuma ve indirme incelemesi (aynı gün)

Kullanıcı talimatı: indirme akışı ve okuma yapısı bozulmayacak. Bu nedenle bu alanda yalnızca okundu, sözleşme ve testlerle doğrulandı; okuma/indirme koduna dokunulmadı.

İncelenen: `BookDetailView`, `BookDetailLoadingModel`, `ReaderView` (PDF okuyucu, önizleme sınırı, yer imleri, sayfa seçici, ayarlar), `DownloadManager`, `ReaderContentLoader`, `DownloadsView`, `ReaderProgressSync`, `ReaderPosition`, `DownloadAccessPolicy`; sunucuda `ReaderProgress` ve `BookComments`.

Doğrulananlar:
- Okuma hakkı yerel kopya varken bile sunucuda sayılıyor; her asenkron adımda nesil/oturum kontrolü var; geçici okuma dosyaları kapanışta siliniyor.
- İndirme: geçici klasöre indirme → içerik doğrulama → dosya koruması + yedekten hariç → atomik taşıma. Geçerli çevrimdışı kopya başarısız yeni istekle silinmiyor.
- Okuyucu tam ekran açıkken detay modelinin `cancel()` çağrısı kitabı temizlemiyor; okuyucu içeriği kaybolmaz.
- Kitap yorumları sunucuda temizlenmiş metin olarak geliyor.

Tek değişiklik: "Benzer kitaplar" başlığındaki, gidecek ekranı olmayan ve dokunulamayan "Tümünü gör ›" etiketi kaldırıldı. `artifacts/reader-review-20261115/reader-before.json` ile 31 okuma/indirme dosyası karşılaştırıldı: yalnızca `BookDetailView.swift` değişti (bu başlık).

Bilinçli olarak dokunulmayan, raporlanan davranışlar:
1. Kayıtlı okuma konumu geçersizse veya dosya türüyle uyuşmuyorsa (ör. kitap sunucuda PDF'ten EPUB'a değiştiyse) okuyucu kitabı açmaz ve hata gösterir. Bu, kullanıcının diğer cihazdaki konumunu 1. sayfayla ezmemek için verilmiş belgelenmiş bir karardır (`READING_SYNC_VALIDATION.md`). Böyle bir kayıt oluşursa sunucu tarafında düzeltilmesi gerekir.
2. Premium olmayan ve sunucunun indirmesine izin verdiği bir kullanıcıda indirme oturumu ağ hatasıyla başarısız olursa "Premium gerekli" uyarısı görünür; mesaj yanıltıcı olabilir ama akış değiştirilmedi.
3. İndirilenler ekranı kitapları adıyla değil "Kitap #ID" olarak listeliyor ve silme yalnızca uzun basmayla açılıyor.

Çalıştırılan: `reader-transfer-test-windows.ps1` 11/11, `library-mutation-state-test-windows.ps1` 12/12, Core okuma/indirme/EPUB/ilerleme testleri 117/117, değişen dosya için Swift ayrıştırma. Satın alma koruması 241/0.

### Okuma/indirme: raporlanan 3 noktanın düzeltilmesi (kullanıcı onayıyla)

1. **Kullanılamayan kayıtlı konum artık kitabı kilitlemiyor.** Kayıtlı konum geçersizse, dosya türüyle uyuşmuyorsa (`ReaderView`) veya EPUB dosyasında bulunamıyorsa (`EPUBReaderView`: konum çözümleme ve sayfa içi geri yükleme), kitap hata yerine baştan açılır ve "Kaldığın yer bu kitap dosyasında bulunamadı…" bilgisi 6 saniye gösterilir. Kayıt koruması sürer: PDF ve EPUB açılışta konum yazmaz (PDF `lastPage` geri yüklenen sayfadır; EPUB başlangıç çapasını sunucuya yazmadan kurar). Sunucudaki kayıt yalnızca kullanıcı sayfa değiştirdiğinde güncellenir. `EPUBPositionAdapter`, `ReaderProgressSync` ve konum yazma yolları değişmedi; `EPUBReaderPositionTests` adaptörün hata fırlatmasını doğrulamaya devam eder.
2. **İndirmede bağlantı hatası artık "Premium gerekli" göstermiyor.** İndirme oturumu `URLError`, HTTP 5xx veya 408 ile başarısız olursa bağlantı mesajı gösterilir; diğer durumlarda önceki davranış aynıdır.
3. **İndirilenler ekranı:** kitap adı (önce kütüphane, yoksa herkese açık katalog; çevrimdışıyken numara), satıra dokununca kitap detayı, görünür ve onaylı "Sil" düğmesi. Silme mevcut `DownloadManager.remove` ile yapılır.

Değişen okuma/indirme dosyaları: `BookDetailView`, `DownloadsView`, `ReaderView`, `EPUBReaderView`. Değişmeyen 27 dosya arasında `DownloadManager`, `ValidatedBookFileTransfer`, `ReaderContentLoader`, `ReaderProgressSync`, `EPUBPositionAdapter` ve tüm Core okuma/indirme politikaları var. Doğrulama: Core 560/560, okuyucu aktarım 11/11, kütüphane 12/12, 4 dosya Swift ayrıştırma, sembol kontrolü 0 eksik, satın alma 241/0. Native derleme ve cihazda EPUB/PDF açma macOS gerektirir.
