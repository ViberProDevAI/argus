import Foundation

// MARK: - Value Master Engine
/// Council member responsible for valuation analysis (P/E, P/B, DCF)
struct ValueMasterEngine: FundamentalCouncilMember, Sendable {
    let id = "value_master"
    let name = "Değer Ustası"
    
    nonisolated init() {}
    
    func analyze(financials: FinancialSnapshot, symbol: String) async -> FundamentalProposal? {
        // Check if we have enough valuation data
        guard let pe = financials.peRatio else { return nil }
        
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        var intrinsicValue: Double? = nil
        var marginOfSafety: Double? = nil
        
        // === DYNAMIC EXPECTATIONS ===
        // Priority: 1) Analyst target price 2) Forward PE 3) Sector PE
        let expectedPE: Double
        let expectationSource: String
        
        if let forwardPE = financials.forwardPE, forwardPE > 0 {
            expectedPE = forwardPE
            expectationSource = "Forward P/E"
        } else {
            expectedPE = financials.sectorPE ?? 20.0
            expectationSource = "Sektör Ort."
        }
        
        // Calculate upside based on analyst target price
        let analystUpside: Double? = {
            guard let target = financials.targetMeanPrice, target > 0, financials.price > 0 else { return nil }
            return (target - financials.price) / financials.price * 100
        }()
        
        // Analyst recommendation (1=Strong Buy, 5=Sell)
        let analystBullish = (financials.recommendationMean ?? 3.0) < 2.5
        let analystBearish = (financials.recommendationMean ?? 3.0) > 3.5
        
        // === DYNAMIC PREMIUM TOLERANCE ===
        // High-quality companies (analysts bullish) get more PE tolerance
        let qualityMultiplier = analystBullish ? 2.0 : 1.5
        
        let peDiscount = (expectedPE - pe) / expectedPE
        let pb = financials.pbRatio ?? 3.0
        let pbCheap = pb < 1.5
        let peImproving = (financials.forwardPE ?? pe) < pe
        
        // === DECISION LOGIC WITH ANALYST DATA ===
        
        // DEEP VALUE (unchanged - extreme cases)
        if pe < 10 && pb < 1.0 {
            confidence = 0.90
            reasoning = "Derin değer fırsatı: P/E=\(String(format: "%.1f", pe)), P/B=\(String(format: "%.1f", pb))"
            action = .buy
            intrinsicValue = financials.price * (expectedPE / pe)
            marginOfSafety = (intrinsicValue! - financials.price) / intrinsicValue! * 100
        }
        // ANALYST BULLISH + UNDERVALUED
        else if let upside = analystUpside, upside > 20 && analystBullish {
            confidence = 0.85
            reasoning = "Analist hedef: +%\(Int(upside)) potansiyel (\(financials.analystCount ?? 0) analist)"
            action = .buy
            intrinsicValue = financials.targetMeanPrice
            marginOfSafety = upside
        }
        // UNDERVALUED vs Expected PE
        else if peDiscount > 0.20 && pbCheap {
            confidence = 0.80
            reasoning = "Değerinin altında: \(expectationSource)'e %\(Int(peDiscount * 100)) iskonto"
            action = .buy
            intrinsicValue = financials.price * (1 + peDiscount)
            marginOfSafety = peDiscount * 100
        }
        // FAIRLY VALUED + IMPROVING
        else if peDiscount > 0 && peImproving {
            confidence = 0.65
            reasoning = "Makul değerli, Forward P/E iyileşiyor (\(String(format: "%.1f", financials.forwardPE ?? pe)))"
            action = .buy
        }
        // OVERVALUED - BUT CHECK ANALYST CONSENSUS FIRST
        else if pe > expectedPE * qualityMultiplier {
            // Even if PE is high, if analysts are bullish, don't sell
            if analystBullish {
                confidence = 0.50
                reasoning = "Yüksek P/E ama analistler pozitif - dikkatli bekle"
                return nil // No strong opinion
            } else {
                confidence = 0.75
                reasoning = "Aşırı değerli: P/E (\(String(format: "%.1f", pe))) > \(expectationSource) × \(String(format: "%.1f", qualityMultiplier))"
                action = .sell
            }
        }
        // ANALYST BEARISH
        else if analystBearish, let upside = analystUpside, upside < 0 {
            confidence = 0.70
            reasoning = "Analistler negatif: %\(Int(upside)) düşüş beklentisi"
            action = .sell
        }
        // EXTREMELY OVERVALUED (unchanged)
        else if pe > 50 && pb > 5 {
            confidence = 0.85
            reasoning = "Aşırı pahalı: P/E=\(String(format: "%.1f", pe)), P/B=\(String(format: "%.1f", pb))"
            action = .sell
        }
        else {
            return nil // No strong opinion
        }
        
        guard confidence >= 0.60 else { return nil }
        
        return FundamentalProposal(
            proposer: id,
            proposerName: name,
            action: action,
            confidence: confidence,
            reasoning: reasoning,
            targetPrice: intrinsicValue,
            intrinsicValue: intrinsicValue,
            marginOfSafety: marginOfSafety
        )
    }
    
    func vote(on proposal: FundamentalProposal, financials: FinancialSnapshot) -> FundamentalVote {
        guard let pe = financials.peRatio else {
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Veri yok", weight: 0)
        }
        
        let sectorPE = financials.sectorPE ?? 20.0
        let pb = financials.pbRatio ?? 3.0
        
        switch proposal.action {
        case .buy:
            if pe > sectorPE * 2 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Aşırı pahalı (P/E: \(String(format: "%.1f", pe)))", weight: 1.0)
            } else if pe < sectorPE * 0.8 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Değerli (P/E: \(String(format: "%.1f", pe)))", weight: 1.0)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Makul değerli", weight: 0.5)
            
        case .sell:
            if pe < 10 && pb < 1.0 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Derin değer - SAT tehlikeli", weight: 1.0)
            } else if pe > sectorPE * 1.5 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Pahalı, SAT mantıklı", weight: 1.0)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Değer nötr", weight: 0.5)
            
        case .hold:
            return FundamentalVote(voter: id, voterName: name, decision: .approve, reasoning: "Bekle uygun", weight: 0.5)
        }
    }
}

// MARK: - Growth Master Engine
/// Council member responsible for growth analysis
struct GrowthMasterEngine: FundamentalCouncilMember, Sendable {
    let id = "growth_master"
    let name = "Büyüme Ustası"
    
    nonisolated init() {}
    
    func analyze(financials: FinancialSnapshot, symbol: String) async -> FundamentalProposal? {
        let revenueGrowth = financials.revenueGrowth ?? 0
        let earningsGrowth = financials.earningsGrowth ?? 0
        let epsGrowth = financials.epsGrowth ?? 0
        
        // No growth data
        if revenueGrowth == 0 && earningsGrowth == 0 { return nil }
        
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // HYPER GROWTH
        if revenueGrowth > 30 && earningsGrowth > 30 {
            confidence = 0.85
            reasoning = "Hiper büyüme: Gelir +%\(Int(revenueGrowth)), Karlılık +%\(Int(earningsGrowth))"
            action = .buy
        }
        // STRONG GROWTH
        else if revenueGrowth > 15 && earningsGrowth > 15 {
            confidence = 0.75
            reasoning = "Güçlü büyüme: Gelir +%\(Int(revenueGrowth)), Karlılık +%\(Int(earningsGrowth))"
            action = .buy
        }
        // ACCELERATING GROWTH
        else if epsGrowth > revenueGrowth && epsGrowth > 10 {
            confidence = 0.70
            reasoning = "Hızlanan EPS büyümesi: +%\(Int(epsGrowth))"
            action = .buy
        }
        // DECLINING
        else if revenueGrowth < -10 && earningsGrowth < -10 {
            confidence = 0.80
            reasoning = "Çift haneli daralma: Gelir %\(Int(revenueGrowth)), Karlılık %\(Int(earningsGrowth))"
            action = .sell
        }
        // STAGNANT
        else if revenueGrowth < 2 && earningsGrowth < 2 {
            confidence = 0.60
            reasoning = "Durgun büyüme"
            action = .hold
        }
        else {
            return nil
        }
        
        guard confidence >= 0.60 else { return nil }
        
        return FundamentalProposal(
            proposer: id,
            proposerName: name,
            action: action,
            confidence: confidence,
            reasoning: reasoning,
            targetPrice: nil,
            intrinsicValue: nil,
            marginOfSafety: nil
        )
    }
    
    func vote(on proposal: FundamentalProposal, financials: FinancialSnapshot) -> FundamentalVote {
        let revenueGrowth = financials.revenueGrowth ?? 0
        let earningsGrowth = financials.earningsGrowth ?? 0
        
        switch proposal.action {
        case .buy:
            if revenueGrowth < -20 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Gelir çöküşte (%\(Int(revenueGrowth)))", weight: 1.0)
            } else if revenueGrowth > 10 && earningsGrowth > 0 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Büyüme pozitif", weight: 1.0)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Büyüme nötr", weight: 0.5)
            
        case .sell:
            if revenueGrowth > 25 && earningsGrowth > 25 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Hiper büyüme - SAT tehlikeli", weight: 0.8)
            } else if revenueGrowth < 0 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Negatif büyüme", weight: 1.0)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Büyüme belirsiz", weight: 0.5)
            
        case .hold:
            return FundamentalVote(voter: id, voterName: name, decision: .approve, reasoning: "Bekle destekleniyor", weight: 0.5)
        }
    }
}

// MARK: - Quality Master Engine
/// Council member responsible for quality metrics (ROE, margins, debt)
struct QualityMasterEngine: FundamentalCouncilMember, Sendable {
    let id = "quality_master"
    let name = "Kalite Ustası"
    
    nonisolated init() {}
    
    func analyze(financials: FinancialSnapshot, symbol: String) async -> FundamentalProposal? {
        let roe = financials.roe ?? 0
        let debtToEquity = financials.debtToEquity ?? 0
        let netMargin = financials.netMargin ?? 0
        let currentRatio = financials.currentRatio ?? 1.5
        
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // HIGH QUALITY
        if roe > 20 && netMargin > 15 && debtToEquity < 0.5 {
            confidence = 0.85
            reasoning = "Yüksek kalite: ROE %\(Int(roe)), Marj %\(Int(netMargin)), Düşük borç"
            action = .buy
        }
        // GOOD QUALITY
        else if roe > 15 && netMargin > 10 && debtToEquity < 1.0 {
            confidence = 0.70
            reasoning = "İyi kalite: ROE %\(Int(roe)), Marj %\(Int(netMargin))"
            action = .buy
        }
        // DEBT CRISIS
        else if debtToEquity > 3.0 && currentRatio < 1.0 {
            confidence = 0.90
            reasoning = "Borç krizi: D/E=\(String(format: "%.1f", debtToEquity)), Current Ratio=\(String(format: "%.1f", currentRatio))"
            action = .sell
        }
        // LOW QUALITY
        else if roe < 5 && netMargin < 3 {
            confidence = 0.65
            reasoning = "Düşük kalite: ROE %\(Int(roe)), Marj %\(Int(netMargin))"
            action = .sell
        }
        else {
            return nil
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return FundamentalProposal(
            proposer: id,
            proposerName: name,
            action: action,
            confidence: confidence,
            reasoning: reasoning,
            targetPrice: nil,
            intrinsicValue: nil,
            marginOfSafety: nil
        )
    }
    
    func vote(on proposal: FundamentalProposal, financials: FinancialSnapshot) -> FundamentalVote {
        let roe = financials.roe ?? 10
        let debtToEquity = financials.debtToEquity ?? 1.0
        let currentRatio = financials.currentRatio ?? 1.5
        
        switch proposal.action {
        case .buy:
            if debtToEquity > 3.0 || currentRatio < 0.8 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Finansal risk yüksek", weight: 1.0)
            } else if roe > 15 && debtToEquity < 1.0 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Kaliteli bilanço", weight: 1.0)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Kalite orta", weight: 0.5)
            
        case .sell:
            if roe > 25 && debtToEquity < 0.5 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Yüksek kalite - SAT riskli", weight: 0.8)
            } else if roe < 5 || debtToEquity > 2.0 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Düşük kalite, SAT mantıklı", weight: 1.0)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Kalite orta", weight: 0.5)
            
        case .hold:
            return FundamentalVote(voter: id, voterName: name, decision: .approve, reasoning: "Bekle uygun", weight: 0.5)
        }
    }
}

// MARK: - Dividend Master Engine
/// Council member responsible for dividend analysis
struct DividendMasterEngine: FundamentalCouncilMember, Sendable {
    let id = "dividend_master"
    let name = "Temettü Ustası"
    
    nonisolated init() {}
    
    func analyze(financials: FinancialSnapshot, symbol: String) async -> FundamentalProposal? {
        guard let yield = financials.dividendYield, yield > 0 else { return nil }
        
        let payoutRatio = financials.payoutRatio ?? 50
        let dividendGrowth = financials.dividendGrowth ?? 0
        
        var confidence = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // DIVIDEND KING
        if yield > 4 && payoutRatio < 60 && dividendGrowth > 5 {
            confidence = 0.85
            reasoning = "Temettü kralı: %\(String(format: "%.1f", yield)) verim, sürdürülebilir ödeme, büyüyen"
            action = .buy
        }
        // GOOD DIVIDEND
        else if yield > 2.5 && payoutRatio < 70 {
            confidence = 0.70
            reasoning = "İyi temettü: %\(String(format: "%.1f", yield)) verim, sürdürülebilir"
            action = .buy
        }
        // DIVIDEND TRAP
        else if yield > 8 && payoutRatio > 100 {
            confidence = 0.80
            reasoning = "Temettü tuzağı: %\(String(format: "%.1f", yield)) verim ama >100% ödeme oranı"
            action = .sell
        }
        // DECLINING DIVIDEND
        else if dividendGrowth < -10 {
            confidence = 0.70
            reasoning = "Azalan temettü: %\(Int(dividendGrowth)) düşüş"
            action = .sell
        }
        else {
            return nil
        }
        
        guard confidence >= 0.65 else { return nil }
        
        return FundamentalProposal(
            proposer: id,
            proposerName: name,
            action: action,
            confidence: confidence,
            reasoning: reasoning,
            targetPrice: nil,
            intrinsicValue: nil,
            marginOfSafety: nil
        )
    }
    
    func vote(on proposal: FundamentalProposal, financials: FinancialSnapshot) -> FundamentalVote {
        let yield = financials.dividendYield ?? 0
        let payoutRatio = financials.payoutRatio ?? 50
        
        switch proposal.action {
        case .buy:
            if yield > 8 && payoutRatio > 100 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Temettü tuzağı riski", weight: 0.7)
            } else if yield > 3 && payoutRatio < 70 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Sağlıklı temettü", weight: 0.8)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Temettü nötr", weight: 0.3)
            
        case .sell:
            if yield > 4 && payoutRatio < 60 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Kaliteli temettü - SAT düşün", weight: 0.6)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Temettü belirsiz", weight: 0.3)
            
        case .hold:
            return FundamentalVote(voter: id, voterName: name, decision: .approve, reasoning: "Bekle uygun", weight: 0.4)
        }
    }
}

// MARK: - Moat Master Engine
/// Council member responsible for competitive advantage analysis
struct MoatMasterEngine: FundamentalCouncilMember, Sendable {
    let id = "moat_master"
    let name = "Hendek Ustası"
    
    nonisolated init() {}
    
    func analyze(financials: FinancialSnapshot, symbol: String) async -> FundamentalProposal? {
        // Moat indicators
        let grossMargin = financials.grossMargin ?? 30
        let operatingMargin = financials.operatingMargin ?? 10
        let roe = financials.roe ?? 10
        let institutionalOwnership = financials.institutionalOwnership ?? 50
        
        var confident = 0.0
        var action: ProposedAction = .hold
        var reasoning = ""
        
        // WIDE MOAT
        if grossMargin > 50 && operatingMargin > 20 && roe > 20 {
            confident = 0.85
            reasoning = "Geniş hendek: Yüksek marjlar (Brüt: %\(Int(grossMargin)), Op: %\(Int(operatingMargin))), Güçlü ROE"
            action = .buy
        }
        // NARROW MOAT
        else if grossMargin > 40 && operatingMargin > 15 && roe > 15 {
            confident = 0.70
            reasoning = "Dar hendek: İyi marjlar ve ROE"
            action = .buy
        }
        // INSTITUTIONAL FAVORITE
        else if institutionalOwnership > 80 && roe > 15 {
            confident = 0.65
            reasoning = "Kurumsal favori: %\(Int(institutionalOwnership)) kurumsal sahiplik"
            action = .buy
        }
        // NO MOAT
        else if grossMargin < 25 && operatingMargin < 5 {
            confident = 0.70
            reasoning = "Hendek yok: Düşük marjlar, rekabet baskısı"
            action = .sell
        }
        else {
            return nil
        }
        
        guard confident >= 0.65 else { return nil }
        
        return FundamentalProposal(
            proposer: id,
            proposerName: name,
            action: action,
            confidence: confident,
            reasoning: reasoning,
            targetPrice: nil,
            intrinsicValue: nil,
            marginOfSafety: nil
        )
    }
    
    func vote(on proposal: FundamentalProposal, financials: FinancialSnapshot) -> FundamentalVote {
        let grossMargin = financials.grossMargin ?? 30
        let operatingMargin = financials.operatingMargin ?? 10
        
        switch proposal.action {
        case .buy:
            if grossMargin < 20 && operatingMargin < 5 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Rekabet avantajı yok", weight: 0.7)
            } else if grossMargin > 40 && operatingMargin > 15 {
                return FundamentalVote(voter: id, voterName: name, decision: .approve,
                                       reasoning: "Güçlü rekabet pozisyonu", weight: 0.9)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Hendek belirsiz", weight: 0.4)
            
        case .sell:
            if grossMargin > 50 && operatingMargin > 20 {
                return FundamentalVote(voter: id, voterName: name, decision: .veto,
                                       reasoning: "Geniş hendek - SAT düşün", weight: 0.7)
            }
            return FundamentalVote(voter: id, voterName: name, decision: .abstain, reasoning: "Hendek nötr", weight: 0.4)
            
        case .hold:
            return FundamentalVote(voter: id, voterName: name, decision: .approve, reasoning: "Bekle uygun", weight: 0.5)
        }
    }
}
