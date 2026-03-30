# ARGUS MEMORY
> Ortak çalışma hafızası. Claude her oturum sonunda günceller.
> Kullanıcı istediği zaman tek satır not ekleyebilir.

---

## MİMARİ KARARLAR

### SafeHavenRouter — Neden ayrı servis?
Ticker her zaman çalışmalı, AutoPilot döngüsüne bağımlı olmamalı.
ViewModel içine koymak test edilemezliğe yol açardı.
**Dikkat:** Offline mode gelirse router state'i persist etmek gerekecek.

### TradeBrainExecutor — aether nil bug (düzeltildi)
Semptom: Her kriz aynı 20R risk tavanı, makro hiç etkisiz.
Kök neden: Line ~305'te `aether: nil as Double?` hardcoded — ExecutionGovernor
hep 50 default kullanıyordu → maxRiskR = 20 (limitsiz).
Fix: `MacroRegimeService.shared.getCachedRating()?.numericScore` ile değiştirildi.
**Benzer risk:** ChironConfig'de başka sabit varsayımlar olabilir.

### ChironConfig — dynamicMaxRiskR eşikleri (düzeltildi)
Eski hali: Aether < 50 → 20R (unlimited). Makro tabanlı tavan hiç çalışmıyordu.
Yeni eşikler: ≥70→10R · 55-70→6R · 40-55→3R · 25-40→1.5R · <25→0R.

### PortfolioStore — Retroaktif stop/take-profit (eklendi)
Uygulama kapalıyken fiyat tetikleyiciyi geçerse: satış currentPrice değil
stopLoss/takeProfit fiyatından yapılır.
Gap tespiti: currentPrice < stopLoss * 0.99 → reason: STOP_LOSS_RETROACTIVE.

### AutoPilotStore — prepareSirkiyeInput USD/TRY sorunu (düzeltildi)
Yahoo Finance "USDTRY=X" olarak saklıyor, kod "USD/TRY" arıyordu → nil dönüyordu.
Fix: Üç anahtar variant + fallback (35.0 TL) ile çözüldü.

### BorsaPyProvider — Render.com cold start (düzeltildi)
Render free tier 30-60s uyanma süresi, timeout 20s'ydi → ilk batch hep başarısız.
Fix: warmUp() eklendi, Bootstrap Phase 3'te AutoPilot'tan önce tetikleniyor.
AutoPilot loop gecikmesi 3s → 5s'e yükseltildi.

### ArgusGrandCouncil — Dinamik Aether ağırlığı (planlandı)
Şu an sabit: Aether %20. Planlanan: Bull→%20, Neutral→%32, Bear→%47.
Neden: Düşen piyasada makro sinyal en kritik, ama en az ağırlığa sahipti.

### RegimePositionSizer (planlandı, henüz yazılmadı)
Aether skoru + rejim → pozisyon çarpanı (0.0–1.0).
Dosya: argus/Services/Chiron/RegimePositionSizer.swift

### PortfolioHeatGate (planlandı, henüz yazılmadı)
Portföy drawdown'u yeni alımları kısıtlar.
cool→1.0x · warm→0.5x · hot→0.2x · critical→0.0x
Dosya: argus/Services/Chiron/PortfolioHeatGate.swift

---

## BİLİNEN TEHLİKELİ NOKTALAR

- **ChironRegimeEngine pain threshold:** Sabit -$20 dolar. Kullanıcının portföy
  büyüklüğüne göre ayarlanmalı, ileride konfigurasyon olabilir.
- **WatchlistStore BIST sembolleri:** AutoPilot çalışabilmesi için gerekli
  semboller dinamik olarak inject ediliyor. Eklenme zamanlaması bootstrap
  sırasına bağlı — sıra değişirse semboller eksik kalabilir.
- **MarketDataStore quote keys:** Yahoo Finance key formatı tutarsız
  (^VIX vs VIX, USDTRY=X vs USD/TRY). Her yeni entegrasyonda kontrol et.

---

## UI TERCİHLERİ

- Kart sistemi → terminal/satır stili tercih edilir (SmartTickerStrip örneği)
- Bildirimler: popup değil persistent ama kapatılabilir
- Türkçe etiketler kullanıcıya dönük her yerde (reason code'lar dahil)
- Güvenli liman barı: Aether'in hemen altında, koşul yoksa görünmez

---

## AKTİF SPRINT

**Tema:** Argus'u piyasa koşullarına duyarlı hale getirmek

Tamamlanan:
- [x] Retroaktif stop/take-profit gap fill
- [x] BorsaPy warm-up + BIST USD/TRY fix
- [x] Aether nil bug fix (TradeBrainExecutor)
- [x] dynamicMaxRiskR eşik düzeltmesi
- [x] SafeHavenRouter (kriz tespiti + varlık skoru)
- [x] SmartTickerStrip → kayan terminal ticker

Sıradaki:
- [ ] RegimePositionSizer — rejim bazlı pozisyon boyutu
- [ ] PortfolioHeatGate — drawdown kapısı
- [ ] ArgusGrandCouncil dinamik Aether ağırlığı
- [ ] Regime-aware trailing stop (ArgusAutoPilotEngine)

---

## KULLANICI NOTLARI
<!-- Buraya istediğin zaman tek satır ekle, ben düzenlerim -->

---
*Son güncelleme: 2026-03-30*
