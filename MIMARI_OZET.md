# Argus Projesi - Mimarı Öğrenimler Özeti

## 📋 Oluşturulan CLAUDE.md İçeriği

**912 satırlık kapsamlı rehber:**

### Bölümler
1. **Proje Özeti** - Argus nedir, bileşenleri
2. **Kodlama Kuralları** - 10 bölüm (yapı, stil, adlandırma, vb.)
3. **MİMARİ GÜVENLİĞİ** - ⚠️ 7 KRITIK SORUN
4. **Git İş Akışı** - Commit alışkanlıkları
5. **Test ve Kalite** - Testing strategy
6. **Yaygın Sorunlar** - Çözümler table'ı
7. **Useful Commands** - Terminal komutları
8. **Mimarı Karar Ağacı** - Yeni kod nereye yazılmalı?
9. **Red Flags** - Eğer bunu yapıyorsan, SAT VE DÜŞÜN
10. **Best Practices** - Doğru mimarı örnekleri
11. **Kalite Metrikleri** - Ölçülebilir hedefler
12. **Referanslar** - Öğrenme kaynakları

---

## 🚨 7 KRITIK MİMARİ SORUNU (Detaylı)

### 1. GOD OBJECTS - Çok Fazla Sorumluluk
- **TradingViewModel** (1,459 satır) - 30 @Published, 54 function
- **UnifiedDataStore** (383 satır) - 38 @Published, duplicate veri
- **ArgusDecisionEngine** (866 satır) - 500 satırlık single function
- **PortfolioStore** (601 satır)
- **ExecutionStateViewModel** (392 satır)

**Çözüm**: Bir ViewModel = BİR görev, max 300 satır

### 2. MULTIPLE SOURCES OF TRUTH - Veri Sync Hatası
- Orion Analysis: 4 yerde kopyalanmış
- Portfolio: 4 yerde kopyalanmış
- Risk: Geçici desinkronizasyon

**Çözüm**: SSOT belirle (PortfolioStore true source, geri kalanlar observe)

### 3. NAVIGATION KAYBOLUŞU - 108 View, 5 Erişilebilir
- DeepLinkManager: 41 satır, 3 fonksiyon (yetersiz)
- AppTabBar: 5 tab'a erişim
- 103 view: Orphaned (hiç gidilemez)

**Çözüm**: NavigationCoordinator + tüm 108 view'a enum mapping

### 4. SIKI BAĞLANTILAR (Tight Coupling) - 124+ Singleton
- UnifiedDataStore → WatchlistViewModel → MarketDataStore → SignalStateViewModel → ExecutionStateViewModel → DiagnosticsViewModel → PortfolioStore
- ArgusDecisionEngine: 5+ hard-coded `.shared` erişimi

**Çözüm**: Dependency Injection - constructor ile inject et

### 5. STATE MANAGEMENT KAOS - Tüm Update Tüm Render
- UnifiedDataStore: 7 different .objectWillChange observer
- Tek quote update → 7 sink → tüm views re-render → donuş
- ArgusSanctumView: "REMOVED OBSERVATION TO STOP RE-RENDERS" (ölü kod)

**Çözüm**: Granular @Published properties (her değişkenin ayrı update'i)

### 6. ÖLÜ KOD - 121 TODO, Deprecated API
- 121 TODO/FIXME (50 dosya)
- 3 deprecated API hala aktif
- Placeholder implementations (scoutingCandidates = [])

**Çözüm**: Sil, backlog'a taşı, complete yap

### 7. BAĞLANTISIZ MODÜLLER - Var Ama Ulaşılamaz
- Orphaned Labs (ArgusLabView, ChronosLabView, OrionLabView)
- Modal state'ler ölü kod
- BIST subsystem parçalanmış

**Çözüm**: Navigation'a ekle veya sil

---

## ✅ ÇÖZÜM STRATEJİSİ (Priority Order)

| # | Görev | İmpakt | Zorluk | Tahmini |
|---|-------|--------|--------|---------|
| 1 | UnifiedDataStore kaldır | Veri sync bugs ortadan kalkar | Yüksek | 4 saat |
| 2 | TradingViewModel'i böl | Test edilebilir | Yüksek | 6 saat |
| 3 | Navigation router oluştur | 100+ orphaned view erişilebilir | Orta | 3 saat |
| 4 | ArgusDecisionEngine'i böl | Unit test yazılabilir | Yüksek | 4 saat |
| 5 | Singleton → DI dönüştürme | Test coverage artır | Çok Yüksek | 12+ saat |
| 6 | Deprecated API migration | Kod temizliği | Düşük | 1 saat |
| 7 | TODO'ları backlog'a taşı | Kod temizliği | Çok Düşük | 30 min |
| 8 | Placeholder implementasyonları | Feature'lar çalışır | Orta | 2 saat |

---

## 🎯 KONTROL LİSTESİ - Yeni Feature Yazarken

### Before Coding:
- [ ] Bu feature mevcut ViewModel'e eklenir mi? → Eğer evet, hataydı
- [ ] 3+ service'e bağlanıyor mu? → Tasarımı gözden geçir
- [ ] Aynı veri başka yerde tutulmuş mu? → SSOT'ı kontrol et
- [ ] Navigation path'ı ekledim mi? → AppTabBar veya DeepLinkManager
- [ ] Dependencies hard-coded mi? → Dependency injection yap

### While Coding:
- [ ] ViewModel 300+ satır geçti mi? → Böl
- [ ] 5+ `.shared` instance var mı? → DI yap
- [ ] objectWillChange.send() tüm veriyi broadcast'liyor mu? → Granular @Published
- [ ] Modal state var ama trigger yok? → Sil veya main navigation'a ekle
- [ ] Test yazabildim mi? → Eğer yazamadıysam, tight coupling var

### After Coding:
- [ ] Başka ViewModel'i observe etmem gerek mi? → Service aracılığıyla paylaş
- [ ] Deprecated API kullandığı var mı? → Yeni API'ye geç
- [ ] TODO koydum mu? → Backlog'a taşı
- [ ] Placeholder kod var mı? → Complete yap veya kaldır

---

## 🚨 RED FLAGS - Bunu Yapıyorsan SAT VE DÜŞÜN

| Red Flag | Anlamı | Çözüm |
|----------|--------|-------|
| `.shared` 5+ kez | Coupling çok fazla | DI yap |
| ViewModel 400+ satır | God object | Böl |
| Aynı veri 2+ yerde @Published | SSOT yok | Birleştir |
| `objectWillChange.send()` her yerde | Tüm app re-render | Granular @Published |
| Modal state var ama trigger yok | Dead code | Sil veya nav'a ekle |
| TODO 10+ satır açıklama | Neden hala kodda? | Backlog'a taşı |
| Test yazamıyorum | Design problem | DI ve protocol'ler |
| View 500+ satır | God component | Extract subviews |
| Başka VM'yi @ObservedObject'le | Tight coupling | Service paylaş |

---

## 💡 BEST PRACTICES (Örneklerle)

### State Management - Granular Updates
```swift
// ❌ YAPMAAAA
@Published var everythingState: State  // 30 property
objectWillChange.send()  // tüm app re-render

// ✅ DOĞRU
@Published var quotes: [Quote] = []
@Published var portfolio: Portfolio = Portfolio()
// Views sadece ihtiyaç duydukları şeyi gözlemler
```

### Service Design - Dependency Injection
```swift
// ❌ YAPMAAAA
class ArgusDecisionEngine {
    func makeDecision() {
        let regime = ChironRegimeEngine.shared
        let synergy = ChimeraSynergyEngine.shared
    }
}

// ✅ DOĞRU
class ArgusDecisionEngine {
    init(
        regimeEngine: RegimeEngine,
        synergyEngine: SynergyEngine
    ) { ... }
}
```

### Navigation - All Views Accessible
```swift
// ❌ YAPMAAAA
navigate(to: String)  // 3 fonksiyon, 103 orphaned view

// ✅ DOĞRU
navigate(to: NavigationDestination)  // enum, tüm views
enum NavigationDestination: Hashable {
    case home, markets, backtest, labs, reports, // ...
}
```

---

## 📊 KALİTE METRİKLERİ

| Metrik | Hedef | Şu Anki | Status |
|--------|-------|--------|--------|
| ViewModel max satır | < 300 | 1,459 | ❌ |
| Service max satır | < 500 | 866 | ⚠️ |
| Service dependencies | < 3 | 5+ | ❌ |
| SSOT per domain | 1 | 3-4 | ❌ |
| Test coverage | > 60% | ? | ❓ |
| Deprecated API usage | 0% | 3 active | ❌ |
| TODO count | < 20 | 121 | ❌ |
| Nav accessible views | 100% | 5% (5/108) | ❌ |

---

## 📚 Referanslar

- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-in-swift/)
- [Protocol-Oriented Programming](https://developer.apple.com/videos/play/wwdc2015/408/)
- [Avoiding God Objects](https://refactoring.guru/smells/refused-bequest)
- [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single-responsibility_principle)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)

---

## 🗓️ Başlama Adımları

1. CLAUDE.md'yi baştan sona oku
2. Mimarı karar ağacını bookmark'la
3. Red flags'leri hafızana al
4. Yeni feature yazarken kontrol listesini tamamla
5. Refactor görevlerini backlog'a ekle
