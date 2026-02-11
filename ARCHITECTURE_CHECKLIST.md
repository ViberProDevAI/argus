# Argus Mimarı Kontrol Listesi

## 🎯 Her Feature Yazarken Kullan

### ⚠️ BEFORE CODE (Tasarım Aşaması)

**Bu soruları sor:**
- [ ] Bu feature hangi ViewModel'de yazılmalı? Max 300 satır mı aşacak?
- [ ] Hangi service'lere erişim gerekli? (3 taneden fazlaysa tasarımı gözden geçir)
- [ ] Kullanacağı veri başka bir yerde @Published mi? (Duplicate veri yok mu?)
- [ ] Navigation path'ı AppTabBar veya DeepLinkManager'a ekledim mi?
- [ ] Hard-coded `.shared` kullanacak mıyım? (YAPMAA - dependency inject et)

**Örnek tasarım dokümantasyonu:**
```
Feature: "Yeni Bactest Sonuçları"

ViewModel: ChironViewModel (existing, 180 satır)
Services: ArgusBacktestEngine, ChironDataLakeService
Data Model: BacktestResult (new struct)
Navigation: .backtest case'ini NavigationDestination'a ekle
Dependencies: ChironViewModel.init(backtestEngine, dataLake)
```

---

### 🔧 WHILE CODING (Geliştirme Aşaması)

#### Dosya Yapısı
```swift
import SwiftUI

// MARK: - ViewModel
class MyViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading = false

    let service: MyService

    init(service: MyService) {
        self.service = service
    }
}

// MARK: - View
struct MyView: View {
    @StateObject var viewModel: MyViewModel

    var body: some View {
        // UI
    }
}

// MARK: - Preview
#Preview {
    MyView(viewModel: MyViewModel(service: MockMyService()))
}
```

**Her 50 satırda sor:**
- [ ] ViewModel hala 300 satırın altında mı?
- [ ] `.shared` 5 taneden fazla kullandığım mı?
- [ ] objectWillChange.send() tüm veriyi broadcast'liyor mu?
- [ ] Modal state kullanıyor muyum ve trigger'ı yok mu?
- [ ] Test yazabilir miyim? (Yazamazsam, coupling var)

---

### ✅ AFTER CODING (Review Aşaması)

**Son kontrol:**
- [ ] Başka ViewModel'i @ObservedObject'le mi tutuyorum?
  - EVET → Hata! Service aracılığıyla veri paylaş
- [ ] Deprecated API kullanmışım mı?
  - EVET → Yeni API'ye geç (CLAUDE.md'de listeleniyor)
- [ ] TODO yorum koydum mu?
  - EVET → Açıklama yaz ve backlog'a taşı, kodu temizle
- [ ] Placeholder kod bıraktığı var mı?
  - EVET → Complete yap veya feature flag ile sağla
- [ ] Unit test yazabildim mi?
  - HAYIR → Tight coupling var, refactor et

**Commit mesajı:**
```
feat: Bactest Sonuçları Sayfası

- ChironViewModel'e new backtest results section eklendi
- ChironDataLakeService ile data fetch implementasyonu
- NavigationDestination'a .backtest case eklendi
- Unit tests yazıldı (ChironViewModelTests.swift)

Closes #123
```

---

## 🚨 RED FLAGS - Görürsen DURA

| Durum | Aksiyon |
|-------|---------|
| ViewModel **400+ satır** geçti | Başka dosyaya taşı, split logic |
| 5+ `.shared` instanceof | Dependency injection yapılmalı |
| Aynı veri 2+ @Published | SSOT'ı birleştir |
| `objectWillChange.send()` var | Granular @Published yap |
| Modal state **trigger'sız** | Sil veya main navigation'a ekle |
| Test yazamazsam | Design problem, refactor |
| View 500+ satır | Extract subviews |

---

## 📐 MIMARÎ KARAR AĞACI

```
Yeni kod yazıyorum...

  "ViewModel'e ekleyeyim mi?"
    → ViewModel 300+ satır mı? → HAYIR mi ekle, EVET mi böl
    → Başka ViewModel'i observe etmem gerek mi? → EVET mi service'te yap

  "Service'te yazayım mi?"
    → Hard-coded .shared mı? → Dependency inject et
    → 200+ satır mı? → Başka fonksiyona böl
    → 5+ service dependency'si var mı? → Tight coupling, gözden geçir

  "View'da yazayım mı?"
    → ❌ SADECE UI layout
    → @State sadece local UI state
    → ViewModel'den veri gel

  "Navigation mı?"
    → NavigationDestination enum'a ekle
    → AppTabBar veya NavigationCoordinator'a route ekle
    → Tüm 108 view'a erişim sağla
```

---

## 📋 GOD OBJECT TEST

ViewModel'in şunu yapıyorsa, GOD OBJECT'tir:

- [ ] 2+ subsystem'in verisi var mı?
- [ ] 20+ @Published property'si var mı?
- [ ] 40+ fonksiyonu var mı?
- [ ] 300+ satırı geçiyor mu?
- [ ] Başka ViewModel'ler buna depend mu ediyor?

**Eğer YES ≥ 3 → BOL VE AYIR!**

Nasıl?
```swift
// ❌ GOD OBJECT
class TradingViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    @Published var market: MarketData
    @Published var signals: [Signal]
    @Published var execution: ExecutionState
    // ... 30 daha
}

// ✅ AYRIŞTIRILMIŞ
class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    let service: PortfolioService
    init(service: PortfolioService) { ... }
}

class MarketViewModel: ObservableObject {
    @Published var market: MarketData
    let service: MarketService
    init(service: MarketService) { ... }
}

// Views kendi ViewModel'lerini kullan
@StateObject var portfolio = PortfolioViewModel(...)
@StateObject var market = MarketViewModel(...)
```

---

## 🔗 COUPLING TEST

Servisten/ViewModel'den sor:
- [ ] `.shared` 5 taneden fazla kullanuyor mu?
- [ ] Hard-coded singleton'a erişim var mı?
- [ ] Başka service initialize ediyor mu? (injectable olmalı)

**Eğer EVET → Dependency injection'a çevir:**

```swift
// ❌ TIGHT COUPLING
class ArgusDecisionEngine {
    func makeDecision() {
        let regime = ChironRegimeEngine.shared
        let ledger = ArgusLedger.shared
    }
}

// ✅ LOOSE COUPLING
class ArgusDecisionEngine {
    let regimeEngine: RegimeEngine
    let ledger: TradeLedger

    init(regimeEngine: RegimeEngine, ledger: TradeLedger) {
        self.regimeEngine = regimeEngine
        self.ledger = ledger
    }

    func makeDecision() {
        let decision = regimeEngine.analyze()
        ledger.record(decision)
    }
}

// Kullanım ve test
let mockRegime = MockRegimeEngine()
let mockLedger = MockTradeLedger()
let engine = ArgusDecisionEngine(
    regimeEngine: mockRegime,
    ledger: mockLedger
)
```

---

## 📊 KALİTE METRIKLERI (Hedefler)

Düzenli olarak kontrol et:

| Metrik | Hedef | Şu Anki | Status |
|--------|-------|--------|--------|
| Max ViewModel satırı | 300 | 1,459 | 🔴 |
| Max Service satırı | 500 | 866 | 🟡 |
| Avg service dependencies | 2-3 | 5+ | 🔴 |
| Code duplication | < 5% | ~15%? | 🟡 |
| Test coverage | > 60% | ? | ❓ |
| Navigation accessible views | 100% | 5% | 🔴 |
| Deprecated API usage | 0% | 3 active | 🔴 |
| TODO count | < 20 | 121 | 🔴 |

**Hedef**: Tüm metrikler 🟢 olana kadar refactor et.

---

## 🎓 ÖĞRENME KAYNAKLARI

- CLAUDE.md - Tüm kurallar ve örnekler
- MIMARI_OZET.md - Hızlı referans
- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-in-swift/)
- [Protocol-Oriented Programming](https://developer.apple.com/videos/play/wwdc2015/408/)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)

---

## 🚀 HIZLI BAŞLAMA

1. **Yeni feature yazacaksam:**
   - BEFORE CODE bölümünü oku
   - Tasarım dokümantasyonu yaz
   - WHILE CODING kontrol listesini kullan

2. **Code review yapacaksam:**
   - RED FLAGS tablosunu kontrol et
   - COUPLING TEST'i çalıştır
   - GOD OBJECT TEST'i uygula

3. **Refactor yapmacaksam:**
   - KALİTE METRİKLERİ'nden başla
   - MIMARÎ KARAR AĞACI'nı takip et
   - Özür dile ve bölmeye başla

---

## 📝 Notlar

- Bu kontrol listesi her feature yazarken kullanılmalı
- Red flags görürsen, tasarımı gözden geçir
- Test yazamazsam, tight coupling var (fact)
- CLAUDE.md her sorunun çözümü vardır

**EN ÖNEMLİ**: Bir ViewModel = BİR görev. Yapan yoksa, tasarımda hata vardır.
