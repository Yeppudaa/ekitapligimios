# iOS API 1.0.34 — eski uygulama uyumluluk incelemesi

Tarih: 12 Ekim 2026. Kullanıcı hedef paketi **1.0.34** olarak doğruladı; kurulu sunucu sürümü **1.0.32**.

## Sonuç

İncelenen kaynak/paket kontrollerinde **1.0.34'ün eski uygulamaları bozacak bir API değişikliği bulunmadı**. Güncelleme zorunluluğu eklenmiyor. Bu incelemede ek üretim kodu veya paket değişikliği yapılmadı; yalnızca testler ve rapor doğruluğu geliştirildi. Hazırlanan 1.0.34 ZIP aynı hash ile korunuyor.

Bu sonuç, gerçek eski iPhone uygulamasıyla canlı/staging uçtan uca testlerin yerini tutmaz. Mevcut uygulamanın kendi okuyucu/oturum hatalarını sunucu paketi tek başına ortadan kaldırmaz. Yeni native görünümler eski uygulamaya eklenmez.

## Paket ve sözleşme

- 1.0.32 kaynak baseline: `d1dd1395f84250452e813d3cb07db30a9b6be6f6`.
- 1.0.34: 135 dosyanın **130'u** bu baseline ile aynı. Farklı dosyalar: `addon.json`, README, `ChatSerializer.php`, `MobileSession.php`, `ApnsPush.php`.
- 1.0.33 ZIP'e göre **132/135** dosya tamamen aynı; yalnızca APNs servisi, version manifest ve README farklı.
- Login/register, reader/session/source/progress, catalog/library, üyelik/satın alma/restore controller'ları, yollar, options, cron, Setup ve izin kontrolleri paket karşılaştırmasında aynı.
- Mobil auth ve push device-token formatı/endpoint'leri aynı. Push temizliği login/refresh tokenına veya satın alma kayıtlarına dokunmaz.
- Chat'e eklenen `is_premium`, `role_type`, `announcement_member` alanları eski istemcilerde yok sayılır. Eski alanların tüm tip/değerleri karşılaştırılarak korunmaları doğrulandı; eski sürümler tam alıntı/duyuru metnini okumaya devam eder.
- Premium görünüm yardımcı metodu yerel BookThreads kaynağında salt okunur kontrol olarak incelendi; üyelik/hak verme işlemi yapmaz.

## Yeni test kanıtları

Kanıt dizini: `artifacts/compatibility-deep-20261012/`.

| Eski native Core | Git referansı | Yeni sunucunun gerçek ürettiği chat yanıtlarıyla XCTest |
|---|---|---|
| 1.0.8 | d1dd139 | 4/4 geçti |
| 1.0.7 | c11799b | 4/4 geçti |
| 1.0.6 | b8dbb6f | 4/4 geçti |
| 1.0.5 | 3e8c81f | 4/4 geçti |
| 1.0.4 | 08537db | 4/4 geçti |

Komut her sürüm için ayrı, gerçek önceki kaynakla çalıştırıldı:

```powershell
.\Scripts\legacy-client-compatibility-test-windows.ps1 -ClientRef <git-ref> -AddonZip .\artifacts\apns-20261012\server-package\Ekitapligim-IosApi.zip
```

Normal/premium mesaj, alıntılı cevap, tam yükseltme duyurusu ve mesaj sayfası test edildi. Toplam **20 XCTest** geçti. 1.0.7 ve daha eski sürümlerin yapılandırılmış alıntı desteği yoktur; bu sürümlerde sunucunun mevcut tam `message` alanı korunur. 1.0.8 ayrı `message_body` ve `quoted_message` alanlarını kullanır.

Her koşuda 1.0.32'nin gerçek serializer'ı ile yeni serializer'ın çıktıları **15 mesaj senaryosunda, bütün eski alanların tip/değerleriyle birebir** karşılaştırıldı: boş/Unicode/normal mesaj, tam alıntı/yalnız alıntı/tarihsel alıntı, gizlenmiş/nested alıntı, premium/yönetici/moderatör/staff, bot ve yükseltme duyurusu. Yeni alanlar dışında eski çıktılarda değişiklik yok.

Eski 1.0.32 servisinin oluşturduğu sentetik session'ın geçerliliği ve erişim süresi dolduktan sonra yeni standalone serviste yenilenmesi geçti. Bu doğrudan servis testi aşağıda belirtilen public route ayrımını kanıtlamaz.

`Tests/Integration/IosApiUpgradeCompatibilityTest.php` gerçek kurulu XF `StepRunnerUpgradeTrait` kodunu app/DB bootstrap yapmadan çalıştırdı: 1.0.32 veya 1.0.33'ten geçişte yeni Setup adımı seçilmedi. Eski şema/satın alma/üyelik uzlaştırma migration'ları tekrar çalıştırılmadı. Normal XenForo cache/data import'u veya canlı kurulum bu testte yapılmadı.

`Tests/Backend/ApnsTransportContractTest.php`, cURL/OpenSSL içeren `C:\xampp\php\php.exe` ile geçti. Geçici, yalnızca teste ait P-256 anahtarla gerçek JWT imzası doğrulandı; production/development host, HTTP/2 POST, topic, bearer, priority, payload, timeout ve TLS varsayılanları korundu. Gerçek response parsing milisaniyeli timestamp, hatalı timestamp, gateway ve transport senaryolarıyla doğrulandı. cURL fonksiyonları test namespace'inde mock edildi: sıfır ağ isteği. PATH PHP'sinin cURL eklentisi yoktu; doğru yerel runtime kullanıldı. Anahtar/config/random fixture dosyaları test sonunda silindi.

Önceden çalıştırılmış APNs delivery/cleanup, session, reader, purchase/restore/crypto/membership testleri ve workspace/paket denetimleri de geçmişti. Bu inceleme onlar için yeni bir runtime kaynağı değişikliği yapmadı. Kanıtlar [APNS_UNREGISTERED_VALIDATION.md](APNS_UNREGISTERED_VALIDATION.md) ve `artifacts/apns-20261012/` altında.

## Public oturum yenileme yoluyla ilgili düzeltme

Derin route incelemesi, `/ios-api/v1/auth/refresh` ve logout yollarının mevcut **MobileApi** controller/service'ine yönlendiğini gösterdi. 1.0.34 bu route'u değiştirmez; çalışan 1.0.32'nin giriş/yenileme yolu korunur. Yerel MobileApi servisinde 120 saniyelik kayıp yanıt kurtarma mevcut; canlı MobileApi kodu bu incelemede doğrulanmadı. Standalone IosApi `MobileSession` düzeltmesinin public yolda tek başına etkinleştiği önceki ifade fazla genişti; API/önceki raporlar buna göre düzeltildi. Kullanıcı çalışan giriş yolunu korumak istediği için bu uyumluluk incelemesinde controller remap veya yeni login davranışı eklenmedi.

## Kurulacak dosya

`artifacts/apns-20261012/server-package/Ekitapligim-IosApi.zip`

SHA-256: `9C98ECE68B1C6E760EB329BC3AA8FC0CA5F7E554900B458B9CCF8E23362DABA9`.

Canlı kurulum yapılmadı. XenForo üzerinden **mevcut eklentiyi yükseltme** akışı kullanılmalı; eklentiyi kaldırıp yeniden kurmak bu incelemenin kapsamında değildir. Mevcut sunucu/dosya/DB yedeği geri dönüş için tutulmalı. Yükseltme sonrası güncellenmemiş gerçek cihazla login, izinli kitap açma, library/progress, chat ve purchase/restore uçtan uca kontrolü; APNs için geçerli cihazda teslimat yapılmalı. Bu cihaz/sunucu kanıtı olmadan “her sürümde her işlem kesin sorunsuz” denmez.
