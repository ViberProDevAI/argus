import Foundation
import Combine
import SwiftUI

// MARK: - MODELS

/// Holds analysis results for multiple timeframes to enable strategic decision making.
struct MultiTimeframeAnalysis {
    let m5: OrionScoreResult
    let m15: OrionScoreResult
    let h1: OrionScoreResult
    let h4: OrionScoreResult
    let daily: OrionScoreResult
    let weekly: OrionScoreResult
    let generatedAt: Date
    
    // Legacy support
    var intraday: OrionScoreResult { h4 }

    // Timeframe accessor for dynamic selection
    func scoreFor(timeframe: TimeframeMode) -> OrionScoreResult {
        switch timeframe {
        case .m5: return m5
        case .m15: return m15
        case .h1: return h1
        case .h4: return h4
        case .daily: return daily
        case .weekly: return weekly
        }
    }

    // Strategic Synthesis (The "Brain" Advice)
    var strategicAdvice: String {
        if daily.score > 60 && h4.score > 60 {
            return "Tam Gaz İleri: Hem ana trend hem kısa vade momentumu seni destekliyor."
        } else if daily.score > 60 && h4.score < 40 {
            return "Fırsat Kollama: Ana trend yukarı ama kısa vade düzeltmede. Dönüş bekle ve AL."
        } else if daily.score < 40 && h4.score > 60 {
            return "Tuzak Uyarısı: Ölü kedi sıçraması olabilir. Ana trend hala düşüşte."
        } else {
            return "Uzak Dur: Piyasa her vadede negatif."
        }
    }
}

// MARK: - STORE

/// Orion Store (State Layer) 🏛️
/// Manages Multi-Timeframe Technical Analysis.
@MainActor
final class OrionStore: ObservableObject {
    static let shared = OrionStore()
    
    // MARK: - State
    @Published var analysis: [String: MultiTimeframeAnalysis] = [:]
    @Published var isLoading: Bool = false
    
    private init() {}
    
    // MARK: - Actions
    
    /// Triggers a robust multi-timeframe analysis.
    func ensureAnalysis(for symbol: String) async {
        // 1. Freshness Check (5 mins)
        if let existing = analysis[symbol], Date().timeIntervalSince(existing.generatedAt) < 300 {
            return 
        }
        
        self.isLoading = true
        defer { self.isLoading = false }
        
        // 2. Parallel Data Fetching & Analysis
        print("🧠 OrionStore: Starting MTF Analysis for \(symbol) (6 Timeframes)...")
        
        // Timeframes to fetch
        let timeframes: [(String, String)] = [
            ("m5", "5m"),
            ("m15", "15m"),
            ("h1", "1h"),
            ("h4", "4h"),
            ("daily", "1day"),
            ("weekly", "1week")
        ]
        
        let results = await withTaskGroup(of: (String, OrionScoreResult?).self) { group -> [String: OrionScoreResult] in
            
            for (key, tfParam) in timeframes {
                group.addTask {
                    // Fetch candles
                    let candles = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: tfParam).value
                    if let data = candles, !data.isEmpty {
                        // SPY Benchmark only for Daily/Weekly
                        let spyTimeframe = (key == "daily" || key == "weekly") ? "1day" : nil
                        var spyCandles: [Candle]? = nil
                        
                        if let spyTf = spyTimeframe {
                            spyCandles = await MarketDataStore.shared.ensureCandles(symbol: "SPY", timeframe: spyTf).value
                        }
                        
                        let score = await OrionAnalysisService.shared.calculateOrionScoreAsync(symbol: symbol, candles: data, spyCandles: spyCandles)
                        return (key, score)
                    }
                    return (key, nil)
                }
            }
            
            var collected: [String: OrionScoreResult] = [:]
            for await (key, res) in group {
                if let r = res {
                    collected[key] = r
                }
            }
            return collected
        }
        
        // 3. Fallback Logic (Propagate Daily if others missing to prevent crash)
        guard let daily = results["daily"] ?? results["h4"] ?? results["h1"] else {
             print("⚠️ OrionStore: Analysis Failed for \(symbol) - No Daily/H4/H1 Data")
             return
        }
        
        let finalAnalysis = MultiTimeframeAnalysis(
            m5: results["m5"] ?? daily,
            m15: results["m15"] ?? daily,
            h1: results["h1"] ?? daily,
            h4: results["h4"] ?? daily,
            daily: daily,
            weekly: results["weekly"] ?? daily,
            generatedAt: Date()
        )
        
        self.analysis[symbol] = finalAnalysis

        // Sync with SignalStateViewModel for UI binding
        SignalStateViewModel.shared.orionAnalysis[symbol] = finalAnalysis

        print("🧠 OrionStore: Logic Synthesis Complete. Advice: \(finalAnalysis.strategicAdvice)")
    }
    
    // MARK: - Accessors
    
    func getAnalysis(for symbol: String) -> MultiTimeframeAnalysis? {
        return analysis[symbol]
    }
}
