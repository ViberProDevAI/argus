import Foundation

/// Static utility to map symbols to risk clusters/sectors.
struct ClusterMap: Sendable {
    nonisolated static func getCluster(for symbol: String) -> String {
        switch symbol {
        // Semiconductors
        case "NVDA", "AMD", "AVGO", "MU", "TSM", "ARM", "INTC", "QCOM":
            return "Semicon"
            
        // Software / Cloud / AI
        case "MSFT", "ADBE", "CRM", "PLTR", "SNOW", "ORCL", "NOW":
            return "Software"
            
        // Mega Cap Tech (General)
        case "AAPL", "META", "GOOGL", "AMZN":
            return "MegaTech"
            
        // Crypto Proxies
        case "BTC-USD", "ETH-USD", "MSTR", "COIN", "MARA", "RIOT":
            return "CryptoProxy"
            
        // Energy
        case "XOM", "CVX", "OXY":
            return "Energy"
            
        // Finance
        case "JPM", "BAC", "GS", "V", "MA":
            return "Finance"
            
        // Default / Others
        default:
            return "General"
        }
    }
}
