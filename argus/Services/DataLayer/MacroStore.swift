import Foundation
import Combine

/// Unified Store for Macro Data (Aether Engine)
/// Centralizes fetching of CPI, VIX, Rates, and Commodities.
@MainActor
final class MacroStore: ObservableObject {
    static let shared = MacroStore()
    
    // Key: Symbol (e.g. "FRED.CPI", "MARKET.VIX")
    @Published var indicators: [String: DataValue<Double>] = [:]
    @Published var series: [String: DataValue<[Candle]>] = [:]
    
    private init() {}
    
    // MARK: - Access
    
    func getValue(for symbol: String) -> Double? {
        return indicators[symbol]?.value
    }
    
    func getSeries(for symbol: String) -> [Candle]? {
        return series[symbol]?.value
    }
    
    // MARK: - Actions
    
    func fetchIndicator(symbol: String) async {
        // Simple deduplication via "Is Fresh?" check
        if let current = indicators[symbol], !current.isStale, -current.provenance.fetchedAt.timeIntervalSinceNow < 3600 {
            return
        }
        
        do {
            // Determine Provider based on symbol prefix or Registry
            // For now, simpler heuristics mapping typical Aether inputs
            let providerTag: ProviderTag
            if symbol.hasPrefix("FRED") { providerTag = .fred }
            else if symbol == "VIX" || symbol == "DXY" { providerTag = .yahoo } // Mapped in Orchestrator
            else { providerTag = .yahoo }
            
            // We use Orchestrator to fetch "Candles" usually for Macro to get trend, 
            // but sometimes we just want the latest value.
            // Let's assume we fetch Candles for robust trend analysis.
            
            // Map generic symbol to provider-specific if needed, or rely on Orchestrator mapping
            let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1D", limit: 30)
            
            guard let latest = candles.last else { throw URLError(.badServerResponse) }
            
            let val = DataValue(
                value: latest.close,
                provenance: DataProvenance(
                    source: providerTag.rawValue,
                    fetchedAt: Date(),
                    confidence: 1.0
                ),
                status: .fresh
            )
            
            let ser = DataValue(
                value: candles,
                provenance: DataProvenance(source: providerTag.rawValue, fetchedAt: Date(), confidence: 1.0),
                status: .fresh
            )
            
            self.indicators[symbol] = val
            self.series[symbol] = ser
            
        } catch {
            print("📉 MacroStore: Failed to fetch \(symbol): \(error)")
            // Mark Stale if exists
            if let current = indicators[symbol] {
                indicators[symbol] = DataValue(value: current.value, provenance: current.provenance, status: .stale)
            }
        }
    }
    
    func fetchBatch(symbols: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for sym in symbols {
                group.addTask { await self.fetchIndicator(symbol: sym) }
            }
        }
    }
}
