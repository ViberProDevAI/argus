import Foundation
import Combine

struct AlertItem: Identifiable {
    let id = UUID()
    let symbol: String
    let date: Date
    let message: String
    let type: AlertType
    let score: Double
    
    enum AlertType {
        case buy
        case sell
        case neutral
    }
}

class AlertManager: ObservableObject {
    static let shared = AlertManager()
    
    @Published var alerts: [AlertItem] = []
    @Published var isScanning = false
    
    private init() {}
    
    func scanWatchlist(symbols: [String]) async {
        await MainActor.run { self.isScanning = true; self.alerts = [] }
        
        for symbol in symbols {
            do {
                // 1. Veri Çek (Backtest için historical)
                let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1D", limit: 365)
                
                // 2. Analiz Et - ArgusBacktestEngine kullan
                let config = BacktestConfig(strategy: .orionV2)
                let result = await ArgusBacktestEngine.shared.runBacktest(
                    symbol: symbol,
                    config: config,
                    candles: candles,
                    financials: nil
                )
                
                // 3. Sinyal Kontrolü
                let score = result.winRate
                
                if result.totalReturn > 10 && score > 60 {
                    let alert = AlertItem(symbol: symbol, date: Date(), message: "Güçlü AL Sinyali (Güven: %\(Int(score)))", type: .buy, score: score)
                    await MainActor.run { self.alerts.append(alert) }
                } else if result.totalReturn < -10 && score < 40 {
                    let alert = AlertItem(symbol: symbol, date: Date(), message: "Güçlü SAT Sinyali (Getiri: %\(Int(result.totalReturn)))", type: .sell, score: 100 - score)
                    await MainActor.run { self.alerts.append(alert) }
                }
                
            } catch {
                print("Alert scan error for \(symbol): \(error)")
            }
        }
        
        await MainActor.run {
            self.isScanning = false
            self.saveToWidget()
        }
    }
    
    private func saveToWidget() {
        // Widget için verileri hazırla (Basitleştirilmiş JSON)
        let widgetData = alerts.prefix(3).map { alert in
            [
                "symbol": alert.symbol,
                "score": alert.score,
                "type": alert.type == .buy ? "buy" : "sell",
                "message": alert.message
            ] as [String : Any]
        }
        
        if let userDefaults = UserDefaults(suiteName: "group.com.argus.Algo-Trading") {
            userDefaults.set(widgetData, forKey: "widgetSignals")
            // Widget'ı yenile
            // WidgetCenter.shared.reloadAllTimelines() // WidgetKit import etmek gerekir, burası Service katmanı olduğu için UI kodunu buraya karıştırmayalım veya import ekleyelim.
            // Şimdilik sadece kaydedelim.
        }
    }
}
