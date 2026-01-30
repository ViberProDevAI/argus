import Foundation

// MARK: - Structure Master Engine
/// Council member responsible for support/resistance and structure analysis
struct StructureMasterEngine: TechnicalCouncilMember, Sendable {
    let id = "structure_master"
    let name = "Yapısal Analist"
    
    nonisolated init() {}
    
    // MARK: - Analyze & Propose
    
    func analyze(candles: [Candle], symbol: String) async -> CouncilProposal? {
        guard candles.count >= 50 else { return nil }
        
        let currentPrice = candles.last?.close ?? 0
        
        // Find key levels
        let pivots = findPivotPoints(candles: candles)
        let supports = findSupportLevels(candles: candles, pivots: pivots)
        let resistances = findResistanceLevels(candles: candles, pivots: pivots)
        
        // Check proximity to levels
        let nearSupport = supports.first(where: { abs(currentPrice - $0) / $0 < 0.02 })
        let nearResistance = resistances.first(where: { abs(currentPrice - $0) / $0 < 0.02 })
        
        // Breakout detection
        let recentHigh = candles.suffix(20).map { $0.high }.max() ?? currentPrice
        let recentLow = candles.suffix(20).map { $0.low }.min() ?? currentPrice
        
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // SUPPORT BOUNCE
        if let support = nearSupport {
            // Price at support level
            let bounceStrength = (currentPrice - support) / support
            if bounceStrength > 0 && bounceStrength < 0.01 {
                confidence = 0.75
                reasoning = "Destek seviyesinde (\(String(format: "%.2f", support))) - Toparlanma potansiyeli"
                action = .buy
            }
        }
        
        // RESISTANCE REJECTION
        if let resistance = nearResistance {
            let rejectionStrength = (resistance - currentPrice) / resistance
            if rejectionStrength > 0 && rejectionStrength < 0.01 {
                confidence = 0.70
                reasoning = "Direnç seviyesinde (\(String(format: "%.2f", resistance))) - Ret potansiyeli"
                action = .sell
            }
        }
        
        // BREAKOUT UP
        if currentPrice > recentHigh * 0.99 {
            confidence = 0.80
            reasoning = "Yukarı kırılım tespit edildi (>\(String(format: "%.2f", recentHigh)))"
            action = .buy
        }
        
        // BREAKDOWN
        if currentPrice < recentLow * 1.01 {
            confidence = 0.75
            reasoning = "Aşağı kırılım tespit edildi (<\(String(format: "%.2f", recentLow)))"
            action = .sell
        }
        
        guard confidence >= 0.70 else { return nil }
        
        let atr = calculateATR(candles: candles)
        let stopLoss = action == .buy ? currentPrice - (atr * 2) : currentPrice + (atr * 2)
        let target = action == .buy ? (resistances.first ?? currentPrice * 1.05) : (supports.first ?? currentPrice * 0.95)
        
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
        
        let currentPrice = candles.last?.close ?? 0
        let pivots = findPivotPoints(candles: candles)
        let resistances = findResistanceLevels(candles: candles, pivots: pivots)
        let supports = findSupportLevels(candles: candles, pivots: pivots)
        
        switch proposal.action {
        case .buy:
            // Check if near major resistance
            if let resistance = resistances.first, (resistance - currentPrice) / resistance < 0.02 {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Major direnç noktası (\(String(format: "%.2f", resistance))) - AL riskli", weight: 1.0)
            }
            // Check if at support
            if let support = supports.first, (currentPrice - support) / support < 0.03 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Destek bölgesinde (\(String(format: "%.2f", support)))", weight: 1.0)
            }
            return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                               reasoning: "Kritik seviyeden uzak", weight: 0.5)
            
        case .sell:
            // Check if near major support
            if let support = supports.first, (currentPrice - support) / support < 0.02 {
                return CouncilVote(voter: id, voterName: name, decision: .veto, 
                                   reasoning: "Major destek noktası (\(String(format: "%.2f", support))) - SAT riskli", weight: 1.0)
            }
            // Check if at resistance
            if let resistance = resistances.first, (resistance - currentPrice) / resistance < 0.03 {
                return CouncilVote(voter: id, voterName: name, decision: .approve, 
                                   reasoning: "Direnç bölgesinde (\(String(format: "%.2f", resistance)))", weight: 1.0)
            }
            return CouncilVote(voter: id, voterName: name, decision: .abstain, 
                               reasoning: "Kritik seviyeden uzak", weight: 0.5)
            
        case .hold:
            return CouncilVote(voter: id, voterName: name, decision: .approve, 
                               reasoning: "Yapısal belirsizlik - bekle mantıklı", weight: 0.7)
        }
    }
    
    // MARK: - Helpers
    
    private func findPivotPoints(candles: [Candle]) -> [Double] {
        guard candles.count >= 5 else { return [] }
        
        var pivots: [Double] = []
        
        for i in 2..<(candles.count - 2) {
            let current = candles[i]
            let prev1 = candles[i-1]
            let prev2 = candles[i-2]
            let next1 = candles[i+1]
            let next2 = candles[i+2]
            
            // Swing High
            if current.high > prev1.high && current.high > prev2.high &&
               current.high > next1.high && current.high > next2.high {
                pivots.append(current.high)
            }
            
            // Swing Low
            if current.low < prev1.low && current.low < prev2.low &&
               current.low < next1.low && current.low < next2.low {
                pivots.append(current.low)
            }
        }
        
        return pivots.sorted()
    }
    
    private func findSupportLevels(candles: [Candle], pivots: [Double]) -> [Double] {
        let currentPrice = candles.last?.close ?? 0
        return pivots.filter { $0 < currentPrice }.sorted(by: >).prefix(3).map { $0 }
    }
    
    private func findResistanceLevels(candles: [Candle], pivots: [Double]) -> [Double] {
        let currentPrice = candles.last?.close ?? 0
        return pivots.filter { $0 > currentPrice }.sorted().prefix(3).map { $0 }
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
}
