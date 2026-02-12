# Argus Kod İncelemesi — Kickoff (2026-02-12)

Bu doküman, Argus için başlatılan ilk kod incelemesinin **başlangıç bulgularını** ve güvenlik/mimari odaklı aksiyon planını içerir.

## Kapsam
- Güvenlik yüzeyi (network, gizli anahtar yönetimi, loglama)
- Mimari sürdürülebilirlik (god object, sorumluluk ayrımı, bağımlılık yönü)
- Operasyonel doğrulama (çalıştırılabilirlik ve temel kontrol komutları)

## Hızlı Bulgular

### 1) Güvenlik: Dış servis erişimlerinde HTTP fallback açık
- `BorsaPyProvider` içinde fallback URL listesi `http://` adresleri içeriyor.
- `normalizeBaseURL` fonksiyonu hem `http` hem `https` şemasına izin veriyor.
- Risk: Üretimde yanlış konfigürasyon veya DNS/mitm kombinasyonlarında şifrelenmemiş trafik denemesi.
- Etki: Orta/Yüksek (özellikle finansal veri bütünlüğü açısından).

**Kanıt dosyaları:**
- `argus/Services/Providers/BorsaPyProvider.swift` (fallback URL ve scheme doğrulama)

### 2) Güvenlik: RSS kaynaklarında plaintext HTTP feed kullanımı
- `RSSNewsProvider` içinde bazı kaynaklar `http://` ile tanımlı.
- Risk: Haber içeriği manipülasyonu, yanlış sinyal türetme, güven zafiyeti.
- Etki: Orta (karar destek sisteminde veri kaynağı güvenilirliği zedelenir).

**Kanıt dosyaları:**
- `argus/Services/RSSNewsProvider.swift` (`BBC Türkçe`, `Diken` feed URL’leri)

### 3) Mimari: Büyük nesneler hâlâ kritik eşiğin üzerinde
- Satır bazlı ölçümde çekirdek dosyalar halen büyük.
- Özellikle `TradingViewModel` ve `ArgusDecisionEngine` tek dosyada çok sayıda sorumluluk taşıyor.
- Risk: Değişiklik maliyeti artışı, test edilebilirlik düşüşü, regresyon olasılığı.

**Satır ölçümü (wc -l):**
- `TradingViewModel.swift`: 1581
- `ArgusDecisionEngine.swift`: 866
- `PortfolioStore.swift`: 601
- `ExecutionStateViewModel.swift`: 435

## Mimari ve Güvenlik İçin Önerilen Yol Haritası

### Faz 1 (Hızlı Sertleştirme — 1-2 gün)
1. `BorsaPyProvider` içinde production profile’da `http` fallback’i kapat.
2. RSS kaynaklarını mümkünse `https` mirror/endpoint’lere taşı.
3. Ağ çağrılarında merkezi bir `NetworkPolicy` kontrolü ekle (şema, host allowlist).

### Faz 2 (Refactor Hazırlığı — 2-4 gün)
1. `TradingViewModel` için bounded-context ayırımı çıkar (Signals, Portfolio, Execution, UI state).
2. `ArgusDecisionEngine` için use-case bazlı orchestration katmanı tasarla.
3. `ServiceContainer` üzerinden constructor injection zorunlu hale getir; yeni `.shared` kullanımını dondur.

### Faz 3 (Doğrulama ve Regresyon Güvenliği)
1. Kritik path’ler için birim test kapsamını artır.
2. Ağ güvenliği için negatif testler (http engelleme, allowlist dışı host red).
3. Karar motoru için snapshot test + deterministik fixture seti.

## Bu Turda Yapılan Doğrulamalar
- Ortamda `xcodebuild` yok; iOS derleme/test bu container’da çalıştırılamadı.
- Python tarafı (`Scripts/borsapy_server`) sözdizimi derleme kontrolü başarılı.

## Sonuç
Kod incelemesi başlatıldı. Önceliklendirme sırası:
1) Network şema güvenliği (`http` fallback ve feed’ler),
2) God object küçültme planı,
3) DI/bağımlılık disiplininin sıkılaştırılması.
