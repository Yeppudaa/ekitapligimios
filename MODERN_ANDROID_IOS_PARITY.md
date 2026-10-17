# Android → iOS tasarım ve sesli kitap aktarımı — 17 Ekim 2026

Bu çalışma, güncel Android kaynaklarını ve aynı web görsellerini **native SwiftUI** ekranlarına aktarır. Premium satın alma sayfası, ödeme/geri yükleme, üyelik hesaplama, giriş/kayıt ve Google giriş kodu kullanıcı talebi gereği korunur. Bu alanların Android'deki görsel yeniliği bu iOS çalışmasına dahil edilmez. Sesli kitap erişim mesajı mevcut native Premium sayfasını açar.

## Ekran ve davranış envanteri

| Alan | iOS değişikliği | Korunan gerçek işlev |
|---|---|---|
| Ana sayfa | Aynı manzara görselleri; keşif, sonraki kitap, türler, seçki/yeni kitaplar, sohbet ve topluluk | Gerçek API kitapları, editör seçkisi, arama, okuma devamı ve canlı içerik |
| Kitap kataloğu | Görselli hero, gerçek editör havuzundan rastgele öne çıkan kitap, modern filtreler/kartlar | Kitap arama/filtre/sayfalama ve detay; gereksiz Sesli Kitaplar çipi yok |
| Kütüphanem | Görselli kişisel başlık, raf sayıları, devam kartları | E-kitap okuma/indirme/progres ve mevcut raf işlemleri |
| Profil | E-kitap ve sesli kitap alanları, kişisel raflar, gerçek devam kartı | Premium üyelik ve günlük limit bileşenleri değiştirilmez |
| Menü | Görselli koyu başlık, gruplar, seçili rota, sayaçlar; Premium aktif/kalan gün | Mevcut oturum ve abonelik verisi; yeni üyelik sorgusu veya ödeme davranışı yok |
| Sesli kitap kataloğu | Aynı görseller, modern kartlar, varsayılan kapalı/açılabilir filtreler | Arama, sıralama, süre/dil/tür/yazar filtreleri, hata/boş/sayfalama durumları |
| Sesli kitap detayı | Koyu görsel hero, altın Sesli dinle, bölümler/hakkında/benzerler, paylaşım, raflar | Manifest erişimi; standart üyeye Premium açıklaması. Kullanıcı yorumları, anlatıcı hakkında ve eski boş süre/detay şeridi yok |
| Sesli kitap oynatıcı | Aynı manzara, kapak, bölümler/notlar/alıntılar, net ±15 saniye ve ayarlar | Tek uygulama düzeyi AVPlayer; hız, ses, uyku, seek, kayıtlı devam, not/alıntı/yer imi |
| Mini oynatıcı | Gezinmede ortak oynatıcı; geniş oynatıcıyla aynı anda görünmez; kapatma | Kapatma sesi durdurur; arka planda devam; hesap değişiminde kapanır. Uygulama işlemi sonlanınca ses de sonlanır |
| Sesli kitaplığım | Sekmelere göre aynı raf görselleri; gerçek istatistikler ve devam | Kaydedilen/dinlenen/tamamlanan/sonra/favori/geçmiş rafları |
| Kitap Gündemi | Aynı görseller ve modern başlık/akış | Gerçek gönderi, not, alıntı ve etkileşim yöntemleri |
| Yazarlar / Yayınevleri | Aynı arşiv görselleri, modern liste/kartlar | Gerçek arama, detay ve kitap yönlendirmeleri |
| Canlı akış | Aynı salon arka planı, modern olay kartları, görünürken yenileme | Sesli kitap başlangıç/tamamlanma/favori/sonra/kaydet etkinlikleri ve native rota; eski sayfalar korunur |
| Okur Sohbeti | Aynı salon görseli; üst alan sabit, mesaj alanı kayar | Gönderme/alıntı/tepki/moderasyon ve özel oda erişimi korunur; gereksiz oda şeridi kaldırılır |
| Kitap istekleri / Forumlar | Aynı görseller, modern istatistikler, arama, durum/kategori kartları | Gerçek istek/oy/başlık/yanıt işlemleri |
| Bildirimler | Modern kartlar, okunmamış vurgusu ve iOS izin durumu | Mevcut açma/okuma/sayfalama; izin isteme yalnız açık dokunuşla |
| Profil ziyareti | Mobil API 1.0.155 ortak ziyaret rotası | Web ile aynı sunucu gizlilik/bildirim politikası; misafir/kendi profili için yazma yok |

Ana sayfadaki **2K+ Yayınevi** istatistiği bulunmaz. Sahte yerel kitap/progres üretilmez. Görsellerin kaynak ve dönüşüm kanıtı hazırlık paketindeki `modern-image-assets.json` dosyasındadır; büyük manzara sprite'ları yerine Android ile aynı kırpımlar kullanılır.

## API ve hesap güvenliği

- E-kitap ve satın alma API istemcileri değişmez. Sesli kitap ayrı `AudioRepository` üzerinden aynı sitenin `mobile-api/v1/audio-books` ve `audio-library` rotalarını kullanır; mevcut Keychain oturumu ve koordine token yenilemesi paylaşılır.
- Premium dinleme sunucu manifest/stream izniyle denetlenir. Görsel düğme veya istemci üyelik durumu tek başına yetki vermez.
- Yayın yapılandırması HTTPS kalır. Stream adresleri aynı origin ve beklenen kitap/bölüm rotasıyla sınırlandırılır; yönlendirme, çerez, credential ve disk önbelleği kullanılmaz.
- MP3 istekleri en fazla 512 KiB aralıkla okunur. Aralık isteğine tüm dosyayla 200 dönülürse gövde belleğe alınmadan reddedilir. Geçersiz/eksik/fazla byte ve hatalı Content-Range reddedilir.
- İstekler hesap değişimini gönderim ve yanıt sonrasında kontrol eder. İlerleme oturum/sıra/gerçek dinleme kredisiyle senkronize edilir. Not ve alıntılar mevcut birinci taraf Kitap Gündemi alanında saklanır.
- Backend dosyaları ve canlı sunucu bu iOS çalışmasıyla değiştirilmez. Sunucuda AudioBooks + MobileAudioBridge + MobileApi 1.0.155 ve uyumlu IosApi kurulumu gerekir.

## Doğrulama ve açık kapılar

Kaynak sözdizimi, taşınabilir çekirdek testleri, korunan dosya karşılaştırması ve yerelleştirme/görsel kontrolleri ayrı kanıtlanır. Sözdizimi taraması SwiftUI tip denetimi veya görsel test yerine geçmez.

Windows üzerinde tamamlanan kontroller: **415/415 Core XCTest**, tam çalışma alanı/statik/erişilebilirlik doğrulaması ve **13/13 korunan akış karşılaştırması** başarılı. 40 korunan dosya, AppContainer'ın 45 mevcut metodu, profil üyelik/kota blokları ve Google handlerları aynı. Doğrulama kayıtları hazırlık paketinde saklanır. Yazar/forum hero başlıklarındaki eski 126 pt kırpma kaldırıldı; metin boyuna göre doğal yükseklik kullanılır.

Beş yeni native AVPlayer testi, uygulama içinden üretilen sessiz WAV verisini gerçek `AVAssetResourceLoader` ve kimlik doğrulamalı HEAD/206 üzerinden oynatır: ilerleme, duraklatma/devam, ±15 saniye, kapatma, hesap değişimi, Premium reddi ve sonlandırma. Bunlar yalnız Apple simülatöründe çalışabilir; fixture hiçbir canlı kitap dosyası veya canlı hesaba yazma kullanmaz.

`ios-modern-parity-validation` Codemagic iş akışı yalnız Swift testleri, native iPhone/iPad simülatör testleri/ekran görüntüleri ve imzasız Production derlemesi çalıştırır. Mevcut `ios-production` iş akışı korunur; bu doğrulama iş akışı Apple hesabına bağlanmaz, profil oluşturmaz, TestFlight/App Store dağıtmaz ve e-posta göndermez.

DEBUG fixture 16 gerçek ekranı, büyük yazı/koyu görünüm/yatay yönü, menü kaydırma/kapatma, sabit sohbet üst alanı, filtre açma/kapama, Premium erişim mesajı ve profil→sesli kitaplık rotasını denetler. Tüm fixture istekleri yerelde karşılanır ve yazmalar 405 döner. Canlı hesabın bildirim/ödemesi test fixture ile doğrulanmış sayılmaz.

Mac derlemesi, simülatör sonuçları ve görüntüler incelenmeden **yayına hazır / birebir doğrulandı / tüm cihazlar sorunsuz** sonucu verilmez. Gerçek cihazda arka plan/kilit ekranı, kesinti ve uygulamayı tamamen kapatma; APNs teslimi; App Store Sandbox Google giriş/satın alma regresyonu ayrıca cihaz kapısıdır.
