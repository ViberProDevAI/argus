import Foundation

// MARK: - Portfolio Risk Service
/// Profesyonel portföy risk yönetimi - korelasyon, VaR, konsantrasyon

actor PortfolioRiskService {
    static let shared = PortfolioRiskService()
    
    // MARK: - Configuration
    
    private var config = RiskConfig.default
    
    func updateConfig(_ config: RiskConfig) {
        self.config = config
    }
    
    // MARK: - Correlation Analysis
    
    /// İki hisse arasındaki korelasyonu hesapla
    func calculateCorrelation(returns1: [Double], returns2: [Double]) -> Double {
        guard returns1.count == returns2.count, returns1.count > 1 else { return 0.0 }
        
        let n = Double(returns1.count)
        let mean1 = returns1.reduce(0, +) / n
        let mean2 = returns2.reduce(0, +) / n
        
        var covariance = 0.0
        var var1 = 0.0
        var var2 = 0.0
        
        for i in 0..<returns1.count {
            let diff1 = returns1[i] - mean1
            let diff2 = returns2[i] - mean2
            covariance += diff1 * diff2
            var1 += diff1 * diff1
            var2 += diff2 * diff2
        }
        
        let denominator = sqrt(var1 * var2)
        guard denominator > 0 else { return 0.0 }
        
        return covariance / denominator
    }
    
    /// Portföy korelasyon matrisi
    func buildCorrelationMatrix(positions: [PortfolioPosition], candles: [String: [Candle]]) -> [[Double]] {
        let symbols = positions.map { $0.symbol }
        let n = symbols.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        
        // Günlük getiri hesapla
        var returnSeries: [String: [Double]] = [:]
        for symbol in symbols {
            if let candleList = candles[symbol], candleList.count > 1 {
                var returns: [Double] = []
                for i in 1..<candleList.count {
                    let ret = (candleList[i].close - candleList[i-1].close) / candleList[i-1].close
                    returns.append(ret)
                }
                returnSeries[symbol] = returns
            }
        }
        
        // Korelasyon matrisi
        for i in 0..<n {
            for j in 0..<n {
                if i == j {
                    matrix[i][j] = 1.0
                } else if i < j {
                    if let r1 = returnSeries[symbols[i]], let r2 = returnSeries[symbols[j]] {
                        let minLen = min(r1.count, r2.count)
                        let corr = calculateCorrelation(
                            returns1: Array(r1.suffix(minLen)),
                            returns2: Array(r2.suffix(minLen))
                        )
                        matrix[i][j] = corr
                        matrix[j][i] = corr
                    }
                }
            }
        }
        
        return matrix
    }
    
    // MARK: - Value at Risk (VaR)
    
    /// Historical VaR hesaplama
    func calculateVaR(
        portfolioValue: Double,
        historicalReturns: [Double],
        confidence: Double = 0.95
    ) -> Double {
        guard !historicalReturns.isEmpty else { return 0.0 }
        
        let sorted = historicalReturns.sorted()
        let index = Int((1.0 - confidence) * Double(sorted.count))
        let varPct = abs(sorted[max(0, index)])
        
        return portfolioValue * varPct
    }
    
    /// Portföy VaR (tüm pozisyonlar için)
    func calculatePortfolioVaR(
        positions: [PortfolioPosition],
        candles: [String: [Candle]],
        confidence: Double = 0.95,
        horizon: Int = 1 // Gün
    ) -> VaRResult {
        var portfolioReturns: [Double] = []
        var totalValue = 0.0
        
        // Her gün için portföy getirisini hesapla
        let maxDays = candles.values.map { $0.count }.min() ?? 0
        guard maxDays > 20 else {
            return VaRResult(var95: 0, var99: 0, expectedShortfall: 0, portfolioValue: 0, horizon: horizon)
        }
        
        for position in positions {
            totalValue += position.currentValue
        }
        
        // Günlük portföy getirileri
        for day in 1..<maxDays {
            var dailyReturn = 0.0
            for position in positions {
                if let candleList = candles[position.symbol], day < candleList.count {
                    let weight = position.currentValue / totalValue
                    let ret = (candleList[day].close - candleList[day-1].close) / candleList[day-1].close
                    dailyReturn += weight * ret
                }
            }
            portfolioReturns.append(dailyReturn)
        }
        
        // VaR hesapla
        let sorted = portfolioReturns.sorted()
        let n = sorted.count
        
        let var95Index = Int(0.05 * Double(n))
        let var99Index = Int(0.01 * Double(n))
        
        let var95 = abs(sorted[max(0, var95Index)]) * totalValue * sqrt(Double(horizon))
        let var99 = abs(sorted[max(0, var99Index)]) * totalValue * sqrt(Double(horizon))
        
        // Expected Shortfall (CVaR)
        let tailReturns = Array(sorted.prefix(var95Index + 1))
        let es = tailReturns.isEmpty ? 0 : abs(tailReturns.reduce(0, +) / Double(tailReturns.count)) * totalValue
        
        return VaRResult(
            var95: var95,
            var99: var99,
            expectedShortfall: es,
            portfolioValue: totalValue,
            horizon: horizon
        )
    }
    
    // MARK: - Concentration Risk
    
    /// Tek hisse konsantrasyon kontrolü
    func checkSingleStockConcentration(positions: [PortfolioPosition]) -> [ConcentrationWarning] {
        var warnings: [ConcentrationWarning] = []
        let totalValue = positions.reduce(0.0) { $0 + $1.currentValue }
        guard totalValue > 0 else { return warnings }
        
        for position in positions {
            let weight = position.currentValue / totalValue * 100.0
            if weight > config.maxSinglePositionPct {
                warnings.append(ConcentrationWarning(
                    type: .singleStock,
                    symbol: position.symbol,
                    currentPct: weight,
                    limitPct: config.maxSinglePositionPct,
                    severity: weight > config.maxSinglePositionPct * 1.5 ? .critical : .warning
                ))
            }
        }
        
        return warnings
    }
    
    /// Sektör konsantrasyon kontrolü
    func checkSectorConcentration(positions: [PortfolioPosition], sectorMap: [String: String]) -> [ConcentrationWarning] {
        var warnings: [ConcentrationWarning] = []
        let totalValue = positions.reduce(0.0) { $0 + $1.currentValue }
        guard totalValue > 0 else { return warnings }
        
        var sectorExposure: [String: Double] = [:]
        
        for position in positions {
            let sector = sectorMap[position.symbol] ?? "Diğer"
            sectorExposure[sector, default: 0] += position.currentValue
        }
        
        for (sector, value) in sectorExposure {
            let weight = value / totalValue * 100.0
            if weight > config.maxSectorPct {
                warnings.append(ConcentrationWarning(
                    type: .sector,
                    symbol: sector,
                    currentPct: weight,
                    limitPct: config.maxSectorPct,
                    severity: weight > config.maxSectorPct * 1.5 ? .critical : .warning
                ))
            }
        }
        
        return warnings
    }
    
    // MARK: - Correlation Warning
    
    /// Yüksek korelasyonlu pozisyonları tespit et
    func findHighCorrelationPairs(
        positions: [PortfolioPosition],
        correlationMatrix: [[Double]]
    ) -> [CorrelationWarning] {
        var warnings: [CorrelationWarning] = []
        let symbols = positions.map { $0.symbol }
        let n = symbols.count
        
        for i in 0..<n {
            for j in (i+1)..<n {
                let corr = correlationMatrix[i][j]
                if corr > config.highCorrelationThreshold {
                    warnings.append(CorrelationWarning(
                        symbol1: symbols[i],
                        symbol2: symbols[j],
                        correlation: corr,
                        severity: corr > 0.9 ? .critical : .warning
                    ))
                }
            }
        }
        
        return warnings
    }
    
    // MARK: - Max Drawdown
    
    /// Portföy max drawdown hesapla
    func calculateMaxDrawdown(equityCurve: [Double]) -> DrawdownResult {
        guard equityCurve.count > 1 else {
            return DrawdownResult(maxDrawdown: 0, maxDrawdownPct: 0, peakIndex: 0, troughIndex: 0)
        }
        
        var peak = equityCurve[0]
        var peakIndex = 0
        var maxDrawdown = 0.0
        var maxDrawdownPct = 0.0
        var troughIndex = 0
        
        for (i, value) in equityCurve.enumerated() {
            if value > peak {
                peak = value
                peakIndex = i
            }
            
            let drawdown = peak - value
            let drawdownPct = drawdown / peak * 100.0
            
            if drawdownPct > maxDrawdownPct {
                maxDrawdown = drawdown
                maxDrawdownPct = drawdownPct
                troughIndex = i
            }
        }
        
        return DrawdownResult(
            maxDrawdown: maxDrawdown,
            maxDrawdownPct: maxDrawdownPct,
            peakIndex: peakIndex,
            troughIndex: troughIndex
        )
    }
    
    // MARK: - Full Risk Report
    
    /// Kapsamlı risk raporu oluştur
    func generateRiskReport(
        positions: [PortfolioPosition],
        candles: [String: [Candle]],
        sectorMap: [String: String],
        equityCurve: [Double]
    ) -> PortfolioRiskReport {
        // VaR
        let varResult = calculatePortfolioVaR(positions: positions, candles: candles)
        
        // Korelasyon
        let corrMatrix = buildCorrelationMatrix(positions: positions, candles: candles)
        let corrWarnings = findHighCorrelationPairs(positions: positions, correlationMatrix: corrMatrix)
        
        // Konsantrasyon
        let stockConc = checkSingleStockConcentration(positions: positions)
        let sectorConc = checkSectorConcentration(positions: positions, sectorMap: sectorMap)
        
        // Drawdown
        let ddResult = calculateMaxDrawdown(equityCurve: equityCurve)
        
        // Overall Risk Score (0-100, yüksek = riskli)
        var riskScore = 20.0 // Base
        
        riskScore += min(30.0, varResult.var95 / varResult.portfolioValue * 1000.0) // VaR contribution
        riskScore += Double(corrWarnings.count) * 5.0 // Correlation warnings
        riskScore += Double(stockConc.count) * 10.0 // Stock concentration
        riskScore += Double(sectorConc.count) * 8.0 // Sector concentration
        riskScore += min(20.0, ddResult.maxDrawdownPct / 2.0) // Drawdown contribution
        
        return PortfolioRiskReport(
            generatedAt: Date(),
            portfolioValue: varResult.portfolioValue,
            riskScore: min(100, riskScore),
            varResult: varResult,
            drawdownResult: ddResult,
            correlationWarnings: corrWarnings,
            concentrationWarnings: stockConc + sectorConc,
            correlationMatrix: corrMatrix,
            symbols: positions.map { $0.symbol }
        )
    }
}

// MARK: - Risk Configuration

struct RiskConfig: Sendable {
    let maxSinglePositionPct: Double // Tek hisse max %
    let maxSectorPct: Double         // Sektör max %
    let highCorrelationThreshold: Double
    let maxDrawdownPct: Double       // Max izin verilen drawdown
    
    static nonisolated let `default` = RiskConfig(
        maxSinglePositionPct: 20.0,
        maxSectorPct: 40.0,
        highCorrelationThreshold: 0.75,
        maxDrawdownPct: 25.0
    )
    
    static nonisolated let conservative = RiskConfig(
        maxSinglePositionPct: 10.0,
        maxSectorPct: 25.0,
        highCorrelationThreshold: 0.60,
        maxDrawdownPct: 15.0
    )
}

// MARK: - Risk Models

struct VaRResult: Codable, Sendable {
    let var95: Double           // %95 güven VaR
    let var99: Double           // %99 güven VaR
    let expectedShortfall: Double // CVaR
    let portfolioValue: Double
    let horizon: Int            // Gün
    
    var var95Pct: Double { portfolioValue > 0 ? var95 / portfolioValue * 100 : 0 }
    var var99Pct: Double { portfolioValue > 0 ? var99 / portfolioValue * 100 : 0 }
}

struct DrawdownResult: Codable, Sendable {
    let maxDrawdown: Double
    let maxDrawdownPct: Double
    let peakIndex: Int
    let troughIndex: Int
}

struct ConcentrationWarning: Codable, Identifiable, Sendable {
    var id: String { "\(type.rawValue)_\(symbol)" }
    
    enum WarningType: String, Codable, Sendable {
        case singleStock = "Tek Hisse"
        case sector = "Sektör"
    }
    
    enum Severity: String, Codable, Sendable {
        case warning = "Uyarı"
        case critical = "Kritik"
    }
    
    let type: WarningType
    let symbol: String
    let currentPct: Double
    let limitPct: Double
    let severity: Severity
}

struct CorrelationWarning: Codable, Identifiable, Sendable {
    var id: String { "\(symbol1)_\(symbol2)" }
    
    enum Severity: String, Codable, Sendable {
        case warning = "Uyarı"
        case critical = "Kritik"
    }
    
    let symbol1: String
    let symbol2: String
    let correlation: Double
    let severity: Severity
}

struct PortfolioRiskReport: Codable, Sendable {
    let generatedAt: Date
    let portfolioValue: Double
    let riskScore: Double       // 0-100
    let varResult: VaRResult
    let drawdownResult: DrawdownResult
    let correlationWarnings: [CorrelationWarning]
    let concentrationWarnings: [ConcentrationWarning]
    let correlationMatrix: [[Double]]
    let symbols: [String]
    
    var riskLevel: String {
        switch riskScore {
        case 0..<30: return "Düşük"
        case 30..<60: return "Orta"
        case 60..<80: return "Yüksek"
        default: return "Çok Yüksek"
        }
    }
}

// MARK: - Portfolio Position (Helper)

struct PortfolioPosition: Sendable {
    let symbol: String
    let quantity: Double
    let avgCost: Double
    let currentPrice: Double
    
    var currentValue: Double { quantity * currentPrice }
    var pnl: Double { (currentPrice - avgCost) * quantity }
    var pnlPct: Double { avgCost > 0 ? (currentPrice - avgCost) / avgCost * 100 : 0 }
}

