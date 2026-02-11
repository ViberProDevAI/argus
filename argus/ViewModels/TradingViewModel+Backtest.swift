import Foundation

extension TradingViewModel {
    
    // Trigger from UI
    func runPhoenixBacktest(symbol: String) {
        guard let candles = candles[symbol], candles.count > 100 else { return }
        
        self.isBacktesting = true
        
        Task {
            let config = BacktestConfig(
                initialCapital: 10_000,
                strategy: .phoenixChannel,
                stopLossPct: 0.05
            )
            
            let result = await ArgusBacktestEngine.shared.runBacktest(
                symbol: symbol,
                config: config,
                candles: candles,
                financials: nil
            )
            
            self.activeBacktestResult = result
            self.isBacktesting = false
        }
    }
}
