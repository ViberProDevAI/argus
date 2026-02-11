import Foundation

// MARK: - Price Master Engine
/// Council member responsible for price action and volume analysis
struct PriceMasterEngine: TechnicalCouncilMember, Sendable {
    let id = "price_master"
    let name = "Fiyat Analisti"
    
    nonisolated init() {}
    
    // MARK: - Analyze & Propose
    
    func analyze(candles: [Candle], symbol: String) async -> CouncilProposal? {
        guard candles.count >= 30, let currentCandle = candles.last else {
            return nil
        }
        let currentPrice = currentCandle.close
        
        // Volume analysis
        let volumes = candles.map { $0.volume }
        let avgVolume = volumes.suffix(20).reduce(0, +) / 20.0
        let currentVolume = currentCandle.volume
        let volumeRatio = avgVolume > 0 ? currentVolume / avgVolume : 1.0
        
        // Price action analysis
        let bodySize = abs(currentCandle.close - currentCandle.open)
        let upperWick = currentCandle.high - max(currentCandle.open, currentCandle.close)
        let lowerWick = min(currentCandle.open, currentCandle.close) - currentCandle.low
        let totalRange = currentCandle.high - currentCandle.low
        
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // Güvenli önceki mum erişimi
        let prevIndex = candles.count - 2
        guard prevIndex >= 0 else { return nil }
        let prevCandle = candles[prevIndex]

        // BULLISH ENGULFING with Volume
        if currentCandle.close > currentCandle.open { // Green candle
            if prevCandle.close < prevCandle.open && // Previous red
               currentCandle.close > prevCandle.open && // Engulfs
               volumeRatio > 1.5 {
                confidence = 0.80
                reasoning = "Yutan Boğa + Yüksek Hacim (x\(String(format: "%.1f", volumeRatio)))"
                action = .buy
            }
        }

        // BEARISH ENGULFING with Volume
        if currentCandle.close < currentCandle.open { // Red candle
            if prevCandle.close > prevCandle.open && // Previous green
               currentCandle.close < prevCandle.open && // Engulfs
               volumeRatio > 1.5 {
                confidence = 0.75
                reasoning = "Yutan Ayı + Yüksek Hacim (x\(String(format: "%.1f", volumeRatio)))"
                action = .sell
            }
        }
        
        // HAMMER (Bullish reversal)
        if lowerWick > bodySize * 2 && upperWick < bodySize * 0.5 {
            confidence = 0.70
            reasoning = "Çekiç formasyonu (dip avcısı)"
            action = .buy
        }
        
        // SHOOTING STAR (Bearish reversal)
        if upperWick > bodySize * 2 && lowerWick < bodySize * 0.5 {
            confidence = 0.70
            reasoning = "Kayan Yıldız formasyonu (zirve işareti)"
            action = .sell
        }
        
        // DOJI with high volume (indecision, but notable)
        if bodySize < totalRange * 0.1 && volumeRatio > 2.0 {
            // Don't propose, but will influence voting
            return nil
        }
        
        guard confidence >= 0.65 else { return nil }
        
        let atr = calculateATR(candles: candles)
        let stopLoss = action == .buy ? currentPrice - (atr * 1.5) : currentPrice + (atr * 1.5)
        let target = action == .buy ? currentPrice + (atr * 2.5) : currentPrice - (atr * 2.5)
        
        return CouncilProposal(
            proposer: id,
            proposerName: name,
            action: action,
            confidence: confidence,
            reasoning: reasoning,
            entryPrice: currentPrice,
            stopLoss: stopLoss,
            target: target
        )
    }
    
    // MARK: - Vote on Others' Proposals
    
    func vote(on proposal: CouncilProposal, candles: [Candle], symbol: String) -> CouncilVote {
        guard candles.count >= 20, let currentCandle = candles.last else {
            return CouncilVote(voter: id, voterName: name, decision: .abstain, reasoning: "Yetersiz veri", weight: 0)
        }
        
        // Volume analysis
        let volumes = candles.map { $0.volume }
        let avgVolume = volumes.suffix(20).reduce(0, +) / 20.0
        let currentVolume = currentCandle.volume
        let volumeRatio = avgVolume > 0 ? currentVolume / avgVolume : 1.0
        
        // Price action
        let isGreenCandle = currentCandle.close > currentCandle.open
        let bodySize = abs(currentCandle.close - currentCandle.open)
        let avgBodySize = candles.suffix(10).map { abs($0.close - $0.open) }.reduce(0, +) / 10.0
        let _ = bodySize > avgBodySize * 1.5
        
        switch proposal.action {
        case .buy:
            // Support buy with volume confirmation
            if volumeRatio > 1.3 && isGreenCandle {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Hacim onayı (x\(String(format: "%.1f", volumeRatio))) + Yeşil mum", weight: 1.0)
            }
            // Veto if volume divergence (price up, volume down)
            if volumeRatio < 0.7 && isGreenCandle {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Hacim uyumsuzluğu - AL güvenilir değil", weight: 0.8)
            }
            return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                               reasoning: "Hacim nötr", weight: 0.5)
            
        case .sell:
            // Support sell with volume confirmation
            if volumeRatio > 1.3 && !isGreenCandle {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Satış hacmi yüksek (x\(String(format: "%.1f", volumeRatio)))", weight: 1.0)
            }
            // Veto if volume divergence (price down, volume down)
            if volumeRatio < 0.7 && !isGreenCandle {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Zayıf satış baskısı - SAT acele etme", weight: 0.7)
            }
            return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                               reasoning: "Hacim nötr", weight: 0.5)
            
        case .hold:
            return CouncilVote(voter: id, voterName: name, decision: .approve, 
                               reasoning: "Fiyat aksiyonu belirsiz", weight: 0.6)
        }
    }
    
    // MARK: - Helpers
    
    private func calculateATR(candles: [Candle], period: Int = 14) -> Double {
        guard candles.count >= period + 1 else { return 0.0 }
        
        var trs: [Double] = []
        for i in 1..<candles.count {
            let h = candles[i].high
            let l = candles[i].low
            let cp = candles[i-1].close
            let tr = max(h - l, max(abs(h - cp), abs(l - cp)))
            trs.append(tr)
        }
        
        return trs.suffix(period).reduce(0, +) / Double(period)
    }
}
