# TestFlight gönderimi — 4 Ekim 2026

Ekitapligim **1.0.8 / build 41**, Codemagic ile App Store Connect'e yüklendi. Apple işlemesi tamamlandı. TestFlight ekranı **Waiting for Review** durumunu ve **Ekitapligim Internal Testers** grubunu (2 davet) gösteriyor. Bu durum beta incelemesinin beklediğini gösterir; inceleme onayı veya cihazda kurulum yapıldığı iddia edilmez. App Store üretim gönderimi kapalı kaldı.

- Binary kaynak commit'i: `aacc7fa`.
- Codemagic: [başarılı build 52](https://codemagic.io/app/6a90147f8e10fa41794a8aef/build/6ac1804d7394575b200ad3a9).
- TestFlight: [build 41](https://appstoreconnect.apple.com/teams/5349caa7-6ba1-477f-ba50-1f52e9446819/apps/6789584323/testflight/ios/cce279b0-98c0-4df5-8f44-a2ada9b33696).
- Xcode 26.3 / Mac mini M2: iPhone/iPad test hedefleri derlendi; **102 native birim + 24 UI testi, sıfır hata**.
- Üç profil ilerleme testi ve 13 ChatModel testi geçti. Sohbet UI testleri tam metin/dar genişlik, avatarla profil açma, büyük yazı/erişilebilirlik, alıntı iptali, ifade ekleme/kaldırmayı doğruladı.
- Production IPA derlemesi ve imzalı `aps-environment=production` kontrolü geçti.
- Satın alma uygulaması/ürünleri/entitlement kaynakları değişmedi. Korunan 34 dosyadan 30'u birebir aynı; project.yml ve 3 xcconfig dosyasında yalnız marketing/build sürümü değişti.

## Bu gönderimde giderilen engeller

İlk native çalıştırma eksik zorunlu alanlı profil test yanıtı ve sohbet UI testlerinin Keychain/erişilebilirlik kimliği sorunlarını gösterdi. Profil test yanıtı sunucu sözleşmesine uyarlandı; DEBUG sohbet test ortamına bellek token deposu verildi; alıntı kapsayıcısının iptal düğmesi kimliğini ezmesi giderildi ve dokunma alanı korundu. Testler atlanmadı.

İkinci çalıştırmada 126 test geçti ancak Apple, onaylı 1.0.7 sürümüne tekrar yüklemeyi reddetti. Sürüm tüm yapılandırmalarda 1.0.8/build 41 yapıldı. Son çalıştırmada 126 test tekrar geçti ve yükleme kabul edildi.

## Kanıtlar ve sınırlar

`ios-tests.log`, `production-entitlements.plist`, `purchase-protection-final.log` ve `testflight-1.0.8-build41.jpg` bu dizindedir. Tam xcresult/derleme kanıtları yerelde `.codex-artifacts/testflight-20261004/build52` altında saklandı. Önceki çapraz platform raporu ve IosApi 1.0.32 paketi geçerlidir; bu TestFlight gönderimi sunucu eklentisini üretime kurmadı. Fiziksel cihazda APNs/FCM teslimi ve iki hesapla iOS–Android–web etkileşim yazımı ayrı uçtan uca doğrulamadır. App Store hazır olunduğu iddia edilmez.
