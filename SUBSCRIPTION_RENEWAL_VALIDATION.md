# Otomatik yenilenen Premium planları — 13 Ekim 2026

## İkinci inceleme / 1.0.10 TestFlight çalışması

Kullanıcı yeniden derin inceleme ve ardından TestFlight incelemesine gönderim istedi. Restore sırasında yerel abonelik bulunduğunda Apple eşitlemesinin atlanması düzeltildi: kullanıcı başlatmış restore her zaman Apple ile eşitler, sync başarısız/iptal olursa mevcut doğrulanmış hakları yine kontrol eder. Ödeme alınmış fakat sunucu doğrulaması bekleyen işlem varken yeni ödeme başlatılması önlendi ve kullanıcıya yeniden satın alma yerine doğrulama/restore bilgisi verildi. Başka cihazdan lifetime keşfi, sync iptali ve bekleyen ödeme kilidi için native regresyon testleri eklendi. Aşağıdaki ilk inceleme sonuçları tarihsel olup yeni build sonuçları ayrıca kaydedilecek.

IosApi 1.0.36 canlı XenForo yönetim panelinden yükseltildi. `https://ekitapligim.com/ios-api/v1/` uç noktasında açık API smoke kontrolü ve kimliği doğrulanmış `prepare_purchase=1` yanıtı geçti; yanıt yeni iki ürün kimliğini desteklenenler arasında döndürdü. App Store Connect'te 3 ve 6 aylık otomatik yenilenen ürünler aynı abonelik grubunda ve mevcut aylık/yıllık ürünlerle aynı hizmet seviyesinde oluşturuldu. Aylık, yıllık ve süresiz mevcut ürünlerin onaylı olduğu doğrulandı. Yeni iki ürün henüz Apple onaylı değildir. Gerçek Apple Sandbox ödeme/yenileme/geri yükleme zinciri de henüz fiziksel cihazda kanıtlanmadı.

İkinci incelemede önbelleğe alınmış aylık hakkın yanında başka cihazdan gelen süresiz alımı sınayan StoreKitTest testi ilk iPad CI koşusunda başarısız oldu. Test düzeneği, dışarıdan satın almayı `SKTestSession` ile oluşturduktan sonra StoreKit eşitlemesini bekleyecek şekilde düzeltildi (`93451fa`). Düzeltme sonrası iPhone/iPad PremiumPurchaseTests ve Codemagic'in imzalı üretim testleri geçti. GitHub'ın son iPhone işinde satın alma dışı `ChatUITests.testPremiumUsernameKeepsNativeProfileNavigationAtLargeTextSize` aralıklı başarısız oldu; Codemagic aynı kaynakta 27 UI testini sıfır hatayla geçti. GitHub iPad, kaynak doğrulama ve ekran görüntüsü işleri başarılıydı.

Codemagic production build 56, `7d6a89b` commit'inden imzalı IPA üretti ve App Store Connect'e **1.0.10 (43)** olarak yükledi. Codemagic `** TEST EXECUTE SUCCEEDED **` ve App Store distribution `WAITING_FOR_REVIEW` kaydı verdi; App Store Connect TestFlight ekranı da 1.0.10 (43) için Waiting for Review gösterdi. 3 aylık abonelik ayrı App Review gönderimi `3595d57f-0341-4783-b8b0-58a051a02552` ile Waiting for Review durumunda. 6 aylık ilk gönderim `0de1214d-00b7-4009-b9a9-abecfe3fb93a`, Apple'ın eşzamanlı iki iOS gönderimi sınırını aşmadan uygulama sürümüyle birleştirmek için geri çekildi. **1.0.10 (43) ve 6 aylık abonelik** yeni gönderim `6072d278-5f92-4b53-ad13-acfb1b700c05` içinde birlikte Waiting for Review durumunda. Sürüm için manuel yayın seçildi; onay otomatik olarak halka açmayacak. Her iki abonelik inceleme görseli gerçek iPhone 16 Premium ekranı testinden alındı. Bunlar Apple onayı veya fiziksel cihazda gerçek Sandbox satın alma doğrulaması değildir. App Review kanıtı: `artifacts/purchase-recheck-20261013/appstore-1.0.10-submitted.png`.

## Ürünler ve geçiş

| Plan | Ürün kimliği (`com.ekitapligim.app.premium.` önekiyle) | Tür / dönem | Türkiye hedef fiyatı |
|---|---|---|---|
| Aylık | `monthly` | Otomatik yenilenen / 1 ay | ₺100 |
| 3 aylık | `quarterly` | Otomatik yenilenen / 3 ay | ₺239,99 |
| 6 aylık | `semiannual` | Otomatik yenilenen / 6 ay | ₺400 |
| Yıllık | `yearly` | Otomatik yenilenen / 1 yıl | ₺750 |
| Süresiz | `lifetime` | Tek ödeme / non-consumable | ₺2.500 |

Kartlardaki fiyatlar StoreKit'ten gelir; tablodaki rakamlar canlı fiyat doğrulaması değildir. Dört yenilenen plan aynı abonelik grubunda, aynı hizmet seviyesinde olmalıdır. Her biri kullanıcı iptal edene kadar kendi döneminde Apple tarafından yenilenir. Uygulama veya sunucu kendi başına ödeme çekmez.

Eski `three_months`, `six_months`, `yearly_once` ürünleri yeni katalogda satılmaz. Eski ödemelerin doğrulanması, kullanılmamış sürenin korunması ve geri yüklenmesi devam eder. Önceden tek seferlik satın alınmış paketler kullanıcı onayı olmadan otomatik ödemeye dönüştürülmez. Eski kimlikler test dosyasında yalnız geri yükleme fixture'ı olarak tutulur.

## Ödeme korumaları

- StoreKit ürün türü ve dönemi ödeme öncesinde kontrol edilir; örneğin 3 aylık plan ancak `.autoRenewable` ve 3 ay dönemli ürünle satın alınır.
- Ödeme hazırlığı `supported_product_ids` döndürür. `quarterly` ve `semiannual`, sunucu açıkça desteklediğini bildirmeden ödeme başlatamaz. Diğer ürünlerde eski sunucu yanıtları uyumluluğunu korur.
- Yeni kimlikler hem doğrulama hem Apple bildirimlerinin izin listesine alınır. Yenilenme bitişi Apple'ın imzalı işleminden gelir; tekrarlanan bildirim ek süre veya ikinci kayıt oluşturmaz.
- Mevcut Apple imzası, hesap UUID'si, sahiplik, grace, iade, izin teslimi ve sunucu doğrulaması kontrolleri korunur. Doğrulama kesintisinde işlem tamamlanmadan bırakılır ve yeniden denenir.
- Eski süreli paketten yenilenen aboneliğe geçerken ek ödeme bilgisi gösterilir. Süresiz alım mevcut Apple aboneliğini kendiliğinden iptal etmediğinden mevcut uyarı korunur.
- Kartların her birinde ayrı Türkçe tanıtım metni vardır. Ödeme, yenileme aralıkları, iptal ve süresiz ürün istisnası ayrı açıklamada görünür.

## Yerel kontroller

- `Scripts/swift-test-windows.ps1 -Clean -Release`: 358 XCTest geçti; `artifacts/renewable-20261013/swift-core-release.log`. Sondaki boş Swift Testing koşucusu ayrı olup 358 XCTest sonucunu değiştirmez. Bu iOS uygulama derlemesi değildir.
- `Tests/Backend/AppStoreRenewableCatalogTest.php`: 4 dönem için hazırlık, ilk ödeme, tür reddi, tekrarlı doğrulama, uygulama kapalıyken yenileme bildirimi teslimi, geri yükleme, iptal, süre sonu, grace ve iade geçti. Controller testleri imzalanmış yük yerine fixture kullanır; gerçek ES256/zincir testleri ayrıca paket kontrolünde çalışır.
- `Scripts/premium-contract-audit.ps1`: ürün listesi, dört yenileme dönemi, tek grup/aynı seviye, lifetime türü, eski kimlikler ve ödeme korumaları geçti; `artifacts/renewable-20261013/premium-contract.log`.
- `Scripts/appstore-preflight.ps1`: yerel mağaza metni/yapılandırma kontrolü geçti; `artifacts/renewable-20261013/preflight.log`. Canlı mağaza onayını doğrulamaz.
- `Scripts/validate-workspace.ps1 -Strict`: Swift/PHP kaynak, API sözleşmesi, gizli bilgi taraması ve statik erişilebilirlik kontrolleri geçti; `artifacts/renewable-20261013/workspace.log`. Fiziksel cihaz erişilebilirliği değildir.
- Değişen üç native Swift dosyası `swiftc -frontend -parse` ile geçti; `artifacts/renewable-20261013/swift-native-parse.log`. iOS SDK ile type-check değildir.
- `Scripts/build-ios-api-addon.ps1 -CreateZip -OutputDirectory artifacts/renewable-20261013` ve `Scripts/mobileapi-release-audit.ps1 -AddonZip artifacts/renewable-20261013/Ekitapligim-IosApi.zip` geçti. Paket **1.0.36 / 1000036**, 136 dosya; kayıtlar `backend-build.log` ve `package-audit.log`. SHA-256: `746DA9D5A6F06DAB19D57055A49526F015F68D4CC74FCD860CD0D20CDC168809`.

Native testlere dört dönem için StoreKit satın alma → `Transaction.updates` ile zorlanmış yenileme → yeni servisle restore → iptal → süre sonu senaryoları eklendi. Ayrıca ürün türü/dönemi ve eski backend'e karşı ödeme başlatılmaması testleri eklendi. Windows üzerinde StoreKitTest, iOS clean/Production build ve UI testleri çalıştırılamaz. Son kaynak için macOS GitHub iPad işi ve Codemagic'in imzalı üretim derleme/testleri geçti. Ayrı GitHub iPhone işindeki sohbet UI kararsızlığı yukarıda açıklandı; satın alma testleri o koşuda geçti.

## Yayına geçiş sırası ve açık kontroller

1. IosApi 1.0.36 canlıya kuruldu ve kimliği doğrulanmış `prepare_purchase=1` yanıtında yeni iki ürünün desteklendiği doğrulandı. Önceki 1.0.35 süre koruma değişiklikleri bu pakete dahildir. Eski uygulamaların makbuzlarıyla uyumluluğu staging'de ayrıca kontrol et.
2. App Store Connect'te `quarterly` ve `semiannual` ürünleri belirtilen süre/fiyatla, aylık ve yıllık ürünlerle aynı gruba ve aynı hizmet seviyesine konarak oluşturuldu. Yerelleştirmeler ve gerçek uygulama inceleme görselleri tamamlandı; ikisi de Apple incelemesinde. `yearly` ürünü mevcut yenilenen yıllık üründür.
3. Production build ve StoreKitTest senaryoları Codemagic'de geçti; TestFlight 1.0.10 (43) Beta App Review'da, aynı build ve 6 aylık abonelik de public App Review'da. Apple onaylarını izle. GitHub iPhone sohbet UI testindeki aralıklı hatayı ayrıca izle. Fiziksel cihazda VoiceOver ve büyük metinle Premium ekranını doğrula.
4. Gerçek Sandbox/TestFlight'ta dört dönemin satın alınması, hızlandırılmış otomatik yenilenmesi, uygulama kapalıyken bildirim teslimi, tekrar kurulum/ikinci cihazda restore, ödeme sonrası ağ kesintisi ve tekrar deneme, hesap değiştirme, yanlış hesap, Ask to Buy, iptal, grace, süre sonu ve refund'u doğrula. Süresiz ve üç eski süreli ürünün restore testlerini tamamla.
5. Yeni ürünler Apple tarafından onaylanıp bu kanıtlar tamamlandıktan sonra uygulamayı yayınla. Eski ürünlerin satıştan kaldırılması, eski uygulamaları etkileyebileceğinden ayrıca planlanmalı; doğrulama/restore desteği kaldırılmamalı.

`project.yml` aynı StoreKit fixture'ını uygulama ve native test hedeflerine bağlar. Yeni ürünler mevcut satın alma geçmişi/hesap eşleme alanlarını kullanır; ek izin veya veri kategorisi yoktur. Entitlements ve privacy manifest bu davranışla uyumludur.

Apple kaynakları: [abonelik süreleri ve grup seviyeleri](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information/), [mevcut satın alma hakları](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [StoreKit test yenilemesi](https://developer.apple.com/documentation/storekittest/sktestsession/forcerenewalofsubscription%28productidentifier%3A%29).
