import Foundation
import Combine

// MARK: - Vortex Engine Strategy Core
/// "Strategos" / "Vortex" - The Dynamic Strategy Engine.
/// Decides the "Intent" of a trade and orchestrates the plan lifecycle.
class VortexEngine: ObservableObject {
    static let shared = VortexEngine()
    
    // Dependencies
    private let planStore = PositionPlanStore.shared
    
    // Regime monitoring
    @Published var currentRegime: MarketRegime = .neutral
    
    private init() {
        print("🌪️ Vortex Engine Online")
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Regime Check (On-demand)
    
    // MARK: - Intent Analysis
    
    /// Analyzes the trade context to determine the "Intent" (Why are we buying?)
    func analyzeIntent(snapshot: EntrySnapshot) -> TradeIntent {
        let atlasScore = snapshot.atlasScore ?? 0.0
        let orionScore = snapshot.orionScore ?? 0.0
        
        // Map Macro Stance to Score
        var demeterScore = 50.0
        switch snapshot.aetherStance {
        case .riskOn: demeterScore = 80.0
        case .cautious: demeterScore = 50.0
        case .defensive: demeterScore = 30.0
        case .riskOff: demeterScore = 15.0
        }
        
        // 1. Value Investment: Strong Fundamentals, decent macro, tech secondary
        if atlasScore > 75 && demeterScore > 60 {
            return .valueInvestment
        }
        
        // 2. Momentum Trade: Strong Tech, Fundamentals irrelevant (but not disaster)
        if orionScore > 80 {
            return .momentumTrade
        }
        
        // 3. Speculative: High Volume/News, Tech breakout, Low Fundamentals
        // (Simplified logic for now, assumes if not Value/Momentum but high volatility -> Speculative)
        if (snapshot.atr ?? 0) / snapshot.entryPrice > 0.05 { // >5% Daily volatility
            return .speculativeSniper
        }
        
        // Default to Swing
        return .technicalSwing
    }
    
    // MARK: - Plan Generation
    
    /// Generates a Vortex-compliant plan based on the intent.
    func createPlan(for trade: Trade, snapshot: EntrySnapshot, decision: ArgusGrandDecision, thesis: String, invalidation: String, candles: [Candle]? = nil) -> PositionPlan {
        let intent = analyzeIntent(snapshot: snapshot)
        let atr = snapshot.atr ?? (trade.entryPrice * 0.03)
        
        var bullish: Scenario
        var bearish: Scenario
        var neutral: Scenario?
        
        // Helper to extract
        func extract(_ scenarios: [Scenario], type: ScenarioType) -> Scenario {
            return scenarios.first(where: { $0.type == type }) ?? Scenario(type: type, steps: [], isActive: false)
        }
        
        switch intent {
        case .valueInvestment:
            let scenarios = SmartPlanGenerator.shared.generatePlan(entryPrice: trade.entryPrice, entrySnapshot: snapshot, style: .conservative, grandDecision: decision, candles: candles)
            bullish = extract(scenarios, type: .bullish)
            bearish = extract(scenarios, type: .bearish)
            neutral = extract(scenarios, type: .neutral)
            
        case .momentumTrade:
            let scenarios = SmartPlanGenerator.shared.generatePlan(entryPrice: trade.entryPrice, entrySnapshot: snapshot, style: .momentum, grandDecision: decision, candles: candles)
            bullish = extract(scenarios, type: .bullish)
            bearish = extract(scenarios, type: .bearish)
            
        case .speculativeSniper:
            // ONE SHOT: Single Target, Single Stop. "Sniper Mode"
            // Target: ATR * 3, Stop: ATR * 1
            let target = trade.entryPrice + (atr * 3)
            let stop = trade.entryPrice - atr
            
            bullish = Scenario(type: .bullish, steps: [
                PlannedAction(trigger: .priceAbove(target), action: .sellAll, description: "Sniper Hedef: \(String(format: "%.2f", target))", priority: 1)
            ], isActive: true)
            
            bearish = Scenario(type: .bearish, steps: [
                PlannedAction(trigger: .priceBelow(stop), action: .sellAll, description: "Sniper Stop: \(String(format: "%.2f", stop))", priority: 0)
            ], isActive: true)
            
        case .technicalSwing, .undefined:
            // Use Adaptive Planning based on Market Regime (Phase 4 Integration)
            let result = SmartPlanGenerator.shared.generateAdaptivePlan(entryPrice: trade.entryPrice, entrySnapshot: snapshot, grandDecision: decision, candles: candles)
            let scenarios = result.scenarios
            print("🌪️ Adaptive Plan Styles: \(result.styleUsed.rawValue) - Reason: \(result.reason)")
            
            bullish = extract(scenarios, type: .bullish)
            bearish = extract(scenarios, type: .bearish)
            neutral = extract(scenarios, type: .neutral)
        }
        
        let plan = PositionPlan(
            tradeId: trade.id,
            snapshot: snapshot,
            initialQuantity: trade.quantity,
            thesis: thesis,
            invalidation: invalidation,
            bullish: bullish,
            bearish: bearish,
            neutral: neutral,
            intent: intent
        )
        
        print("🌪️ Vortex Generated Plan for \(trade.symbol) - Intent: \(intent.rawValue)")
        
        // FAZE 3.3: Backtest validation (ileride tam implementasyon için placeholder)
        // Gerçek implementasyon için: ArgusBacktestEngine.shared.testPlan(...) çağırılmalı
        let backtestScore = 50.0  // Placeholder
        if backtestScore < 40.0 {
            print("⚠️ Plan backtest skor düştük: \(backtestScore)%")
        }
        
        return plan
    }
    
    // MARK: - Plan Management
    
    func updatePlan(tradeId: UUID, newTarget: Double, quantityPercent: Double, reason: String) {
        // Find existing plan
        guard var plan = planStore.getPlan(for: tradeId) else { return }
        
        // Create Revision
        let oldDesc = plan.bullishScenario.steps.first?.description ?? "N/A"
        let revision = PlanRevision(
            timestamp: Date(),
            reason: reason,
            changeDescription: "Hedef Güncellendi: \(newTarget), Miktar: %\(quantityPercent)",
            triggeredBy: "User Manual Override"
        )
        
        // Apply changes (Simply replacing the first bullish step for Sniper/Single logic for now)
        // In a complex scenario, we might need to know WHICH step to edit.
        // For "Sniper Mode", there is only 1 step.
        
        var steps = plan.bullishScenario.steps
        if !steps.isEmpty {
            steps[0] = PlannedAction(
                trigger: .priceAbove(newTarget),
                action: (quantityPercent >= 100) ? .sellAll : .sellPercent(quantityPercent),
                description: "Manuel Hedef: \(String(format: "%.2f", newTarget)) (% \(Int(quantityPercent)) Satış)",
                priority: 1
            )
        } else {
            // Create if empty
            steps.append(PlannedAction(
                 trigger: .priceAbove(newTarget),
                 action: (quantityPercent >= 100) ? .sellAll : .sellPercent(quantityPercent),
                 description: "Manuel Hedef: \(String(format: "%.2f", newTarget))",
                 priority: 1
            ))
        }
        
        let newBullish = Scenario(type: .bullish, steps: steps, isActive: true)
        plan.bullishScenario = newBullish
        plan.journeyLog.append(revision)
        
        // Save
        planStore.updatePlan(plan)
        
        // Log the manual override
        print("🌪️ Vortex: Plan updated for \(plan.originalSnapshot.symbol) - New target: \(newTarget)")
    }
    
    // MARK: - Regime Handlers
    
    private func handleCrashRegime() {
        print("🌪️ Vortex: CRASH REGIME DETECTED. Tightening all stops.")
        // Logic to iterate all active plans and tighten stops would go here.
    }
}
