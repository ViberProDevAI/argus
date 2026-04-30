import Foundation
import Combine
import SwiftUI

// MARK: - Signal State ViewModel
/// Extracted from TradingViewModel (God Object Decomposition - Phase 2)
/// Responsibilities: Orion analysis, Council decisions, signal aggregation

@MainActor
final class SignalStateViewModel: ObservableObject {
    static let shared = SignalStateViewModel()
    
    // MARK: - Published Properties
    
    /// Orion Multi-Timeframe Analysis (Orion 2.0)
    @Published var orionAnalysis: [String: MultiTimeframeAnalysis] = [:]
    @Published var isOrionLoading: Bool = false
    
    /// Grand Council Decisions
    @Published var grandDecisions: [String: ArgusGrandDecision] = [:]
    
    /// Orion V3 Pattern Store
    @Published var patterns: [String: [OrionChartPattern]] = [:]
    
    /// Phoenix Channel Results
    @Published var phoenixResults: [String: PhoenixAdvice] = [:]
    
    /// Athena Factor Scores
    @Published var athenaResults: [String: AthenaFactorResult] = [:]
    
    /// Demeter Sector Scores
    @Published var demeterScores: [DemeterScore] = []
    
    /// Chimera Synergy Signals
    @Published var chimeraSignals: [String: ChimeraSignal] = [:]

    /// Argus Decisions (Decision V2)
    @Published var argusDecisions: [String: ArgusDecisionResult] = [:]

    /// Argus Explanations
    @Published var argusExplanations: [String: ArgusExplanation] = [:]
    
    // MARK: - Cached Daily Scores (Performance Optimization)
    //
    // Önceden bu computed property'di: `orionAnalysis.mapValues { $0.daily }`.
    // `viewModel.orionScores[symbol]` her erişimde tüm dictionary'yi yeniden
    // mapliyor; TradeBrain, PortfolioView, MarketView, StockDetailView gibi
    // 15+ noktada body içinde çağrıldığı için her quote/decision güncellemesinde
    // O(N×V) mapValues maliyeti oluşuyordu.
    //
    // Şimdi: orionAnalysis değiştiğinde **bir kez** map'lenip @Published olarak
    // tutulur. View'lar sözcük cache'inden okur — re-render sayısı değişmez,
    // ama her body computation'ında full dict regeneration kalkar.
    @Published private(set) var orionScores: [String: OrionScoreResult] = [:]

    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupOrionStoreBinding()
        setupOrionScoresCache()
    }

    // MARK: - Orion Store Binding
    private func setupOrionStoreBinding() {
        OrionStore.shared.$analysis
            .receive(on: DispatchQueue.main)
            .sink { [weak self] analysis in
                self?.orionAnalysis = analysis
            }
            .store(in: &cancellables)

        OrionStore.shared.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isOrionLoading)
    }

    /// orionAnalysis değiştiğinde daily score'ları bir kez map'le ve cache'le.
    /// Aynı RunLoop turunda gelen ardışık güncellemeler için latest'i alır.
    private func setupOrionScoresCache() {
        $orionAnalysis
            .map { analysis in analysis.mapValues { $0.daily } }
            .receive(on: RunLoop.main)
            .assign(to: &$orionScores)
    }
    
    // MARK: - Orion Analysis
    
    /// Ensure Orion analysis is available for a symbol
    func ensureOrionAnalysis(for symbol: String) async {
        await OrionStore.shared.ensureAnalysis(for: symbol)
    }
    
    /// Get Orion score for a symbol
    func getOrionScore(for symbol: String) -> Double? {
        return orionAnalysis[symbol]?.daily.score
    }
    
    /// Get Orion verdict for a symbol
    func getOrionVerdict(for symbol: String) -> String {
        return orionAnalysis[symbol]?.daily.verdict ?? "N/A"
    }
    
    // MARK: - Council Decisions
    
    /// Request Grand Council decision for a symbol
    /// Request Grand Council decision for a symbol
    func requestCouncilDecision(
        symbol: String,
        candles: [Candle],
        snapshot: FinancialSnapshot?, // CHANGED from FinancialsData
        macro: MacroSnapshot,
        news: HermesNewsSnapshot?,
        engine: AutoPilotEngine
    ) async -> ArgusGrandDecision {
        let decision = await ArgusGrandCouncil.shared.convene(
            symbol: symbol,
            candles: candles,
            snapshot: snapshot,
            macro: macro,
            news: news,
            engine: engine
        )
        grandDecisions[symbol] = decision
        return decision
    }
    
    /// Get cached decision for a symbol
    func getCachedDecision(for symbol: String) -> ArgusGrandDecision? {
        return grandDecisions[symbol]
    }
    
    // MARK: - Pattern Detection
    
    /// Detect patterns for a symbol
    func detectPatterns(symbol: String, candles: [Candle]) async {
        let detected = await OrionPatternEngine.shared.detectPatterns(candles: candles)
        patterns[symbol] = detected
    }
    
    /// Get patterns for a symbol
    func getPatterns(for symbol: String) -> [OrionChartPattern] {
        return patterns[symbol] ?? []
    }
    
    // MARK: - Chimera Integration
    
    /// Update Chimera signals
    func updateChimeraSignal(symbol: String, signal: ChimeraSignal) {
        chimeraSignals[symbol] = signal
    }
    
    /// Get aggregate signal strength for a symbol
    func getSignalStrength(for symbol: String) -> Double {
        var strength = 0.0
        var count = 0
        
        if let orion = orionAnalysis[symbol] {
            strength += orion.daily.score
            count += 1
        }
        
        if let decision = grandDecisions[symbol] {
            strength += decision.confidence * 100
            count += 1
        }
        
        return count > 0 ? strength / Double(count) : 0
    }
}
