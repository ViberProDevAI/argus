import Foundation

// MARK: - Smart Plan Generator
/// ATR ve teknik seviyelere göre dinamik plan oluşturur

class SmartPlanGenerator {
    static let shared = SmartPlanGenerator()
    
    private init() {}
    
    // MARK: - Plan Types
    
    enum PlanStyle: String, CaseIterable {
        case conservative = "Muhafazakâr"
        case balanced = "Dengeli"
        case aggressive = "Agresif"
        case momentum = "Momentum"
        case swingTrade = "Swing"
        
        var description: String {
            switch self {
            case .conservative: return "Düşük risk, erken kâr alma"
            case .balanced: return "Ortalama risk/getiri"
            case .aggressive: return "Yüksek risk, yüksek getiri"
            case .momentum: return "Trend takibi, trailing stop"
            case .swingTrade: return "Kısa vadeli, hızlı çıkış"
            }
        }
    }
    
    // MARK: - Generate Smart Plan
    
    func generatePlan(
        entryPrice: Double,
        entrySnapshot: EntrySnapshot,
        style: PlanStyle = .balanced,
        grandDecision: ArgusGrandDecision,
        candles: [Candle]? = nil
    ) -> [Scenario] {
        // İLERİ TARİHLİ GÖREV 2: ATR hesapla
        let atr: Double
        if let snapshotAtr = entrySnapshot.atr {
            atr = snapshotAtr
        } else if let candles = candles, !candles.isEmpty {
            // Candles'dan ATR hesapla (basit yöntem: True Range average)
            var trValues: [Double] = []
            for i in 1..<min(candles.count, 15) {
                let high = candles[i].high
                let low = candles[i].low
                let prevClose = candles[i-1].close
                let tr = max(high - low, abs(Double(high - prevClose)), abs(Double(low - prevClose)))
                trValues.append(tr)
            }
            atr = trValues.isEmpty ? entryPrice * 0.02 : trValues.reduce(0, +) / Double(trValues.count)
        } else {
            atr = entryPrice * 0.02  // Varsayılan %2
        }
        
        switch style {
        case .conservative:
            return conservativePlan(entry: entryPrice, atr: atr, snapshot: entrySnapshot)
        case .balanced:
            return balancedPlan(entry: entryPrice, atr: atr, snapshot: entrySnapshot, decision: grandDecision)
        case .aggressive:
            return aggressivePlan(entry: entryPrice, atr: atr, snapshot: entrySnapshot)
        case .momentum:
            return momentumPlan(entry: entryPrice, atr: atr, snapshot: entrySnapshot)
        case .swingTrade:
            return swingTradePlan(entry: entryPrice, atr: atr, snapshot: entrySnapshot)
        }
    }
    
    // MARK: - Chiron Regime-Based Style Selection (NEW - Phase 3)
    
    /// Dynamically selects plan style based on Chiron market regime
    /// Returns recommended style and reasoning
    func recommendStyleForRegime() -> (style: PlanStyle, reason: String) {
        let regime = ChironRegimeEngine.shared.globalResult.regime
        
        switch regime {
        case .trend:
            // Strong trend - use momentum trailing stop
            return (.momentum, "Trend rejimi tespit edildi. Trailing stop ile trend takibi önerilir.")
            
        case .chop:
            // Range-bound - be conservative, quick exits
            return (.conservative, "Yatay piyasa. Erken kâr alımı ve dar stop önerilir.")
            
        case .riskOff:
            // Defensive - be very conservative
            return (.conservative, "Riskten kaçış modu. Minimum risk ile erken çıkış önerilir.")
            
        case .newsShock:
            // High volatility event - aggressive with wider stops
            return (.aggressive, "Haber şoku. Geniş ATR çarpanları kullanılıyor.")
            
        case .neutral:
            // Default balanced
            return (.balanced, "Nötr piyasa. Dengeli plan önerilir.")
        }
    }
    
    /// Generate plan with automatic regime-based style selection
    func generateAdaptivePlan(
        entryPrice: Double,
        entrySnapshot: EntrySnapshot,
        grandDecision: ArgusGrandDecision,
        candles: [Candle]? = nil
    ) -> (scenarios: [Scenario], styleUsed: PlanStyle, reason: String) {
        let recommendation = recommendStyleForRegime()
        let scenarios = generatePlan(
            entryPrice: entryPrice,
            entrySnapshot: entrySnapshot,
            style: recommendation.style,
            grandDecision: grandDecision,
            candles: candles
        )
        return (scenarios, recommendation.style, recommendation.reason)
    }
    
    // MARK: - Conservative Plan
    
    private func conservativePlan(entry: Double, atr: Double, snapshot: EntrySnapshot) -> [Scenario] {
        // Stop: ATR × 1.5
        let stopPrice = entry - (atr * 1.5)
        
        // Hedefler: ATR × 1, 2, 3
        let target1 = entry + atr
        let target2 = entry + (atr * 2)
        
        return [
            Scenario(type: .bullish, steps: [
                PlannedAction(
                    trigger: .priceAbove(target1),
                    action: .sellPercent(50),
                    description: "ATR × 1 (\(formatPrice(target1))): %50 sat",
                    priority: 1
                ),
                PlannedAction(
                    trigger: .priceAbove(target1),
                    action: .setBreakeven,
                    description: "Başabaşa stop koy",
                    priority: 2
                ),
                PlannedAction(
                    trigger: .priceAbove(target2),
                    action: .sellAll,
                    description: "ATR × 2 (\(formatPrice(target2))): Kalanı sat",
                    priority: 3
                )
            ], isActive: true),
            
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop: ATR × 1.5 (\(formatPrice(stopPrice)))",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
    
    // MARK: - Balanced Plan
    
    private func balancedPlan(entry: Double, atr: Double, snapshot: EntrySnapshot, decision: ArgusGrandDecision) -> [Scenario] {
        // Stop: ATR × 2
        let stopPrice = entry - (atr * 2)
        
        // Hedefler: ATR × 2, 3, 4
        let target1 = entry + (atr * 2)
        let target2 = entry + (atr * 3)
        let target3 = entry + (atr * 4)
        
        var steps: [PlannedAction] = [
            PlannedAction(
                trigger: .priceAbove(target1),
                action: .sellPercent(30),
                description: "ATR × 2 (\(formatPrice(target1))): %30 sat",
                priority: 1
            ),
            PlannedAction(
                trigger: .priceAbove(target1),
                action: .activateTrailingStop(5),
                description: "%5 trailing stop aktifleştir",
                priority: 2
            ),
            PlannedAction(
                trigger: .priceAbove(target2),
                action: .sellPercent(40),
                description: "ATR × 3 (\(formatPrice(target2))): %40 sat",
                priority: 3
            ),
            PlannedAction(
                trigger: .priceAbove(target3),
                action: .sellAll,
                description: "ATR × 4 (\(formatPrice(target3))): Kalanı sat",
                priority: 4
            )
        ]
        
        // RSI aşırı alım kontrolü
        if let rsi = snapshot.rsi, rsi > 65 {
            steps.insert(PlannedAction(
                trigger: .rsiOverbought(threshold: 75),
                action: .sellPercent(25),
                description: "RSI > 75: %25 sat (giriş RSI zaten yüksekti)",
                priority: 0
            ), at: 0)
        }
        
        // Council değişikliği kontrolü
        steps.append(PlannedAction(
            trigger: .councilActionChanged(from: decision.action, to: .trim),
            action: .reduceAndHold(30),
            description: "Council AZALT derse: %30 sat, geri kalanı tut",
            priority: 10
        ))
        
        steps.append(PlannedAction(
            trigger: .councilActionChanged(from: decision.action, to: .liquidate),
            action: .sellAll,
            description: "Council ÇIK derse: Tamamını sat",
            priority: 11
        ))
        
        // Zaman bazlı
        steps.append(PlannedAction(
            trigger: .daysWithoutProgress(days: 30, minGain: 5),
            action: .reevaluate,
            description: "30 gün %5 kâr yok: Yeniden değerlendir",
            priority: 20
        ))
        
        return [
            Scenario(type: .bullish, steps: steps.filter { step in
                // Bullish senaryosu için sadece kazanç/RSI tetikleyicileri
                if case .priceAbove = step.trigger { return true }
                if case .rsiOverbought = step.trigger { return true }
                if case .activateTrailingStop = step.action { return true }
                return false
            }, isActive: true),
            
            Scenario(type: .neutral, steps: steps.filter { step in
                // Nötr senaryo: zaman ve council
                if case .daysWithoutProgress = step.trigger { return true }
                if case .councilActionChanged = step.trigger { return true }
                return false
            }, isActive: true),
            
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop: ATR × 2 (\(formatPrice(stopPrice)))",
                    priority: 0
                ),
                PlannedAction(
                    trigger: .councilActionChanged(from: decision.action, to: .liquidate),
                    action: .sellAll,
                    description: "Council ÇIK: Tamamını sat",
                    priority: 1
                )
            ], isActive: true)
        ]
    }
    
    // MARK: - Aggressive Plan
    
    private func aggressivePlan(entry: Double, atr: Double, snapshot: EntrySnapshot) -> [Scenario] {
        // Stop: ATR × 2.5
        let stopPrice = entry - (atr * 2.5)
        
        // Hedefler: ATR × 3, 5, 8
        let target1 = entry + (atr * 3)
        let target2 = entry + (atr * 5)
        let target3 = entry + (atr * 8)
        
        return [
            Scenario(type: .bullish, steps: [
                PlannedAction(
                    trigger: .priceAbove(target1),
                    action: .sellPercent(20),
                    description: "ATR × 3 (\(formatPrice(target1))): %20 sat",
                    priority: 1
                ),
                PlannedAction(
                    trigger: .priceAbove(target1),
                    action: .activateTrailingStop(8),
                    description: "%8 trailing stop aktifleştir",
                    priority: 2
                ),
                PlannedAction(
                    trigger: .priceAbove(target2),
                    action: .sellPercent(30),
                    description: "ATR × 5 (\(formatPrice(target2))): %30 sat",
                    priority: 3
                ),
                PlannedAction(
                    trigger: .priceAbove(target3),
                    action: .sellAll,
                    description: "ATR × 8 (\(formatPrice(target3))): Kalanı sat",
                    priority: 4
                )
            ], isActive: true),
            
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop: ATR × 2.5 (\(formatPrice(stopPrice)))",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
    
    // MARK: - Momentum Plan
    
    private func momentumPlan(entry: Double, atr: Double, snapshot: EntrySnapshot) -> [Scenario] {
        // Stop: ATR × 1.5 başlangıç, sonra trailing
        let initialStop = entry - (atr * 1.5)
        let target1 = entry + (atr * 1.5)
        
        return [
            Scenario(type: .bullish, steps: [
                PlannedAction(
                    trigger: .priceAbove(target1),
                    action: .setBreakeven,
                    description: "ATR × 1.5: Başabaşa stop",
                    priority: 1
                ),
                PlannedAction(
                    trigger: .priceAbove(target1),
                    action: .activateTrailingStop(5),
                    description: "%5 trailing stop aktifleştir - trend takibi",
                    priority: 2
                ),
                PlannedAction(
                    trigger: .rsiOverbought(threshold: 80),
                    action: .sellPercent(50),
                    description: "RSI > 80: %50 sat, momentum zayıflıyor",
                    priority: 3
                )
            ], isActive: true),
            
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(initialStop),
                    action: .sellAll,
                    description: "İlk stop: ATR × 1.5",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
    
    // MARK: - Swing Trade Plan
    
    private func swingTradePlan(entry: Double, atr: Double, snapshot: EntrySnapshot) -> [Scenario] {
        // Kısa vadeli: ATR × 1 stop, ATR × 2 hedef
        let stopPrice = entry - atr
        let target = entry + (atr * 2)
        
        return [
            Scenario(type: .bullish, steps: [
                PlannedAction(
                    trigger: .priceAbove(target),
                    action: .sellAll,
                    description: "Hedef: ATR × 2 (\(formatPrice(target)))",
                    priority: 1
                )
            ], isActive: true),
            
            Scenario(type: .neutral, steps: [
                PlannedAction(
                    trigger: .maxHoldingDays(10),
                    action: .sellAll,
                    description: "10 gün oldu: Swing trade süresi doldu",
                    priority: 1
                )
            ], isActive: true),
            
            Scenario(type: .bearish, steps: [
                PlannedAction(
                    trigger: .priceBelow(stopPrice),
                    action: .sellAll,
                    description: "Stop: ATR × 1 (\(formatPrice(stopPrice)))",
                    priority: 0
                )
            ], isActive: true)
        ]
    }
    
    // MARK: - Helpers
    
    private func formatPrice(_ price: Double) -> String {
        return String(format: "%.2f", price)
    }
    
    // MARK: - Plan Summary
    
    func summarizePlan(_ scenarios: [Scenario], entryPrice: Double) -> String {
        var summary = ""
        
        for scenario in scenarios {
            summary += "\n[\(scenario.type.rawValue)]\n"
            for step in scenario.steps.sorted(by: { $0.priority < $1.priority }) {
                summary += "  • \(step.trigger.displayText) → \(step.action.displayText)\n"
            }
        }
        
        return summary
    }
}
