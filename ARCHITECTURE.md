# Argus mimarisi ve metodoloji

Bu belge, kod tabanı ile `README` / `CONTRIBUTING` arasındaki boşluğu kapatır; özellikle modül haritası, durum yönetimi geçişi, test/DI beklentileri ve analitik şeffaflık maddelerini toplar.

## 1. Modül özeti (ekran ↔ servis)

| Alan | Ana servis / store örnekleri | Not |
|------|------------------------------|-----|
| Piyasa verisi | `MarketDataStore`, `TwelveDataService`, `YahooFinanceProvider`, `BorsaPyProvider` | Çoklu sağlayıcı; Heimdall yönlendirme |
| BIST | `BorsaPyProvider`, `BistDataService`, `TahtaEngine`, `KAPDataService` | Opsiyonel backend |
| Portföy / işlem | `PortfolioStore`, `PaperBroker`, `PositionPlanStore` | Gerçek aracı yok; paper |
| Konsey / karar | `ArgusGrandCouncil`, `ArgusDecisionEngine` | Çok modüllü skor birleşimi |
| Teknik | `OrionAnalysisService`, `OrionMultiFrameEngine`, `ChartPatternEngine` | |
| Makro | `MacroRegimeService`, `AetherAllocationEngine`, `FRED`/`TCMB` servisleri | |
| Chiron / öğrenme | `ChironDataLakeService`, `ChironLearningJob`, backtest motorları | |
| Alkindus / RAG | `AlkindusRAGEngine`, `PineconeService`, `GeminiEmbeddingService` | Opsiyonel Pinecone |
| Hermes / haber | `HermesLLMService`, `GeminiNewsService`, `RSSNewsProvider` | |
| Trade Brain | `TradeBrainExecutor`, `HorizonEngine`, `SelfQuestionEngine` | |
| Autopilot | `AutoPilotService`, `ArgusAutoPilotEngine` | Güvenlik katmanları ile |
| Teşhis | `HeimdallOrchestrator`, `ServiceHealthMonitor` | |

Liste tam değildir; yeni motor eklendiğinde bu tablo güncellenmelidir.

## 2. Durum katmanı ve geçiş (rapor maddesi: çift merkez)

**Bugün:** `TradingViewModel` (geniş facade) ile `AppStateCoordinator` ve çok sayıda `*.shared` singleton birlikte çalışıyor.

**Hedef:** Tek görünür koordinasyon yüzeyi (`AppStateCoordinator` veya seçilen başka facade); ağır veri `Store`/`ViewModel` alt bileşenlerinde; mümkün olan yerde protokol + enjeksiyon.

**Önerilen sıra (atlanmadan ilerlemek için kontrol listesi):**

1. Yeni özellikler yalnızca `PortfolioStore` / `MarketDataStore` / ilgili store üzerinden eklenir; `TradingViewModel`'e yalnızca ince proxy eklenir.
2. Ekranlar mümkün olduğunca `environmentObject(coordinator)` + domain store ile beslenir; doğrudan `Xxx.shared` çağrısı eklenmez.
3. Her tamamlanan ekran için `TradingViewModel`'deki tekrarlayan `@Published` / hesaplanmış alan bir alt modüle taşınır ve test notu düşülür.
4. `DIContainer` ve `DependencyValues` için kritik servislerde `DependencyKey` tanımlanır (önce test edilebilir saf mantık).
5. `TradingViewModel` yalnızca geriye dönük uyumluluk için ince facade kalacak şekilde inceltilir (uzun vadeli).

## 3. Bağımlılık enjeksiyonu

- **`DIContainer`:** `@MainActor` servis protokolleri ve `reset()` / `configure(...)` ile test izolasyonu.
- **`DependencyValues` (`Services/DI/DependencyContainer.swift`):** SwiftUI ortamı için; `test` ortamı boş başlar, `DependencyKey` eklendikçe doldurulur.
- **Protokol soyutlama:** `DataProvider: Sendable`, `FundamentalsProviderProtocol: Sendable`, `PortfolioStoreProtocol` tanımlıdır (`Services/Providers/DataProviderProtocol.swift`). Yeni singleton'lar bu kalıba uygun şekilde protokol arkasına alınmalıdır.
- **Testlerde:** Saf mantık için doğrudan struct/fonksiyon testi; servisler için `DIContainer.shared.reset()` + `configure` veya ileride `DependencyKey` ile sahte değer.

## 4. Gözlemlenebilirlik

- **`ArgusLogger` (actor):** Üretimde OSLog; DEBUG'da konsol. Yeni kodda ham `print` kullanılmamalı.
- **Fire-and-forget statik API:** `ArgusLogger.info("...", category: "XXX")` — `await` gerektirmez; tüm kritik dosyalarda bu kalıba geçildi.
- **`ArgusLogger.Module` statik yardımcıları:** DEBUG odaklı; ağır iş yok.

## 5. Test stratejisi

- **`argusTests`** hedefi Xcode projesine bağlıdır; şema `argus` altında test çalıştırır.
- Mevcut testler: `TradeValidatorTests`, `CachePolicyTests`, `SymbolMapperTests`, `MarketViewModelTests`, `TradingViewModelFacadeTests`, `PortfolioViewModelTests`, `SignalViewModelTests`, `PulsingFABViewTests`.
- Öncelik: doğrulanabilir saf mantık (`TradeValidator`, cache politikası, hesap motorları), ardından ViewModel facade.
- CI: GitHub Actions ile `Secrets.xcconfig.example` → `Secrets.xcconfig` kopyası sonrası `xcodebuild test`.
- **CI hedefi:** Workflow varsayılan olarak `iPhone 16` simülatörünü kullanır. Runner'da yoksa `xcodebuild -scheme argus -showdestinations` çıktısına göre `.github/workflows/ios.yml` içindeki `-destination` güncellenmelidir.
- **Yerel:** CoreSimulator / bellek hatasıyla derleme kırılırsa ortam sorunudur; Xcode'da bir simülatör kurup tekrar deneyin.

## 6. Analitik şeffaflık ve ürün sınırları (yatırım yazılımı)

- Uygulama **yatırım tavsiyesi değildir**; gösterilen skorlar, konsey çıktıları ve simülasyonlar **model varsayımlarına** bağlıdır.
- Backtest / forward test: **geçmişe sızıntı (lookahead)** ve **survivorship** gibi riskler tamamen elimine edilemez; sonuçlar yönlendirici kabul edilmelidir.
- Kullanıcıya dönük metinlerde veri gecikmesi, sağlayıcı kesintisi ve model belirsizliği mümkün olduğunca açık tutulmalıdır.

## 7. Rapor takibi (tamamlanan / süren işler)

| Konu | Durum |
|------|--------|
| Test hedefi + paylaşılan scheme | Tamamlandı |
| CI iş akışı | Tamamlandı |
| Canlı mimari belgesi (`ARCHITECTURE.md`) | Tamamlandı |
| CONTRIBUTING test/DI bölümü | Güncellendi |
| `argusApp` başlangıç logları → `ArgusLogger` | Tamamlandı |
| `TradeBrainView` yardımcı bileşen ayrımı | Tamamlandı |
| `print` → `ArgusLogger` sistematik geçiş | Tamamlandı (~240+ çağrı: Store'lar, TradeBrain, Council, Chiron, Heimdall, Groq, Keychain, Makro, TEFAS, ViewModel'ler) |
| `ArgusLogger` fire-and-forget statik API | Tamamlandı (`nonisolated static` — `await` gerektirmez) |
| `TradingViewModel` god-class bölme | SSoTBindings + ExportHelpers ayrıldı (1584→1325 satır) |
| Ek testler | TradeValidator, CachePolicy, SymbolMapper testleri eklendi |
| Singleton azaltma: protokol soyutlama | `PortfolioStoreProtocol` + `DataProvider: Sendable` tanımlandı |
| Kalan `print` temizliği (uzun kuyruk ~80 dosya) | Süreğen |
| Singleton → DI tam geçiş | Süreğen (§2 kontrol listesi) |

Bu tablo her önemli PR'da güncellenmelidir.
