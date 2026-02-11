import Foundation

class AutoPilotExecutionManager {
    static let shared = AutoPilotExecutionManager()
    
    private let corse = ArgusCorseEngine()
    private let pulse = ArgusPulseEngine()
    private let shield = ArgusShieldEngine()
    private let logger = AutoPilotLogger.shared
    
    private init() {}
    
    // Main Entry Point
    func runCycle(
        symbols: [String],
        getContext: (String) -> AutoPilotContext?,
        executor: TradeExecutor
    ) async {
        
        // Ensure Hedge Symbol (SQQQ) is considered for Shield
        var analysisList = symbols
        if !analysisList.contains("SQQQ") {
             analysisList.append("SQQQ")
        }
        
        for symbol in analysisList {
            guard let context = getContext(symbol) else { continue }
            
            // 1. Get Proposals in parallel
            async let pCorse = corse.propose(for: symbol, context: context)
            async let pPulse = pulse.propose(for: symbol, context: context)
            async let pShield = shield.propose(for: symbol, context: context)
            
            let proposals = await [pCorse, pPulse, pShield]
            
            // 2. Resolve Conflicts & Filter
            let finalAction = resolveConflicts(proposals: proposals, context: context)
            
            // 3. Execute
            if let action = finalAction {
                execute(proposal: action, context: context, executor: executor)
            }
        }
    }
    
    private func resolveConflicts(proposals: [AutoPilotProposal], context: AutoPilotContext) -> AutoPilotProposal? {
        // Filter out Skips
        let active = proposals.filter { $0.action != .skip && $0.action != .hold }
        
        if active.isEmpty { return nil }
        
        // Priority: SHIELD > CORSE > PULSE
        if let shieldP = active.first(where: { $0.engine == .shield }) {
            // Shield is active. It overrides everything on its symbol.
            // Since Shield only trades SQQQ (or hedge), it doesn't conflict with AAPL trades directly,
            // BUT implies a macro state.
            // If Shield is buying SQQQ, it doesn't necessarily block Corse buying AAPL (pair trading),
            // BUT traditionally Shield activates in Risk Off, where Corse disables itself anyway.
            return shieldP
        }
        
        // Single Proposal?
        if active.count == 1 {
            // Check Rule 3: Do not close other's position if not owner
            // (Engine logic already handles specific ownership check usually, but double check)
            let p = active.first!
            if p.action == .sell {
                if let trade = context.openTrade, trade.engine != nil, trade.engine != p.engine {
                    // Corse trying to sell Pulse's trade or vice versa (shouldn't happen with Engine checks, but safety)
                    logger.log(createDecision(from: p, context: context, reasonOverride: "Blocked: Cannot sell other engine's trade"))
                    return nil
                }
            }
            // Check Rule 1: Only 1 active trade per symbol
            if p.action == .buy {
                if context.openTrade != nil {
                    // Already have a trade. Do not buy more (Simple Rule)
                    // Unless it's "adding" to position? For now, rule is "Single Position".
                    return nil
                }
            }
            return p
        }
        
        // Conflict! (e.g. Corse Buy vs Pulse Sell, or Corse Buy vs Pulse Buy)
        let corseP = active.first(where: { $0.engine == .corse })
        let pulseP = active.first(where: { $0.engine == .pulse })
        
        if let c = corseP, let p = pulseP {
            // Priority Logic
            // If Argus Final Score is High -> Corse Priority
            // If News is High -> Pulse Priority?
            // "System Preference": Corse is safer.
            
            if c.action == p.action {
                // Both want same thing. Merge?
                // Just pick Corse for stability.
                return c
            } else {
                // Opposing views.
                // Corse Buy, Pulse Sell?
                // Cancel out -> Skip.
                return nil
            }
        }
        
        return active.first
    }
    
    private func execute(proposal: AutoPilotProposal, context: AutoPilotContext, executor: TradeExecutor) {
        // Calculate Quantity if needed
        var qty = proposal.quantity ?? 0.0
        if qty <= 0.000001, let exposure = proposal.targetExposurePercent {
            let targetVal = context.equity * exposure
            qty = targetVal / context.price
        }
        
        // Cap Quantity
        let maxQty = (context.equity * 0.10) / context.price // Max 10%
        qty = min(qty, maxQty)
        
        if qty <= 0 { return }
        
        if proposal.action == .buy {
             executor.executeBuy(symbol: proposal.symbol, quantity: qty, price: context.price, engine: proposal.engine)
        } else if proposal.action == .sell {
             executor.executeSell(symbol: proposal.symbol, quantity: qty, price: context.price, engine: proposal.engine, reason: proposal.rationale ?? "AutoPilot Exit")
        }
        
        // Log
        let decision = createDecision(from: proposal, context: context, quantity: qty)
        logger.log(decision)
    }
    
    private func createDecision(from p: AutoPilotProposal, context: AutoPilotContext, quantity: Double = 0.0, reasonOverride: String? = nil) -> AutoPilotDecision {
        return AutoPilotDecision(
            id: UUID(),
            timestamp: Date(),
            mode: "live",
            strategy: p.engine.rawValue,
            symbol: p.symbol,
            action: p.action.rawValue,
            quantity: quantity,
            positionValueUSD: quantity * context.price,
            price: context.price,
            takeProfit: nil,
            stopLoss: nil,
            riskMultiple: nil,
            atlasScore: p.scores.atlas,
            orionScore: p.scores.orion,
            aetherScore: p.scores.aether,
            hermesScore: p.scores.hermes,
            demeterScore: nil,
            argusFinalScore: context.argusFinalScore,
            dataQualityScore: p.dataQualityScore,
            fundamentalsPartial: false,
            technicalPartial: false,
            macroPartial: false,
            cryptoFallbackUsed: false,
            dataSourceNotes: nil,
            provider: "ExecutionManager", // Fallback for signals aggregated here
            portfolioValueBefore: context.equity,
            portfolioValueAfter: nil,
            rationale: reasonOverride ?? p.rationale
        )
    }
}
