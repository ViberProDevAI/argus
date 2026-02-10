import Foundation
import SwiftUI
import Combine

// MARK: - Hermes News ViewModel
/// Haber analizi ve news insight yönetimi için ayrılmış ViewModel.
/// TradingViewModel'den ADIM 3B refactoring ile oluşturuldu.
/// Direct store access yerine backward compatibility için TradingViewModel extension metodlarını çağırır.
final class HermesNewsViewModel: ObservableObject {

    // MARK: - Singleton
    static let shared = HermesNewsViewModel()

    // MARK: - Published Properties

    // News Data
    @Published var newsBySymbol: [String: [NewsArticle]] = [:]
    @Published var newsInsightsBySymbol: [String: [NewsInsight]] = [:]
    @Published var hermesEventsBySymbol: [String: [HermesEvent]] = [:]
    @Published var kulisEventsBySymbol: [String: [HermesEvent]] = [:]

    // Hermes Feeds
    @Published var watchlistNewsInsights: [NewsInsight] = [] // Tab 1: "Takip Listem"
    @Published var generalNewsInsights: [NewsInsight] = []   // Tab 2: "Genel Piyasa"

    // Loading State
    @Published var isLoadingNews: Bool = false
    @Published var newsErrorMessage: String? = nil

    // Hermes Mode & Summaries
    @Published var hermesSummaries: [String: [HermesSummary]] = [:] // Symbol -> Summaries
    @Published var hermesMode: HermesMode = .full

    // MARK: - Dependencies (Direct Store Access)
    private var watchlistStore: WatchlistStore { WatchlistStore.shared }
    private var marketDataStore: MarketDataStore { MarketDataStore.shared }

    // MARK: - Computed Convenience
    private var watchlist: [String] { watchlistStore.items }

    // Quotes from MarketDataStore (DataValue wrapper)
    private var quotes: [String: Quote] {
        var result: [String: Quote] = [:]
        for (symbol, dataValue) in marketDataStore.quotes {
            if let quote = dataValue.value {
                result[symbol] = quote
            }
        }
        return result
    }

    // USD/TRY Rate - stored locally, synced with RiskViewModel via AnalysisViewModel
    @Published private var _usdTryRate: Double = 35.0
    private var usdTryRate: Double {
        get { _usdTryRate }
        set { _usdTryRate = newValue }
    }

    // Macro Rating from MacroRegimeService
    private var macroRating: MacroEnvironmentRating? { MacroRegimeService.shared.getCachedRating() }

    // BIST Atmosphere - stored locally
    @Published private var _bistAtmosphere: AetherDecision? = nil
    @Published private var _bistAtmosphereLastUpdated: Date? = nil

    private var bistAtmosphere: AetherDecision? {
        get { _bistAtmosphere }
        set { _bistAtmosphere = newValue }
    }
    private var bistAtmosphereLastUpdated: Date? {
        get { _bistAtmosphereLastUpdated }
        set { _bistAtmosphereLastUpdated = newValue }
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - News & Insights (Gemini)

    @MainActor
    func loadNewsAndInsights(for symbol: String, isGeneral: Bool = false) {
        // Reset state only if specific symbol fetch failing affects UI state differently
        isLoadingNews = true
        newsErrorMessage = nil

        Task {
            do {
                let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)

                // 1. Fetch News (Fetch MORE to filter bad apples)
                let articles: [NewsArticle]
                if isBist {
                    articles = try await RSSNewsProvider().fetchNews(symbol: symbol, limit: 30)
                } else {
                    articles = try await YahooFinanceNewsProvider.shared.fetchNews(symbol: symbol, limit: 20)
                }

                self.newsBySymbol[symbol] = articles

                // 2. Analyze Top Articles
                var candidates = articles

                if !isGeneral {
                    // STRICT FILTER ENHANCED: Ticker OR Company Name
                    let aliases: [String: [String]] = [
                        "AAPL": ["APPLE", "IPHONE", "IPAD", "MACBOOK"],
                        "AMZN": ["AMAZON", "AWS", "PRIME"],
                        "GOOGL": ["GOOGLE", "ALPHABET", "YOUTUBE", "GEMINI"],
                        "GOOG": ["GOOGLE", "ALPHABET", "YOUTUBE"],
                        "MSFT": ["MICROSOFT", "WINDOWS", "AZURE", "OPENAI"],
                        "TSLA": ["TESLA", "MUSK", "CYBERTRUCK"],
                        "NVDA": ["NVIDIA", "GPU", "AI CHIP"],
                        "META": ["META", "FACEBOOK", "INSTAGRAM", "WHATSAPP"],
                        "NFLX": ["NETFLIX"],
                        "AMD": ["AMD", "ADVANCED MICRO"],
                        "INTC": ["INTEL"],
                        "AVGO": ["BROADCOM"],
                        "ORCL": ["ORACLE"],
                        "CRM": ["SALESFORCE"],
                        "ADBE": ["ADOBE"],
                        "QCOM": ["QUALCOMM"],
                        "IBM": ["IBM"],
                        "CSCO": ["CISCO"],
                        "UBER": ["UBER"],
                        "ABNB": ["AIRBNB"],
                        "PLTR": ["PALANTIR"],
                        "COIN": ["COINBASE", "BITCOIN", "CRYPTO"],
                        "HOOD": ["ROBINHOOD"],
                        "BABA": ["ALIBABA"],
                        "BIDU": ["BAIDU"],
                        "TCEHY": ["TENCENT"],
                        "TSM": ["TAIWAN SEMI", "TSMC"]
                    ]

                    let symbolUpper = symbol.uppercased()
                    let symbolAliases = aliases[symbolUpper] ?? []

                    candidates = articles.filter { article in
                        let headline = article.headline.uppercased()
                        if headline.contains(symbolUpper) { return true }
                        for alias in symbolAliases {
                            if headline.contains(alias) { return true }
                        }
                        return false
                    }

                    // Fallback: If strict filter killed everything, check GENERAL FEED for matches
                    if candidates.isEmpty {
                        let generalMatches = self.generalNewsInsights.filter { insight in
                            return insight.symbol.uppercased() == symbolUpper
                        }

                        if !generalMatches.isEmpty {
                            print("Hermes: Found relevant news in General Feed for \(symbol). Using it.")
                            self.newsInsightsBySymbol[symbol] = generalMatches
                            self.isLoadingNews = false
                            // Note: loadArgusData removed - caller should handle if needed
                            return
                        }

                        print("Hermes: No relevant news found for \(symbol) (Strict Filter + General Check). Skipping.")
                        self.isLoadingNews = false
                        return
                    }
                }

                // Limit Logic
                let limit = isGeneral ? 6 : 3
                let topArticles = Array(candidates.prefix(limit))

                let scope: HermesEventScope = isBist ? .bist : .global
                let events = try await HermesLLMService.shared.analyzeEvents(
                    articles: topArticles,
                    scope: scope,
                    isGeneral: isGeneral
                )

                let insights = mapEventsToInsights(events)

                // HERMES DISCOVERY: Check for new opportunities from all insights
                for insight in insights {
                    if let tickers = insight.relatedTickers, !tickers.isEmpty {
                        Task { await AutoPilotStore.shared.analyzeDiscoveryCandidates(tickers, source: insight) }
                    }
                }

                // Add to Relevant Feed
                if isGeneral {
                    for insight in insights {
                        if !self.generalNewsInsights.contains(where: { $0.articleId == insight.articleId }) {
                            self.generalNewsInsights.append(insight)
                        }
                    }
                    self.hermesEventsBySymbol["GENERAL"] = events
                } else {
                    for insight in insights {
                        if !self.watchlistNewsInsights.contains(where: { $0.articleId == insight.articleId }) {
                            self.watchlistNewsInsights.append(insight)
                        }
                    }
                }

                if !isGeneral {
                    self.newsInsightsBySymbol[symbol] = insights
                    if isBist {
                        self.kulisEventsBySymbol[symbol] = events
                    } else {
                        self.hermesEventsBySymbol[symbol] = events
                    }
                }

                // Re-sort Feeds (Newest first)
                if isGeneral {
                    self.generalNewsInsights.sort { $0.createdAt > $1.createdAt }
                } else {
                    self.watchlistNewsInsights.sort { $0.createdAt > $1.createdAt }
                }

                self.isLoadingNews = false

            } catch {
                self.isLoadingNews = false
                self.newsErrorMessage = "Haber akışı alınamadı: \(error.localizedDescription)"
                print("News fetch error: \(error)")
            }
        }
    }

    // Hermes: Load Watchlist Feed
    @MainActor
    func loadWatchlistFeed() {
        isLoadingNews = true

        // Define key symbols + Watchlist
        let keySymbols = ["SPY", "QQQ", "BTC-USD", "ETH-USD"]
        let allSymbols = Set(keySymbols + watchlist).prefix(8)

        Task {
            for symbol in allSymbols {
                loadNewsAndInsights(for: symbol, isGeneral: false)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0s between symbols
            }
        }
    }

    // Hermes: Load General Feed
    func loadGeneralFeed() {
        isLoadingNews = true
        loadNewsAndInsights(for: "GENERAL", isGeneral: true)

        // BIST haberleri yüklenirken Sirkiye Atmosferini de güncelle
        Task {
            await refreshBistAtmosphere()
        }
    }

    // MARK: - Sirkiye Engine Integration (BIST Politik Atmosfer)

    @MainActor
    func refreshBistAtmosphere() async {
        // 1. USD/TRY Kuru (BorsaPyProvider - Doviz.com'dan)
        var usdTry: Double = self.usdTryRate
        var usdTryPrevious: Double = self.usdTryRate

        do {
            let fxRate = try await BorsaPyProvider.shared.getFXRate(asset: "USD")
            usdTry = fxRate.last
            usdTryPrevious = fxRate.open
            self.usdTryRate = usdTry
            print("💱 BorsaPy: USD/TRY = \(String(format: "%.4f", usdTry))")
        } catch {
            // Fallback: Mevcut quote'ları kullan
            if let usdTryQuote = self.quotes["USD/TRY"] ?? self.quotes["USDTRY=X"] {
                usdTry = usdTryQuote.currentPrice
                usdTryPrevious = usdTryQuote.previousClose ?? usdTryQuote.currentPrice
            }
        }

        // 2. Global VIX (Gerçek Veri)
        var globalVix: Double? = nil
        if let vixQuote = self.quotes["^VIX"] {
            globalVix = vixQuote.currentPrice
        } else if let macro = self.macroRating {
            globalVix = macro.volatilityScore
        }

        // 3. Brent Petrol (BorsaPyProvider - Doviz.com'dan)
        var brentOil: Double? = nil
        do {
            let brentRate = try await BorsaPyProvider.shared.getBrentPrice()
            brentOil = brentRate.last
            print("🛢️ BorsaPy: Brent = $\(String(format: "%.2f", brentRate.last))")
        } catch {
            if let brentQuote = self.quotes["BZ=F"] ?? self.quotes["BRENT"] {
                brentOil = brentQuote.currentPrice
            }
        }

        // 4. DXY (Dolar Endeksi)
        var dxy: Double? = nil
        if let dxyQuote = self.quotes["DX-Y.NYB"] ?? self.quotes["DXY"] {
            dxy = dxyQuote.currentPrice
        }

        // 5. Haber Verisi (Sirkiye için Türkiye haberleri)
        let turkeyRelatedInsights = self.generalNewsInsights.filter { insight in
            let text = insight.headline.lowercased()
            return text.contains("türk") || text.contains("turk") ||
                   text.contains("erdoğan") || text.contains("erdogan") ||
                   text.contains("tcmb") || text.contains("merkez bankası") ||
                   text.contains("borsa istanbul") || text.contains("bist") ||
                   text.contains("tl") || text.contains("lira")
        }

        // HermesNewsSnapshot oluştur
        var hermesSnapshot: HermesNewsSnapshot? = nil
        if !turkeyRelatedInsights.isEmpty {
            hermesSnapshot = HermesNewsSnapshot(
                symbol: "BIST",
                timestamp: Date(),
                insights: turkeyRelatedInsights,
                articles: self.newsBySymbol["GENERAL"] ?? []
            )
        }

        // 6. Sirkiye Engine'i çağır
        let input = SirkiyeEngine.SirkiyeInput(
            usdTry: usdTry,
            usdTryPrevious: usdTryPrevious,
            dxy: dxy,
            brentOil: brentOil,
            globalVix: globalVix,
            newsSnapshot: hermesSnapshot,
            currentInflation: 45.0,
            policyRate: 50.0,
            xu100Change: nil,
            xu100Value: nil,
            goldPrice: nil
        )

        let decision = await SirkiyeEngine.shared.analyze(input: input)

        // 7. Sonucu kaydet
        self.bistAtmosphere = decision
        self.bistAtmosphereLastUpdated = Date()

        print("🇹🇷 Sirkiye: Atmosfer güncellendi - Skor: \(Int(decision.netSupport * 100)), Mod: \(decision.marketMode)")
    }

    func getHermesHighlights() -> [NewsInsight] {
        var allInsights: [NewsInsight] = []
        for list in newsInsightsBySymbol.values {
            allInsights.append(contentsOf: list)
        }

        return allInsights
            .filter { $0.confidence > 0.6 }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Manual Analysis (Sanctum Button)
    @MainActor
    func analyzeOnDemand(symbol: String) async {
        self.isLoadingNews = true

        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)

        do {
            let articles: [NewsArticle]
            if isBist {
                articles = try await RSSNewsProvider().fetchNews(symbol: symbol, limit: 20)
            } else {
                articles = try await YahooFinanceNewsProvider.shared.fetchNews(symbol: symbol, limit: 15)
            }

            self.newsBySymbol[symbol] = articles

            let scope: HermesEventScope = isBist ? .bist : .global
            let events = try await HermesLLMService.shared.analyzeEvents(
                articles: articles,
                scope: scope,
                isGeneral: false
            )

            let insights = mapEventsToInsights(events)
            self.newsInsightsBySymbol[symbol] = insights

            if isBist {
                self.kulisEventsBySymbol[symbol] = events
            } else {
                self.hermesEventsBySymbol[symbol] = events
            }
        } catch {
            self.newsErrorMessage = "Haber analizi yapılamadı: \(error.localizedDescription)"
        }

        self.hermesMode = HermesCoordinator.shared.getCurrentMode()
        self.isLoadingNews = false

        // Note: Argus recalculation removed - caller should handle if needed
    }

    // MARK: - Private Helpers

    private func mapEventsToInsights(_ events: [HermesEvent]) -> [NewsInsight] {
        return events.map { event in
            let sentiment: NewsSentiment = event.sentimentLabel ?? .neutral

            let delayPenalty = HermesEventScoring.delayFactor(
                ageMinutes: max(0.0, Date().timeIntervalSince(event.publishedAt) / 60.0)
            )

            let riskFlagsText = event.riskFlags.map { $0.rawValue }.joined(separator: ", ")
            let detail = """
            Bu haber \(event.polarity == .positive ? "olumlu" : (event.polarity == .negative ? "olumsuz" : "karma")) etki üretiyor.
            Şiddet: \(Int(event.severity))/100, Kaynak güveni: \(Int(event.sourceReliability))/100.
            Gecikme etkisi: %\(Int(delayPenalty * 100)).
            \(riskFlagsText.isEmpty ? "" : "Uyarılar: \(riskFlagsText).")
            """

            return NewsInsight(
                id: UUID(),
                symbol: event.symbol,
                articleId: event.articleId,
                headline: event.headline,
                summaryTRLong: detail,
                impactSentenceTR: event.rationaleShort,
                sentiment: sentiment,
                confidence: event.confidence,
                impactScore: event.finalScore,
                relatedTickers: nil,
                createdAt: event.createdAt
            )
        }
    }
}
