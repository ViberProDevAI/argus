import Foundation

// MARK: - Pattern Master Engine
/// Council member responsible for chart pattern analysis (includes Phoenix + ChartPatternEngine)
struct PatternMasterEngine: TechnicalCouncilMember, Sendable {
    let id = "pattern_master"
    let name = "Formasyon Ustası"
    
    nonisolated init() {}
    
    // MARK: - Analyze & Propose
    
    func analyze(candles: [Candle], symbol: String) async -> CouncilProposal? {
        guard candles.count >= 60 else { return nil }
        
        let currentPrice = candles.last?.close ?? 0
        
        // 1. Phoenix Analysis (Channel Reversion)
        let phoenixAdvice = PhoenixLogic.analyze(
            candles: candles,
            symbol: symbol,
            timeframe: .h1,
            config: PhoenixConfig()
        )
        
        // 2. Gemini Pattern Analysis (if available)
        let geminiPatterns = await ChartPatternEngine.shared.analyzePatterns(symbol: symbol, candles: candles)
        
        // Combine signals
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // Phoenix signal
        if phoenixAdvice.confidence >= 70 {
            if phoenixAdvice.triggers.touchLowerBand || phoenixAdvice.triggers.rsiReversal {
                confidence = max(confidence, phoenixAdvice.confidence / 100.0)
                action = .buy
                reasoning = "Phoenix: \(phoenixAdvice.reasonShort)"
            }
        }
        
        // Gemini patterns
        if geminiPatterns.hasPatterns {
            for pattern in geminiPatterns.highConfidencePatterns {
                if pattern.bias == .bullish && pattern.confidence > confidence {
                    confidence = pattern.confidence
                    action = .buy
                    reasoning = "\(pattern.nameTR) (\(pattern.stage.rawValue)) - \(pattern.notes ?? "")"
                } else if pattern.bias == .bearish && pattern.confidence > confidence {
                    confidence = pattern.confidence
                    action = .sell
                    reasoning = "\(pattern.nameTR) (\(pattern.stage.rawValue)) - \(pattern.notes ?? "")"
                }
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        // Use Phoenix targets if available
        let stopLoss = phoenixAdvice.invalidationLevel ?? (action == .buy ? currentPrice * 0.97 : currentPrice * 1.03)
        let target = phoenixAdvice.targets.first ?? (action == .buy ? currentPrice * 1.05 : currentPrice * 0.95)
        
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
        guard candles.count >= 60 else {
            return CouncilVote(voter: id, voterName: name, decision: .abstain, reasoning: "Yetersiz veri", weight: 0)
        }
        
        // Quick Phoenix check
        let phoenixAdvice = PhoenixLogic.analyze(
            candles: candles,
            symbol: symbol,
            timeframe: .h1,
            config: PhoenixConfig()
        )
        
        let currentPrice = candles.last?.close ?? 0
        
        switch proposal.action {
        case .buy:
            // Check if Phoenix shows oversold
            if phoenixAdvice.triggers.touchLowerBand || phoenixAdvice.triggers.rsiReversal {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Phoenix oversold sinyali", weight: 1.0)
            }
            // Check if Phoenix shows overbought (veto buy)
            if phoenixAdvice.confidence < 30 && !phoenixAdvice.triggers.trendOk {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Phoenix negatif trend", weight: 0.8)
            }
            return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                               reasoning: "Net formasyon yok", weight: 0.5)
            
        case .sell:
            // Check if at channel top
            if let upperBand = phoenixAdvice.channelUpper, currentPrice > upperBand * 0.98 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Kanal tepesinde", weight: 1.0)
            }
            // Check if oversold (veto sell)
            if phoenixAdvice.triggers.touchLowerBand {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Kanal dibinde - SAT tehlikeli", weight: 1.0)
            }
            return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                               reasoning: "Net formasyon yok", weight: 0.5)
            
        case .hold:
            return CouncilVote(voter: id, voterName: name, decision: .approve, 
                               reasoning: "Formasyon bekleniyor", weight: 0.6)
        }
    }
}
