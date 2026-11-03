# IosApi 1.0.37 satın alma denetimi — 18 Ekim 2026

**Sonuç:** İncelenen pakette satın alma akışını bozacak bir değişiklik veya çalıştırılan testlerde regresyon bulunmadı. Bu sonuç gerçek Apple Sandbox alışverişi ya da canlı kurulum doğrulaması değildir.

İncelenen ZIP: `artifacts/library-favorites-20261018/Ekitapligim-IosApi.zip`.

SHA-256: `de46e68120d9bc8685e4a0703d289a16ba8f8fe6a1654e8f421f1c9dd462cc75`. Denetim boyunca paket değiştirilmedi.

## Dosya ve yükseltme karşılaştırması

Önceki 1.0.36 paketiyle bütün dosyalar karşılaştırıldı: 130 mevcut dosya birebir aynı, altı dosya değişmiş, bir raf servisi eklenmiş; silinen dosya yok. Satın alma doğrulama, Apple bildirimleri, abonelik/üyelik servisleri, ürün sözleşmesi, Apple sertifikası, zamanlanmış uzlaştırma ve ödeme rotaları birebir aynı.

`upgrade1000037Step1()` yalnızca açıklama içerir; ödeme tablolarına, Premium gruplarına veya abonelik kayıtlarına işlem yapmaz. Önceki sürümlerin satın alma kurulum kodu değişmemiştir. Yeni raf servisi BookThreads raf/favori kayıtlarıyla çalışır; satın alma veya entitlement servislerini çağırmaz.

iOS kaynak incelemesinde StoreKit servisi ve yapılandırması, ürün kataloğu, satın alma hazırlama/doğrulama alanları ve geri yükleme çağrıları değişmemiştir. Yeni raf kuyruğu StoreKit tarafından kullanılmaz. Kitaplık onay kontrolü yalnızca kitaplık işlemlerine uygulanır.

## Çalıştırılan kontroller

- Kullanıcının verdiği ZIP'ten çıkarılan dosyalar üzerinde **8 App Store test paketi ve 1 bearer/hesap izolasyon paketi: 9/9 başarılı**.
- Satın alma doğrulama/bildirimleri, account binding, üyelik teslimi, tekrar istekler, eski istemciler, aylık/üç aylık/altı aylık/yıllık abonelik, yenileme, geri yükleme, iptal, sona erme, grace period ve iade senaryoları geçti.
- Gerçek yerel ES256 imza ve sertifika zinciri kontrolleri geçti. **9/9 satın alma PHP dosyası** sözdizimi kontrolünü geçti.
- iOS Core testleri yeniden çalıştırıldı: **456/456 başarılı**; ürün kataloğu, hazırlık/doğrulama politikaları, entitlement ve oturum yenileme testleri dahil.

Sunucu testleri bellekte SQLite ve yerel fixture kullanır. Apple'a, ödeme sistemine veya canlı veritabanına istek yapılmadı. Native StoreKitTest/Apple Sandbox, gerçek MySQL/XenForo yükseltmesi ve cihaz üzerinde uçtan uca satın alma bu Windows ortamında çalıştırılmadı.

## Kanıtlar

- [Arşiv incelemesi](zip-review.md)
- [Dosya hash karşılaştırması](zip-comparison.json)
- [ZIP üzerinde sunucu testleri ve çıkış kodları](extracted-zip-purchase-tests.json)
- [Core testi günlüğü](core-tests.log)
- Ayrıntılı sunucu günlükleri: `test-logs/`.
