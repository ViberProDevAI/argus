import Foundation

// MARK: - Monetary Policy Engine (ex-FedMaster)
/// Council member responsible for Fed and interest rate analysis
struct MonetaryPolicyEngine: MacroCouncilMember, Sendable {
    let id = "monetary_policy"
    let name = "Monetary Policy"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // Yield curve inversion = recession signal
        if macro.yieldCurveInverted {
            confidence = 0.85
            stance = .defensive
            reasoning = "Yield Curve Inverted - Recession Signal"
        }
        // High and rising rates
        else if let fedRate = macro.fedFundsRate, fedRate > 5.0 {
            confidence = 0.75
            stance = .cautious
            reasoning = "High Rates (%\(String(format: "%.2f", fedRate))) - Liquidity Constraint"
        }
        // Low rates = risk on
        else if let fedRate = macro.fedFundsRate, fedRate < 2.0 {
            confidence = 0.80
            stance = .riskOn
            reasoning = "Low Rates (%\(String(format: "%.2f", fedRate))) - High Liquidity"
        }
        // 10Y yield analysis
        else if let tenY = macro.tenYearYield {
            if tenY > 4.5 {
                confidence = 0.70
                stance = .cautious
                reasoning = "High 10Y Yield (%\(String(format: "%.2f", tenY))) - Bond Competition"
            } else if tenY < 3.0 {
                confidence = 0.70
                stance = .riskOn
                reasoning = "Low 10Y Yield - Equity Attractive"
            }
        }
        else {
            return nil
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        if macro.yieldCurveInverted && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto, 
                             reasoning: "Yield Curve Inverted - Risk too high", weight: 1.0)
        }
        
        if let fedRate = macro.fedFundsRate, fedRate > 5.5 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Rates too high for Risk-On", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Monetary Neutral", weight: 0.5)
    }
}

// MARK: - Market Sentiment Engine (ex-SentimentMaster)
/// Council member responsible for market sentiment (VIX, Fear & Greed)
struct MarketSentimentEngine: MacroCouncilMember, Sendable {
    let id = "market_sentiment"
    let name = "Market Sentiment"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // VIX Analysis
        if let vix = macro.vix {
            if vix > 35 {
                confidence = 0.85
                stance = .riskOff
                reasoning = "Extreme Fear (VIX: \(Int(vix))) - Panic Mode"
            } else if vix > 25 {
                confidence = 0.75
                stance = .defensive
                reasoning = "Elevated Fear (VIX: \(Int(vix)))"
            } else if vix < 12 {
                confidence = 0.70
                stance = .cautious
                reasoning = "Complacency (VIX: \(Int(vix))) - Caution"
            } else if vix < 18 {
                confidence = 0.75
                stance = .riskOn
                reasoning = "Calm Market (VIX: \(Int(vix)))"
            }
        }
        
        // Fear & Greed
        if let fg = macro.fearGreedIndex {
            if fg < 20 {
                confidence = max(confidence, 0.85)
                stance = .riskOn  // Contrarian - extreme fear = buy
                reasoning = "Extreme Fear (F&G: \(Int(fg))) - Contrarian Buy"
            } else if fg > 80 {
                confidence = max(confidence, 0.80)
                stance = .defensive
                reasoning = "Extreme Greed (F&G: \(Int(fg))) - Correction Risk"
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        let vix = macro.vix ?? 20
        
        if vix > 35 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "VIX too high - Panic Mode", weight: 1.0)
        }
        
        if let fg = macro.fearGreedIndex, fg > 85 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Extreme Greed - Correction Imminent", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Sentiment Neutral", weight: 0.5)
    }
}

// MARK: - Sector Rotation Engine (ex-SectorMaster)
/// Council member responsible for sector rotation analysis
struct SectorRotationEngine: MacroCouncilMember, Sendable {
    let id = "sector_rotation"
    let name = "Sector Rotation"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        guard let phase = macro.sectorRotation else { return nil }
        
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        switch phase {
        case .earlyExpansion:
            confidence = 0.80
            stance = .riskOn
            reasoning = "Early Expansion - Tech & Finance Lead"
        case .lateExpansion:
            confidence = 0.70
            stance = .cautious
            reasoning = "Late Expansion - Energy & Materials Lead"
        case .earlyRecession:
            confidence = 0.85
            stance = .defensive
            reasoning = "Early Recession - Defensive Sectors Lead"
        case .lateRecession:
            confidence = 0.75
            stance = .cautious
            reasoning = "Late Recession - Bottoming Process"
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        guard let phase = macro.sectorRotation else {
            return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Phase Unclear", weight: 0.3)
        }
        
        if phase == .earlyRecession && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Recession Phase - Reduce Risk", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Rotation Neutral", weight: 0.5)
    }
}

// MARK: - Economic Cycle Engine (ex-CycleMaster)
/// Council member responsible for economic cycle analysis
struct EconomicCycleEngine: MacroCouncilMember, Sendable {
    let id = "economic_cycle"
    let name = "Economic Cycle"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // GDP + Unemployment analysis
        if let gdp = macro.gdpGrowth, let unemployment = macro.unemploymentRate {
            if gdp > 3 && unemployment < 4 {
                confidence = 0.80
                stance = .riskOn
                reasoning = "Strong Economy: GDP +%\(String(format: "%.1f", gdp)), UE %\(String(format: "%.1f", unemployment))"
            } else if gdp < 0 {
                confidence = 0.85
                stance = .defensive
                reasoning = "Negative GDP: %\(String(format: "%.1f", gdp)) - Recession"
            } else if unemployment > 6 {
                confidence = 0.75
                stance = .cautious
                reasoning = "High Unemployment: %\(String(format: "%.1f", unemployment))"
            }
        }
        
        // Inflation
        if let inflation = macro.inflationRate {
            if inflation > 5 {
                confidence = max(confidence, 0.75)
                stance = .cautious
                reasoning += " | High Inflation: %\(String(format: "%.1f", inflation))"
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        if let gdp = macro.gdpGrowth, gdp < -1 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Recession - Risk Off", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Cycle Neutral", weight: 0.5)
    }
}

// MARK: - Cross-Asset Engine (ex-CorrelationMaster)
/// Council member responsible for cross-asset correlation analysis
struct CrossAssetEngine: MacroCouncilMember, Sendable {
    let id = "cross_asset"
    let name = "Cross-Asset"
    
    nonisolated init() {}
    
    func analyze(macro: MacroSnapshot) async -> MacroProposal? {
        var confidence = 0.0
        var stance: MacroStance = .cautious
        var reasoning = ""
        
        // Market breadth
        if let adRatio = macro.advanceDeclineRatio {
            if adRatio > 2.0 {
                confidence = 0.75
                stance = .riskOn
                reasoning = "Strong Breadth (A/D: \(String(format: "%.1f", adRatio)))"
            } else if adRatio < 0.5 {
                confidence = 0.80
                stance = .defensive
                reasoning = "Weak Breadth (A/D: \(String(format: "%.1f", adRatio)))"
            }
        }
        
        // Percent above 200MA
        if let above200 = macro.percentAbove200MA {
            if above200 > 70 {
                confidence = max(confidence, 0.75)
                stance = .riskOn
                reasoning += " | %\(Int(above200)) above 200MA"
            } else if above200 < 30 {
                confidence = max(confidence, 0.80)
                stance = .defensive
                reasoning = "Only %\(Int(above200)) above 200MA - Market Weak"
            }
        }
        
        // Put/Call ratio
        if let pcr = macro.putCallRatio {
            if pcr > 1.2 {
                confidence = max(confidence, 0.70)
                stance = .riskOn  // Contrarian
                reasoning += " | High P/C (\(String(format: "%.2f", pcr))) - Fear"
            } else if pcr < 0.7 {
                confidence = max(confidence, 0.70)
                stance = .cautious
                reasoning += " | Low P/C (\(String(format: "%.2f", pcr))) - Complacency"
            }
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return MacroProposal(
            proposer: id,
            proposerName: name,
            stance: stance,
            confidence: confidence,
            reasoning: reasoning
        )
    }
    
    func vote(on proposal: MacroProposal, macro: MacroSnapshot) -> MacroVote {
        if let above200 = macro.percentAbove200MA, above200 < 20 && proposal.stance == .riskOn {
            return MacroVote(voter: id, voterName: name, decision: .veto,
                             reasoning: "Market Internals Weak", weight: 0.9)
        }
        
        return MacroVote(voter: id, voterName: name, decision: .abstain, reasoning: "Cross-Asset Neutral", weight: 0.5)
    }
}
