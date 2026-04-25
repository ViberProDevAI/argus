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
    
    // MARK: - Legacy Support
    
    /// Legacy accessor for daily Orion scores
    var orionScores: [String: OrionScoreResult] {
        return orionAnalysis.mapValues { $0.daily }
    }
    
    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupOrionStoreBinding()
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
