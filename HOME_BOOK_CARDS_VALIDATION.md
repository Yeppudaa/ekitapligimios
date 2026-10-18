# Ana sayfa kitap kartları — 18 Ekim 2026

## Sorun ve kaynak düzeltmesi

Kullanıcının Yeni Eklenenler görüntüsündeki kartlar incelendi. Eski `HomeBookCard` uzaktan gelen görseli doğrudan `aspectRatio` ile ölçüyordu. Görsel yüklenirken `ProgressView`, başarılı olduğunda görsel, bulunamadığında ise GeometryReader tabanlı kapak farklı doğal ölçüler veriyordu. Üstte `maxHeight: .infinity`, başlıkta ise her kitap için üç satır ayıran `UniformCardText` vardı. Tek satırlık başlıkla yazar arasında iki gereksiz metin satırı ayrılıyordu. Eski test sadece kartın yüksekliğinin 100 pt'den büyük olmasını ve iki kartın eşit boyunu kontrol ettiği için ikisinin de fazla uzaması yakalanmıyordu.

- `Design/HomeBookCard.swift`: kapak alanı genişlik/yükseklik = 1/1,48 oranında bağımsız ölçülür. İndirilen görsel bir overlay içinde bu alana yerleşir; görselin doğal oranı veya yükleme durumu kart yüksekliğini değiştirmez.
- Ana sayfa kapakları `.fit` ile bütün olarak gösterilir; geniş/dar görsel kartı uzatmaz ve üzerindeki yazılar kırpılmaz. Kapak çevresinde 10 pt, kart çevresinde 12 pt sabit iç boşluk vardır.
- Kartın sınırsız yükseklik esnetmesi kaldırıldı. Başlık iki satır, yazar bir satır ayırır; kategori/başlık/yazar arası 5 pt'dir. Normal yazıda kısa/uzun başlık ve eksik metadata aynı kart düzenini kullanır. Erişilebilirlik yazısında metin doğal yüksekliğine büyür.
- Kart genişliğini kartın kendisi yerine ana sayfanın yatay kitap listesi belirler. Ekran/pencere daraldığında görünür genişlikle sınırlandırılır.
- Boş/yüklenemeyen kapakta mevcut yerelleştirilmiş kitap kapağı tasarımı gösterilir. Bekleme sırasında da yalnız boş bir alan yerine aynı tasarım ve yükleme göstergesi kullanılır. Boş kitap adı mevcut yerelleştirilmiş varsayılan başlığa döner.
- Ortak görsel bileşeninin varsayılan `.fill` davranışı diğer ekranlarda korunur; ana sayfa `.fit` seçer. API, izinler, veri toplama, satın alma ve proje yetkileri değişmez.

## Test kapsamı ve çalıştırılanlar

`HomeBookCardLayoutTests`: dört native test; yatay/dikey sentetik görsel, yükleniyor ve eksik kapak fazlarında 124/148/220 pt alan oranı; 156/172/220/320 pt kartlar; kısa/uzun/eksik metadata; yüksek ebeveynin kartı esnetmemesi; erişilebilirlik metni ve gerçek SwiftUI görüntü ekleri.

`HomeBookRailUITests`: üç native test; gerçek Home Yeni Eklenenler akışında kapak oranı, başlık/yazar aralığı, yatay kaydırma, başarısız/gecikmeli yüklemede değişmeyen geometri, kitap detayına açılma ve büyük yazı. `ModernParityHomeCoverFixture` yalnız DEBUG ve açık UI fixture parametresiyle küçük sentetik PNG yanıtları üretir; gerçek ağa kapak isteği gönderilmez. Tall/wide/404/delayed durumları test edilir.

Bu Windows ortamında çalıştırılan kontroller:

- İlgili yedi Swift dosyası için `swiftc -frontend -parse -D DEBUG`: geçti.
- `Scripts/swift-static-audit.ps1`: geçti.
- `Scripts/ui-accessibility-audit.ps1`: geçti; kaynak taramasıdır, native VoiceOver doğrulaması değildir.
- `Scripts/validate-workspace.ps1`: geçti; çıktı `artifacts/home-book-cards-workspace.log` altında.
- Değiştirilen izlenen dosyalar için `git diff --check`: geçti.
- `bash -n Scripts/layout-audit-macos.sh`: geçti.

`project.yml` kaynak klasörlerini topladığı için yeni bileşen ve test dosyaları XcodeGen hedeflerine otomatik dahil edilir. `Scripts/layout-audit-macos.sh` yeni testleri de iPhone 11 ve iPhone 13 üzerinde çalıştıracak şekilde güncellendi: cihaz başına 9 bileşen ve 11 UI testinin başarıyla, sıfır atlamayla tamamlanması istenir. Başarılı sonuç sayısı kadar gerçek ekran görüntüsü eklerinin incelenmesi de gereklidir.

**Xcode, iOS SDK ve simulator bu bilgisayarda bulunmadığından yeni yedi native test henüz çalıştırılmadı.** Swift ayrıştırma, gerçek SwiftUI boyutlandırmasını veya görüntü kalitesini kanıtlamaz. Native test ve görsel inceleme tamamlanmadan kusursuz görünüm veya tüm cihazlar için doğrulama iddiası yoktur. Canlıya/TestFlight'a dağıtım yapılmadı. Çalışma ağacındaki önceden var olan değişiklikler korundu.
