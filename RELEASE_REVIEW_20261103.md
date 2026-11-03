# Genel yayın incelemesi — 3 Kasım 2026

**Henüz yayın onayı yok.** Bugünkü okuyucu geçişi, misafir/giriş, mesajlar/üyeler/profil, profil düzenleme, dizinler, canlı akış, bildirimler, gündem fotoğrafları ve premium çerçeve ile ortak oturum/ödeme/okuma altyapısı inceleniyor. Eski tarihlerde geçen testler güncel kaynak için otomatik onay sayılmıyor.

## Bulunan ve düzeltilen sorunlar

1. Fotoğraflı paylaşım iki istek kullanırken arada hesap değiştirilirse eski taslak yeni hesaba gönderilebiliyordu. Yeni regresyon önce bu POST'u gerçekten yakaladı. Yükleme başlatan oturuma bağlandı; hesap değişimi/çıkış gönderimi kesiyor, aynı oturumun doğrulanmış token yenilemesi çalışıyor.
2. Gerçek Xcode 26.3 derlemesi `ProfilePhotoLoader` içinde `PhotosPickerItem` türünün bulunamadığını gösterdi. Eksik SwiftUI importu düzeltildi. Sonraki derleme okuyucu test ekranının salt okunur `accessibilityReduceMotion` ortam değerine yazdığını yakaladı; test için hareket tercihi bağımlılığı eklendi, gerçek kullanım sistem tercihini izlemeye devam eder. Avatar yerleşim testindeki aynı geçersiz atama da durağan sahneyle değiştirildi. Windows sözdizimi testinin native derleme yerine geçmediği somut olarak doğrulandı.
3. Uzun premium adlarında iki satır sınırı sonda yer alan onay rozetini kesebiliyordu. Kendi profili ve üye satırında premium adın tamamının satıra yayılmasına izin verildi.
4. Eski genel denetim betiği, kayıtlı kimlik bilgilerini yazma testleri için otomatik yetki sayıyordu. Artık yazmalar ayrıca `-ExerciseMutations`, canlı alan adı da `-AllowProductionMutations` istiyor. Salt okunur akış ziyaret/şart kabulü/presence/mesaj okundu kaydı üretmiyor. Sahte HTTP ile iki betiğin üretim koruması doğrulandı.
5. Sesli kitap yönlendirme test yardımcısı yeni katalog-arama durumunu içermediği için derlenmiyordu. Yardımcı güncellendi, altı gerçek yönlendirme testi geçti.
6. DEBUG test giriş verisindeki eski yasal bağlantılar metadata ön kontrolünü bozuyordu; mevcut yasal URL'lerle eşitlendi.
7. Üç xcconfig dosyasındaki eski sürüm değerleri kaldırıldı; tek kaynak `project.yml`. Codemagic'in gerçek Apple sorgusunda App Store ve TestFlight son sürümü **1.1.1/build 49**, yeni aday **1.1.2/build 50** olarak doğrulandı. Dağıtım CI'sı her iki kanalın bütün sürümlerindeki en yüksek build numarasını imzalamadan önce tekrar sorgular; kullanılan numara bunların ve kaynak alt sınırının üstünde olur. İmzalı IPA denetimindeki eski sabit 1.1.1 koşulu da aynı kaynağa bağlandı.
8. Xcode 16.4'e bağlı eski CI seçimi güncellendi. Ayrı, yayın yapmayan tam inceleme akışı Xcode 26+ seçer, temiz Development/Production derlemesi ve iki iPhone/iPad'de bütün native/UI sınıflarını çalıştırır. [Apple SDK koşulu](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).
9. Eski smoke betiği PUT gövdesinin içerik türünü belirtmiyordu. Gerçek yardımcıyı sahte HTTP ile çağıran regresyon önce başarısız oldu; uygulamayla aynı UTF-8 form başlığı eklendikten sonra geçti. Salt okunur koruma testi de tekrar geçti. Önceki canlı HTTP 400 yanıtının yalnızca bundan kaynaklandığı kanıtlanmış değildir; canlı yazma tekrarlanmadı.
10. Fotoğraf UI test sunucusu yalnızca canlı alan adını tanıyordu; Development derlemesinin `.local.invalid` adresinde kabiliyet ve resim istekleri yanlış genel JSON yanıtına düşüyordu. Test sunucusu üç yapılandırılmış HTTPS adresiyle eşitlendi. Üç yeni sözleşme testi (gerçek URLSession multipart dahil) Windows ve Apple URLSession üzerinde geçti; tam UI tekrar kontrolü bekleniyor.
11. Premium piksel testindeki dikey çevirme, üstteki sabit kitap yerine alttaki hareketli kenarı örnekliyordu. Çevirme kaldırıldı ve üst/alt kontrolü eklendi. Ses süre testinin zorunlu senkron tanılama kayıtları kaldırıldı; iki saniyelik performans sınırı korundu. Büyük yazıda kütüphane testinin kartın tümünü ekrana sığdırma koşulu, görünür ve dokunulabilir merkez kontrolüne dönüştürüldü. Bu native test düzeltmelerinin sonucu henüz doğrulanmadı.
12. Codemagic için elle başlatılan `ios-release-review` eklendi: aynı commit üzerinde native, küçük/büyük iPhone ve iPad grupları seçilebilir. Yayın adımı yoktur. Kullanım: `CODEMAGIC_RELEASE_REVIEW.md`. Codemagic üzerinde henüz çalıştırılmadı.
13. Codemagic'teki ilk salt okunur sürüm kontrolü, eski `Ekitapligim Codemagic 3` bağlantısının bulunmadığını gösterdi. Hesapta var olan `Ekitapligim Codemagic` bağlantı adıyla üç ilgili workflow eşitlendi; yeni anahtar oluşturulmadı veya yetki genişletilmedi. Sonraki kontrol 1 dakika 6 saniyede başarılı oldu. Yedi yerel sürüm regresyonu geçti; okunamayan/bozuk Apple yanıtı eski bir numaraya sessizce düşmez.

8217603 native sonuç paketi indirildi: 266 testten 264'ü geçti; yalnızca iki avatar piksel testi başarısız (52 assertion). Ses hesap değiştirme testi bu çalışmada 1,257 saniyede geçti. Orijinal PNG'lerde iki animasyon fazı karşılaştırıldığında sabit kitap ve fotoğraf açıklığında değişen piksel yok. Küçük avatar testindeki ikinci sorun, piksel merkezlerini yuvarlamanın sağ ve sol örnekleri asimetrik yapmasıydı; örnekler simetrik seçildi, dekoratif parıltının içinden alındı ve ayrıca gerçek opak fotoğrafın merkezi/çapı ölçülüyor. Dört boyutun PNG analizi geçti; Apple testinin tekrarı bekleniyor. Bu son değişiklik yalnızca test ve CI seçimidir; uygulama davranışı değişmedi.

İndirilen native renderlarda yazar/yayınevi görselli başlıkları ve uzun satırlar (284/354/724 genişlik, normal ve erişilebilir yazı), topluluk başlığı, premium ad/çerçeve ve okuyucu geçişinin örnek kareleri incelendi. İncelenen bu bileşenlerde kesilme/taşma görülmedi; bu değerlendirme tam sayfa UI gezinme ve fiziksel cihaz kontrolünün yerine geçmez.

## Çalıştırılmış kanıtlar

Yerel ayrıntılar `.codex-artifacts/release-review-20261103/` içinde; kimlik bilgileri ve test verisi gövdeleri rapora alınmadı.

| Kontrol | Gözlenen sonuç |
| --- | --- |
| Swift Core, Windows normal | 538 test geçti |
| Swift Core, Windows temiz optimize | 538 test geçti |
| Swift Core, macOS/Xcode 26.3 | 538 test geçti |
| Temiz native Development derlemesi | Xcode 26.3 ile `8217603` kaynağında yeniden geçti (`2026-11-03T11:14:33Z`) |
| Temiz native Production derlemesi | Xcode 26.3 ile `8217603` kaynağında imzasız cihaz derlemesi geçti (`2026-11-03T11:20:50Z`); imzalı arşiv/dağıtım kanıtı değildir |
| Taşınabilir uygulama modelleri/sözleşmeleri | 127 test: gündem 27 (üç yeni medya test sözleşmesi dahil), profil/dizin 32, bildirim 10, canlı akış 8, kütüphane 12, sesli yorum 8, sesli yönlendirme 6, sohbet 13, okuma aktarımı 11 |
| Sunucu sözleşmeleri | 29 PHP paketi geçti; ReaderDriveSource gerçek yerel kurulu ExternalEbook doğrulayıcısıyla sınandı. HTTP/veritabanı kullanılmadı; canlı sunucudaki kaynakla eşitlik kanıtı değildir |
| Sunucu paket kimliği | Hazır IosApi 1.0.40 ZIP'indeki 161 dosya güncel kaynakla aynı; SHA-256 `591a880afa12ef12560e1e3a49d48d42a5711f70662f90eb8013bae19887792a` |
| Sözdizimi | 317 Swift dosyası normal ve DEBUG ayrıştırıldı |
| Statik kontroller | Workspace, temel gizli bilgi taraması, erişilebilirlik etiketleri, metadata ön kontrolü, YAML/bash sözdizimi ve diff kontrolü geçti |
| Canlı genel HTTPS | Destek, gizlilik, kurallar, kitap API'si ve AASA geçti |
| Canlı C harfi sorgusu | İlk sayfa 11 eşleşme/317 ms; ikinci sayfayla 30 eşleşme/464 ms. Tek bilgisayar ölçümü, cihaz performans garantisi değil |
| Canlı üyeler | Mevcut `is_premium` ve `role_type` alanları doğrulandı; dekorasyon için yeni sunucu alanı gerekmiyor |

Taşınabilir model testleri Apple Combine/SwiftUI'ı taklit eden saklama yardımcıları kullanır; gerçek Apple framework, cihaz veya APNs kanıtı değildir. İlk iki macOS derlemesinde bulunan import/test ortamı hataları düzeltildikten sonra temiz Development derlemesi geçti. GitHub'ın gecikmeli ara logları önce imzalamada bekleme olarak yorumlandı; tam loglar bu yorumu çürüttü. İptal edilen 41621590518 çalışmasında native testler bitmişti: 266 testten 263'ü geçti, üç testte 53 assertion başarısız oldu (iki avatar piksel testi ve ses oynatıcı hesap değişimi süre testi). UI testlerinde de fotoğraf paylaşımı ve görünürlük hataları görüldü. Bunlar başarılı sayılmadı; sonuç paketleriyle yeniden inceleniyor. Global paket imzalama zorlaması kaldırıldı, test uygulamasının ad-hoc kimliği ve Keychain entitlements dosyası korundu. Yeni çalışma işlem adlarını/CPU sürelerini kaydeder ve Production derlemesini testlerden önce çalıştırır.

Kod [ayrı inceleme dalında](https://github.com/Yeppudaa/ekitapligimios/tree/codex/release-review-20261103). İlk native hata [çalışma 41618242757](https://github.com/Yeppudaa/ekitapligimios/actions/runs/41618242757) içinde saklandı. 8217603 derleme/test kanıtı [41623814220](https://github.com/Yeppudaa/ekitapligimios/actions/runs/41623814220) içindedir. Test düzeltmeleri ve Codemagic akışını içeren 4c30106 kaynağının tam incelemesi: [41626715451](https://github.com/Yeppudaa/ekitapligimios/actions/runs/41626715451). Tamamlanmamış çalışmalar tam test başarısı sayılmaz.

7b3cf10 son avatar ölçüm düzeltmesi için [native tekrar çalışması](https://github.com/Yeppudaa/ekitapligimios/actions/runs/41628975223) başlatıldı. Bu çalışma yalnızca native grubu içerir; diğer cihaz gruplarının yerine sayılmaz.

4c30106 sonuç paketi de indirildi: **270 native testten 268'i geçti**. Kalan iki test avatar kenar örneklemesi ve yeni üst/alt renk kontrolüdür. Kenar örneklemesi 7b3cf10'da düzeltildi. Renk kontrolü semantik SwiftUI kırmızı/mavi renklerini saf RGB sanıyordu; koordinat kalibrasyonu için açık sRGB ana renkleri kullanıldı. Üretim çerçevesi değiştirilmedi. 2653f5b kaynağındaki [native tekrar](https://github.com/Yeppudaa/ekitapligimios/actions/runs/41632459633) henüz sonuçlanmadı.

**Gerçek Codemagic sürüm kontrolü başarılı:** [6ae9cd9957e81944fbc19941](https://codemagic.io/app/6a5221a644ecae83eeea61ec/build/6ae9cd9957e81944fbc19941). Kaynak `2653f5b4561162726a755da3f223968a0314b0ba`; App Store 1.1.1 `READY_FOR_SALE`; her iki kanalın son build'i 49; sıradaki aday 1.1.2 (50). `version-plan.json` indirildi ve ekran kanıtı yerel denetim klasörüne kaydedildi. Bu çalışma imzalama, TestFlight yüklemesi veya mağaza gönderimi yapmadı.

## Açık yayın koşulları

- Güncel kaynağın native Development/Production derlemesi, tüm UI/native testleri ve ekran görüntülerinin incelenmesi tamamlanmalı.
- Canlı `book-agenda?media_capabilities=1` sorgusu sürümlü fotoğraf kabiliyeti yerine eski akış yanıtını verdi. IosApi 1.0.40'ın izinler, saklama, moderasyon ve silme davranışıyla staging'de kurulup sınanması gerekiyor. Yapılandırılmış staging alan adına erişilemedi. Paket hazır olması kurulum kanıtı değildir.
- İmzalı iPhone'da gerçek APNs popup, fotoğraf seçimi/HEIC/iCloud, profil yükleme, Google oturumu, okuyucu ve VoiceOver kontrolü yapılmalı. Yerel bildirim tanısı APNs teslimatını kanıtlamaz.
- Son imzalı build için Sandbox satın alma/geri yükleme, hesap silme ve ilgili Apple mağaza bilgileri doğrulanmalı.
- Kullanıcı son açıklamasında Apple girişinin hazır olmadığını ve eklenmesini istemediğini belirtti. Google girişi korundu. Mevcut kaynakta 4.8'in istediği eşdeğer gizlilik odaklı alternatif veya doğrulanmış istisna bulunmadığından inceleme riski açık. [Apple 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services).
- Yeni şartları otomatik kabul etmeyen salt okunur giriş denemesi HTTP 403 aldı; bu sonuç kimlik doğrulamalı canlı işlevlerin geçtiği şeklinde raporlanamaz.

Eski `parity-audit.ps1` güncel mimari/renk/sekme düzenini tanımayan regex iddiaları, eski rotalar ve kendi Swift ortamı nedeniyle hatalar raporluyor. 1.0.33–1.0.35'e özel legacy paket kapısı da 1.0.40 için uygun değil; bu kontroller geçilmiş sayılmadı ve başarılı göstermek için gevşetilmedi. Yeni tam native ve güncel sözleşme testlerinin sonuçları esas alınmalı; server/staging uyumluluğu ayrıca doğrulanmalı.

## Denetim sırasında oluşan yan etki

Eski parity betiğini çalıştırırken otomatik yazma davranışı önceden fark edilmedi. Yerel olarak yapılandırılmış test hesabıyla canlı sunucuda profil ziyareti, şart kabulü, presence ve okuyucu oturum kayıtları oluştu; 39444 numaralı kitabın ilerlemesine `%1 / sayfa 1` yazıldı. Sonraki kütüphane isteği HTTP 400 verdiği için yorum/sohbet/gündem/forum paylaşımı aşamasına ulaşılmadı. Bu durum kullanıcıya açıklandı. Önceki ilerleme bilinmediğinden tahmin ederek geri yazılmadı. Tekrarını engelleyen varsayılan salt okunur davranış ve regresyon testi eklendi.

Bu inceleme sunucu kurmadı, TestFlight yüklemedi ve App Store'a göndermedi. Kaynak/CI başarısı tek başına mağaza yayınına hazır olunduğu anlamına gelmez.
