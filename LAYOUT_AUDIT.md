# Uygulama genelinde dar ekran ve metin yerleşimi incelemesi

Ana sayfa kitaplarının dikey uzaması için ek düzeltme ve test kapsamı: [HOME_BOOK_CARDS_VALIDATION.md](HOME_BOOK_CARDS_VALIDATION.md). Yeni kapak alanı görsel fazlarından bağımsız ölçülür; eski sınırsız yükseklik kaldırılmıştır. Güncel `layout-audit-macos.sh`, menü opaklık testleri dahil cihaz başına 11 bileşen ve 11 UI testi ister; aşağıdaki önceki sayı ve sonuçlar tarihsel kapsamı anlatır. Yeni native testler Windows üzerinde çalıştırılmadı.

Tarih: 18 Ekim 2026.

## iOS 26 menü düğmesindeki iç içe zemin — ek düzeltme

Profil ve Kitap Gündemi kullanıcı görüntüleri, özel menü karesinin iOS 26'nın paylaşılan cam araç çubuğu zeminine yerleştirildiğini gösteriyor. Yenileme gibi yan eylemler aynı kapsülde gruplanabiliyordu. [Apple'ın ToolbarContent belgesine](https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:)) uygun olarak ortak `EKitapligimMenuToolbarItem` bu zemini yalnız menü öğesinde gizler ve menüyü ayrı gruba alır. Katalogun doğrudan ToolbarItem kullanımı da bu ortak bileşene taşındı. iOS 26 çalışma zamanı ve Swift 6.2 derleyici koşulları, iOS 17 hedefini ve eski Xcode/SDK derlemesini korur.

Ana sayfa, Kitaplar, Kitap Gündemi, Canlı Akış, İstekler, Profil ve Forum aynı 44×44 pt menü yüzünü kullanır. Yüz tamamen opak beyazdır; dış çerçeve/gölge katmanı yoktur, köşeler 14 pt'dir. Bildirim noktası yüzün içinde kalır ve okunmamış sayı erişilebilirlik değeriyle bildirilir. Ana sayfanın özel başlığı ve diğer sayfaların native gezinme yerleşimi korunur.

Mevcut dört `ShellMenuLayoutUITests` senaryosu güçlendirildi: yedi kök sayfada tek menü, 44–48 pt sınır, komşu eylemlerden ayrı dokunma alanı ve çekmece öncesi/sonrası görseller denetlenir. İki yeni `MenuButtonAppearanceTests` testi gerçek ortak yüzü kırmızı/mavi zemin üstünde çizer; opak iç yüzeyi ve dışa taşan halka/gölge/bildirim noktası olmamasını denetler, sekiz inceleme görseli ekler. Native toolbar camını ancak gerçek shell UI görüntüleri doğrular. Bu testler Windows'ta çalıştırılmadı; özellikle iOS 26 native cam zemininin kalktığı simülatör/cihaz görüntüsüyle doğrulanmalıdır. Swift sözdizimi ve statik erişilebilirlik/Swift denetimleri geçti; bu kontroller native görünüm kanıtı değildir.

## Menü ile sayfa eylemlerinin çakışması — ek düzeltme

Son kullanıcı görüntüsündeki Canlı Aktivite yenileme düğmesini ortak menü örtüyordu. `RootView` içindeki mutlak sağ üst menü katmanı kaldırıldı; `ShellMenu.swift` aynı görsel düğmeyi gezinme çubuklarının ölçülen araçlarına ekler. Ana sayfanın gizli gezinme çubuğu korunur; menü gerçek logo/Premium satırında ayrı bir çocuktur. Katalog, Forum, Gündem, Canlı Aktivite, İstekler ve Profil yerleşimleri; bu alanlardan açılan filtreli katalog, kitap detayı, konu ve konuşma yolları kaynak üzerinden incelendi. Eski Home 58 pt ve kitap detayı 78 pt menü rezervleri kaldırıldı. Sayfa eylemleri, paylaşım/geri işlevleri ve kimlik doğrulama akışları korunur.

`ShellMenuLayoutUITests` dört native test içerir: normal ve erişilebilirlik yazısında yedi kök sayfada gerçek menü/eylem çerçevelerinin ayrılığı ve erişimi; Canlı Aktivite'de yenileme/kaydırma/menü aç-kapat; Ana sayfa → filtreli katalog → kitap detayı üst eylemleri. Yeni `MODERN_PARITY_SHELL_NAVIGATION=1` yalnız DEBUG çevrimdışı fixture seçeneğidir; önceki bağımsız ekran fixture'ları değişmez. `layout-audit-macos.sh` iPhone 11/13 üzerinde dört önceki layout testine bu dört testi ekleyerek tam sekiz başarılı, sıfır atlanan UI testi gerektirir.

Bu ek çalışma sırasında derleme, native test veya simülatör çalıştırılmadı. Aşağıdaki önceki kontrollerin sonuçları bu menü düzeltmesinin doğrulandığı anlamına gelmez. Yeni UI testlerinin çalışması ve ekran görüntülerinin incelenmesi bekler.

## Sonuç ve kanıt sınırı

Ana ekranlar, bu ekranların kartları, ortak tasarım bileşenleri, okuyucu, oynatıcı ve hesap formları kaynak kodu üzerinden ayrıntılı incelendi. Dar alanda metni sıkıştıran satırlar, büyüyen metni kesen sabit yükseklikler ve bazı üst üste binme riskleri düzeltildi. İnceleme 320, 375, 390 ve 414 pt portre genişliklerini ve normal yazıdan erişilebilirlik yazı boyutlarına kadar olan yerleşimleri dikkate alır. iPhone 13 ve iPhone 11 için hazırlanan native doğrulama ayrıca bu cihazları adlarıyla seçer.

**Bu sonuç, iPhone üzerinde bütün ekranların taşmadan çalıştığının doğrulanması değildir.** Bu bilgisayarda Windows ve Swift sözdizimi denetleyicisi var; Xcode, iOS SDK ve simülatör yok. Ekran görüntüleri bu çalışma sırasında iOS üzerinde üretilmedi. Kaynak incelemesi, sözdizimi kontrolü veya dış ScrollView sınırının doğru olması tek başına içerideki her metnin kesilmediğini kanıtlamaz.

## İncelenen alanlar ve düzeltmeler

| Alan | Bulunan risk ve yapılan düzenleme |
| --- | --- |
| Ana sayfa | Sabit arama yüksekliği minimum yüksekliğe dönüştürüldü. Gündem kartları üç satırlık kompakt önizleme gösterir; tam içerik mevcut detayda açılır. Büyük yazıda kapak/metin bölümleri dikeyleşiyor. Görsellerin ve dekoratif ikonların sınırları korunuyor. |
| Katalog | Küçük üst etiket büyütüldü. Sıralama seçenekleri sıkışan segmented görünümden inline seçeneklere alındı. Liste kartlarında normal yazıda kategori/sayfa bilgisi tek satırda eşit alan kullanıyor; erişilebilirlik yazısında alt alta geçiyor. |
| Kitap detayı | Dar alanda kapak ve bilgi bölümü dikeyleşiyor. Puan/indirme/premium satırları, yazar/yayınevi, ISBN/kategori, yorum başlıkları ve rapor düğmeleri tam yüksekliğe büyüyebiliyor. Metin düğmelerindeki sabit yükseklik sınırları kaldırıldı. |
| Kitaplık ve profil | Misafir ekranı kaydırılabiliyor. Raf/aksiyon ızgaraları büyük yazıda tek sütuna geçiyor. İç içe kartların gerçek dar genişliği dikkate alınıyor. Devam edilen kitap, kota, başarı, üyelik ve bilgi satırları gerektiğinde dikeyleşiyor. |
| Yazarlar, yayınevleri, üyeler | Büyük yazıda tek sütun veya dikey kartlar; uzun ad, rol, tarih ve açıklamalar için büyüyen metin alanları. Üye mesajı açılan sayfası klavyeyle kaydırılabiliyor. |
| Forum | Konu adı, kullanıcı/tarih ve sayaçların aynı satırda rekabet etmesi azaltıldı. Güvenlik menüsünün bulunduğu alanda konu başlığına boşluk ayrıldı. Uzun konu detay başlığı sabit 126 pt alana kırpılmıyor. |
| Sohbet, mesajlar ve yorumlar | Mesaj listesindeki güvenlik menüsünün başlığı/tarihi örtme riski giderildi. Büyük yazıda başlık/kimlik alanları dikeyleşiyor. Sabit yüksekliği olan yanıt editörünün büyük placeholder metni artık editörün dışına taşan overlay olarak çizilmiyor. |
| Kitap gündemi ve istekler | Dar kartlarda aksiyon sayaçları ve rozetler uyarlanabilir yerleşim kullanıyor. Büyük yazıda kapak, kullanıcı ve metin alanları dikeyleşiyor. Dekoratif puan yıldızlarının boyutu sınırlandırıldı; erişilebilir puan kontrolü korundu. |
| Canlı akış ve bildirimler | Büyük yazıda zaman/tür, banner ve metrik kartları dikeyleşiyor. Küçük sabit metadata metinleri ölçeklenen yazı stillerine alındı. |
| Sesli kitaplar | Birden fazla düğmeli satırlar sığmadığında dikeyleşiyor. Raf kartları yazıyla büyüyüp viewport genişliğini aşmıyor. Büyük yazıda gridler tek sütun, bölüm adı/süre ayrı satır oluyor. |
| Oynatıcı | Bölüm başlığı sürelerden ayrıldı; kontrol grupları için dikey alternatif var. Mini oynatıcıda büyük yazıya yer açılıyor. Not düzenleyicisi klavye/azalan yükseklik için kaydırılabiliyor. Oynatma davranışı değiştirilmedi. |
| AI asistanı | Üç araç çubuğu aksiyonu mevcut “daha fazla” menüsünde toplandı. Uzun bilgi/karşılaştırma satırları dikeyleşiyor. Küçük kitap listeleri doğal yüksekliği baştan ölçen HStack kullanıyor; büyük listelerde lazy yapı ve tüm içerik korunuyor. |
| İstatistikler ve indirmeler | Hedef başlığı/değeri sığmadığında dikeyleşiyor. Büyük yazıda istatistik ızgarası tek sütun oluyor. İndirme dosya adı/hata mesajı tam yüksekliğe büyüyor. |
| Okuyucu | İlerleme/senkron bilgileri büyük yazıda ayrı satırlara geçiyor. Yükleme adımları daha erken dikeyleşiyor. Önizleme sınırı kartı kısa yükseklikte kaydırılabiliyor; kapatma ve premium aksiyonları korunuyor. |
| Hediye çarkı | Küçük etiket büyütüldü. Büyük yazıda ödül listesi tek sütun, cüzdan bilgisi dikey. Geri sayımın büyüyüp tek satırdan taşmasını önlemek için sayısal gösterge sınırlı görsel boyutta tutuluyor. |
| Giriş ve hesap formları | Yasal bağlantılar sığmadığında dikeyleşiyor. Metin düğmeleri büyüyebiliyor. Uzun kullanıcı adı/e-posta ve etiket-değer çiftleri gerektiğinde ayrı satırlara geçiyor. |
| Ortak başlıklar, menü ve kartlar | Başlık/aksiyon satırlarına gerçek sığma alternatifi eklendi. Menü rozetleri büyük yazıda başlığın yanından altına taşındı; ikonlar sabit simge alanından taşmıyor. Hata, forum, kota ve bilgi kartlarının büyük yazı yerleşimi iyileştirildi. |
| Premium | Önceki incelemede düzeltilen büyüyen görsel etiketleri, metin kontrastı ve büyük yazı yerleşimleri korundu. Native test genişliklerine 390 ve 414 pt eklendi. |

`DeleteAccountView`, `CommunitySafetyView`, `ReportContentView`, `TermsAcceptanceView` ve `BlockMemberView` de incelendi: mevcut kaydırılabilir Form/List/ScrollView ve büyüyen metin düzenlerinde yeni somut sabit yükseklik sorunu bulunmadığı için gereksiz değişiklik yapılmadı.

Alt gezinme çubuğu, sabit boyutlu kapak/ikon alanları, ilerleme çizgileri, kaydırılabilir kategori şeritleri ve küçük özet kartlarının bilinçli satır sınırları incelendi. Kısa bir liste önizlemesinin metni kısaltması ile tam detay metninin kırpılması aynı kabul edilmedi. Native incelemede özellikle mini oynatıcı+alt çubuk, klavyeli sayfalar ve yatay konum ayrıca kontrol edilmelidir.

## Kart ölçülerinin eşitlenmesi — 18 Ekim 2026

`UniformCardText`, aynı gruptaki kartlar için belirlenen metin satırlarının alanını kısa veya eksik bilgilerde de ayırır. Büyük erişilebilirlik yazılarında satır sınırı uygulanmaz. Ana sayfanın kitap, kategori, keşif, kompakt okuma, editoryal ve öneri kartları ile sesli kitap kartları bu ortak davranışı kullanır. Kullanıcının sonraki tasarım isteğiyle Gündem rayı ayrı bir kısa önizleme düzenine geçirildi: normal yazıda 300 pt ortak yükseklik (yazı tercihiyle ölçeklenir), üç satır metin, tek başlıkta kullanıcı/tür ve kompakt kitap/sayaç alanı. Erişilebilirlik yazılarında kartın yüksekliği doğaldır; üç satır önizleme, tam VoiceOver içeriği ve detay bağlantısı korunur. Bu son değişiklik için derleme/native test çalıştırılmadı.

Son kontrolde katalog liste kartları da tamamlandı: başlık, yazar, kategori/sayfa ve puan alanları normal yazıda aynı sayıda satır kaplar; eksik bilgi görünür bir değer üretmeden yerini korur. Kitaplık satırlarındaki metin alanı kalan genişliği doldurarak yön oklarını hizalar. Farklı işlevlerdeki büyük tanıtım alanları ve küçük kitap kartları kendi gruplarının ölçülerini korur.

Mevcut `testHomeNewArrivalCardsRemainVisibleAndOpenNativeBookDetails` testi kısa başlıklı ilk kartı, uzun başlıklı ve yazar/kategori bilgisi eksik ikinci kartla karşılaştıracak çevrimdışı veri seçeneğiyle güçlendirildi. `testHomeAgendaRailKeepsDifferentContentAtEqualCardDimensions` uzun inceleme ve kısa not kartlarının gerçek genişlik/yüksekliklerini karşılaştırır. Testlerin iOS üzerinde çalıştırılması ve görüntülerin incelenmesi bekliyor; bu Windows kontrolü görsel başarı kanıtı değildir.

## Ayrıntılı alt raporlar

- [Ana sayfa, katalog, profil ve kitap detayları](artifacts/layout-audit-20261018/home-catalog-profile.md)
- [Topluluk, mesajlar ve hesap formları](artifacts/layout-audit-20261018/community-forms.md)
- [Sesli kitaplar, oynatıcı ve AI](artifacts/layout-audit-20261018/audio-ai.md)
- [Premium tasarım ve okunabilirlik incelemesi](PREMIUM_DESIGN_VALIDATION.md)

## Bu bilgisayarda çalıştırılan kontroller

- App, native test ve UI test klasörlerindeki **124 Swift dosyasının** `swiftc -frontend -parse` denetimi geçti. Bu sayı eşzamanlı başka çalışmaların dosyalarını da kapsayan mevcut çalışma alanı sayısıdır; 124 dosyanın tamamı bu incelemede değiştirilmedi.
- `Scripts/swift-static-audit.ps1` geçti.
- `Scripts/ui-accessibility-audit.ps1` geçti. Bu bir kaynak denetimidir; VoiceOver çalıştırması değildir.
- `Scripts/premium-contract-audit.ps1` geçti; satın alma ürün/işlem sözleşmesi kontrolleri korundu.
- `git diff --check` geçti; yalnız LF/CRLF dönüşüm bildirimleri çıktı.
- `Scripts/layout-audit-macos.sh` için Bash sözdizimi denetimi geçti. Xcode komutları Windows üzerinde çalıştırılmadı.
- Premium'a ait önceki 69 sayısal kontrast kontrolü başarılıdır; bu sayı bütün uygulamanın kontrastının ölçüldüğü anlamına gelmez.

## Hazırlanan native testler

`App/EkitapligimUITests/LayoutAuditUITests.swift`, mevcut çevrimdışı fixture ile 16 gerçek ekranın üstünü ve üç kaydırma konumunu normal/açık, erişilebilirlik/açık ve erişilebilirlik/koyu görünümde kaydeder. Menü kapatma erişimini ve dış kaydırma alanının yatay sınırlarını da kontrol eder. Satın alma, giriş veya ses oynatma başlatmaz. Görüntülerin gözle incelenmesi gerekir; dış sınır kontrolü içerideki her taşmayı otomatik bulmaz.

`App/EkitapligimTests/ResponsiveComponentLayoutTests.swift`, gerçek ortak başlık/kota/forum/bilgi/okuyucu bileşenlerini 320/375/390/414 pt ve dört yazı boyutunda ölçer, ekran görüntüsü ekleri hazırlar. `PremiumLayoutTests` aynı şekilde Premium bileşenlerini 320/375/390/393/414 pt genişliklerde ölçer. Testler, kaynak kodunu taklit etmek yerine gerçek SwiftUI bileşenlerini UIHostingController ile çalıştırır. **Bu yeni native testler bu bilgisayarda çalıştırılmadı.**

Mac'te, projenin Xcode/XcodeGen bağımlılıkları hazır olduğunda:

```sh
bash Scripts/layout-audit-macos.sh
```

Betik iPhone 11 ve iPhone 13 simülatörlerini adlarıyla ister; eksik cihazı başka cihazla değiştirip başarılı göstermez. Cihaz başına beş bileşen testi ve dört UI testi için sıfır atlama/sıfır hata içeren sonuç özeti ister. Sonuçları ve gerçek XCTest görüntü eklerini `build/layout-audit` altında tutar. Mevcut üretim/dağıtım iş akışlarını değiştirmez.

Bu sınırlı betik; tüm formların her sunucu durumunu, gerçek ödeme ekranlarını, gerçek AVPlayer oynatmasını, dosya indirmesini, okuyucu içeriğini veya bütün landscape/klavye senaryolarını kapsamaz. Bunlar için mevcut özel okuyucu/AI/hediye çarkı/oynatıcı UI testleri ve gerçek cihaz kontrolü gerekir.

## Değişiklik sınırı

Bu incelemenin değişiklikleri yerleşim ve sunuma yöneliktir. StoreKit, ücret/fiyat kaynağı, API, izin/kimlik doğrulama, backend, veri modelleri ve oynatma servisleri bu inceleme için değiştirilmedi. Çalışma alanında önceden ve eşzamanlı başka işlerin değişiklikleri var; korunmuştur ve bu raporun sonucu olarak gösterilmemelidir. Yayına hazırlık veya “bütün cihazlar sorunsuz” iddiasında bulunulmaz.
