# Argus Projesi - Claude Code Rehberi

## Proje Özeti

Argus, SwiftUI ile geliştirilmiş bir iOS ticaret ve pazar analiz uygulamasıdır. Sofistike portföy analizi, pazar içgörüleri ve ticaret sinyalleri sunan çeşitli sistemler aracılığıyla kullanıcıları destekler.

## Temel Bileşenler

### Çekirdek Sistemler (Mit İsimleri)
- **Alkindus**: Yapay zeka destekli pazar analizi ve örüntü öğrenmesi
- **Aether Council**: Çok ajandalı karar verme sistemi
- **Agora**: Tartışma ve yürütme yönetişim motoru
- **Chiron**: Geriye dönük test ve strateji değerlendirme sistemi
- **Heimdall**: Hata ayıklama ve veri dışa aktarım araçları
- **Hermes**: Haber ve veri akışı yönetimi
- **Orion**: Teknik analiz ve desen tanıma
- **Phoenix**: Senaryo analizi ve risk modelleme
- **Athena**: Eğitim ve akıllı öğrenme
- **Poseidon**: Pazar durumu izleme

### Ana Görünümler
- `AlkindusDashboardView`: Pazar içgörüleri sunan ana panel
- `PortfolioView`: Kullanıcı portföy yönetimi
- `BistMarketView` / `BistPortfolioView`: Türk pazarı (BIST) entegrasyonu
- `ArgusCockpitView`: Radar ve gerçek zamanlı izleme
- `ArgusSanctumView`: Karar tarihi ve analiz
- `MarketView`: İzleme listesi ve pazar takibi
- `SettingsView`: Yapılandırma ve tercihler

### Servisler (Kritik)
- `MarketDataProvider`: Dış pazar veri kaynağı
- `APIKeyStore`: Güvenli kimlik bilgisi yönetimi
- `AnalysisService`: Pazar analizi mantığı
- `AlertManager`: Bildirimler ve uyarılar
- `HapticManager`: Dokunsal geri bildirim
- `AutoPilotService/Manager`: Otomatik ticaret yönetimi
- `ArgusDecisionEngine`: Karar verme motoru

---

## ⚠️ MİMARİ GÜVENLİĞİ VE KAÇINILMASI GEREKEN HATALAR

### **CRİTİK SORUNLAR (Şu Anda Koddaki)**

#### 1. **GOD OBJECTS - Çok Fazla Sorumluluk**

**TradingViewModel.swift** (1,459 satır) ❌ **KÖTÜ**
- 30 @Published property, 54 fonksiyon
- Facade olarak 5 farklı subsystem'i proxy'liyor
- Bir değişiklik tüm uygulamayı etkileyebilir

**UnifiedDataStore.swift** (383 satır) ❌ **KÖTÜ**
- 38 @Published property
- "Single Source of Truth" iddiasına rağmen PortfolioStore, SignalStateViewModel'den duplicate veri çekiyor (lines 84-100)
- Aynı veriyi 2 yerde tutmak = veri senkronizasyon hatası riski

**ArgusDecisionEngine.swift** (866 satır) ❌ **ÇOOOK KÖTÜ**
- 500+ satır single `makeDecision()` fonksiyonu
- 5+ service dependency'ye hard-coded erişim (.shared)
- İşler: opinion aggregation, debate simulation, consensus scoring, risk auditing, execution planning

**PortfolioStore.swift** (601 satır)
**ExecutionStateViewModel.swift** (392 satır)

**Nasıl Düzelt:**
```
✅ Bir ViewModel = BİR görev (TradingViewModel sadece trading state, bitti)
✅ Bir Service = BİR iş mantığı (ArgusDecisionEngine sadece karar ver, geri kalan servislere git)
✅ 200-300 satırı geçerse işleri ayır
```

---

#### 2. **ÇOKLU DOĞRULUK KAYNAĞI (Multiple Sources of Truth) - Veri Sync Hatası**

❌ **PROBLEM**: Aynı veri birden fazla yerde tutulmuş
```
Orion Analiz Verisi:
  └─ SignalStateViewModel.orionAnalysis (gerçek kaynak)
  └─ UnifiedDataStore.orionAnalysis (kopyası - sync hatası riski)
  └─ TradingViewModel.orionAnalysis (facade proxy)
  └─ AnalysisViewModel.orionAnalysis (başka proxy)

Portfolio Verisi:
  └─ PortfolioStore.trades (gerçek kaynak)
  └─ UnifiedDataStore.portfolio (sink ile copy - gecikme riski)
  └─ TradingViewModel.portfolio (RiskViewModel üzerinden)
  └─ ExecutionStateViewModel (independent observer)
```

**Risk**: PortfolioStore güncellenirse → UnifiedDataStore sink'i biraz sonra alır → geçici desinkronizasyon → kullanıcı eski veri görür

**Nasıl Düzelt:**
```swift
// ❌ YAPMAAAA
class UnifiedDataStore: ObservableObject {
    @Published var portfolio: PortfolioState

    func setupBindings() {
        PortfolioStore.shared.$trades
            .sink { self.portfolio.trades = $0 }  // KOPYALAMA
            .store(in: &cancellables)
    }
}

// ✅ DOĞRU
class PortfolioStore: ObservableObject {
    @Published var trades: [Trade] = []
}

// Views doğrudan PortfolioStore'u kullan
@ObservedObject var portfolio = PortfolioStore.shared
```

---

#### 3. **NAVIGATION KAYBOLUŞU - 108 View, 5 Sadece Kullanılıyor**

**DeepLinkManager.swift** - sadece 41 satır ❌ **YETERSIZ**

```swift
// Yalnızca 3 fonksiyon, hiçbir stack management yok
navigate(to:)
openStockDetail(symbol:)
// Başka hiç bir view'a gidilemez!
```

**AppTabBar sadece 5 tab'a erişim veriyor:**
- ✅ Home (Alkindus)
- ✅ Markets (Market)
- ✅ Alkindus (Analysis)
- ✅ Portfolio (Portfolio)
- ✅ Settings

**Gitmek İmkansız Olan Views (108 içinden 103!):**
- ❌ ArgusBacktestView
- ❌ ArgusFlightRecorderView
- ❌ ArgusAnalystReportView
- ❌ MarketReportView
- ❌ BistMarketView
- ❌ DiscoverView
- ❌ NotificationsView
- ❌ TradeBrainView
- ❌ ArgusLabView, ChronosLabView, OrionLabView (modal state'te ölü kod)
- ❌ 90+ daha fazlası...

**Nasıl Düzelt:**
```swift
// ✅ Proper Navigation Router
protocol NavigationPath {
    case home
    case markets
    case analysis
    case portfolio
    case settings
    case backtest
    case labs
    case reports
    case discover
    case notifications
    case tradeBrain
    case bist
    // + tüm 108 view için
}

class NavigationCoordinator: ObservableObject {
    @Published var path: NavigationPath?

    func navigate(to: NavigationPath) {
        path = to  // Stack management
    }

    func push(_ view: NavigationPath) { }
    func pop() { }
    func popToRoot() { }
}
```

---

#### 4. **SIKI BAĞLANTILAR (Tight Coupling) - Service Hell**

❌ **KÖTÜ**: 124+ `.shared` singleton cascade
```
UnifiedDataStore.shared
  ↓
WatchlistViewModel.shared
  ↓
MarketDataStore.shared
  ↓
SignalStateViewModel.shared
  ↓
ExecutionStateViewModel.shared
  ↓
...
```

**ArgusDecisionEngine hard-coded dependencies:**
```swift
let regime = ChironRegimeEngine.shared  // Line 142
let synergy = ChimeraSynergyEngine.shared  // Line 147
let ledger = ArgusLedger.shared  // Line 491
```

**Problem**: Unit test yazamazsın, refactor edemezsin, mock edemezsin

**Nasıl Düzelt:**
```swift
// ❌ YAPMAAAA
class ArgusDecisionEngine {
    func makeDecision() {
        let regime = ChironRegimeEngine.shared  // Hard-coded
    }
}

// ✅ DOĞRU
class ArgusDecisionEngine {
    let regimeEngine: RegimeEngine
    let synergyEngine: SynergyEngine
    let ledger: TradeLedger

    init(
        regimeEngine: RegimeEngine,
        synergyEngine: SynergyEngine,
        ledger: TradeLedger
    ) {
        self.regimeEngine = regimeEngine
        self.synergyEngine = synergyEngine
        self.ledger = ledger
    }

    func makeDecision() {
        // Dependency injection - test edilebilir!
    }
}
```

---

#### 5. **DURUM MANAGEMENT KAOS - Tüm Değişim Tüm Veriyi Tetikliyor**

❌ **PROBLEM**: UnifiedDataStore observer hell (lines 24-59)
```swift
setupBindings() {
    WatchlistViewModel.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 1
    AppStateCoordinator.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 2
    MarketDataStore.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 3
    SignalStateViewModel.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 4
    ExecutionStateViewModel.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 5
    DiagnosticsViewModel.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 6
    PortfolioStore.shared.objectWillChange
        .sink { self?.objectWillChange.send() }  // 7
}
```

**Sonuç**: Tek bir quote güncellemesi → 7 sink tetiklenir → UnifiedDataStore tüm views'a bildiri gönderir → 10+ view re-render → uygulamada donuş

**ArgusSanctumView'deki comment bu sorunu açıkça gösteriyor:**
```swift
// LEAVING LEGACY VM BUT REMOVING OBSERVATION TO STOP RE-RENDERS
// ↑ Gözlem kaldırılmak zorunda çünkü app donuyor!
```

**Nasıl Düzelt:**
```swift
// ❌ YAPMAAAA - tüm changes'i rebroadcast etme
objectWillChange.send()

// ✅ DOĞRU - sadece ilgili değişimi gönder
@Published var quotes: [Quote] = []  // Granular update

// Views sadece ihtiyaç duydukları değişkeni gözlemle
@State var quotes = MarketDataStore.shared.$quotes
```

---

#### 6. **KÖL KOD ve BROKEN REFERENCES - Deprecated Apilar Hala Kullanılıyor**

❌ **121 TODO/FIXME** (50 dosya genelinde)
- MacroRegimeService: 19 TODO
- ArgusDecisionEngine: 1 (500+ satır fonksiyonda ne beklenir?)
- AlkindusCalibrationEngine: 2
- ArgusAutoPilotEngine: 1

❌ **Deprecated Apilar Hala Kodda:**
```swift
@available(*, unavailable, message: "Use ArgusLedger instead")
class SignalTrackerService { }  // Ama hala dosyada!

@available(*, deprecated, message: "Use MarketDataProvider")
class APIService { }  // Ama hala kullanılıyor

@available(*, deprecated, message: "Use ArgusLedger")
class ChironJournalService { }
```

❌ **Placeholder Implementations:**
```swift
var scoutingCandidates: [TradeSignal] { return [] }  // ✋ PLACEHOLDER
var topGainers: [Quote] = []  // "Placeholders to fix build"
```

**Nasıl Düzelt:**
```
✅ Deprecated kod sil, önerilen yere geç
✅ TODO'ları backlog'a taşı, koddaki açıklamadan kaldır
✅ Placeholder'ları gerçek implementasyonla yap veya feature flag'le
```

---

#### 7. **BAĞLANTISIZ MODÜLLER - Kod Var Ama Gitmek Yolu Yok**

❌ **Orphaned Labs** (hiç bir ana navigation'a erişilemiyor):
- ArgusLabView
- ChronosLabView
- OrionLabView
- ObservatoryView

❌ **ArgusSanctumView'de modal state hala var (ölü kod):**
```swift
@State private var showChronosLabSheet = false  // Trigger yok
@State private var showArgusLabSheet = false
@State private var showObservatorySheet = false
```

❌ **BIST Subsystem parçalanmış:**
- BistAtmosphereView orphaned
- RejimEngine'de 4 TODO
- Unified BIST navigation yok

**Nasıl Düzelt:**
```
✅ Labs'ı main navigation'a ekle
✅ Modal state'leri kaldır
✅ BIST'i feature olarak tamamla veya kaldır
```

---

### **KONTROL LİSTESİ - Yeni Feature Yazarken**

#### Before you code:
- [ ] Bu feature mevcut bir ViewModel'e eklenir mi? **EĞER EVET** → hataydı, ayrı ViewModel yap
- [ ] Bu feature 3+ service'e bağlanmıyor mu?
- [ ] Aynı veri başka bir yerde tekrar tutulmuyor mu? (SSOT'ı kontrol et)
- [ ] Navigation path'ı AppTabBar veya DeepLinkManager'a ekledim mi?
- [ ] Dependencies singleton'a hard-code ettim mi? **YAPMA** → inject et
- [ ] @Published property'lerin tamamını gözlemlemek gerek mi? **HAYIR** → granular data yap

#### While coding:
- [ ] ViewModel 300 satırı geçti mi? → Başka bir dosyaya taşı
- [ ] 5+ `.shared` instance access'i var mı? → Dependency injection yap
- [ ] objectWillChange.send() tüm veriyi broadcast'liyor mu? → Granular @Published yap
- [ ] Modal state'leri kullanıyor mum ve main navigation'dan gelmiyorsa? → Main navigation'a ekle

#### After coding:
- [ ] Test yazabildim mi? (Eğer yazamadıysam, tight coupling var)
- [ ] Başka bir ViewModel'i observe etmesi gerek mi? → İnherit et veya protocol'ü share et
- [ ] Deprecated API kullandığı var mı? → Yeni API'ye geç
- [ ] TODO koydum mu? → Açıklama yapıp backlog'a taşı
- [ ] Placeholder kod bıraktığı var mı? → Complete yap veya kaldır

---

### **BÜYÜK REFACTOR İHTİYACI (Priority Order)**

| Öncelik | Görev | İmpakt | Zorluk |
|---------|-------|--------|--------|
| **1** | UnifiedDataStore kaldır, AppStateCoordinator'u SSOT yap | Veri sync bug'ları ortadan kalkar | Yüksek |
| **2** | TradingViewModel'i 3 sub-VM'e böl | Test edilebilir hale gelir | Yüksek |
| **3** | Navigation router oluştur (tüm 108 view'a erişim) | 100+ orphaned view erişilebilir olur | Orta |
| **4** | ArgusDecisionEngine'i 5 smaller function'a böl | Unit test yazılabilir | Yüksek |
| **5** | Tüm `.shared` singleton'ları dependency injection'a çevir | Test edilebilir, refactor'lanabilir | Çok Yüksek |
| **6** | Deprecated API'ları sil | Kod 20% temizlenir | Düşük |
| **7** | 121 TODO'yu backlog'a taşı | Kod 10% daha temiz | Çok Düşük |
| **8** | Placeholder implementasyonları complete yap | Feature'lar çalışır | Orta |

---

## 📋 KODLAMA KURALLAR VE STANDARTLAR

### 1. **Yapı ve Organizasyon**

#### Dosya Organizasyonu
```
argus/
├── Views/           # SwiftUI görünüm bileşenleri
├── ViewModels/      # ViewModel'ler ve durum yönetimi
├── Services/        # İş mantığı ve dış entegrasyonlar
├── Models/          # Veri yapıları (Codable uyumlu)
├── Navigation/      # Yönlendirme ve deep linking
├── Extensions/      # Yardımcı uzantılar
├── Utilities/       # Helper fonksiyonlar
└── Assets/          # Görseller ve renk paleti
```

#### View Dosyası Yapısı
```swift
import SwiftUI

// MARK: - Main View
struct MyView: View {
    // MARK: - State
    @State private var property = value
    @StateObject private var viewModel = MyViewModel()

    // MARK: - Theme/Colors
    private let bgColor = Color(red: 0.02, green: 0.02, blue: 0.04)

    // MARK: - Body
    var body: some View {
        ZStack {
            // Content
        }
    }

    // MARK: - Subviews
    private var headerSection: some View {
        // Implementation
    }
}

// MARK: - Preview
#Preview {
    MyView()
}
```

### 2. **Kod Stilleri**

#### Renk Tanımlaması
- **Özel RGB renkleri tercih edilir** (hard-coded değerler):
  ```swift
  let bgColor = Color(red: 0.02, green: 0.02, blue: 0.04)      // Arka plan
  let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)       // Kart
  let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)            // Vurgu
  let gold = Color(red: 1.0, green: 0.8, blue: 0.2)            // İkincil
  let green = Color(red: 0.0, green: 0.8, blue: 0.4)           // Pozitif
  let red = Color(red: 0.9, green: 0.2, blue: 0.2)             // Negatif
  ```

#### Boşluk Yönetimi
- `VStack(spacing: 24)` - Ana bölümler arası
- `Spacer(minLength: 40)` - Büyük ayırıcılar
- `padding(16)` veya `padding(.horizontal, 20)` - İçerik boşluğu
- **Padding değerleri: 8, 12, 16, 20, 24, 40, 110** (tutarlı ölçek)

#### Durum Yönetimi
- `@State` - Local view state
- `@StateObject` - ViewModel oluşturma
- `@ObservedObject` - ViewModel bağlama
- `@EnvironmentObject` - Global state
- **Navigation: NavigationStack** (yeni)

### 3. **Adlandırma Konvansiyonları**

#### Görünümler
- Yapı adları `...View` ile bitişi: `AlkindusDashboardView`, `BistMarketView`
- ViewModels `...ViewModel`: `PortfolioViewModel`, `TradingViewModel`
- Bölüm fonksiyonları açıklayıcı: `headerSection`, `dataToolsSection`, `insightsSection`

#### Servisler
- Singleton pattern: `static let shared = MyService()`
- Açık yorum: `// MARK: - Fetch Candles (Real Data Only)`
- Deprecated gösterimi: `@available(*, deprecated, message: "Use ... instead")`

#### Değişkenler
- Private state: `@State private var isLoading = true`
- Boolean: `isLoading`, `showDrawer`, `isProcessing`
- Sayısal: `processedCount`, `totalToProcess`, `dbSizeMB`

### 4. **Hata Ayıklama ve Uyarılar**

#### Emoji Kullanımı
- `⚠️` - Uyarı ve not
- `// TODO:` - Gelecek görev
- `// FIXME:` - Acil düzeltme
- `// NOTE:` - Önemli bilgi

#### Print Statements
```swift
print("⚠️ API Error for \(symbol): \(error)")
print("Processing: \(processedCount)/\(totalToProcess)")
```

### 5. **Async/Await ve Networking**

#### API Çağrıları
```swift
func fetchCandles(symbol: String, resolution: String = "D") async -> [Candle] {
    do {
        return try await fetchRealCandles(symbol: symbol, resolution: resolution)
    } catch {
        print("⚠️ API Error for \(symbol): \(error)")
        return []
    }
}
```

#### Best Practices
- `async/await` kullan (closure yerine)
- Error handling `do/catch` ile
- Fallback değerleri döndür (boş array, nil)
- Hata logla ama sessiz fail (API hatalarında crash yok)

### 6. **UI Bileşenleri**

#### Navigation
```swift
NavigationStack {
    // Content
    NavigationLink(destination: DetailView()) {
        Text("Detail")
    }
}
```

#### ScrollView
```swift
ScrollView {
    VStack(spacing: 24) {
        // Content sections
    }
}
```

#### Conditional Loading
```swift
if isLoading {
    ProgressView().tint(cyan)
} else if let data = data {
    // Content
} else {
    Text("No data")
}
```

### 7. **Commit Mesajları**

#### Format
```
<type>: <açıklama> [- ek detay]

feat:     Yeni özellik
fix:      Hata düzeltme
UI Fix:   Görünüm düzeltme
Enhance:  İyileştirme
Restore:  Geri yükleme
Add:      Ekleme
Move:     Taşıma
```

#### Örnekler
- `feat: Wisdom Quotes sistemi - loading ve boş portföy sözleri`
- `UI Fix: Orion Layout - Prometheus moved to bottom, Consensus overlapping fixed`
- `Fix: BIST ve Global realize kar/zarar ayristirildi (Portfolio Separation)`
- `Enhance: Yeni 'Agirbasli' Splash Screen animasyonu`

#### Türkçe + İngilizce Karması
- **Ana başlık**: Türkçe veya tanımlayıcı
- **Detaylar**: İngilizce veya teknik terminoloji

### 8. **Kod Desenleri**

#### MVVM Pattern
```swift
// View
struct MyView: View {
    @StateObject var viewModel = MyViewModel()
    var body: some View { ... }
}

// ViewModel
class MyViewModel: ObservableObject {
    @Published var data: [Item] = []
    func loadData() { ... }
}
```

#### Singleton Pattern
```swift
class MyService {
    static let shared = MyService()
    private init() {}

    func doSomething() { ... }
}
```

#### Mock/Test Data
```swift
#Preview {
    MyView()
        .environment(\.locale, Locale(identifier: "tr_TR"))
}
```

### 9. **Performans**

#### Best Practices
- `@State private` - Çerçeve geneli değişkenleri gizle
- `.ignoresSafeArea()` - Tam ekran içeriği
- `lazy` - Kaynakları israf etme
- Avoid `ForEach` ile dinamik data vs önceden yapılandırılmış (performance)

#### Caching
- `DataCacheService`, `CacheManager` kullan
- API sonuçlarını lokal depo
- Redundant çağrıları önle

### 10. **Türkçe ve Lokalizasyon**

#### String Yönetimi
- Hard-coded stringler İngilizce UI'da
- Lokalize edilmesi gereken metinler `LocalizationManager` kullan
- Türkçe parametreler commit mesajlarında ve yorumlarda

#### Tarih/Sayı Formatı
- Türkçe pazar için BIST uyumlu format
- Global pazar için standart format
- Lokale göre ayarlanabilir yapı

---

## 🔄 GİT İŞ AKIŞI

### Commit Alışkanlığı
1. **Sık commit yap** - Her özellikllik/fix için
2. **Net mesajlar** - Değişikliği açıkça belirt
3. **Tekil değişiklik** - Bir committe bir sorunu çöz
4. **Test sonrası** - Commitlemeden önce test et

### Branch Adlandırması (Önerilir)
- `feature/wisdom-quotes` - Yeni özellik
- `fix/header-overlap` - Bug fix
- `ui/layout-improvements` - UI çalışması

---

## 🧪 Test ve Kalite

### Testi Gereken Alanlar
- Tüm yeni View'lar iPhone SE ile Pro Max'ta test et
- API entegrasyonları offline/online her iki durumda
- Dokunsal geri bildirim (haptic) tüm aksiyonlarda
- Koyu mod uyumluluğu

### Cihaz Testleri
```bash
# iPhone SE (2. nesil) - 375x667
# iPhone 14 - 390x844
# iPhone 14 Pro Max - 430x932
```

---

## 📚 Yaygın Sorunlar ve Çözümler

| Sorun | Çözüm |
|-------|-------|
| Derleme hataları | `.pbxproj` sözdizimini kontrol et, CocoaPods güncelle |
| Layout overlap | Padding ve spacing değerlerini kontrol et (110px rule) |
| State loop | @State lifecycle'ını düzgün kullan, dependency gözle |
| API timeout | Fallback değerleri döndür, user'a hata mesajı göster |
| Memory leak | @StateObject lifecycle'a dikkat, cycle referans yok |

---

## 🚀 Faydalı Komutlar

```bash
# Projeyi derle
xcodebuild -workspace argus.xcworkspace -scheme argus -configuration Debug

# Testleri çalıştır
xcodebuild test -workspace argus.xcworkspace -scheme argus

# Derleme artefaktlarını temizle
xcodebuild clean -workspace argus.xcworkspace

# Git durumunu görüntüle
git status

# Son 10 commiti göster
git log --oneline -n 10

# Değişiklikleri gözle
git diff

# Hazırla ve commit yap
git add <file>
git commit -m "feat: Açıklaması"
```

---

---

## 🏗️ MİMARİ KARAR AĞACI - "Bu Kodu Nereye Yazmalıyım?"

```
New code yazıyor musun?
│
├─ "ViewModel'e ekleyeyim" diye düşünüyor musun?
│  └─ ❌ DUR! Şu soruları sor:
│     ├─ Bu ViewModel zaten 300+ satır mı? → Ayrı bir ViewModel yap
│     ├─ Bu sadece UI state mi yoksa business logic mi?
│     │  ├─ UI state → ViewModel'de kalabilir
│     │  └─ Business logic → Service'e taşı
│     ├─ Başka ViewModel'i observe etmem gerek mi? → Coupling! Serviste paylaş
│     └─ Aynı veri başka bir yerde tutulmuş mu? → SSOT'ı kontrol et
│
├─ "Service'te yazayım" diye düşünüyor musun?
│  └─ ✅ DOĞRU! Ama:
│     ├─ Hard-coded `.shared` kullanmıyorum mı? → Dependency injection yap
│     ├─ 200+ satırı geçer miyim? → Başka bir fonksiyona/dosyaya böl
│     ├─ 5+ farklı service'e bağlanıyor mum? → Coupling! Tasarımı gözden geçir
│     └─ Test yazabildim mi? → Eğer yazamadıysam, tight coupling var
│
├─ "View'da yazayım" diye düşünüyor musun?
│  └─ ⚠️ SADECE:
│     ├─ UI layout (VStack, HStack, padding)
│     ├─ Local state (@State)
│     ├─ Basit event handling
│     └─ BAŞKA BİR ŞEY YAPMAAAA!
│
└─ Navigation mı?
   └─ AppTabBar veya DeepLinkManager'a ekle
      (ve tüm 108 view'a erişim sağla!)
```

---

## 🚨 RED FLAGS - Eğer bu'yu yapıyorsan, SAT VE DÜŞÜN

| Red Flag | Anlamı | Çözüm |
|----------|--------|-------|
| `.shared` 5+ kez çağırıyorum | Coupling çoook fazla | Dependency injection |
| ViewModel 400+ satır | God object | Böl, ayrı ViewModel yap |
| Aynı veri 2+ yerde @Published | Multiple sources of truth | SSOT'ı tespit et, birleştir |
| `objectWillChange.send()` her yerde | Tüm app re-render'ı | Granular @Published yap |
| Modal state var ama trigger yok | Dead code | Sil veya main navigation'a ekle |
| TODO yorum 10+ satır | Neden hala kodda? | Backlog'a taşı, kodu temizle |
| Test yazamıyorum | Tight coupling/design problem | Dependency injection, protocol'leri çıkar |
| View dosya 500+ satır | God component | Extract subviews |
| Başka bir ViewModel'i @ObservedObject'le tutuyorum | Tight coupling | Service aracılığıyla veri paylaş |
| Deprecated API hala kullanılıyor | Migration eksik | Yeni API'ye geç |

---

## 🎯 BEST PRACTICES - Doğru Mimarı

### **State Management**
```swift
// ❌ YAPMAAAA
class AppViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    @Published var market: MarketData
    @Published var signals: [Signal]
    @Published var execution: ExecutionState
    @Published var alerts: [Alert]
    @Published var notifications: [Notification]
    // ... 30 property, 54 fonksiyon
}

// ✅ DOĞRU
class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio
    // Sadece portfolio ile ilgili
}

class MarketViewModel: ObservableObject {
    @Published var market: MarketData
    // Sadece market ile ilgili
}

// Views kendi ViewModel'lerini kullanır
@StateObject var portfolio = PortfolioViewModel()
@StateObject var market = MarketViewModel()
```

### **Service Design**
```swift
// ❌ YAPMAAAA - singleton, hard-coded
class ArgusDecisionEngine {
    static let shared = ArgusDecisionEngine()

    func makeDecision(for symbol: String) -> Decision {
        let regime = ChironRegimeEngine.shared
        let synergy = ChimeraSynergyEngine.shared
        let ledger = ArgusLedger.shared
    }
}

// ✅ DOĞRU - injectable, testable
class ArgusDecisionEngine {
    let regimeEngine: RegimeEngine
    let synergyEngine: SynergyEngine
    let ledger: TradeLedger

    init(
        regimeEngine: RegimeEngine,
        synergyEngine: SynergyEngine,
        ledger: TradeLedger
    ) {
        self.regimeEngine = regimeEngine
        self.synergyEngine = synergyEngine
        self.ledger = ledger
    }

    func makeDecision(for symbol: String) -> Decision {
        // Dependency injection - test edilebilir!
    }
}
```

### **Navigation**
```swift
// ❌ YAPMAAAA - DeepLinkManager 41 satır, tüm views orphaned
class DeepLinkManager {
    func navigate(to: String) { }
    func openStockDetail(symbol: String) { }
    // Bitti, başka hiç bir view'a gidemezsin
}

// ✅ DOĞRU - NavigationCoordinator tüm views'ı kapsayan
class NavigationCoordinator: ObservableObject {
    @Published var path: [NavigationDestination] = []

    func navigate(to: NavigationDestination) {
        path.append(to)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeAll()
    }
}

enum NavigationDestination: Hashable {
    case home
    case markets
    case alkindus
    case portfolio
    case settings
    case backtest
    case labs
    case reports
    case discover
    case notifications
    case tradeBrain
    case bist
    // ... tüm 108 view
}
```

### **Avoiding Duplication**
```swift
// ❌ YAPMAAAA
class UnifiedDataStore: ObservableObject {
    @Published var portfolio: Portfolio

    func setupBindings() {
        PortfolioStore.shared.$trades
            .sink { self.portfolio.trades = $0 }  // KOPYALAMA!
    }
}

// ✅ DOĞRU - sadece gözlemleme, kopyalama yok
@Published var portfolio = PortfolioStore.shared.$portfolio
// veya Views doğrudan PortfolioStore'u kullan
```

---

## 📊 MİMARİ KALİTE METRİKLERİ

Şu şekilde ölçebilirsin mimariniz iyi mi?

| Metrik | Hedef | Şu Anki | İş |
|--------|-------|--------|-----|
| ViewModel max satır sayısı | < 300 | 1,459 (TradingVM) | Böl |
| Service max satır sayısı | < 500 | 866 (ArgusDecisionEngine) | Böl |
| Service dependency count | < 3 | 5+ | Decouple |
| SSOT (Single Source of Truth) count | = 1 per domain | 3-4 | Consolidate |
| Test coverage | > 60% | ? | Test yaz |
| Deprecated API usage | 0% | 3 active | Migrate |
| TODO count | < 20 | 121 | Backlog'a taşı |
| Navigation accessible views | 100% | 5% (5/108) | Router oluştur |

---

## 📖 Referanslar

- [SwiftUI Belgelendirmesi](https://developer.apple.com/xcode/swiftui/)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [iOS App Architecture - MVVM](https://www.raywenderlich.com/books)
- [Dependency Injection in Swift](https://www.swiftbysundell.com/articles/dependency-injection-in-swift/)
- [Protocol-Oriented Programming](https://developer.apple.com/videos/play/wwdc2015/408/)
- [Avoiding God Objects](https://refactoring.guru/smells/refused-bequest)
- Ticaret/Finans API Standartları
