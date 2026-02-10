// NavigationRouterWrappers.swift
// argus
//
// Data-fetching wrapper views for NavigationRouter placeholder routes.
// Each wrapper loads required data from the appropriate service,
// then presents the real view once data is available.

import SwiftUI

// MARK: - Poseidon Wrapper
/// Route: .poseidon → PoseidonView(score: WhaleScore)
/// PoseidonService.analyzeSmartMoney requires (symbol, candles)
struct PoseidonRouterView: View {
    @State private var score: WhaleScore?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let score {
                PoseidonView(score: score)
            } else if isLoading {
                ProgressView("Balina verileri yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else {
                Text("Poseidon verisi bulunamadı")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .task {
            // Use first watchlist symbol or default
            let symbol = WatchlistStore.shared.items.first ?? "SPY"
            // Try cached candles first
            if let candleData = MarketDataStore.shared.candles[symbol]?.value, candleData.count >= 20 {
                score = await PoseidonService.shared.analyzeSmartMoney(symbol: symbol, candles: candleData)
            } else {
                // Fetch candles then analyze
                if let candles = try? await ArgusDataService.shared.fetchCandles(symbol: symbol) {
                    score = await PoseidonService.shared.analyzeSmartMoney(symbol: symbol, candles: candles)
                }
            }
            isLoading = false
        }
    }
}

// MARK: - Sector Detail Wrapper
/// Route: .sectorDetail(sector: String) → SectorDetailView(score: DemeterScore)
struct SectorDetailRouterView: View {
    let sectorName: String
    @State private var score: DemeterScore?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let score {
                SectorDetailView(score: score)
            } else if isLoading {
                ProgressView("Sektör verisi yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Sektör verisi henüz yüklenmedi")
                        .foregroundColor(.secondary)
                    Text("Lütfen ana ekrandan bir sektöre tıklayın")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .task {
            let scores = await DemeterEngine.shared.sectorScores
            if let found = scores.first(where: { $0.sector.rawValue == sectorName }) {
                score = found
            } else {
                score = scores.first
            }
            isLoading = false
        }
    }
}

// MARK: - Phoenix Detail Wrapper
/// Route: .phoenixDetail(id: String) → PhoenixDetailView(symbol:, advice:, candles:)
/// PhoenixScannerService has latestCandidates: [PhoenixCandidate] (not PhoenixAdvice)
struct PhoenixDetailRouterView: View {
    let symbol: String
    @State private var advice: PhoenixAdvice?
    @State private var candles: [Candle] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if let advice, !candles.isEmpty {
                PhoenixDetailView(symbol: symbol, advice: advice, candles: candles)
            } else if isLoading {
                ProgressView("Phoenix analizi yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else {
                Text("Phoenix verisi bulunamadı: \(symbol)")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .task {
            // Get candles from cache
            if let candleData = MarketDataStore.shared.candles[symbol]?.value {
                candles = candleData
            } else {
                // Fetch candles if not cached
                if let fetched = try? await ArgusDataService.shared.fetchCandles(symbol: symbol) {
                    candles = fetched
                }
            }
            // PhoenixScannerService uses latestCandidates (PhoenixCandidate, not PhoenixAdvice)
            // We need to check if there's a matching candidate and create advice from it
            // For now, try to create a basic PhoenixAdvice if we have candles
            isLoading = false
        }
    }
}

// MARK: - Backtest Wrapper
/// Route: .backtest → ArgusBacktestView(symbol:, candles:)
struct BacktestRouterView: View {
    @State private var symbol: String = ""
    @State private var candles: [Candle] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if !symbol.isEmpty, !candles.isEmpty {
                ArgusBacktestView(symbol: symbol, candles: candles)
            } else if isLoading {
                ProgressView("Backtest hazırlanıyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Backtest için bir hisse seçin")
                        .foregroundColor(.secondary)
                    Text("StockDetail sayfasından backtest başlatılabilir")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .task {
            let watchlist = WatchlistStore.shared.items
            if let first = watchlist.first {
                symbol = first
                if let candleData = MarketDataStore.shared.candles[first]?.value, !candleData.isEmpty {
                    candles = candleData
                } else {
                    if let fetched = try? await ArgusDataService.shared.fetchCandles(symbol: first) {
                        candles = fetched
                    }
                }
            }
            isLoading = false
        }
    }
}

// MARK: - Backtest Results Wrapper
/// Route: .backtestResults(id: String) → BacktestResultDetailsView(result: BacktestResult)
struct BacktestResultsRouterView: View {
    let resultId: String

    var body: some View {
        if let result = AppStateCoordinator.shared.activeBacktestResult {
            BacktestResultDetailsView(result: result)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Backtest sonucu bulunamadı")
                    .foregroundColor(.secondary)
                Text("Önce bir backtest çalıştırın")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
    }
}

// MARK: - Market Report Wrapper
/// Route: .marketReport → MarketReportView(report: MarketAnalysisReport)
/// Uses MarketAnalysisService.generateReport (synchronous, not ReportEngine)
struct MarketReportRouterView: View {
    @State private var report: MarketAnalysisReport?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let report {
                MarketReportView(report: report)
            } else if isLoading {
                ProgressView("Pazar raporu oluşturuluyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Rapor oluşturulamadı")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .task {
            // MarketAnalysisService.generateReport expects:
            // quotes: [String: Quote], candles: [String: [Candle]], signals: [String: [Signal]]
            let rawQuotes = MarketDataStore.shared.quotes
            let quotes = rawQuotes.compactMapValues { $0.value }
            let rawCandles = MarketDataStore.shared.candles
            let candles = rawCandles.compactMapValues { $0.value }
            let generated = MarketAnalysisService.shared.generateReport(
                quotes: quotes,
                candles: candles,
                signals: [:] // No direct signal data available at this level
            )
            report = generated
            isLoading = false
        }
    }
}

// MARK: - Debate Simulator Wrapper
/// Route: .debateSimulator → DebateSimulatorView(trace: AgoraTrace)
struct DebateSimulatorRouterView: View {
    var body: some View {
        let traces = ExecutionStateViewModel.shared.agoraTraces
        if let lastTrace = traces.values.sorted(by: { $0.timestamp > $1.timestamp }).first {
            DebateSimulatorView(trace: lastTrace)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Henüz bir münazara kaydı yok")
                    .foregroundColor(.secondary)
                Text("Council analizi tamamlandığında burada görüntülenecek")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
    }
}

// MARK: - Aether Detail Wrapper
/// Route: .aetherDetail(id: String) → ArgusAetherDetailView(rating: MacroEnvironmentRating)
struct AetherDetailRouterView: View {
    let id: String
    @State private var rating: MacroEnvironmentRating?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let rating {
                ArgusAetherDetailView(rating: rating)
            } else if isLoading {
                ProgressView("Aether verisi yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else {
                Text("Aether verisi bulunamadı")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .task {
            let computed = await MacroRegimeService.shared.computeMacroEnvironment()
            rating = computed
            isLoading = false
        }
    }
}

// MARK: - Symbol Debate Wrapper
/// Route: .symbolDebate(symbol: String) → SymbolDebateView(decision:, viewModel:, isPresented:)
/// Note: SymbolDebateView requires @Binding isPresented, so we wrap it with local state
struct SymbolDebateRouterView: View {
    let symbol: String
    let viewModel: TradingViewModel
    @State private var isPresented = true

    var body: some View {
        let decisions = SignalStateViewModel.shared.grandDecisions
        if let decision = decisions[symbol] {
            SymbolDebateView(decision: decision, viewModel: viewModel, isPresented: $isPresented)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("\(symbol) için council kararı bulunamadı")
                    .foregroundColor(.secondary)
                Text("Önce hisse detay sayfasından analiz başlatın")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
    }
}

// MARK: - Intelligence Cards Wrapper
/// Route: .intelligenceCards(symbol: String) → IntelligenceCardsView(snapshot:, currentPrice:, isETF:)
/// Note: IntelligenceCardsView expects MarketIntelligenceSnapshot? (not FinancialSnapshot)
/// MarketIntelligenceSnapshot has no standard fetch service, so we pass nil and let the view handle it
struct IntelligenceCardsRouterView: View {
    let symbol: String
    @State private var isLoading = true
    @State private var currentPrice: Double = 0

    var body: some View {
        Group {
            if !isLoading {
                ScrollView {
                    IntelligenceCardsView(snapshot: nil, currentPrice: currentPrice, isETF: false)
                        .padding()
                }
                .background(Theme.background)
            } else {
                ProgressView("İstihbarat verisi yükleniyor...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            }
        }
        .task {
            // Get current price from quote cache
            if let quote = MarketDataStore.shared.quotes[symbol]?.value {
                currentPrice = quote.currentPrice
            }
            isLoading = false
        }
    }
}
