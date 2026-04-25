import Foundation
import Combine

@MainActor
class ChronosLabViewModel: ObservableObject {
    // MARK: - Published State
    @Published var selectedSymbol: String = ""
    @Published var inSampleDays: Double = 180
    @Published var outOfSampleDays: Double = 30
    
    @Published var isAnalyzing: Bool = false
    @Published var progress: Double = 0.0
    @Published var result: WalkForwardResult?
    @Published var overfitAnalysis: OverfitAnalysis?
    
    // MARK: - Dependencies
    private let engine = ChronosWalkForwardEngine.shared
    private var candles: [String: [Candle]]
    
    init(initialSymbol: String = "", candles: [String: [Candle]] = [:]) {
        self.selectedSymbol = initialSymbol
        self.candles = candles
    }
    
    func setCandles(_ newCandles: [String: [Candle]]) {
        self.candles = newCandles
    }
    
    // MARK: - Actions
    
    func startAnalysis() {
        guard !selectedSymbol.isEmpty else { return }
        guard let symbolCandles = candles[selectedSymbol], !symbolCandles.isEmpty else {
            // Handle error or show alert
            return
        }
        
        isAnalyzing = true
        progress = 0.1
        result = nil
        overfitAnalysis = nil
        
        Task {
            // 1. Config
            let config = WalkForwardConfig(
                inSampleDays: Int(inSampleDays),
                outOfSampleDays: Int(outOfSampleDays),
                stepDays: Int(outOfSampleDays), // Sliding step same as OOS window
                initialCapital: 10_000
            )
            
            // 2. Run Engine (Heavy work)
            let wfResult = await engine.runWalkForward(
                symbol: selectedSymbol,
                candles: symbolCandles,
                config: config,
                strategy: .argusStandard, // Default strategy for now
                 financials: nil // Optional
            )
            
            self.progress = 0.8
            
            // 3. Analyze Overfit
            let analysis = await engine.calculateOverfitScore(result: wfResult)
            
            self.progress = 1.0
            
            // 4. Update UI
            self.result = wfResult
            self.overfitAnalysis = analysis
            self.isAnalyzing = false
        }
    }
    
    // MARK: - Helpers
    var formattedConsistency: String {
        guard let r = result else { return "--" }
        return String(format: "%.0f%%", r.consistencyScore)
    }
    
    var formattedOverfitScore: String {
        guard let a = overfitAnalysis else { return "--" }
        return "\(Int(a.score))/100"
    }
    
    var recommendationColor: String {
        guard let a = overfitAnalysis else { return "gray" }
        switch a.level {
        case .low: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}
