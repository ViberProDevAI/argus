import Foundation

// MARK: - AI Signal Models

struct AISignal: Identifiable, Codable {
    var id = UUID()
    let symbol: String
    let action: SignalAction // BUY, SELL, HOLD
    let confidenceScore: Double // 0-100
    let strategyName: String
    let reason: String
    let timestamp: Date
}

// MARK: - AI Signal Provider Protocol

protocol AISignalProvider {
    func generateSignals(quotes: [String: Quote], candles: [String: [Candle]]) async -> [AISignal]
}

// MARK: - AI Signal Service (Implementation)

class AISignalService: AISignalProvider {
    static let shared = AISignalService()
    
    private init() {}
    
    /// Generates AI-driven signals based on REAL market data and strategies.
    ///
    /// - Parameters:
    ///   - quotes: Current market quotes.
    ///   - candles: Historical candle data.
    /// - Returns: A list of `AISignal` objects.
    func generateSignals(quotes: [String: Quote], candles: [String: [Candle]]) async -> [AISignal] {
        var signals: [AISignal] = []
        
        // Her sembol için stratejileri çalıştır
        for (symbol, symbolCandles) in candles {
            // Yeterli veri yoksa atla
            guard symbolCandles.count > 50 else { continue }
            
            // Backtest motorunu çalıştır
            let config = BacktestConfig(strategy: .orionV2)
            let result = await ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: config,
                candles: symbolCandles,
                financials: nil
            )
            
            // Sonuç yeterince iyiyse sinyal oluştur
            if result.totalReturn > 10 && result.winRate > 50 {
                let action: SignalAction = result.totalReturn > 0 ? .buy : .sell
                let signal = AISignal(
                    symbol: symbol,
                    action: action,
                    confidenceScore: result.winRate,
                    strategyName: "Argus Orion V2",
                    reason: "Backtest: %\(String(format: "%.1f", result.totalReturn)) getiri, %\(String(format: "%.1f", result.winRate)) kazanma oranı",
                    timestamp: Date()
                )
                signals.append(signal)
            }
        }
        
        // Güven skoruna göre sırala (En yüksek en üstte)
        return signals.sorted { $0.confidenceScore > $1.confidenceScore }
    }
    
}
