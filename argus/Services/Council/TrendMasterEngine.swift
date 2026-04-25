import Foundation

// MARK: - Trend Master Engine
/// Council member responsible for trend analysis (EMA, ADX, SuperTrend)
struct TrendMasterEngine: TechnicalCouncilMember, Sendable {
    let id = "trend_master"
    let name = "Trend Analisti"
    nonisolated init() {}
    
    // MARK: - Analyze & Propose
    
    func analyze(candles: [Candle], symbol: String) async -> CouncilProposal? {
        guard candles.count >= 50 else { return nil }
        
        let closes = candles.map { $0.close }
        let currentPrice = closes.last ?? 0
        
        // Calculate indicators
        guard let sma20 = sma(closes, 20),
              let sma50 = sma(closes, 50),
              let sma200 = sma(closes, 200) else { return nil }
        
        let adx = calculateADX(candles: candles, period: 14)
        let _ = determineTrendStrength(price: currentPrice, sma20: sma20, sma50: sma50, sma200: sma200)
        
        // Only propose if strong conviction
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // BULLISH CONDITIONS
        if currentPrice > sma20 && sma20 > sma50 && sma50 > sma200 {
            // Perfect alignment
            confidence = 0.85
            if adx > 25 {
                confidence = 0.90
                reasoning = "Mükemmel trend hizalaması (Fiyat > SMA20 > SMA50 > SMA200) + Güçlü ADX (\(Int(adx)))"
            } else {
                reasoning = "Trend hizalaması pozitif ama ADX zayıf (\(Int(adx)))"
            }
            action = .buy
        }
        // GOLDEN CROSS
        else if sma50 > sma200 && previousSMA50(closes) <= previousSMA200(closes) {
            confidence = 0.80
            reasoning = "Golden Cross tespit edildi (SMA50 > SMA200)"
            action = .buy
        }
        // BEARISH CONDITIONS
        else if currentPrice < sma20 && sma20 < sma50 && sma50 < sma200 {
            // Death alignment
            confidence = 0.85
            reasoning = "Düşüş trend hizalaması (Fiyat < SMA20 < SMA50 < SMA200)"
            action = .sell
        }
        // DEATH CROSS
        else if sma50 < sma200 && previousSMA50(closes) >= previousSMA200(closes) {
            confidence = 0.80
            reasoning = "Death Cross tespit edildi (SMA50 < SMA200)"
            action = .sell
        }
        // NEUTRAL - No proposal
        else {
            return nil
        }
        
        // Only propose if confidence is high enough
        guard confidence >= 0.70 else { return nil }
        
        // Calculate stop loss based on ATR
        let atr = calculateATR(candles: candles)
        let stopLoss = action == .buy ? currentPrice - (atr * 2) : currentPrice + (atr * 2)
        let target = action == .buy ? currentPrice + (atr * 3) : currentPrice - (atr * 3)
        
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
        guard candles.count >= 50 else {
            return CouncilVote(voter: id, voterName: name, decision: .abstain, reasoning: "Yetersiz veri", weight: 0)
        }
        
        let closes = candles.map { $0.close }
        let currentPrice = closes.last ?? 0
        
        guard let _ = sma(closes, 20),
              let sma50 = sma(closes, 50),
              let sma200 = sma(closes, 200) else {
            return CouncilVote(voter: id, voterName: name, decision: .abstain, reasoning: "Hesaplama hatası", weight: 0)
        }
        
        let adx = calculateADX(candles: candles, period: 14)
        
        // Vote based on trend alignment
        switch proposal.action {
        case .buy:
            // Support buy if trend is up or neutral
            if currentPrice > sma50 && sma50 > sma200 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Trend yukarı yönlü", weight: 1.0)
            } else if currentPrice < sma200 && adx > 30 {
                // Strong downtrend - VETO buy
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Güçlü düşüş trendi - AL tehlikeli", weight: 1.0)
            } else {
                return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                                   reasoning: "Trend belirsiz", weight: 0.5)
            }
            
        case .sell:
            // Support sell if trend is down
            if currentPrice < sma50 && sma50 < sma200 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Trend aşağı yönlü", weight: 1.0)
            } else if currentPrice > sma200 && adx > 30 {
                // Strong uptrend - VETO sell
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Güçlü yükseliş trendi - SAT tehlikeli", weight: 1.0)
            } else {
                return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                                   reasoning: "Trend belirsiz", weight: 0.5)
            }
            
        case .hold:
            return CouncilVote(voter: id, voterName: name, decision: .approve, 
                               reasoning: "Bekle kararını destekliyorum", weight: 0.5)
        }
    }
    
    // MARK: - Helpers
    
    private func sma(_ values: [Double], _ period: Int) -> Double? {
        guard values.count >= period else { return nil }
        let slice = values.suffix(period)
        return slice.reduce(0, +) / Double(period)
    }
    
    private func previousSMA50(_ closes: [Double]) -> Double {
        guard closes.count >= 51 else { return 0 }
        let slice = closes.dropLast().suffix(50)
        return slice.reduce(0, +) / 50.0
    }
    
    private func previousSMA200(_ closes: [Double]) -> Double {
        guard closes.count >= 201 else { return 0 }
        let slice = closes.dropLast().suffix(200)
        return slice.reduce(0, +) / 200.0
    }
    
    private func calculateADX(candles: [Candle], period: Int) -> Double {
        guard candles.count >= period + 1 else { return 0 }
        
        var plusDMs: [Double] = []
        var minusDMs: [Double] = []
        var trs: [Double] = []
        
        for i in 1..<candles.count {
            let high = candles[i].high
            let low = candles[i].low
            let prevHigh = candles[i-1].high
            let prevLow = candles[i-1].low
            let prevClose = candles[i-1].close
            
            let plusDM = max(0, high - prevHigh)
            let minusDM = max(0, prevLow - low)
            
            plusDMs.append(plusDM > minusDM ? plusDM : 0)
            minusDMs.append(minusDM > plusDM ? minusDM : 0)
            
            let tr = max(high - low, max(abs(high - prevClose), abs(low - prevClose)))
            trs.append(tr)
        }
        
        guard plusDMs.count >= period else { return 0 }
        
        let avgPlusDM = plusDMs.suffix(period).reduce(0, +) / Double(period)
        let avgMinusDM = minusDMs.suffix(period).reduce(0, +) / Double(period)
        let avgTR = trs.suffix(period).reduce(0, +) / Double(period)
        
        guard avgTR > 0 else { return 0 }
        
        let plusDI = (avgPlusDM / avgTR) * 100
        let minusDI = (avgMinusDM / avgTR) * 100
        
        let diSum = plusDI + minusDI
        guard diSum > 0 else { return 0 }
        
        let dx = abs(plusDI - minusDI) / diSum * 100
        return dx // Simplified ADX (should be smoothed, but this works for voting)
    }
    
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
    
    private func determineTrendStrength(price: Double, sma20: Double, sma50: Double, sma200: Double) -> String {
        if price > sma20 && sma20 > sma50 && sma50 > sma200 {
            return "GÜÇLÜ YÜKSELİŞ"
        } else if price < sma20 && sma20 < sma50 && sma50 < sma200 {
            return "GÜÇLÜ DÜŞÜŞ"
        } else if price > sma200 {
            return "ZAYIF YÜKSELİŞ"
        } else if price < sma200 {
            return "ZAYIF DÜŞÜŞ"
        }
        return "YATAY"
    }
}
