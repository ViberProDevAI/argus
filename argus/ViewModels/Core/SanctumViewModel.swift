import Foundation
import Combine
import SwiftUI

// MARK: - Sanctum View Model
/// "Sanctum" (Hisse Detay) ekranı için özel, hafif sıklet yönetici.
/// AMACI: God Object (TradingViewModel) bağımlılığını ortadan kaldırmak.
/// Sadece tek bir sembolün verisini yönetir.

@MainActor
final class SanctumViewModel: ObservableObject {

    // MARK: - Properties
    let symbol: String

    // Timeframe State (Chart & Orion synchronization)
    @Published var selectedTimeframe: TimeframeMode = .daily

    // UI State
    @Published var quote: Quote?
    @Published var snapshot: FinancialSnapshot?
    @Published var candles: [Candle] = []
    // Argus Council State (Bridged from SignalStateViewModel & HermesStateViewModel)
    @Published var orionAnalysis: MultiTimeframeAnalysis?
    @Published var orionScore: OrionScoreResult? // Legacy
    @Published var macroRating: MacroEnvironmentRating?
    @Published var grandDecision: ArgusGrandDecision?
    @Published var hermesDecision: HermesDecision?
    @Published var newsInsights: [NewsInsight] = []

    // HERMES State (News & Sentiment)
    @Published var hermesEvents: [HermesEvent] = []
    @Published var kulisEvents: [HermesEvent] = [] // BIST specific
    @Published var isLoadingNews: Bool = false
    @Published var newsErrorMessage: String? = nil

    // Loading States
    @Published var isLoading: Bool = false
    @Published var isCandlesLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies (Direct Access)
    private let marketStore = MarketDataStore.shared
    private let analysisService = FinancialSnapshotService.shared
    // private let executionService = ExecutionService.shared (İleride eklenecek)
    
    // MARK: - Initialization
    init(symbol: String) {
        self.symbol = symbol
        setupBindings()
        
        // Auto-load on init
        Task { await loadData() }
    }
    
    // MARK: - Setup (Reactive Bindings)
    // MARK: - Setup (Reactive Bindings)
    private func setupBindings() {
        // 1. Live Quote Updates (MarketDataStore SSoT)
        marketStore.$quotes
            .map { $0[self.symbol]?.value } // Map to Quote? (matches property type)
            .receive(on: RunLoop.main)
            .assign(to: \.quote, on: self)
            .store(in: &cancellables)
            
        // 2. Orion Analysis (SignalStateViewModel)
        SignalStateViewModel.shared.$orionAnalysis
            .map { $0[self.symbol] } // Map to MultiTimeframeAnalysis?
            .receive(on: RunLoop.main)
            .assign(to: \.orionAnalysis, on: self)
            .store(in: &cancellables)
            
        // 2b. Orion Score (Derived from Analysis)
        SignalStateViewModel.shared.$orionAnalysis
            .map { $0[self.symbol]?.daily } // Access .daily -> OrionScoreResult?
            .receive(on: RunLoop.main)
            .assign(to: \.orionScore, on: self)
            .store(in: &cancellables)
            
        // 3. Grand Council (SignalStateViewModel)
        SignalStateViewModel.shared.$grandDecisions
            .map { $0[self.symbol] } // Map to ArgusGrandDecision?
            .receive(on: RunLoop.main)
            .assign(to: \.grandDecision, on: self)
            .store(in: &cancellables)
            
        // 4. Hermes NewsInsights (HermesStateViewModel)
        HermesStateViewModel.shared.$newsInsightsBySymbol
            .map { $0[self.symbol] ?? [] } // Map to [NewsInsight] (non-optional property)
            .receive(on: RunLoop.main)
            .assign(to: \.newsInsights, on: self)
            .store(in: &cancellables)

        // 4b. Hermes Events (Global stocks)
        HermesStateViewModel.shared.$hermesEventsBySymbol
            .map { $0[self.symbol] ?? [] }
            .receive(on: RunLoop.main)
            .assign(to: \.hermesEvents, on: self)
            .store(in: &cancellables)

        // 4c. Kulis Events (BIST stocks)
        HermesStateViewModel.shared.$kulisEventsBySymbol
            .map { $0[self.symbol] ?? [] }
            .receive(on: RunLoop.main)
            .assign(to: \.kulisEvents, on: self)
            .store(in: &cancellables)

        // 5. Candles (MarketDataStore)
        // Note: MarketDataStore usually doesn't stream candles, so we rely on explicit load or polling if needed.
        // For now, initial load is enough.
    }
    
    func loadData() async {
        self.isLoading = true
        defer { self.isLoading = false }

        // A. Ensure Quote & Candles
        let _ = await marketStore.ensureQuote(symbol: symbol)

        // Fetch Candles for Chart (using selected timeframe)
        await loadCandles(for: selectedTimeframe)

        // B. Fetch Analysis (Argus Core)
        do {
            // Service akıllı cache kullanır, her seferinde apiye gitmez
            let fetchedSnapshot = try await analysisService.fetchSnapshot(symbol: symbol)
            self.snapshot = fetchedSnapshot

        } catch {
            print("⚠️ SanctumVM: Snapshot hatası: \(error)")
        }

        // C. Fetch Macro (Global)
        self.macroRating = await MacroRegimeService.shared.computeMacroEnvironment()
    }

    // MARK: - Timeframe Change Handler
    /// Called when user selects a different timeframe in OrionMotherboardView
    func changeTimeframe(to newTimeframe: TimeframeMode) async {
        guard newTimeframe != selectedTimeframe else { return }

        selectedTimeframe = newTimeframe
        await loadCandles(for: newTimeframe)

        // Update orionScore to reflect the selected timeframe
        if let analysis = orionAnalysis {
            orionScore = analysis.scoreFor(timeframe: newTimeframe)
        }
    }

    // MARK: - Candle Loading (Timeframe-aware)
    private func loadCandles(for timeframe: TimeframeMode) async {
        isCandlesLoading = true
        defer { isCandlesLoading = false }

        let apiTimeframe = timeframe.apiString
        if let candleData = await marketStore.ensureCandles(symbol: symbol, timeframe: apiTimeframe).value {
            self.candles = candleData
            print("✅ SanctumVM: \(symbol) candles loaded for \(apiTimeframe) - \(candleData.count) bars")
        } else {
            print("⚠️ SanctumVM: \(symbol) candles fetch failed for \(apiTimeframe)")
        }
    }

    func refresh() async {
        // Force refresh logic if needed
        await loadData()
    }

    // MARK: - Hermes News Analysis

    /// Fetches news and runs AI analysis for the symbol
    func analyzeOnDemand() async {
        isLoadingNews = true
        newsErrorMessage = nil
        defer { isLoadingNews = false }

        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)

        do {
            // 1. Fetch News
            let articles: [NewsArticle]
            if isBist {
                articles = try await RSSNewsProvider().fetchNews(symbol: symbol, limit: 20)
            } else {
                articles = try await YahooFinanceNewsProvider.shared.fetchNews(symbol: symbol, limit: 15)
            }

            guard !articles.isEmpty else {
                newsErrorMessage = "Bu sembol için haber bulunamadı."
                print("⚠️ SanctumVM Hermes: \(symbol) için haber bulunamadı")
                return
            }

            print("✅ SanctumVM Hermes: \(symbol) için \(articles.count) haber bulundu")

            // 2. Analyze with LLM
            let scope: HermesEventScope = isBist ? .bist : .global
            let events = try await HermesLLMService.shared.analyzeEvents(
                articles: articles,
                scope: scope,
                isGeneral: false
            )

            print("✅ SanctumVM Hermes: \(symbol) için \(events.count) event analiz edildi")

            // 3. Map to Insights
            let insights = events.map { event -> NewsInsight in
                let sentiment: NewsSentiment = event.sentimentLabel ?? {
                    switch event.polarity {
                    case .positive: return .weakPositive
                    case .negative: return .weakNegative
                    case .mixed: return .neutral
                    }
                }()

                let delayPenalty = HermesEventScoring.delayFactor(
                    ageMinutes: max(0.0, Date().timeIntervalSince(event.publishedAt) / 60.0)
                )

                let detail = """
                Bu haber \(event.polarity == .positive ? "olumlu" : (event.polarity == .negative ? "olumsuz" : "karma")) etki üretiyor.
                Şiddet: \(Int(event.severity))/100, Kaynak güveni: \(Int(event.sourceReliability))/100.
                Gecikme etkisi: %\(Int(delayPenalty * 100)).
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

            // 4. Update HermesStateViewModel (SSoT) - this will trigger reactive bindings
            HermesStateViewModel.shared.newsInsightsBySymbol[symbol] = insights
            if isBist {
                HermesStateViewModel.shared.kulisEventsBySymbol[symbol] = events
            } else {
                HermesStateViewModel.shared.hermesEventsBySymbol[symbol] = events
            }

            print("✅ SanctumVM Hermes: \(symbol) analiz tamamlandı - \(insights.count) insight")

        } catch {
            newsErrorMessage = "Haber analizi yapılamadı: \(error.localizedDescription)"
            print("❌ SanctumVM Hermes: \(symbol) analiz hatası: \(error)")
        }
    }
}
