
import Foundation

class RiskMetricsEngine {
    static let shared = RiskMetricsEngine()
    
    private init() {} // Singleton
    
    /// Yıllıklandırılmış Risk Metriklerini hesaplar
    /// - Parameters:
    ///   - prices: Tarihsel fiyat dizisi (Eskiden yeniye sıralı olmalı)
    ///   - riskFreeRate: Yıllık risksiz faiz oranı (Varsayılan: %4.5 = 0.045)
    /// - Returns: RiskMetrics struct
    func calculateMetrics(prices: [Double], riskFreeRate: Double = 0.045) -> RiskMetrics? {
        guard prices.count > 10 else { return nil } // Yetersiz veri
        
        // 1. Günlük getirileri hesapla
        var returns: [Double] = []
        for i in 1..<prices.count {
            let dailyReturn = (prices[i] - prices[i-1]) / prices[i-1]
            returns.append(dailyReturn)
        }
        
        guard !returns.isEmpty else { return nil }
        
        // 2. Ortalama ve Standart Sapma
        let meanReturn = returns.reduce(0, +) / Double(returns.count)
        
        let sumSquaredDiff = returns.map { pow($0 - meanReturn, 2) }.reduce(0, +)
        let stdDev = sqrt(sumSquaredDiff / Double(returns.count - 1))
        
        // 3. Downside Deviation (Sortino için)
        // Risksiz getiri (günlük)
        let dailyRiskFree = riskFreeRate / 252.0
        
        let downsideReturns = returns.map { min(0, $0 - dailyRiskFree) }
        let sumSquaredDownside = downsideReturns.map { pow($0, 2) }.reduce(0, +)
        let downsideDev = sqrt(sumSquaredDownside / Double(returns.count - 1))
        
        // 4. Yıllıklandırma (252 işlem günü)
        let annualizedReturn = meanReturn * 252.0
        let annualizedVolatility = stdDev * sqrt(252.0)
        
        // 5. Ratios
        // Sharpe: (R_p - R_f) / Volatility
        let sharpeRatio = annualizedVolatility > 0 ? (annualizedReturn - riskFreeRate) / annualizedVolatility : 0
        
        // Sortino: (R_p - R_f) / DownsideDev_annualized
        let annualizedDownsideDev = downsideDev * sqrt(252.0)
        let sortinoRatio = annualizedDownsideDev > 0 ? (annualizedReturn - riskFreeRate) / annualizedDownsideDev : 0
        
        // 6. Max Drawdown
        var maxDrawdown: Double = 0
        var peak = prices[0]
        
        for price in prices {
            if price > peak {
                peak = price
            }
            let drawdown = (peak - price) / peak
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }
        
        return RiskMetrics(
            annualizedReturn: annualizedReturn * 100, // Yüzdeye çevir
            annualizedVolatility: annualizedVolatility * 100,
            sharpeRatio: sharpeRatio,
            sortinoRatio: sortinoRatio,
            maxDrawdown: maxDrawdown * 100
        )
    }
    
    /// Asenkron olarak FRED'ten güncel risksiz faiz oranını çekip hesaplar
    func calculateMetricsAsync(prices: [Double], riskFreeRate: Double? = nil) async -> RiskMetrics? {
        let rate: Double
        if let r = riskFreeRate {
            rate = r
        } else {
            // FRED'ten çek, yoksa varsayılan 4.5% kullan
            rate = await FredProvider.shared.getRiskFreeRate() ?? 0.045
        }
        return calculateMetrics(prices: prices, riskFreeRate: rate)
    }
}
