import Foundation

// MARK: - Orion Relative Strength Engine
// Hisselerin endekse (XU100) göre performansını ve sektörel güç analizi

actor OrionRelativeStrengthEngine {
    static let shared = OrionRelativeStrengthEngine()
    
    private init() {}
    
    // MARK: - Ana Fonksiyon
    
    /// BIST hissesi için rölatif güç analizi yapar
    func analyze(symbol: String, candles: [Candle], benchmarkCandles: [Candle]?) async throws -> RelativeStrengthResult {
        let cleanSymbol = symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")
        
        guard candles.count >= 20 else {
            throw RSError.insufficientData
        }
        
        // 1. Rölatif Güç Hesabı
        var rs: Double = 1.0
        if let benchmark = benchmarkCandles, benchmark.count >= 20 {
            rs = calculateRelativeStrength(stockCandles: candles, indexCandles: benchmark, period: 20)
        }
        
        // 2. Beta Hesabı
        var beta: Double = 1.0
        if let benchmark = benchmarkCandles, benchmark.count >= 60 {
            beta = calculateBeta(stockCandles: candles, indexCandles: benchmark, period: 60)
        }
        
        // 3. Momentum (20 günlük değişim)
        let momentum = calculateMomentum(candles: candles, period: 20)
        
        // 4. Sektör bilgisi (sembol bazlı mapping)
        let sector = guessSector(symbol: cleanSymbol)
        
        // 5. Puanlama
        var metrics: [OrionRSMetric] = []
        
        // RS Skoru (Max 40)
        let rsScore: Double
        let rsExplanation: String
        switch rs {
        case 1.2...: rsScore = 40; rsExplanation = "Endeksten %\(Int((rs-1)*100)) daha iyi performans"
        case 1.1..<1.2: rsScore = 35; rsExplanation = "Güçlü pozitif ayrışma"
        case 1.05..<1.1: rsScore = 30; rsExplanation = "Hafif pozitif ayrışma"
        case 0.95..<1.05: rsScore = 20; rsExplanation = "Endeksle paralel hareket"
        case 0.9..<0.95: rsScore = 10; rsExplanation = "Hafif negatif ayrışma"
        default: rsScore = 5; rsExplanation = "Endeksten geride kalıyor"
        }
        metrics.append(OrionRSMetric(
            name: "Rölatif Güç (RS)",
            value: rs,
            score: rsScore,
            maxScore: 40,
            explanation: rsExplanation,
            formula: "(Hisse/XU100) / (Hisse[-20]/XU100[-20])"
        ))
        
        // Beta Skoru (Max 30)
        let betaScore: Double
        let betaExplanation: String
        switch beta {
        case ...0.6: betaScore = 30; betaExplanation = "Düşük volatilite - Defansif hisse"
        case 0.6..<0.9: betaScore = 25; betaExplanation = "Orta-düşük beta"
        case 0.9..<1.1: betaScore = 20; betaExplanation = "Endeksle uyumlu hareket"
        case 1.1..<1.4: betaScore = 15; betaExplanation = "Yüksek beta - Agresif"
        default: betaScore = 10; betaExplanation = "Çok yüksek volatilite - Risk"
        }
        metrics.append(OrionRSMetric(
            name: "Beta",
            value: beta,
            score: betaScore,
            maxScore: 30,
            explanation: betaExplanation,
            formula: "Cov(Hisse, Endeks) / Var(Endeks)"
        ))
        
        // Momentum Skoru (Max 30)
        let momentumScore: Double
        let momentumExplanation: String
        switch momentum {
        case 10...: momentumScore = 30; momentumExplanation = "Güçlü yukarı momentum"
        case 5..<10: momentumScore = 25; momentumExplanation = "Pozitif momentum"
        case 0..<5: momentumScore = 20; momentumExplanation = "Hafif pozitif"
        case -5..<0: momentumScore = 15; momentumExplanation = "Hafif negatif"
        case -10..<(-5): momentumScore = 10; momentumExplanation = "Negatif momentum"
        default: momentumScore = 5; momentumExplanation = "Güçlü aşağı momentum"
        }
        metrics.append(OrionRSMetric(
            name: "Momentum (20G)",
            value: momentum,
            score: momentumScore,
            maxScore: 30,
            explanation: momentumExplanation,
            formula: "(Fiyat - Fiyat[-20]) / Fiyat[-20] × 100"
        ))
        
        let totalScore = rsScore + betaScore + momentumScore
        
        // Durum belirleme
        let status: RSStatus
        if rs > 1.1 && momentum > 5 { status = .outperforming }
        else if rs > 1.0 { status = .stable }
        else if rs < 0.9 { status = .underperforming }
        else { status = .neutral }
        
        return RelativeStrengthResult(
            symbol: cleanSymbol,
            relativeStrength: rs,
            beta: beta,
            momentum: momentum,
            sector: sector,
            status: status,
            totalScore: totalScore,
            metrics: metrics,
            timestamp: Date()
        )
    }
    
    // MARK: - Hesaplamalar
    
    private func calculateRelativeStrength(stockCandles: [Candle], indexCandles: [Candle], period: Int) -> Double {
        guard stockCandles.count >= period, indexCandles.count >= period else { return 1.0 }
        
        let currentStock = stockCandles.last!.close
        let pastStock = stockCandles[stockCandles.count - period].close
        
        let currentIndex = indexCandles.last!.close
        let pastIndex = indexCandles[indexCandles.count - period].close
        
        guard pastStock > 0, pastIndex > 0 else { return 1.0 }
        
        let stockRatio = currentStock / pastStock
        let indexRatio = currentIndex / pastIndex
        
        guard indexRatio > 0 else { return 1.0 }
        
        return stockRatio / indexRatio
    }
    
    private func calculateBeta(stockCandles: [Candle], indexCandles: [Candle], period: Int) -> Double {
        guard stockCandles.count >= period, indexCandles.count >= period else { return 1.0 }
        
        // Günlük getirileri hesapla
        var stockReturns: [Double] = []
        var indexReturns: [Double] = []
        
        let startIndex = max(stockCandles.count - period, 1)
        
        for i in startIndex..<stockCandles.count {
            let stockReturn = (stockCandles[i].close - stockCandles[i-1].close) / stockCandles[i-1].close
            stockReturns.append(stockReturn)
            
            if i < indexCandles.count && i >= 1 {
                let indexReturn = (indexCandles[i].close - indexCandles[i-1].close) / indexCandles[i-1].close
                indexReturns.append(indexReturn)
            }
        }
        
        guard stockReturns.count == indexReturns.count, stockReturns.count > 2 else { return 1.0 }
        
        // Kovaryans ve Varyans
        let meanStock = stockReturns.reduce(0, +) / Double(stockReturns.count)
        let meanIndex = indexReturns.reduce(0, +) / Double(indexReturns.count)
        
        var covariance: Double = 0
        var indexVariance: Double = 0
        
        for i in 0..<stockReturns.count {
            covariance += (stockReturns[i] - meanStock) * (indexReturns[i] - meanIndex)
            indexVariance += pow(indexReturns[i] - meanIndex, 2)
        }
        
        guard indexVariance > 0 else { return 1.0 }
        
        return covariance / indexVariance
    }
    
    private func calculateMomentum(candles: [Candle], period: Int) -> Double {
        guard candles.count >= period else { return 0 }
        
        let current = candles.last!.close
        let past = candles[candles.count - period].close
        
        guard past > 0 else { return 0 }
        
        return ((current - past) / past) * 100
    }
    
    private func guessSector(symbol: String) -> String {
        // BistSectorRegistry'den merkezi erişim
        if let sectorName = BistSectorRegistry.sectorName(for: symbol),
           let sectorCode = BistSectorRegistry.sectorCode(for: symbol) {
            return "\(sectorName) (\(sectorCode))"
        }
        return "Diğer"
    }
    
    enum RSError: Error {
        case insufficientData
    }
}

// MARK: - Modeller

struct RelativeStrengthResult: Sendable {
    let symbol: String
    let relativeStrength: Double
    let beta: Double
    let momentum: Double
    let sector: String
    let status: RSStatus
    let totalScore: Double
    let metrics: [OrionRSMetric]
    let timestamp: Date
    
    var statusText: String {
        switch status {
        case .outperforming: return "⬆️ Pozitif Ayrışma"
        case .stable: return "➡️ Endeksle Paralel"
        case .neutral: return "↔️ Nötr"
        case .underperforming: return "⬇️ Negatif Ayrışma"
        }
    }
}

enum RSStatus: String {
    case outperforming = "Pozitif Ayrışma"
    case stable = "Paralel"
    case neutral = "Nötr"
    case underperforming = "Negatif Ayrışma"
}

struct OrionRSMetric: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let value: Double
    let score: Double
    let maxScore: Double
    let explanation: String
    let formula: String
}
