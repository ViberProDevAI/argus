import Foundation

/// The central brain that aggregates scores from all modules to produce a final decision.
struct ArgusDecisionEngine {
    static let shared = ArgusDecisionEngine()
    
    /// Calculates the Final Argus Decision (Core & Pulse) based on available inputs.
    /// Supports asset-type agnostic scoring by ignoring nil components and distributing their weight.
    /// Calculates the Final Argus Decision (Core & Pulse) based on available inputs.
    /// - Parameters:
    ///   - traceContext: Optional (Price, Freshness) for improved auditing.
    ///   - portfolioContext: Optional (IsInPosition, LastTradeTime, LastAction, LastManual...) for Churn Guards.
    func makeDecision(
        symbol: String,
        assetType: SafeAssetType?,
        atlas: Double?,
        orion: Double?,
        orionDetails: OrionScoreResult?,
        aether: Double?,
        hermes: Double?,
        athena: Double?,
        phoenixAdvice: PhoenixAdvice?,
        demeterScore: Double?,
        marketData: (price: Double, equity: Double, currentRiskR: Double)?, 
        traceContext: (price: Double, freshness: Double, source: String)? = nil,
        portfolioContext: (
            isInPosition: Bool,
            lastTradeTime: Date?,
            lastAction: SignalAction?,
            lastManualActionTime: Date?,
            lastManualActionType: SignalAction?
        )? = nil,
        config: ArgusConfig = .defaults,
        candidateSource: CandidateSource = .watchlist // Added for Traceability
    ) -> (AgoraTrace, ArgusDecisionResult) { 
        
        let now = Date()
        // --- KERNEL CONFIGURATION (Dynamically Loaded) ---
        let aggressiveness = UserDefaults.standard.double(forKey: "kernel_aggressiveness")
        let riskTolerance = UserDefaults.standard.double(forKey: "kernel_risk_tolerance")
        let authorityTech = UserDefaults.standard.double(forKey: "kernel_authority_tech")
        
        // Restore Missing Variables
        var unusedFactorsList: [String] = []
        var dataSources: [String: String] = [:]
        
        // Log Price Source if available
        if let tc = traceContext {
            dataSources["Price"] = tc.source
        } else {
            dataSources["Price"] = "Unknown"
        }
        
        // Use config thresholds
        let effectiveBuyThreshold = config.defaultBuyThreshold - ((aggressiveness > 0 ? aggressiveness : config.defaultAggressiveness) - config.defaultAggressiveness) * config.aggressivenessMultiplier
        let effectiveSellThreshold = config.defaultSellThreshold + ((aggressiveness > 0 ? aggressiveness : config.defaultAggressiveness) - config.defaultAggressiveness) * config.aggressivenessMultiplier
        
        let techAuthority = authorityTech > 0 ? authorityTech : config.defaultTechAuthority
        
        // --- PHASE 1: DATA HEALTH GATE (Hard Stop) ---
        var filledModules = 0.0
        if orion != nil { filledModules += 1 }
        if atlas != nil { filledModules += 1 }
        if hermes != nil { filledModules += 1 }
        if aether != nil { filledModules += 1 }
        
        let coveragePct = (filledModules / config.totalModules) * 100.0
        let isDataSufficient = coveragePct >= config.minCoveragePct && orion != nil
        
        let dataHealth = DataHealthSnapshot(
            freshnessScore: traceContext?.freshness ?? 100, 
            missingModules: isDataSufficient ? [] : ["Critical Data Missing"], 
            isAcceptable: isDataSufficient
        )
        
        if !isDataSufficient {
            return makeAbstainDecision(symbol: symbol, reason: "Veri Yetersiz (%/\(Int(coveragePct))). İşlem yapılmadı.", health: dataHealth, now: now)
        }
        
        // --- PHASE 2: GATHER OPINIONS ---
        // Pass authority to technical modules
        let orionOp = opinion(from: .orion, score: orion, role: "Trend Hunter", authority: techAuthority)
        let atlasOp = opinion(from: .atlas, score: atlas, role: "Value Sentinel") // Fundamental usually standard authority
        let hermesOp = opinion(from: .hermes, score: hermes, role: "News Catalyst")
        let aetherOp = opinion(from: .aether, score: aether, role: "Macro Guard")
        
        // Phoenix Logic
        let phoenixOp: ModuleOpinion
        if let ph = phoenixAdvice, ph.status == .active, let slope = ph.regressionSlope {
             let direction = slope > 0 ? 1.0 : -1.0
             let score = 50.0 + (direction * (ph.confidence / 2.0))
             
             // Phoenix is technical, apply authority
             phoenixOp = opinion(from: .phoenix, score: score, role: "Deep Scanner", authority: techAuthority)
             dataSources["Phoenix"] = "Yahoo/Screener (\(ph.timeframe.rawValue))"
        } else {
             phoenixOp = ModuleOpinion(module: .phoenix, stance: .abstain, preferredAction: .hold, strength: 0, score: 0, confidence: 0, evidence: ["Veri Başarısız (502/Timeout)"])
             unusedFactorsList.append("Phoenix (502/Timeout)")
        }
        
        if orion == nil { unusedFactorsList.append("Orion (Missing)") }
        if atlas == nil { unusedFactorsList.append("Atlas (Missing)") }
        if hermes == nil { unusedFactorsList.append("Hermes (Missing)") }
        if aether == nil { unusedFactorsList.append("Aether (Missing)") }
        
        var allOpinions = [orionOp, atlasOp, hermesOp, aetherOp]
        
        // --- PHASE 3: THE COUNCIL ---
        let candidates = allOpinions.filter { $0.preferredAction != .hold }
        
        let claimantOp: ModuleOpinion? = candidates.max(by: { 
            abs($0.score - 50) < abs($1.score - 50) 
        })
        
        if claimantOp == nil {
             return makeAbstainDecision(symbol: symbol, reason: "Konsey Sessiz (Yetersiz Sinyal)", health: dataHealth, now: now, opinions: allOpinions)
        }
        
        var leader = claimantOp!
        leader.stance = .claim
        let claimAction = leader.preferredAction
        
        var finalOpinions: [ModuleOpinion] = []
        finalOpinions.append(leader)
        
        // --- PHASE 3.5: CHIRON WEIGHTING ---
        let chironContext = ChironContext(
            atlasScore: atlas,
            orionScore: orion,
            aetherScore: aether,
            demeterScore: demeterScore,
            phoenixScore: phoenixOp.score,
            hermesScore: hermes,
            athenaScore: athena,
            symbol: symbol,
            orionTrendStrength: orionDetails?.components.trend,
            chopIndex: nil,
            volatilityHint: marketData?.currentRiskR,
            isHermesAvailable: hermes != nil
        )
        
        let chironResult = ChironRegimeEngine.shared.evaluate(context: chironContext)
        let activeWeights = chironResult.pulseWeights
        
        // --- PHASE 3.7: CHIMERA SIGNAL INTEGRATION ---
        // Chimera sinyalleri Konsey tartışmasına dahil edilir
        let chimeraResult = ChimeraSynergyEngine.shared.fuse(
            symbol: symbol,
            orion: orionDetails,
            hermesImpactScore: hermes,
            titanScore: atlas,
            currentPrice: marketData?.price ?? 0,
            marketRegime: chironResult.regime
        )
        
        // Chimera sinyali varsa, Konsey'e modül olarak ekle
        if let primarySignal = chimeraResult.signals.first {
            let chimeraScore: Double
            let chimeraAction: SignalAction
            
            switch primarySignal.type {
            case .deepValueBuy, .perfectStorm, .momentumBreakout:
                // Olumlu sinyal - AL yönünde
                chimeraScore = 70.0 + (primarySignal.severity * 20.0) // 70-90
                chimeraAction = .buy
            case .bullTrap, .fallingKnife:
                // Olumsuz sinyal - SAT yönünde veya bekle
                chimeraScore = 30.0 - (primarySignal.severity * 20.0) // 10-30
                chimeraAction = .sell
            case .sentimentDivergence:
                // Nötr sinyal
                chimeraScore = 50.0
                chimeraAction = .hold
            }
            
            let chimeraOp = ModuleOpinion(
                module: .athena, // Athena modülünü Chimera için kullan (AI-driven signals)
                stance: .abstain,
                preferredAction: chimeraAction,
                strength: primarySignal.severity * 100.0,
                score: chimeraScore,
                confidence: primarySignal.severity,
                evidence: ["Chimera: \(primarySignal.title) - \(primarySignal.description)"]
            )
            allOpinions.append(chimeraOp)
            dataSources["Chimera"] = "ChimeraSynergyEngine (Fused Signal)"
        }
        
        // --- PHASE 4: THE DEBATE ---
        var supportPower = 0.0
        var objectionPower = 0.0
        
        for var op in allOpinions {
            if op.module == leader.module { continue }
            
            var weight: Double = 1.0
            switch op.module {
            case .atlas: weight = activeWeights.atlas
            case .orion: weight = activeWeights.orion * techAuthority // Apply authority again (Double down if needed or just once? Just once in opinion creation or here? Let's apply here primarily for voting power)
            case .aether: weight = activeWeights.aether
            case .demeter: weight = activeWeights.demeter ?? 0.0
            case .phoenix: weight = (activeWeights.phoenix ?? 0.0) * techAuthority
            case .hermes: weight = activeWeights.hermes ?? 0.0
            case .athena: weight = activeWeights.athena ?? 0.0
            default: weight = 1.0
            }
            
            let effectiveStrength = op.strength * weight
            
            if op.preferredAction == claimAction {
                op.stance = .support
                supportPower += effectiveStrength
            } else if op.preferredAction == .hold || op.preferredAction == .wait {
                op.stance = .abstain
            } else {
                op.stance = .object
                objectionPower += effectiveStrength
            }
            finalOpinions.append(op)
        }
        
        allOpinions = finalOpinions
        
        // --- CONSENSUS CALCULATION ---
        let leaderScore = leader.score
        let directionMultiplier = (claimAction == .buy) ? 1.0 : -1.0
        
        let supportImpact = supportPower * config.supportImpactMultiplier * directionMultiplier
        let objectionImpact = objectionPower * config.objectionImpactMultiplier * -directionMultiplier
        
        var finalScore = leaderScore + supportImpact + objectionImpact
        finalScore = min(100.0, max(0.0, finalScore))
        
        // --- PHASE 5: TIERED RESOLUTION (Smart Thresholds) ---
        // Replacing static 70/30 with Dynamic Tiered Sizing
        
        var finalAction: SignalAction = .hold
        var rationale = ""
        var isApproved = false
        var targetSizeR = 0.0 // Dynamic sizing based on conviction
        
        let consensusScore = finalScore
        let supporters = finalOpinions.filter { $0.stance == .support }
        let objectors = finalOpinions.filter { $0.stance == .object }
        
        // Helper: Calculate Consensus Quality (0.0 - 1.0)
        // Quality = Data Health Ratio * Average Confidence of Participants
        let activeParticipants = finalOpinions.filter { $0.confidence > 0 }
        let avgConfidence = activeParticipants.isEmpty ? 0.0 : (activeParticipants.reduce(0.0) { $0 + $1.confidence } / Double(activeParticipants.count))
        let healthRatio = dataHealth.healthScore / 100.0
        let consensusQuality = healthRatio * avgConfidence
        
        // Helper to determine Tier with Quality Gate
        func determineTier(score: Double, isBuy: Bool, quality: Double) -> (tier: String, size: Double, approved: Bool) {
            let s = isBuy ? score : (100.0 - score) 
            
            // QUALITY GATES
            // If Quality < 0.5 (Poor), hard limit to Tier 3 or Reject.
            // If Quality < 0.8 (Decent), hard limit to Tier 2.
            
            if quality < 0.4 { return ("RED (Düşük Veri Kalitesi: \(Int(quality*100))%)", 0.0, false) }
            
            let maxTierAllowed = (quality >= 0.8) ? 1 : (quality >= 0.5 ? 2 : 3)
            
            if s >= 85 { 
                if maxTierAllowed <= 1 { return ("BANKO (Tier 1)", 1.0, true) }
                return ("BANKO -> STANDART (Veri Kalitesi Düşük)", 0.5, true) // Downgrade
            }
            if s >= 70 { 
                if maxTierAllowed <= 2 { return ("STANDART (Tier 2)", 0.5, true) }
                return ("STANDART -> SPEKÜLATİF (Veri Kalitesi Düşük)", 0.25, true) // Downgrade
            }
            if s >= 60 { return ("SPEKÜLATİF (Tier 3)", 0.25, true) }
            
            return ("YETERSİZ GÜÇ", 0.0, false)
        }
        
        if claimAction == .buy {
            let tier = determineTier(score: consensusScore, isBuy: true, quality: consensusQuality)
            
            // TECHNICAL VETO CHECK: The Gatekeeper Rule (v2 - Threshold Based)
            // Only STRONG technical objections (strength > 60) can veto
            // Weak objections reduce position size but don't block
            let strongTechObjectors = objectors.filter { 
                ($0.module == .orion || $0.module == .phoenix) && $0.strength > 60 
            }
            let technicalVeto = !strongTechObjectors.isEmpty
            
            // Weak technical objection = reduce confidence, not block
            let weakTechObjectors = objectors.filter {
                ($0.module == .orion || $0.module == .phoenix) && $0.strength <= 60 && $0.strength > 40
            }
            
            if tier.approved {
                if technicalVeto {
                    // STRONG VETO TRIGGERED
                    finalAction = .hold
                    isApproved = false
                    targetSizeR = 0.0
                    
                    // Identify who vetoed
                    let vetoers = strongTechObjectors.map { "\($0.module.rawValue) (\(Int($0.strength)))" }.joined(separator: " & ")
                    rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "REDDEDİLDİ (Teknik Veto: \(vetoers))")
                } else {
                    // APPROVED
                    finalAction = .buy
                    isApproved = true
                    targetSizeR = tier.size
                    
                    // Position size reduction based on objections
                    var sizeReductionReason = ""
                    
                    // Weak technical objections reduce size
                    if !weakTechObjectors.isEmpty {
                        targetSizeR = min(targetSizeR, 0.5)
                        let techNames = weakTechObjectors.map { $0.module.rawValue }.joined(separator: ", ")
                        sizeReductionReason = "Zayıf Teknik İtiraz: \(techNames)"
                    }
                    
                    // Non-technical objections also reduce size
                    if objectionPower >= 0.5 && targetSizeR > 0.5 {
                        targetSizeR = 0.5
                        if sizeReductionReason.isEmpty {
                            sizeReductionReason = "Genel İtiraz"
                        }
                    }
                    
                    if sizeReductionReason.isEmpty {
                        rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "ALIM ONAYLANDI (\(tier.tier))")
                    } else {
                        rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "ALIM ONAYLANDI (\(tier.tier)) - Risk Düşürüldü: \(sizeReductionReason)")
                    }
                }
            } else {
                finalAction = .hold
                rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "ALIM REDDEDİLDİ (\(tier.tier))")
            }
            
        } else if claimAction == .sell {
            // Sell logic uses 0-100 scale natively in `determineTier` by inverting
            let tier = determineTier(score: consensusScore, isBuy: false, quality: consensusQuality)
            
            if tier.approved {
                finalAction = .sell
                isApproved = true
                targetSizeR = tier.size
                 rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "SATIŞ ONAYLANDI (\(tier.tier))")
            } else {
                finalAction = .hold
                rationale = generateConsensusText(claimant: leader, supporters: supporters, objectors: objectors, result: "SATIŞ REDDEDİLDİ (Puan: \(Int(consensusScore)))")
            }
        } else {
            rationale = "Konsey Beklemede."
        }
        
        // Pass the RAW Consensus Score to the result
        
        // --- PHASE 4.5: EXECUTION PLAN (ATR-BAZLI STOP LOSS) ---
        let proposedAction = claimAction

        // ATR-bazlı stop loss hesabı (daha akıllı ve volatiliteye duyarlı)
        let price = marketData?.price ?? 0
        let atr = phoenixAdvice?.atr ?? (price * 0.02) // Fallback: fiyatın %2'si

        // Kullanıcı risk toleransını da dikkate al
        let userRiskFactor = riskTolerance > 0 ? (riskTolerance / config.defaultRiskTolerance) : 1.0

        let stopLossValue: Double?
        let takeProfitValue: Double?

        if price > 0 && proposedAction == .buy {
            let adjustedATR = atr * userRiskFactor
            stopLossValue = price - (adjustedATR * config.atrStopMultiplier)
            takeProfitValue = price + (adjustedATR * config.atrTargetMultiplier)
        } else if price > 0 {
            stopLossValue = nil // Satış için stop loss yok
            takeProfitValue = nil
        } else {
            stopLossValue = nil
            takeProfitValue = nil
        }

        let riskPlan = RiskPlan(
            stopLoss: stopLossValue,
            takeProfit: takeProfitValue,
            maxDrawdown: config.maxDrawdown
        )
        
        var phGuidance: PhoenixGuidance? = nil
        if let ph = phoenixAdvice, ph.status == .active {
            phGuidance = PhoenixGuidance(
                priceBand: "Regresyon Kanalı",
                recommendedEntry: ph.reasonShort, // Dynamic Reason from Phoenix Engine
                confidence: ph.confidence
            )
        }
        
        let execPlan = ExecutionPlan(
            targetAction: finalAction,
            targetSizeR: targetSizeR, // Use dynamic tiered size
            entryGuidance: phGuidance,
            riskPlan: riskPlan,
            validityWindow: config.validityWindow
        )
        
        let debate = AgoraDebate(
            claimant: leader,
            opinions: allOpinions,
            consensusParams: ConsensusParams(
                totalClaimStrength: leader.strength,
                totalObjectionStrength: objectionPower,
                netScore: consensusScore,
                deliberationText: rationale
            )
        )
        
        // --- PHASE 6: CHIRON LOGGING (The Memory) ---
        // Fire and forget logging
        let finalTier = isApproved ? (finalAction == .buy ? determineTier(score: consensusScore, isBuy: true, quality: consensusQuality).tier : determineTier(score: consensusScore, isBuy: false, quality: consensusQuality).tier) : "RED"
        

        
        // --- PHASE 7: CHIRON GATING (Risk Budget) ---
        // `price` already defined in Phase 4.5 above

        // Pass the PLAN to Chiron, not just "Buy"
        // TODO: Update Chiron to accept ExecutionPlan. For now, we adapt.
        
        let riskResult = ChironRegimeEngine.shared.auditRisk(
            action: finalAction,
            entryPrice: price,
            stopLoss: riskPlan.stopLoss,
            quantity: 1.0, // Quantity calculated later by Governor
            equity: marketData?.equity ?? 10000.0,
            currentPortfolioRiskR: marketData?.currentRiskR ?? 0.0,
            aetherScore: aetherOp.score // Dynamic Limit Input from Aether Module
        )
        
        if !riskResult.isApproved && finalAction == .buy {
            finalAction = .hold
            rationale += "\n\n⛔️ RİSK VETOSU: \(riskResult.reason)"
        }
        
        let finalDecision = AgoraDecision(
            action: finalAction,
            quantity: 0.0, // Placeholder
            executionPlan: execPlan,
            rationale: rationale,
            executionStrategy: "MARKET"
        )
        
        let trace = AgoraTrace(
            id: UUID(),
            timestamp: now,
            symbol: symbol,
            candidateSource: candidateSource, // Dynamic Source
            dataHealth: dataHealth,
            debate: debate,
            riskEvaluation: riskResult,
            finalDecision: finalDecision,
            dataSourceUsage: dataSources,
            unusedFactors: unusedFactorsList
        )
        
        // Calculate Info Quality (Phase 3) for UI
        let iqWeights: [String: Double] = [
            "Atlas": informationQuality(for: .atlas),
            "Orion": informationQuality(for: .orion),
            "Aether": informationQuality(for: .aether),
            "Hermes": informationQuality(for: .hermes),
            "Demeter": informationQuality(for: .demeter)
        ]

        // Legacy Support
        let legacyScore = isApproved ? consensusScore : 50.0 // True Score
        let legacy = buildLegacyResult(
            symbol: symbol,
            finalAction: finalAction,
            trace: trace,
            assetType: assetType,
            now: now,
            score: legacyScore,
            scores: (atlas, orion, aether, hermes, athena, demeterScore),
            phoenixAdvice: phoenixAdvice,
            moduleWeights: iqWeights // Pass Weights
        )
        
        // --- CHIRON LOGGING (Memory) ---
        Task {
            // Argus Ledger (The Scientific Truth)
            let refs = ArgusLedger.shared.getSnapshotRefs(symbol: symbol)
            let hashes = refs.values.map { $0 }
            
            ArgusLedger.shared.logDecision(
                decisionId: trace.id.uuidString,
                symbol: symbol,
                action: finalAction.rawValue,
                currentPrice: marketData?.price ?? 0,
                moduleScores: [
                    "orion": orion ?? 0,
                    "atlas": atlas ?? 0,
                    "aether": aether ?? 0,
                    "hermes": hermes ?? 0,
                    "phoenix": phoenixOp.score
                ],
                inputBlobHashes: hashes,
                configHash: "default_v1",
                weightsHash: "chiron_pulse_v1"
            )
            
            // Also Log Module Opinions
            for op in allOpinions {
                 // We need a helper for logModuleOpinion or just generic event.
                 // For V0, let's keep it simple or add if easy.
            }

            // Legacy Chiron Journal Removed (Phase 4 Refactor)
            
            // --- ALKINDUS OBSERVATION (Shadow Mode) ---
            await AlkindusCalibrationEngine.shared.observe(
                symbol: symbol,
                action: finalAction.rawValue,
                moduleScores: [
                    "orion": orion ?? 0,
                    "atlas": atlas ?? 0,
                    "aether": aether ?? 0,
                    "hermes": hermes ?? 0,
                    "phoenix": phoenixOp.score
                ],
                regime: chironResult.regime.rawValue,
                currentPrice: marketData?.price ?? 0
            )
        }
        
        return (trace, legacy)
    }
    
    // --- SPECIAL HANDLING: NO DATA ---
    private func makeAbstainDecision(symbol: String, reason: String, health: DataHealthSnapshot, now: Date, opinions: [ModuleOpinion] = [], source: CandidateSource = .watchlist) -> (AgoraTrace, ArgusDecisionResult) {
        
        let decision = AgoraDecision(action: .hold, quantity: 0, executionPlan: nil, rationale: reason, executionStrategy: "NONE")
        
        // Empty debate
        let debate = AgoraDebate(claimant: nil, opinions: opinions, consensusParams: ConsensusParams(totalClaimStrength: 0, totalObjectionStrength: 0, netScore: 0, deliberationText: reason))
        
        // Bypass Risk (No trade)
        let risk = RiskGateResult(isApproved: false, riskBudgetR: 0, deltaR: 0, maxR: 0, reason: "İşlem Yok")
        
        let trace = AgoraTrace(
            id: UUID(),
            timestamp: now,
            symbol: symbol,
            candidateSource: source, // Dynamic
            dataHealth: health,
            debate: debate,
            riskEvaluation: risk,
            finalDecision: decision,
            dataSourceUsage: [:],
            unusedFactors: ["Veri Yetersiz"]
        )
        
        // Legacy with C / Hold
        let legacy = buildLegacyResult(
            symbol: symbol,
            finalAction: .hold,
            trace: trace,
            assetType: .stock,
            now: now,
            score: 0.0,
            scores: (nil, nil, nil, nil, nil, nil),
            moduleWeights: nil // No data
        )
        
        return (trace, legacy)
    }
    
    // --- AGORA OPINION BUILDER ---
    // --- AGORA OPINION BUILDER ---
    // --- AGORA OPINION BUILDER ---
    
    /// Information Quality Weights (NEW)
    /// Different modules have different reliability levels for decision making
    /// Based on: signal-to-noise ratio, time horizon stability, historical accuracy
    private func informationQuality(for module: EngineTag) -> Double {
        switch module {
        case .atlas:   return 1.0   // Fundamental data is most reliable (slow-changing)
        case .aether:  return 0.95  // Macro data is stable and well-sourced
        case .orion:   return 0.85  // Technical is reliable but noisier
        case .phoenix: return 0.75  // Reversion signals have lower success rate
        case .hermes:  return 0.50  // News is very noisy, highest false positive rate
        case .cronos:  return 0.60  // Timing is speculative
        case .athena:  return 0.90  // Factor model is well-researched
        case .demeter: return 0.80  // Sector analysis moderately reliable
        default:       return 0.70
        }
    }
    
    private func opinion(from module: EngineTag, score: Double?, role: String, authority: Double = 1.0) -> ModuleOpinion {
        guard let s = score else {
             return ModuleOpinion(module: module, stance: .abstain, preferredAction: .hold, strength: 0, score: 0, confidence: 0, evidence: ["Veri Yok"])
        }
        
        // 1. Fuzzy Logic for Preferred Action
        // Use KERNEL Thresholds (Recalculated locally or passed? Let's recalculate for simplicity, engine is stateless mostly)
        // Actually, to respect the exact effectiveBuyThreshold calculated in makeDecision, we should ideally pass it.
        // But to keep signature clean, we re-fetch user defaults or use standard fuzzy.
        // Let's use the 'authority' param to adjust STRENGTH, but 'aggressiveness' is global.
        
        let aggressiveness = UserDefaults.standard.double(forKey: "kernel_aggressiveness")
        let agg = aggressiveness > 0 ? aggressiveness : 0.55
        let config = ArgusConfig.defaults
        
        // Lower threshold = More Aggressive
        let buyLimit = config.defaultBuyThreshold - (agg - config.defaultAggressiveness) * config.aggressivenessMultiplier
        let sellLimit = config.defaultSellThreshold + (agg - config.defaultAggressiveness) * config.aggressivenessMultiplier
        
        var action: SignalAction = .hold
        var evidenceTrace = ""
        
        if s >= buyLimit {
            action = .buy
            evidenceTrace = s >= (buyLimit + 20) ? "GÜÇLÜ ALIM" : "ALIM"
        } else if s <= sellLimit {
            action = .sell
            evidenceTrace = s <= (sellLimit - 20) ? "GÜÇLÜ SATIŞ" : "SATIŞ"
        } else {
            action = .hold
            evidenceTrace = "NÖTR"
        }
        
        // 2. Set Strength (Conviction)
        // 50 is neutral.
        let rawStrength = abs(s - 50.0) / 50.0
        let qualityMultiplier = informationQuality(for: module)
        
        // AUTHORITY multiplier applied here
        let adjustedStrength = rawStrength * qualityMultiplier * authority
        
        return ModuleOpinion(
            module: module,
            stance: .abstain, // Calculated in Phase 4
            preferredAction: action,
            strength: adjustedStrength,
            score: s, // Store Raw Score
            confidence: qualityMultiplier, // Now reflects information quality
            evidence: ["\(module.rawValue) skoru: \(Int(s)) (\(evidenceTrace)) [Q:\(Int(qualityMultiplier*100))%]"]
        )
    }
    
    // --- DELIBERATION TEXT ---
    private func generateConsensusText(claimant: ModuleOpinion, supporters: [ModuleOpinion], objectors: [ModuleOpinion], result: String) -> String {
        var text = ""
        
        // 1. Result Header
        // Clean up result string if necessary or keep standard header
        if result.contains("REDDEDİLDİ") {
            text += "⛔️ \(result)\n\n"
        } else {
            text += "✅ \(result)\n\n"
        }
        
        // 2. Claimant (The 'Why')
        switch claimant.module {
        case .orion:
            text += "Orion teknik göstergelerde belirgin bir yükseliş trendi tespit etti. "
        case .atlas:
            text += "Atlas, şirketin temel verilerini ve değerlemesini son derece cazip buldu. "
        case .phoenix:
            text += "Phoenix yapay zeka senaryoları yukarı yönlü bir hareket öngörüyor. "
        case .hermes:
            text += "Hermes, hisse ile ilgili kritik derecede olumlu bir haber akışı yakaladı. "
        default:
            text += "\(claimant.module.rawValue) alım fırsatı görüyor. "
        }
        
        // 3. Supporters
        if !supporters.isEmpty {
            let names = supporters.map { $0.module.rawValue }.joined(separator: ", ")
            text += "Bu analiz \(names) tarafından da teyit edildi."
        }
        
        // 4. Objectors (Risks)
        if !objectors.isEmpty {
            text += "\n\n⚠️ Risk Notları: "
            for obj in objectors {
                let reason = obj.evidence.first ?? "Belirsiz risk"
                text += "\(obj.module.rawValue) bu karara şerh düştü: \(reason). "
            }
        }
        
        return text
    }
    
    private func buildLegacyResult(
        symbol: String,
        finalAction: SignalAction,
        trace: AgoraTrace,
        assetType: SafeAssetType?,
        now: Date,
        score: Double,
        scores: (atlas: Double?, orion: Double?, aether: Double?, hermes: Double?, athena: Double?, demeterScore: Double?),
        phoenixAdvice: PhoenixAdvice? = nil,
        moduleWeights: [String: Double]? = nil
    ) -> ArgusDecisionResult {
         
         // Build Standard Outputs for UI Grid
         var stdOutputs: [String: StandardModuleOutput] = [:]
         
         if let s = scores.atlas { stdOutputs["Atlas"] = StandardModuleOutput(direction: s > 50 ? "AL" : "SAT", strength: s, confidence: 100, timeframe: "1D", reasons: []) }
         if let s = scores.orion { stdOutputs["Orion"] = StandardModuleOutput(direction: s > 50 ? "AL" : "SAT", strength: s, confidence: 100, timeframe: "1D", reasons: []) }
         if let s = scores.hermes { stdOutputs["Hermes"] = StandardModuleOutput(direction: s > 50 ? "AL" : "SAT", strength: s, confidence: 100, timeframe: "LIVE", reasons: []) }
         if let s = scores.aether { stdOutputs["Aether"] = StandardModuleOutput(direction: s > 50 ? "AL" : "SAT", strength: s, confidence: 100, timeframe: "MACRO", reasons: []) }
         if let s = scores.demeterScore { stdOutputs["Demeter"] = StandardModuleOutput(direction: s > 50 ? "AL" : "SAT", strength: s, confidence: 100, timeframe: "SECTOR", reasons: []) }
         
         return ArgusDecisionResult(
            id: UUID(),
            symbol: symbol,
            assetType: assetType ?? .stock,
            atlasScore: scores.atlas ?? 0,
            aetherScore: scores.aether ?? 0,
            orionScore: scores.orion ?? 0,
            athenaScore: scores.athena ?? 0,
            hermesScore: scores.hermes ?? 0,
            demeterScore: scores.demeterScore ?? 0,
            orionDetails: nil,
            chironResult: nil,
            phoenixAdvice: phoenixAdvice,
            bistDetails: nil,
            standardizedOutputs: stdOutputs,
            moduleWeights: moduleWeights,
            finalScoreCore: score,
            // FIX: Pulse skoru = Orion ağırlıklı (technical-focused)
            // Pulse: %60 Orion, %20 Cronos, %20 Aether
            finalScorePulse: (scores.orion ?? 0) * 0.60 + (scores.demeterScore ?? 50) * 0.20 + (scores.aether ?? 50) * 0.20,
            letterGradeCore: finalAction == .buy ? "A" : (score > 40 ? "C" : "F"),
            letterGradePulse: "-",
            finalActionCore: finalAction,
            finalActionPulse: finalAction,
            isNewsBacked: (scores.hermes ?? 0) > 50,
            isRegimeGood: scores.aether != nil ? scores.aether! >= 40.0 : false,
            isFundamentallyStrong: scores.atlas != nil ? scores.atlas! >= 50.0 : false,
            isDemeterStrong: scores.demeterScore != nil ? scores.demeterScore! >= 50.0 : false,
            generatedAt: now
         )
    }
    
    // MARK: - Phase 2: Churn Logic
    // MARK: - Phase 5: Advanced Churn Guard (Compliance)
    private func checkChurnGuard(
        proposed: SignalAction,
        score: Double,
        context: ChurnContext, // New Context Object
        config: ArgusConfig
    ) -> ChurnGuardResult {
        
        let now = Date()
        
        // 1. Manual Override Check (The "Human Veto")
        // Rule: If user manually SOLD recently, don't Auto BUY immediately.
        if proposed == .buy {
            if let lastManual = context.lastManualActionTime,
               context.lastManualActionType == .sell {
                let age = now.timeIntervalSince(lastManual)
                if age < config.manualOverrideDuration {
                    // EXCEPTION: Only override if score is VERY high (Cobalt Blue Confidence)
                    if score < config.tier1Threshold {
                        return ChurnGuardResult(
                            isBlocked: true,
                            ruleTriggered: "\(ChurnReason.manualOverride.rawValue) (\(Int(config.manualOverrideDuration - age))s left)",
                            lockoutRemaining: config.manualOverrideDuration - age,
                            originalDecision: proposed
                        )
                    }
                }
            }
        }
        
        // 2. Cooldown & MinHold (Time-based preventions)
        if let lastTrade = context.lastTradeTime {
            let age = now.timeIntervalSince(lastTrade)
            let isPulse = context.mode == .pulse
            
            // A. Cooldown (Prevent Flip-Flop)
            let cooldown = isPulse ? config.cooldownPulse : config.cooldownCorse
            if age < cooldown {
                // Determine if it's a flip (Buy->Sell or Sell->Buy) or just noise
                // Argus philosophy: Silence during cooldown.
                return ChurnGuardResult(
                    isBlocked: true,
                    ruleTriggered: isPulse ? ChurnReason.cooldownPulse.rawValue : ChurnReason.cooldownCorse.rawValue,
                    lockoutRemaining: cooldown - age,
                    originalDecision: proposed
                )
            }
            
            // B. MinHold (CORSE Only - Prevent weak hands)
            if !isPulse && context.isInPosition && proposed == .sell {
                if age < config.minHoldCorse {
                    // Exception: Hard Stop Loss (handled by AutoPilot outside, but engine should respect Risk score?)
                    // If Risk Score is terrible (<10), allow panic sell.
                    // But here we rely on standard config.
                    return ChurnGuardResult(
                        isBlocked: true,
                        ruleTriggered: ChurnReason.minHold.rawValue,
                        lockoutRemaining: config.minHoldCorse - age,
                        originalDecision: proposed
                    )
                }
            }
        }
        
        // 3. Hysteresis (Price/Score Memory)
        // Rule: Re-entering a position you just sold requires higher conviction.
        if !context.isInPosition && proposed == .buy {
            if let lastAction = context.lastAction, lastAction == .sell {
                if let lastTrade = context.lastTradeTime, now.timeIntervalSince(lastTrade) < config.reEntryWindow {
                    if score < config.reEntryThreshold {
                        return ChurnGuardResult(
                            isBlocked: true,
                            ruleTriggered: "\(ChurnReason.hysteresis.rawValue) (Score \(Int(score)) < \(Int(config.reEntryThreshold)))",
                            lockoutRemaining: 0,
                            originalDecision: proposed
                        )
                    }
                }
            }
        }
        
        // 4. Idempotency (Duplicate Intent)
        // Check if we already issued this exact decision hash recently?
        // This is typically handled by the ViewModel/Execution layer, but we can flag it here if we had history.
        // Skipping for Engine purity (Engine is stateless-ish).
        
        return ChurnGuardResult(isBlocked: false, ruleTriggered: nil, lockoutRemaining: 0, originalDecision: proposed)
    }
    
    // Helper Context Struct for Churn
    struct ChurnContext {
        let isInPosition: Bool
        let lastTradeTime: Date?
        let lastAction: SignalAction?
        let lastManualActionTime: Date?
        let lastManualActionType: SignalAction?
        let mode: ArgusTimeframeMode
    }

    


    // MARK: - Intraday Analysis (Sniper Mode)
    
    /// Calculates a simplified Argus Score based ONLY on provided candles (e.g. 15m).
    /// Used for "Live Re-Scoring" to detect intraday momentum loss.
    func calculateLocalScore(candles: [Candle]) -> Double {
        // Intraday is 100% Technical (Orion)
        let orionScore = OrionAnalysisService.shared.calculateOrionScore(symbol: "LOCAL", candles: candles, spyCandles: nil)?.score ?? 50.0
        return orionScore
    }
}

// Helper extension
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
