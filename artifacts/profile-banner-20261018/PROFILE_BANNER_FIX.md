# Profil kapağının sağ üstündeki yazı parçası

18 Ekim 2026. Referans: kullanıcının `photo_5954147187635719905_y.jpg` ekran görüntüsü.

Ekran görüntüsünde profil kapağının sağ üstünde beyaz/siyah bir yazı parçası görünüyor. Uygulamadaki bu bölgede ek bir düğme veya metin katmanı yok. Depodaki mevcut test verisinde bulunan herkese açık kapak görseli incelendi; kaynak resim temiz ve sağa doğru devam eden büyük beyaz bir başlık içeriyor. Görsel değiştirilmedi veya sunucuya yüklenmedi.

Önceki yerleşimde farklı en/boy oranlarına sahip arka plan ve uzak kapak görseli aynı ZStack içinde `.scaledToFill()` kullanıyordu. Çerçeve yalnız dış ZStack üzerinde verilmişti. Alt görsellerin doğal boyutları birbirlerinin ölçümünü etkileyerek kapağın aşırı büyümesine ve beyaz başlığın küçük bir bölümünün köşede kalmasına yol açabilecek durumdaydı.

`ProfileBannerArtwork`, her görseli kendi ölçülen genişlik/yüksekliğine ayrı ayrı sığdırıp kırpar. Profil kapağının hem arka planı hem uzak resmi bu bileşeni kullanıyor. Profil düzenleme önizlemesindeki kapak resmi de aynı sınırlamayı kullanıyor. Resim yükleme, profil verileri, düzenleme/satın alma işlemleri değiştirilmedi.

Çalıştırılan kontroller:

- Yeni görsel bileşeni, `ProfileView.swift` ve `ProfileEditView.swift` Swift sözdizimi kontrolünden geçti.
- Swift statik denetimi ve erişilebilirlik kaynak denetimi geçti.
- İlgili dosyalar için `git diff --check` geçti; yalnız LF/CRLF bildirimi var.

Bu Windows ortamında Xcode/iOS simülatörü yok. Yerleşim düzeltmesi kaynakta uygulandı; yeni iPhone ekran görüntüsü veya native render sonucu bu çalışma sırasında elde edilmedi. Görselden yapılan neden analizi, yerel SwiftUI render ile doğrulanmış sonuç olarak sunulmaz.
