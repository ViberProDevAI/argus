import Foundation
import Combine

/// Terminal/Dashboard için gerekli verileri toplayan servis.
/// TradingViewModel'in yükünü hafifletmek için oluşturuldu.
class TerminalService {
    static let shared = TerminalService()
    
    private init() {}
    
    /// Tek bir sembol için tüm verileri toparlar
    func fetchFullData(for symbol: String) async -> TerminalSymbolData {
        // 1. Quote (Fiyat)
        let quoteVal = await MarketDataStore.shared.ensureQuote(symbol: symbol)
        let quote = quoteVal.value
        
        // 2. Candles (Mumlar)
        // Backtest ve Orion için yeterli geçmiş (400 gün)
        let candleVal = await MarketDataStore.shared.ensureCandles(symbol: symbol, timeframe: "1day")
        let candles = candleVal.value
        
        // 3. Prometheus Forecast
        var forecast: PrometheusForecast? = nil
        if let candleData = candles, candleData.count >= 30 {
            let prices = candleData.map { $0.close }.reversed()
            forecast = await PrometheusEngine.shared.forecast(symbol: symbol, historicalPrices: Array(prices))
        }
        
        // 4. Data Health Hesaplama
        let hasQuote = quote != nil
        let candleCount = candles?.count ?? 0
        let hasFund = FundamentalScoreStore.shared.getScore(for: symbol) != nil
        let hasMacro = MacroRegimeService.shared.getCachedRating() != nil
        let hasNews = true // Şimdilik varsayılan
        
        let health = DataHealth(
            symbol: symbol,
            lastUpdated: Date(),
            fundamental: CoverageComponent(available: hasFund, quality: hasFund ? 1.0 : 0.0),
            technical: CoverageComponent(available: hasQuote || candleCount > 0, quality: (hasQuote || candleCount > 0) ? 1.0 : 0.0),
            macro: CoverageComponent(available: hasMacro, quality: hasMacro ? 1.0 : 0.0),
            news: CoverageComponent(available: true, quality: 1.0)
        )
        
        return TerminalSymbolData(
            symbol: symbol,
            quote: quote,
            candles: candles,
            forecast: forecast,
            health: health
        )
    }
    
    /// Watchlist üzerindeki sembolleri batch (paket) halinde yükler
    /// Progress callback ile ilerlemeyi raporlar
    func bootstrapTerminal(
        symbols: [String],
        batchSize: Int = 10,
        onProgress: @escaping (Int, Int) -> Void, // (processed, total)
        onBatchComplete: @escaping ([TerminalSymbolData]) -> Void
    ) async {
        // 0. Macro verisini garantiye al
        _ = await MacroRegimeService.shared.evaluate()
        
        // Sembolleri batch'lere böl
        let batches = stride(from: 0, to: symbols.count, by: batchSize).map {
            Array(symbols[$0..<min($0 + batchSize, symbols.count)])
        }
        
        var processedCount = 0
        
        for (batchIndex, batch) in batches.enumerated() {
            // Paralel veri çekimi
            var batchResults: [TerminalSymbolData] = []
            
            await withTaskGroup(of: TerminalSymbolData.self) { group in
                for symbol in batch {
                    group.addTask {
                        return await self.fetchFullData(for: symbol)
                    }
                }
                
                for await result in group {
                    batchResults.append(result)
                }
            }
            
            // UI Thread'e veri gönderimi için callback
            await MainActor.run {
                onBatchComplete(batchResults)
                processedCount += batch.count
                onProgress(processedCount, symbols.count)
            }
            
            // UI nefes alsın
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}

/// TerminalService'in döndürdüğü veri paketi
struct TerminalSymbolData {
    let symbol: String
    let quote: Quote?
    let candles: [Candle]?
    let forecast: PrometheusForecast?
    let health: DataHealth
}
