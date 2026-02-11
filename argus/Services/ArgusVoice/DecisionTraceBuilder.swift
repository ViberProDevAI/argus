import Foundation

// MARK: - Decision Trace Builder

/// Helper to construct a full DecisionTrace from disparate scoring engines.
struct DecisionTraceBuilder {
    
    static func build(
        symbol: String,
        action: String, // BUY, SELL
        fillPrice: Double,
        quantity: Double,
        mode: String = "PULSE",
        timeframe: String = "15m",
        
        // Detailed Scoring Inputs
        orion: OrionScoreResult?,
        atlas: FundamentalScoreResult?,
        aether: MacroEnvironmentRating?,
        hermes: Double? // Hermes is simple score for now
    ) -> ArgusVoiceTrace {
        
        // 1. Scores Block
        let overall = calculateOverall(orion: orion?.score, atlas: atlas?.totalScore, aether: aether?.numericScore, hermes: hermes)
        
        var missing: [String] = []
        if orion == nil { missing.append("Orion") }
        if atlas == nil { missing.append("Atlas") }
        if aether == nil { missing.append("Aether") }
        if hermes == nil { missing.append("Hermes") }
        
        let scores = ArgusVoiceTrace.Scores(
            overall: overall,
            orion: orion?.score ?? 0,
            atlas: atlas?.totalScore ?? 0,
            aether: aether?.numericScore ?? 0,
            hermes: hermes ?? 0,
            missingModules: missing
        )
        
        // 2. Orion Breakdown
        var orionBlock: ArgusVoiceTrace.OrionBreakdown? = nil
        if let o = orion {
            // Check penalty logic via raw checks or passed data?
            // Argus logic: if RSI>60 and Price>MA20... 
            // We'll rely on what we have.
            // Assumption: Orion 3.0 result has components.
            
            let comp = o.components
            
            orionBlock = ArgusVoiceTrace.OrionBreakdown(
                trend: .init(score: comp.trend, notes: comp.trendDesc),
                momentum: .init(rsi14: 0, macd: comp.momentumDesc, score: comp.momentum), // RSI raw value missing in result, using desc
                phoenix: .init(active: false, score: 0, notes: "N/A"), // Disabled
                relativeStrength: .init(score: comp.relativeStrength, notes: comp.rsDesc),
                volatilityLiquidity: .init(score: comp.volatility, notes: comp.volDesc),
                overboughtPenalty: nil // Needs access to internal penalty flag logic
            )
        }
        
        // 3. Atlas Breakdown
        var atlasBlock: ArgusVoiceTrace.AtlasBreakdown? = nil
        if let a = atlas {
            atlasBlock = ArgusVoiceTrace.AtlasBreakdown(
                profitability: a.profitabilityScore ?? 0,
                growth: a.growthScore ?? 0,
                leverageRisk: a.leverageScore ?? 0,
                cashQuality: a.cashQualityScore ?? 0,
                forwardGuidance: 0, // Not explicitly separate in result
                notes: a.summary
            )
        }
        
        // 4. Aether Breakdown
        var aetherBlock: ArgusVoiceTrace.AetherBreakdown? = nil
        if let ae = aether {
            aetherBlock = ArgusVoiceTrace.AetherBreakdown(
                regime: ae.regime.rawValue,
                score: ae.numericScore,
                drivers: ae.componentStatuses.map { "\($0.key): \($0.value)" }
            )
        }
        
        // 5. Build
        return ArgusVoiceTrace(
            meta: .init(
                tradeId: UUID().uuidString,
                symbol: symbol,
                assetType: "Equity", // Default
                mode: mode,
                timeframe: timeframe,
                signalTimeUTC: Date(),
                fillTimeUTC: Date(),
                providerUsed: ["ActiveProviders"],
                cacheHit: false
            ),
            action: .init(
                type: action,
                fillPrice: fillPrice,
                qty: quantity,
                slippagePct: 0,
                gapPct: 0
            ),
            scores: scores,
            orionBreakdown: orionBlock,
            atlasBreakdown: atlasBlock,
            aetherBreakdown: aetherBlock,
            hermesBreakdown: hermes != nil ? .init(sentiment: "N/A", score: hermes!, confidence: 0, headlines: []) : nil,
            risk: .init(atrPct: 0, stopLossPct: 0, takeProfitPct: 0, positionRiskPct: 0, portfolioExposurePct: 0),
            quality: .init(dataFreshnessSec: 0, anomalies: [], warnings: []),
            reasonCodes: [],
            counterfactuals: []
        )
    }
    
    // Simple average for now
    private static func calculateOverall(orion: Double?, atlas: Double?, aether: Double?, hermes: Double?) -> Double {
        let valid = [orion, atlas, aether, hermes].compactMap { $0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0, +) / Double(valid.count)
    }
}
