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
    /// Timeframe button -> gerçek skorun üretildiği kaynak timeframe
    let sourceTimeframes: [TimeframeMode: TimeframeMode]
    /// Argus konsey kararında baz alınan teknik zaman dilimi.
    let argusReportingTimeframe: TimeframeMode
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

    func sourceFor(timeframe: TimeframeMode) -> TimeframeMode {
        sourceTimeframes[timeframe] ?? timeframe
    }

    func isFallback(timeframe: TimeframeMode) -> Bool {
        sourceFor(timeframe: timeframe) != timeframe
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
                        let analysisCandles: [Candle]
                        if key == "h4" {
                            // Yahoo 4h native desteklemediği için 1h veriyi 4h barlara topluyoruz.
                            analysisCandles = OrionStore.aggregateCandles(data, bucketSize: 4)
                        } else {
                            analysisCandles = data
                        }

                        // SPY Benchmark only for Daily/Weekly
                        let spyTimeframe: String?
                        if key == "weekly" {
                            spyTimeframe = "1week"
                        } else if key == "daily" {
                            spyTimeframe = "1day"
                        } else {
                            spyTimeframe = nil
                        }
                        var spyCandles: [Candle]? = nil
                        
                        if let spyTf = spyTimeframe {
                            spyCandles = await MarketDataStore.shared.ensureCandles(symbol: "SPY", timeframe: spyTf).value
                        }
                        
                        let score = await OrionAnalysisService.shared.calculateOrionScoreAsync(
                            symbol: symbol,
                            candles: analysisCandles,
                            spyCandles: spyCandles
                        )
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
        
        // 3. Fallback Logic (Per-timeframe nearest fallback; UI bu fallback'i görebilir)
        let keyToMode: [String: TimeframeMode] = [
            "m5": .m5,
            "m15": .m15,
            "h1": .h1,
            "h4": .h4,
            "daily": .daily,
            "weekly": .weekly
        ]
        let fallbackOrder: [String: [String]] = [
            "m5": ["m5", "m15", "h1", "h4", "daily", "weekly"],
            "m15": ["m15", "m5", "h1", "h4", "daily", "weekly"],
            "h1": ["h1", "m15", "h4", "daily", "weekly", "m5"],
            "h4": ["h4", "h1", "daily", "weekly", "m15", "m5"],
            "daily": ["daily", "h4", "h1", "weekly", "m15", "m5"],
            "weekly": ["weekly", "daily", "h4", "h1", "m15", "m5"]
        ]

        func resolved(for key: String) -> (score: OrionScoreResult, source: TimeframeMode)? {
            guard let order = fallbackOrder[key] else { return nil }
            for candidate in order {
                if let score = results[candidate], let sourceMode = keyToMode[candidate] {
                    return (score, sourceMode)
                }
            }
            return nil
        }

        guard
            let m5Resolved = resolved(for: "m5"),
            let m15Resolved = resolved(for: "m15"),
            let h1Resolved = resolved(for: "h1"),
            let h4Resolved = resolved(for: "h4"),
            let dailyResolved = resolved(for: "daily"),
            let weeklyResolved = resolved(for: "weekly")
        else {
            print("⚠️ OrionStore: Analysis Failed for \(symbol) - No timeframe produced usable result")
            return
        }

        let finalAnalysis = MultiTimeframeAnalysis(
            m5: m5Resolved.score,
            m15: m15Resolved.score,
            h1: h1Resolved.score,
            h4: h4Resolved.score,
            daily: dailyResolved.score,
            weekly: weeklyResolved.score,
            sourceTimeframes: [
                .m5: m5Resolved.source,
                .m15: m15Resolved.source,
                .h1: h1Resolved.source,
                .h4: h4Resolved.source,
                .daily: dailyResolved.source,
                .weekly: weeklyResolved.source
            ],
            argusReportingTimeframe: .daily,
            generatedAt: Date()
        )

        for mode in TimeframeMode.allCases {
            let source = finalAnalysis.sourceFor(timeframe: mode)
            if source != mode {
                print("⚠️ OrionStore: \(symbol) \(mode.displayLabel) fallback -> \(source.displayLabel)")
            }
        }
        
        self.analysis[symbol] = finalAnalysis

        // Sync with SignalStateViewModel for UI binding
        SignalStateViewModel.shared.orionAnalysis[symbol] = finalAnalysis

        print("🧠 OrionStore: Logic Synthesis Complete. Advice: \(finalAnalysis.strategicAdvice)")
    }
    
    // MARK: - Accessors
    
    func getAnalysis(for symbol: String) -> MultiTimeframeAnalysis? {
        return analysis[symbol]
    }

    private nonisolated static func aggregateCandles(_ candles: [Candle], bucketSize: Int) -> [Candle] {
        guard bucketSize > 1, candles.count >= bucketSize else { return candles }

        let sorted = candles.sorted { $0.date < $1.date }
        var aggregated: [Candle] = []
        aggregated.reserveCapacity(sorted.count / bucketSize + 1)

        var index = 0
        while index < sorted.count {
            let end = min(index + bucketSize, sorted.count)
            let slice = sorted[index..<end]
            guard let first = slice.first, let last = slice.last else { break }

            let high = slice.map(\.high).max() ?? first.high
            let low = slice.map(\.low).min() ?? first.low
            let volume = slice.reduce(0.0) { $0 + $1.volume }

            aggregated.append(
                Candle(
                    date: last.date,
                    open: first.open,
                    high: high,
                    low: low,
                    close: last.close,
                    volume: volume
                )
            )
            index += bucketSize
        }
        return aggregated
    }
}
