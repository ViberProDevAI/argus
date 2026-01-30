import Foundation

/// Agora: The Deliberation Engine
/// Multi-agent deliberation system for definitive trading decisions.
actor AgoraEngine {
    static let shared = AgoraEngine()
    
    private init() {}
    
    // MARK: - State (In-Memory for now, Persistence via ViewModel)
    // Constraint 1 fulfilled via external storage or idempotent calc.
    // Here we focus on the calculation logic.
    
    // MARK: - Main Deliberation Loop
    func deliberate(
        symbol: String,
        signals: [AgoraSignal],
        portfolioContext: AgoraPortfolioContext, // New context struct
        marketData: AgoraMarketData, // Price, Volatility
        config: ArgusConfig
    ) -> AgoraDecisionResult {
        
        let now = Date()
        
        // 1. Calculate Global Confidence (Health)
        // confidence_global = clamp(1 - freshness - missing - outlier)
        let freshnessPenalty = calculateFreshnessPenalty(signals: signals)
        // Assume minimal penalties for missing/outliers for now unless provided
        let globalConfidence = max(0.0, 1.0 - freshnessPenalty)
        
        if globalConfidence < 0.5 {
            // Data is too stale or broken. AUTOMATIC HOLD.
            return makeDecision(.hold, symbol: symbol, reason: "Veri Güveni Düşük (%: \(Int(globalConfidence * 100)))", confidence: globalConfidence, context: portfolioContext)
        }
        
        // 2. Build Claims & Challenges
        var claims: [AgoraClaim] = []
        var challenges: [AgoraChallenge] = []
        
        // Convert Signals to Claims
        for signal in signals {
            // Filter inactive signals
            if signal.action == .noTrade { continue }
            
            // Calculate Raw Impact
            // direction implies +1/-1.
            let impactKey = Double(signal.direction) * signal.strength * signal.confidence
            claims.append(AgoraClaim(sourceSignal: signal, impactScore: impactKey))
        }
        
        // 3. Generate System Challenges (Vetoes & Counters)
        
        // A. Chiron Veto (Risk)
        // If Risk-Off regime and trying to Buy?
        if let aether = signals.first(where: { $0.module == .aether }) {
            // If Aether is bearish (-1) and logic tries to Buy
            // This is actually implemented as a Veto Check later, or a Challenge limiting impact.
            // Let's use Challenge system for "Argument Reduction" and Veto for "Hard Stop".
            if aether.direction < 0 {
                challenges.append(AgoraChallenge(fromModule: .aether, againstModule: .orion, reason: "Risk-Off Rejimi Baskısı", severity: 0.5))
                challenges.append(AgoraChallenge(fromModule: .aether, againstModule: .phoenix, reason: "Risk-Off Rejimi Baskısı", severity: 0.3)) // Phoenix less affected (contrarian)
            }
        }
        
        // 4. Calculate Net Edge (The Debate)
        var netEdge = 0.0
        var effectiveClaims: [AgoraClaim] = []
        
        for claim in claims {
            var effectiveImpact = claim.impactScore
            
            // Find challenges against this module
            let relevantChallenges = challenges.filter { $0.againstModule == claim.sourceSignal.module }
            let maxSeverity = relevantChallenges.map { $0.severity }.max() ?? 0.0
            
            // Reduce impact
            effectiveImpact *= (1.0 - maxSeverity)
            
            netEdge += effectiveImpact
            effectiveClaims.append(AgoraClaim(sourceSignal: claim.sourceSignal, impactScore: effectiveImpact))
        }
        
        // Normalize Net Edge to -1...1 range (approx)
        // Assume max theoretical edge is around 3.0 (3 strong modules)
        let normalizedEdge = min(max(netEdge / 3.0, -1.0), 1.0)
        
        // 5. Determine Proposed Action
        var proposedAction: AgoraAction = .hold
        let edgeThreshold = 0.25 // Min conviction required
        
        if normalizedEdge > edgeThreshold { proposedAction = .buy }
        else if normalizedEdge < -edgeThreshold { proposedAction = .sell }
        
        // 6. Hard Vetoes (The Law)
        // Chiron checks constraints
        if let veto = checkChironVeto(symbol: symbol, proposed: proposedAction, context: portfolioContext) {
            return makeDecision(.noTrade, symbol: symbol, reason: "Chiron Veto: \(veto)", confidence: globalConfidence, context: portfolioContext, veto: veto)
        }
        
        // 7. Churn Prevention (The Gate)
        // Idempotency, Cooldown, Hysteresis checks
        if let churnReason = checkChurn(symbol: symbol, proposed: proposedAction, context: portfolioContext, config: config, netEdge: normalizedEdge) {
             // Exception: Phoenix Override check (Phase 3.3)
             // Override only possible if Phoenix is strongly bullish and Churn is NOT Cooldown/Hard Veto
             let canOverride = checkPhoenixOverride(signals, churnReason)
             if !canOverride {
                 return makeDecision(.hold, symbol: symbol, reason: churnReason, confidence: globalConfidence, context: portfolioContext)
             } else {
                 // Proceed (Override Churn)
             }
        }
        
        // 8. Size Calculation
        // Only if Action is BUY
        var sizePenalty = 0.0
        if proposedAction == .buy {
             // Calculate Penalty based on Risk/Vol
             // High Volatility -> High Penalty
             let volConfig = 0.02 // Daily Vol Proxy
             let vol = marketData.volatilityRatio
             if vol > volConfig {
                 sizePenalty = min((vol - volConfig) * 10, 0.8) // Cap penalty at 80%
             }
        }
        
        return AgoraDecisionResult(
            id: UUID(),
            symbol: symbol,
            timestamp: now,
            finalAction: proposedAction,
            netEdge: normalizedEdge,
            confidenceGlobal: globalConfidence,
            sizePenalty: sizePenalty,
            winningClaims: effectiveClaims,
            activeChallenges: challenges,
            vetoTriggered: nil,
            phoenixLevels: extractPhoenixLevels(signals),
            cooldownState: .ready
        )
    }
    
    // MARK: - Sub-Systems
    
    private func calculateFreshnessPenalty(signals: [AgoraSignal]) -> Double {
        // Average age of critical signals
        let ages = signals.map { max(0, Date().timeIntervalSince($0.timestamp)) }
        guard !ages.isEmpty else { return 1.0 }
        let avgAge = ages.reduce(0, +) / Double(ages.count)
        
        // 5 mins = 0 penalty. 1 hour = 0.5. 24 hours = 1.0
        return min(avgAge / 3600.0, 1.0) * 0.5
    }
    
    private func checkChironVeto(symbol: String, proposed: AgoraAction, context: AgoraPortfolioContext) -> String? {
        // 1. Max Daily Trades
        if context.dailyTradeCount >= 25 { return "Günlük İşlem Limiti (25)" }
        // 2. Risk Off + Buy
        if proposed == .buy && context.isRiskOff { return "Macro Risk-Off (Alım Yasak)" }
        
        return nil
    }
    
    private func checkChurn(symbol: String, proposed: AgoraAction, context: AgoraPortfolioContext, config: ArgusConfig, netEdge: Double) -> String? {
        // Cooldown
        if let lastTime = context.lastInteractionTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < 300 { // 5 min global cooldown
                 return "Cooldown (Kalan: \(Int(300 - elapsed))s)"
            }
        }
        
        // Hysteresis for Re-Entry
        if proposed == .buy && context.lastAction == .sell {
            // Need significantly higher edge
            if netEdge < 0.6 { // 0.6 is very strong
                return "Histerezis (Yetersiz Güç: \(String(format:"%.2f", netEdge)))"
            }
        }
        
        return nil
    }
    
    private func checkPhoenixOverride(_ signals: [AgoraSignal], _ churnReason: String) -> Bool {
        // Only override "Hysteresis" or soft constraints. Never Cooldown.
        if churnReason.contains("Cooldown") { return false }
        
        guard let phx = signals.first(where: { $0.module == .phoenix }) else { return false }
        return phx.confidence > 0.8 && phx.action == .buy
    }
    
    private func extractPhoenixLevels(_ signals: [AgoraSignal]) -> PhoenixLevelPack? {
        // Search Phoenix signal metadata or evidence for levels
        // Simplifying for now - assumed passed via specialized signal or evidence
        return nil
    }
    
    private func makeDecision(_ action: AgoraAction, symbol: String, reason: String, confidence: Double, context: AgoraPortfolioContext, veto: String? = nil) -> AgoraDecisionResult {
        return AgoraDecisionResult(
            id: UUID(),
            symbol: symbol,
            timestamp: Date(),
            finalAction: action,
            netEdge: 0.0,
            confidenceGlobal: confidence,
            sizePenalty: 0.0,
            winningClaims: [],
            activeChallenges: [],
            vetoTriggered: veto,
            phoenixLevels: nil,
            cooldownState: .active
        )
    }
}

// Helper Contexts
struct AgoraPortfolioContext: Sendable {
    let dailyTradeCount: Int
    let isRiskOff: Bool
    let lastInteractionTime: Date?
    let lastAction: AgoraAction?
    let currentPositionRaw: Double // Quantity
}

struct AgoraMarketData: Sendable {
    let price: Double
    let volatilityRatio: Double // ATR/Price
}
