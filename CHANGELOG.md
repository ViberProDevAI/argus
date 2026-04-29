# Argus — Değişiklik Kaydı

## 2026-04 — V5 Tasarım Sprinti (branch: `ui/v5-designkit`)

`main`'e göre **49 commit**, ~**21 700 satır eklendi / 5 900 satır silindi**, 170 dosya dokunuldu. Aşağıda kullanıcıya etki eden başlıklar. Commit hash'leri hızlı arama için.

### 1. V5 Tasarım Dili — Tüm Uygulama

Yeni bir tasarım sistemi ve onun tüm ekranlara indirgenmesi.

- **Tasarım kiti** (`ArgusDesignKit+V5.swift`): `ArgusChip`, `ArgusPill`, `ArgusBar`, `ArgusDot`, `ArgusHair`, `ArgusOrb`, `ArgusSectionCaption`, `ArgusIconButton` (44×44 WCAG tap target). Sprint 1 (`7a16e2c`)
- **Motor logoları**: Chiron/Aether/Orion/Atlas/Hermes/Athena/Demeter/Prometheus/Alkindus için SVG+PNG asset seti + `MotorLogo` view. Sprint 1.1 (`7aaf0d9`), 3.2 (`133c034`)
- **Global chrome**: V5 tab bar + `PulsingFABView` (Argus göz radial gradient, 2.8s pulse). Sprint 2 (`288970a`)
- **`ArgusNavHeader`**: Standart V5 üst-bar bileşeni (bars3 deco + motor/menu/bell aksiyonları + status satırı). Signals, TradeBrain, BIST Market/Portfolio migre edildi.

#### V5'lenen ekranlar (commit sırasına göre)

| Ekran | Commit |
|---|---|
| SettingsView iskeleti | Sprint 3 `4ce446e` |
| Motor detay ekranları (logo entegrasyonu) | Sprint 3.1 `09edee9` |
| MarketView + ChironNeuralLink + AetherHUDView | Sprint 4 `a27c7bb` |
| Sanctum (Orb/CenterCore/Pantheon + MotorEngine bridge) | Sprint 5 `ccb0fd2` |
| Cockpit (TerminalScoreBadge motor logolu) | Sprint 6 `b311eeb`, 14 `b4057bb` |
| Portfolio BIST header | Sprint 7 `fe32a03`, 13 `a6a74ea` |
| StockDetailView tam layout | Sprint 8 `cc7b4a2` |
| ArgusVoice (karşılama + input bar) | Sprint 2.5 `7eeeb81`, `8a77cfc` |
| Phoenix yeni ekran | Sprint 11 `f93f027` |
| MarketView birebir | Sprint 12 `7b2214e` |
| Drawer V5 profil bloğu | Sprint 15 `d357e60` |
| Chiron + Alkindus + Aether body | Sprint 16-18 `a511473` |
| Sanctum HoloPanel shell + Chiron/Athena/Demeter iç gövde | V5.A `45648c1` |
| HoloPanel Aether + Hermes global | V5.A `e2ce895` |
| Prometheus panel | V5.B-4 `f4e2596` |
| Hermes haber akışı | V5.B-3 `676d41c` |
| Orion header + BIST trend + verbal summary | V5.B-1 `1fcf534` |
| Atlas detay header | V5.B-2 `bd9db22` |
| Alkindus dashboard kuyruğu | V5.C `2ed818b` |
| Settings motor renk tonları | V5.D `36a7c21` |
| DiscoverView | V5.E-1 `84476dc` |
| NotificationsView | V5.E-2 `8014243` |
| MarketReport + router wrapper Theme cleanup | V5.E-3 `6b2e045` |
| Sirkiye + proje geneli `Theme.*` → `InstitutionalTheme` sweep (77 dosya) | V5.G-3 `6378292` |
| BistMarketView + BistPortfolioView | V5.E.2 `f74cd01`, `fb69566` |
| Signals MacroBanner + card + empty state | V5.E.2 `da78c50` |
| Observatory + Heimdall + Mimir | V5.F `c814e0f` |
| Piyasa kayar bant (MarqueeTicker) tamamen yeniden tasarlandı | `4f06891` |
| Günsonu + haftalık raporlar (UI + prose rewrite) | `5a0f1cd` |

### 2. Navigasyon Düzeltmeleri

- **Sanctum drawer hotfix** (`2dd5746`): bozuk `NotificationCenter` çağrıları → `router.navigate(...)`. Yeni "Merkezler" bölümü: Chiron Öğrenme, Aether Makro, Phoenix Anka. Konsey Tartışması kısayolu. Global sembollerde Athena+Demeter drawer kalemleri. Yanlış `OrionIcon` ikon dolgularının temizliği.
- **Route'lar V5 view'larına yönlendirildi**: `.chiron` → `ChironInsightsView`, `.phoenix` → `PhoenixV5View`.

### 3. Şirket Logoları — 4 Tur Fix

`CrystalWatchlistRow` ve `DiscoverMarketRow` `CompanyLogoView`'e hiç bağlı değildi; hard-coded gradient avatar çiziyorlardı. Bu yüzden global piyasa ekranında logolar görünmüyordu.

- **logo-fix-1..3** (`22ef29b`, `1e71b95`): `CompanyLogoView` tamamen yeniden yazıldı. Singleton `LogoCache` (@MainActor ObservableObject), detached Task fetch, URLSession ephemeral cache, Content-Type SVG skip, image size > 4 guard. Kaynak zinciri: **FMP → IEX Cloud Storage → Clearbit (domain)**. `LazyVStack` scroll/recycle sırasında task iptali sorunu çözüldü.
- **logo-fix-4** (`9150c94`): Row'lardaki hard-coded gradient kaldırıldı → `CompanyLogoView(size: 36, cornerRadius: 18)`. 33 popüler ABD sembolü için Clearbit domain haritası.
- V5 gradient fallback her zaman ZStack alt katmanında; network gecikirse gradient, logo gelince üstüne oturur.

### 4. Legacy Temizlik

- `ChironDetailView.swift` + `PhoenixView.swift` silindi (V5 muadillerine tüm referanslar taşındı): `f26e48f`, `5693121`
- `Theme.*` eski tokenları → `InstitutionalTheme.Colors.*` / `Spacing.*` / `Radius.*` proje geneli sweep (80+ dosya): `6378292`
- `PortfolioV5Components.swift` deprecated işaretlendi (cowork boşalttı), `.chiron`/`ArgusBar(tint:)` breakage düzeltildi.

### 5. Rapor Motoru Yazımı — AI Üretim Hissiyatı Gitti

- `ReportEngine.swift` tamamen yeniden yazıldı (`5a0f1cd`). `┌──┐ │ └──┘` ASCII tabloları silindi. `[STATS]` / `[OGREN]` / `[MAKRO]` / `[KARAR]` / `[DERS]` etiket gürültüsü silindi.
- Markdown başlıklar (`## Özet`, `## Bugün ne öğrendik?`, `## Piyasa ortamı`).
- Veri-öncelikli Türkçe açılış: "Bugün 3 işlem açıldı. Kapanışlar: **+$240.15** net K/Z (%67 başarı, 2K/1L)."
- Koşullu günün dersi havuzu + fallback (kötü gün / çok veto / default 7 ders).
- `PortfolioReportsView` UI V5: hero + mini-stat tile + section card + accent quote bar + yasal uyarı.

### 6. Piyasa Kayar Bant (MarqueeTicker)

- Arka plan siyah `#060c18` → `surface1`; yükseklik 30→36 pt; sol/sağ LinearGradient fade mask; sabit "CANLI" pill.
- TickerCell: yön-oku (aurora/crimson), fiyat satırı eklendi, yüzde V5 pill, VIX için ters-yön tonlama.
- `ETH-USD` core indekslere eklendi. 60 sn periodic refresh (onAppear/onDisappear timer invalidate).

### 7. Güvenlik Denetimi 2026-04-23 (`9e29854`)

Tam kapsamlı OWASP iOS audit — rapor: `tasks/security-audit-2026-04-23.md`.

**Temiz sonuçlanan kontroller:**
- Hardcoded API key / OAuth token pattern taraması — 0 hit (Gemini/OpenAI/GitHub/Slack/Groq pattern'leri)
- Secrets.xcconfig + `*.xcconfig` gitignore catch-all
- ATS konfigürasyonu sıkı (sadece localhost exception)
- Keychain access levels
- Silent catch / fatalError / NSClassFromString yok
- WKWebView yok (XSS riski yok)
- UserDefaults'ta secret yok

**Bu turda düzeltilen:**
- `RSSNewsProvider`: BBC Türkçe + Diken feed'leri `http://` → `https://` (ATS default olarak bloklardı)
- `KeychainManager`: `kSecAttrAccessibleWhenUnlocked` → `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

**Karar bekleyen bulgular:**
- Git history'de revoke edilmiş Gemini key izi (2 commit). Key geçersiz, pratik risk yok; hijyen için `git filter-repo` yapılabilir.

**Bu turda kapatılan:**
- Face ID toggle + `SecureViewModifier` + `SecurityService` ölü kod silindi (yanıltıcı güvenlik yüzeyi kaldırıldı). Wire-up tercih edildiğinde temiz bir tabandan başlanabilir.

### 8. Bildirim / Sinyal / Keşif İyileştirmeleri

- `NotificationRow`: tone-bazlı kart (buy=aurora, sell=crimson, alert=titan, report=alkindus motor), okunmamış ArgusDot kırmızı.
- `AISignalCard` (Signals): `ArgusPill` action, tone-bazlı border, mono caps sembol.
- `DiscoverMarketCard` + `DiscoverMarketRow`: gainer/loser tonu, V5 gradient avatar.

### 9. Altyapı / Erişilebilirlik

- `ArgusIconButton`: WCAG 2.5.8 garantili 44×44 tap target + zorunlu `accessibilityLabel`.
- `.argusTapTarget(_:)` extension: mevcut view'lara 44×44 hitbox + opsiyonel VoiceOver etiketi.
- 5 drawer sheet `NavigationView → NavigationStack` (deprecation temizliği).

### 10. Hata Düzeltmeleri

- SmartTickerStrip: core indeksler eksikse `viewModel.refreshSymbol(_:)` ile tetiklenir; 60 sn'de bir periodik refresh.
- StockDetailV5Body: "Temel Veriler" grid'i kaldırıldı (veri sağlayıcılardan P/E/EPS/MktCap tutarlı karşılanamıyor; Atlas HoloPanel'e yönlendirildi).
- Cowork breakage fix: `.chiron` → `.motor(.chiron)` (PortfolioV5Components, 2 yer); `ArgusBar(tint:)` → `ArgusBar(color:)` (1 yer).

---

## Bundan sonrası

- **Face ID kararı** bekliyor
- **Git history purge** kararı bekliyor
- **SSL pinning** düşük öncelikli, production için
- **V5.H derin pas**: Dynamic Type denemesi, cihaz üstünde VoiceOver turu
