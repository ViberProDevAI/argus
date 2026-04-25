import Foundation

// MARK: - Momentum Master Engine
/// Council member responsible for momentum analysis (RSI, MACD, Stochastic)
struct MomentumMasterEngine: TechnicalCouncilMember, Sendable {
    let id = "momentum_master"
    let name = "Momentum Ustası"
    
    nonisolated init() {}
    
    // MARK: - Analyze & Propose
    
    func analyze(candles: [Candle], symbol: String) async -> CouncilProposal? {
        guard candles.count >= 30 else { return nil }
        
        let closes = candles.map { $0.close }
        let currentPrice = closes.last ?? 0
        
        // Calculate indicators
        guard let rsi = calculateRSI(candles: candles, period: 14) else { return nil }
        let (_, _, histogram) = calculateMACD(candles: candles)
        let stochastic = calculateStochastic(candles: candles, period: 14)
        
        // Decision logic
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // Ensemble teyit sayacı: RSI + MACD + Stochastic üçlüsünün kaçı uyumlu?
        // Eski sürüm tek gösterge (RSI) gördüğü anda 0.85 confidence veriyordu;
        // ranging piyasalarda RSI 28→32 ping-pong'u sürekli whipsaw üretiyordu.
        // Yeni mantık: en az 2/3 gösterge aynı yönde olmalı; tek gösterge zayıf sinyal.

        let macdHist = histogram ?? 0
        let stoch = stochastic ?? 50

        // OVERSOLD BOUNCE (Strong Buy Signal) — 2/3 ensemble
        if rsi < 30 {
            let rsiSignal = true                        // RSI oversold
            let macdSignal = macdHist > 0               // MACD yukarı dönüyor
            let stochSignal = stoch < 20                // Stoch oversold
            let votes = [rsiSignal, macdSignal, stochSignal].filter { $0 }.count

            if votes >= 2 {
                action = .buy
                confidence = votes == 3 ? 0.92 : 0.82
                let supports = [
                    rsiSignal   ? "RSI \(Int(rsi))" : nil,
                    macdSignal  ? "MACD+" : nil,
                    stochSignal ? "Stoch \(Int(stoch))" : nil
                ].compactMap { $0 }.joined(separator: ", ")
                reasoning = "Aşırı satım (\(supports)) — toparlanma potansiyeli \(votes)/3 teyit"
            } else {
                // Tek gösterge: zayıf sinyal, abstain
                return nil
            }
        }
        // OVERBOUGHT (Sell/Caution Signal) — 2/3 ensemble
        else if rsi > 70 {
            let rsiSignal = true
            let macdSignal = macdHist < 0
            let stochSignal = stoch > 80
            let votes = [rsiSignal, macdSignal, stochSignal].filter { $0 }.count

            if votes >= 2 {
                action = .sell
                confidence = votes == 3 ? 0.88 : 0.75
                let supports = [
                    rsiSignal   ? "RSI \(Int(rsi))" : nil,
                    macdSignal  ? "MACD-" : nil,
                    stochSignal ? "Stoch \(Int(stoch))" : nil
                ].compactMap { $0 }.joined(separator: ", ")
                reasoning = "Aşırı alım (\(supports)) — düzeltme riski \(votes)/3 teyit"

                // Ekstrem aşırı alım özel durum
                if rsi > 80 && votes >= 2 {
                    confidence = min(0.92, confidence + 0.05)
                }
            } else {
                return nil
            }
        }
        // BULLISH MOMENTUM
        else if rsi > 50 && rsi < 70 {
            if let hist = histogram, hist > 0 {
                // Rising momentum
                confidence = 0.70
                reasoning = "Momentum yükseliyor (RSI: \(Int(rsi)), MACD pozitif)"
                action = .buy
            } else {
                return nil // No strong signal
            }
        }
        // BEARISH MOMENTUM
        else if rsi < 50 && rsi > 30 {
            if let hist = histogram, hist < 0 {
                // Falling momentum
                confidence = 0.65
                reasoning = "Momentum düşüyor (RSI: \(Int(rsi)), MACD negatif)"
                action = .sell
            } else {
                return nil // No strong signal
            }
        }
        else {
            return nil // Neutral zone
        }
        
        // Only propose if confidence is high enough
        guard confidence >= 0.65 else { return nil }
        
        // Calculate stops based on ATR
        let atr = calculateATR(candles: candles)
        let stopLoss = action == .buy ? currentPrice - (atr * 1.5) : currentPrice + (atr * 1.5)
        let target = action == .buy ? currentPrice + (atr * 2) : currentPrice - (atr * 2)
        
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
        guard candles.count >= 30 else {
            return CouncilVote(voter: id, voterName: name, decision: .abstain, reasoning: "Yetersiz veri", weight: 0)
        }
        
        guard let rsi = calculateRSI(candles: candles, period: 14) else {
            return CouncilVote(voter: id, voterName: name, decision: .abstain, reasoning: "Hesaplama hatası", weight: 0)
        }
        
        let (_, _, histogram) = calculateMACD(candles: candles)
        
        switch proposal.action {
        case .buy:
            // VETO buy if extremely overbought
            if rsi > 85 {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Aşırı alım (RSI: \(Int(rsi))) - AL tehlikeli", weight: 1.0)
            }
            // Support buy if oversold or neutral
            else if rsi < 40 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "RSI uygun (\(Int(rsi)))", weight: 1.0)
            }
            // Check MACD
            else if let hist = histogram, hist > 0 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "MACD pozitif", weight: 0.8)
            }
            else {
                return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                                   reasoning: "Momentum belirsiz", weight: 0.5)
            }
            
        case .sell:
            // VETO sell if extremely oversold
            if rsi < 20 {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Aşırı satım (RSI: \(Int(rsi))) - SAT tehlikeli", weight: 1.0)
            }
            // Support sell if overbought
            else if rsi > 60 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "RSI yüksek (\(Int(rsi)))", weight: 1.0)
            }
            // Check MACD
            else if let hist = histogram, hist < 0 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "MACD negatif", weight: 0.8)
            }
            else {
                return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                                   reasoning: "Momentum belirsiz", weight: 0.5)
            }
            
        case .hold:
            return CouncilVote(voter: id, voterName: name, decision: .approve, 
                               reasoning: "Bekle destekleniyor", weight: 0.5)
        }
    }
    
    // MARK: - Helpers
    
    private func calculateRSI(candles: [Candle], period: Int) -> Double? {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastRSI(candles: candles, period: period)
    }
    
    private func calculateMACD(candles: [Candle]) -> (Double?, Double?, Double?) {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastMACD(candles: candles)
    }
    
    private func ema(_ values: [Double], _ period: Int) -> Double? {
        guard values.count >= period else { return nil }
        
        let multiplier = 2.0 / Double(period + 1)
        var emaValue = values.prefix(period).reduce(0, +) / Double(period)
        
        for i in period..<values.count {
            emaValue = (values[i] - emaValue) * multiplier + emaValue
        }
        
        return emaValue
    }
    
    private func calculateStochastic(candles: [Candle], period: Int) -> Double? {
        // SSoT: IndicatorService kullanılıyor
        let result = IndicatorService.lastStochastic(candles: candles, kPeriod: period)
        return result.k
    }
    
    private func calculateATR(candles: [Candle], period: Int = 14) -> Double {
        // SSoT: IndicatorService kullanılıyor
        return IndicatorService.lastATR(candles: candles, period: period) ?? 0.0
    }
}
