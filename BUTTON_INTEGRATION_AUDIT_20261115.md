# iOS buton ve sunucu entegrasyonu denetimi — 15 Kasım 2026

Amaç: uygulamadaki her etkileşimli kontrolün bir eyleme bağlı olduğunu ve uygulamanın çağırdığı her sunucu ucunun canlı sunucuda yönlendirildiğini doğrulamak. Windows'ta Xcode olmadığı için kontroller statik kaynak analizi + canlı salt-okunur HTTP yoklaması ile yapıldı; hiçbir yazma isteği gönderilmedi, giriş yapılmadı.

Kanıtlar: `artifacts/button-audit-20261115/` (`button-inventory.md`, `live-route-probe.json`).

## 1. Etkileşimli kontrol envanteri (statik)

75 üretim dosyası tarandı (test host, fixture ve preview dosyaları hariç).

| Kontrol | Adet |
|---|---|
| Button | 468 |
| Menu / confirmationDialog / alert | 82 + 15 + 72 |
| NavigationLink | 47 |
| Link (dış bağlantı) | 41 |
| Picker / Toggle | 15 / 8 |
| refreshable / swipeActions / contextMenu / onTapGesture | 20 / 1 / 2 / 4 |

- Eylemsiz (`{}`) buton: yalnızca 14 adet **uyarı penceresi İptal/Kapat** butonu (SwiftUI'de pencereyi kapatmak için boş eylem normaldir). Sahte veya `print`/TODO ile biten üretim butonu yok.
- 74 `NavigationLink`/`sheet`/`fullScreenCover` hedefinin tümü tanımlı görünüm tipleri; `container.open(route:)` ile kullanılan 17 rota `AppRoute` içinde mevcut.
- 220 erişilebilirlik kimliğinin 130'u mevcut 21 UI test dosyasında kullanılıyor; 45 birim test dosyası var.
- Sesli kitap, AI, kütüphane ve ayarlar görünümleri sunucuyu doğrudan değil `AudioPlaybackController`, `AIAssistantModel`, `AudioFeatureModels` gibi modeller üzerinden çağırır; mimari kurala uygundur.

## 2. Canlı yönlendirme yoklaması (salt-okunur GET)

`APIEndpoint.swift`'teki 71 yol şablonu + sesli kitap (7) + AI (8) + hediye çarkı (2) ucu, kimlik doğrulamasız GET ile yoklandı. JSON yanıt (200/400/401/404-JSON/405) rotanın canlıda var olduğunu gösterir; yalnızca POST kabul eden uçlar GET'e JSON `unknown_api_error`/405 döndürür, bu beklenen davranıştır. HTML 404 ise rotanın canlıda olmadığı anlamına gelir.

| Alan | Sonuç |
|---|---|
| Katalog, kitap detayı, yorumlar, okuyucu erişimi/kaynağı, yazar/yayınevi dizinleri | JSON ✔ |
| Kimlik (login/register/apple/google/refresh/logout/forgot) | POST rotaları JSON ✔ |
| Hesap (`me`, e-posta, şifre, silme, cihaz jetonu, presence, kütüphane, bildirimler, şartlar, abonelik, okuma istatistikleri) | JSON ✔ |
| Mesajlar (`conversations`, `conversation-detail`, `conversation-reply`, okundu işareti) | 401 JSON ✔ |
| Kitap istekleri + oy, kitap gündemi (akış, detay, yorum, tepki, kaydet, yeniden paylaş, takip) | JSON ✔ |
| Forum (forumlar, konular, mesajlar, düzenle/sil), üyeler (detay, takip, engelle, ziyaret) | JSON ✔ |
| Sohbet odaları/mesajlar/tepkiler, canlı akış, yasal metinler, site istatistikleri | JSON ✔ |
| Güvenlik: `safety/reports`, `books/{id}/issue-report`, `members/{id}/block` | JSON ✔ |
| App Store doğrulama `billing/app-store/verify` | POST rotası JSON ✔ |
| Sesli kitap (`mobile-api/v1/audio-books`, detay, kütüphane, manifest, ilerleme, raf, yer imi) | JSON ✔ |
| AI (`mobile-api/v1/ai/bootstrap`, `conversations`, `collections`, `preferences`, kitap profili, eylem onayı) | JSON ✔ |
| Hediye çarkı (`hediye-carki-api/status`, `spin`) | JSON ✔ |

### Sapmalar

1. **`ios-api/v1/posts/{id}/report` canlıda HTML 404.** Kaynakta bu yolu kullanan `ReportKind.post` hiçbir ekrandan çağrılmıyor; forum mesajı şikâyeti `UGCSafetyMenu` → `safety/reports` üzerinden gidiyor ve o uç çalışıyor. Kullanıcıya etkisi yok; ölü kod/eski rota olarak not edildi. Sunucu tarafında IosApi `post-report` rotası canlıya kurulursa veya bu kod kaldırılırsa kapanır.
2. **`mobile-api/v1/ai/collections/{slug}` canlıda HTML 404** (her slug ve sondaki `/` ile denendi). Canlı `collections` listesi şu an boş döndüğü için uygulamada açılabilecek koleksiyon yok; etki yok. AI eklentisinde rota tanımı var (`v1/ai/collections/:str<slug>/`); canlıda sıralama/çakışma veya eksik sürüm olasılığı sunucu tarafında incelenmeli. Android da aynı yolu kullanır.
3. Özel mesaj görseli ve eski mesaj sayfalaması için MobileApi **1.0.160**'ın canlıda kurulu olması gerekir (bkz. `DEEP_REVIEW_20261115.md`).

## 3. Çalıştırılan betikler

- `Scripts/api-route-contract-audit.ps1 -SkipInstalled`: 74 Swift yol şablonu sözleşmeyle eşleşti.
- `Scripts/smoke-readonly-contract-test.ps1`: salt-okunur kontroller yazma yapmıyor; üretim yazma koruması HTTP öncesi duruyor.
- `.codex-temp/button-audit.py`, `nav-check.py`, `screen-integration.py`, `live-route-probe.py`, `identifier-coverage.py` (bu oturumda yazıldı; çıktıları `artifacts/button-audit-20261115/`).

## 4. Yapılamayan

Gerçek cihazda dokunarak test ve SwiftUI hedefinin derlenmesi bu ortamda mümkün değil. `Scripts/reading-room-macos.sh` ve mevcut UI testleri macOS'ta çalıştırılmadan "her buton cihazda çalışıyor" iddiası kanıtlanamaz.
