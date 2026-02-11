import Foundation
import Combine

// MARK: - Position Plan Store
/// Pozisyon planlarını yöneten ve persist eden store

class PositionPlanStore: ObservableObject {
    static let shared = PositionPlanStore()
    
    @Published private(set) var plans: [UUID: PositionPlan] = [:]  // tradeId -> plan
    
    private let persistenceKey = "ArgusPositionPlansVortex" // New Key for V2
    
    // İLERİ TARİHLİ GÖREV 1: External price quotes
    private var priceQuotes: [String: Quote] = [:]
    private var candleStore: [String: [Candle]] = [:]
    
    // MARK: - Helper Methods for Triggers
    
    func updateCandles(_ candles: [String: [Candle]]) {
        self.candleStore = candles
    }
    
    private init() {
        loadPlans()
    }
    
    // MARK: - Sync with Portfolio
    
    /// Mevcut açık trade'ler için eksik planları oluştur
    func syncWithPortfolio(trades: [Trade], grandDecisions: [String: ArgusGrandDecision]) {
        let openTrades = trades.filter { $0.isOpen }
        var createdCount = 0
        
        for trade in openTrades {
            // Plan zaten varsa atla
            if hasPlan(for: trade.id) { continue }
            
            // Varsayılan karar oluştur
            let decision: ArgusGrandDecision
            if let gd = grandDecisions[trade.symbol] {
                decision = gd
            } else {
                // Varsayılan accumulate kararı
                decision = ArgusGrandDecision(
                    id: UUID(),
                    symbol: trade.symbol,
                    action: .accumulate,
                    strength: .normal,
                    confidence: 0.5,
                    reasoning: "Mevcut pozisyon için varsayılan plan",
                    contributors: [],
                    vetoes: [],
                    orionDecision: CouncilDecision(
                        symbol: trade.symbol,
                        action: .hold,
                        netSupport: 0.5,
                        approveWeight: 0,
                        vetoWeight: 0,
                        isStrongSignal: false,
                        isWeakSignal: false,
                        winningProposal: nil,
                        allProposals: [],
                        votes: [],
                        vetoReasons: [],
                        timestamp: Date()
                    ),
                    atlasDecision: nil,
                    aetherDecision: AetherDecision(
                        stance: .cautious,
                        marketMode: .neutral,
                        netSupport: 0.5,
                        isStrongSignal: false,
                        winningProposal: nil,
                        votes: [],
                        warnings: [],
                        timestamp: Date()
                    ),
                    hermesDecision: nil,
                    orionDetails: nil,
                    financialDetails: nil,
                    bistDetails: nil,
                    patterns: nil,
                    timestamp: Date()
                )
            }
            
            createPlan(for: trade, decision: decision)
            createdCount += 1
        }
        
        if createdCount > 0 {
            print("📋 \(createdCount) mevcut trade için plan oluşturuldu")
        }
    }
    
    // İLERİ TARİHLİ GÖREV 1: External data'den fiyatları güncelle
    /// TradingViewModel'den güncel fiyatları al (quote güncellemesinde çağrılır)
    func updatePriceQuotes(_ quotes: [String: Quote]) {
        self.priceQuotes = quotes
        updatePlanPrices() // Planların highestPrice'larını güncelle
    }
    
    /// Planların mevcut fiyatlarını güncelle
    func updatePlanPrices() {
        guard !priceQuotes.isEmpty else { return }
        
        var updatedCount = 0
        for (tradeId, var plan) in plans {
            guard let planSymbol = plan.originalSnapshot.symbol as String? else { continue }
            
            if let quote = priceQuotes[planSymbol] {
                // Highest price'ı güncelle (trailing stop için)
                if quote.currentPrice > plan.highestPrice {
                    plan.highestPrice = quote.currentPrice
                    plans[tradeId] = plan
                    updatedCount += 1
                }
            }
        }
        
        if updatedCount > 0 {
            savePlans()
            print("💰 \(updatedCount) planın highestPrice güncellendi")
        }
    }
    
    // MARK: - Public API
    
    /// Trade için plan var mı?
    func hasPlan(for tradeId: UUID) -> Bool {
        return plans[tradeId] != nil
    }
    
    /// Trade için plan getir
    func getPlan(for tradeId: UUID) -> PositionPlan? {
        return plans[tradeId]
    }
    
    /// Yeni plan oluştur
    @discardableResult
    func createPlan(
        for trade: Trade,
        decision: ArgusGrandDecision,
        thesis: String? = nil
    ) -> PositionPlan {
        let symbolCandles = candleStore[trade.symbol] ?? []

        // 1. Create Snapshot from Decision
        // OrionScoreResult uses 'score' (0-100)
        let orionScore = decision.orionDecision.netSupport * 100 // Use netSupport (0-1) and convert to 0-100
        let atlasScore = 50.0 // Default
        
        // Varsayılan tez
        let defaultThesis = generateThesis(for: trade.symbol, decision: decision)
        let defaultInvalidation = generateInvalidation(for: trade.symbol, decision: decision)
        let finalThesis = thesis ?? defaultThesis
        
        // FAZE 1.3: Technical data'yı orionDetails'ten populate et
        // Map Double? trend to TrendDirection?
        let trendScore = decision.orionDetails?.components.trend
        let mappedTrend: TrendDirection?
        if let score = trendScore {
            if score > 80 { mappedTrend = .strongUp }
            else if score > 60 { mappedTrend = .up }
            else if score < 20 { mappedTrend = .strongDown }
            else if score < 40 { mappedTrend = .down }
            else { mappedTrend = .sideways }
        } else {
            mappedTrend = nil
        }
        
        let atr = estimateATR(from: symbolCandles)
        let sma20 = movingAverage(from: symbolCandles, period: 20)
        let sma50 = movingAverage(from: symbolCandles, period: 50)
        let sma200 = movingAverage(from: symbolCandles, period: 200)
        let supportResistance = estimateSupportResistance(from: symbolCandles)
        let trendFromCandles = estimateTrend(from: symbolCandles, sma20: sma20, sma50: sma50)

        let techData = TechnicalSnapshotData(
            rsi: decision.orionDetails?.components.rsi,
            atr: atr,
            sma20: sma20,
            sma50: sma50,
            sma200: sma200,
            distanceFromATH: nil, distanceFrom52WeekLow: nil,
            nearestSupport: supportResistance.support,
            nearestResistance: supportResistance.resistance,
            trend: mappedTrend ?? trendFromCandles
        )
        
        let snapshot = EntrySnapshot(
            tradeId: trade.id,
            symbol: trade.symbol,
            entryPrice: trade.entryPrice,
            grandDecision: decision,
            orionScore: orionScore,
            atlasScore: atlasScore,
            technicalData: techData,
            macroData: nil,
            fundamentalData: nil
        )
        
        // 2. Delegate to Vortex Engine
        let plan = VortexEngine.shared.createPlan(
            for: trade,
            snapshot: snapshot,
            decision: decision,
            thesis: finalThesis,
            invalidation: defaultInvalidation,
            candles: symbolCandles
        )
        
        plans[trade.id] = plan
        savePlans()
        
        print("📋 Yeni VORTEX planı oluşturuldu: \(trade.symbol)")
        return plan
    }
    
    // MARK: - Helpers
    
    /// Mevcut fiyatı get (plan state'den yoksa external'den)
    private func getCurrentPrice(for tradeId: UUID) -> Double? {
        // Note: Bu fonksiyon external data provider'dan price çekmeli
        // Şimdilik nil dönüyoruz, ileride TradingViewModel'den alabiliriz
        return nil
    }
    
    /// Planı güncelle
    func updatePlan(_ plan: PositionPlan) {
        var updatedPlan = plan
        updatedPlan.lastUpdated = Date()
        plans[plan.tradeId] = updatedPlan
        savePlans()
    }
    
    /// Adımı tamamlandı olarak işaretle
    func markStepCompleted(tradeId: UUID, stepId: UUID) {
        guard var plan = plans[tradeId] else { return }
        
        if !plan.executedSteps.contains(stepId) {
            plan.executedSteps.append(stepId)
            plan.lastUpdated = Date()
            
            // FAZE 2.2: Highest price'ı güncelle (trailing stop için)
            if let currentPrice = getCurrentPrice(for: tradeId) {
                if currentPrice > plan.highestPrice {
                    plan.highestPrice = currentPrice
                }
            }
            
            plans[tradeId] = plan
            savePlans()
            
            print("✅ Plan adımı tamamlandı: \(plan.originalSnapshot.symbol) - Step \(stepId.uuidString.prefix(8))")
        }
    }
    
    /// Plan durumunu güncelle
    func updatePlanStatus(tradeId: UUID, status: PlanStatus) {
        guard var plan = plans[tradeId] else { return }
        plan.status = status
        plan.lastUpdated = Date()
        plans[tradeId] = plan
        savePlans()
    }
    
    /// Trade kapatıldığında planı tamamla
    func completePlan(tradeId: UUID) {
        updatePlanStatus(tradeId: tradeId, status: .completed)
    }
    
    // MARK: - Trigger Checking
    
    /// Tetiklenen aksiyonu bul
    func checkTriggers(
        trade: Trade,
        currentPrice: Double,
        grandDecision: ArgusGrandDecision?
    ) -> PlannedAction? {
        guard let plan = plans[trade.id], plan.isActive else { return nil }
        
        // PnL hesapla
        // Use Original Snapshot Entry Price
        let entryPrice = plan.originalSnapshot.entryPrice
        let pnlPercent = ((currentPrice - entryPrice) / entryPrice) * 100
        let daysHeld = Calendar.current.dateComponents([.day], from: plan.dateCreated, to: Date()).day ?? 0
        
        // Iterate ALL scenarios (Bullish, Bearish, Neutral)
        let activeScenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }.filter { $0.isActive }
        
        for scenario in activeScenarios {
            for step in scenario.steps {
                // ÖNCE: Bu adım zaten tamamlandı mı kontrol et
                if plan.executedSteps.contains(step.id) {
                    continue // ATLA - tekrar tetikleme
                }
                
                let triggered = checkTrigger(
                    trigger: step.trigger,
                    currentPrice: currentPrice,
                    entryPrice: entryPrice,
                    pnlPercent: pnlPercent,
                    daysHeld: daysHeld,
                    grandDecision: grandDecision
                )
                
                if triggered {
                    print("🎯 Tetiklendi: \(plan.originalSnapshot.symbol) - \(step.description)")
                    return step
                }
            }
        }
        
        return nil
    }
    
    private func checkTrigger(
        trigger: ActionTrigger,
        currentPrice: Double,
        entryPrice: Double,
        pnlPercent: Double,
        daysHeld: Int,
        grandDecision: ArgusGrandDecision?
    ) -> Bool {
        // FAZE 2.2: Technical data'ı snapshot'ten al
        let rsi = grandDecision?.orionDetails?.components.rsi
        
        switch trigger {
        // BASIC
        case .priceAbove(let target):
            return currentPrice > target
            
        case .priceBelow(let target):
            return currentPrice < target
            
        case .gainPercent(let target):
            return pnlPercent >= target
            
        case .lossPercent(let target):
            return pnlPercent <= -target
            
        case .daysElapsed(let days):
            return daysHeld >= days
            
        case .councilSignal(let signal):
            guard let gd = grandDecision else { return false }
            switch signal {
            case .trim: return gd.action == .trim
            case .liquidate: return gd.action == .liquidate
            case .accumulate: return gd.action == .accumulate
            case .aggressive: return gd.action == .aggressiveBuy
            }
            
        case .priceAndTime(let price, let days):
            return currentPrice >= price && daysHeld <= days
            
        // ADVANCED - Fiyat bazlı
        case .priceAboveEntry(let percent):
            return pnlPercent >= percent
            
        case .priceBelowEntry(let percent):
            return pnlPercent <= -percent
            
        // ADVANCED - Zaman bazlı
        case .maxHoldingDays(let days):
            return daysHeld >= days
            
        case .daysWithoutProgress(let days, let minGain):
            // X gün geçti ve kâr minGain altında
            return daysHeld >= days && pnlPercent < minGain
            
        // ADVANCED - Bu tetikleyiciler daha fazla veri gerektirir (snapshot, vb.)
        case .trailingStop(let pct):
            // FAZE 2.2: Trailing stop implementasyonu
            // Note: Bu fonksiyona currentPrice geliyor ama plan'ın highestPrice'i de lazım
            // Şimdilik basit trailing stop logic:
            let stopLevel = entryPrice * (1 - pct)
            return currentPrice < stopLevel

        case .atrMultiple(let multiplier):
            // FAZE 2.2: ATR bazlı stop/target
            // Note: ATR verisi orionDetails'te yok, ayrı servisten çekilmeli
            // Şimdilik entryPrice'e %3 ATR varsayıyoruz
            let atr = entryPrice * 0.03
            let stopLevel = entryPrice - (atr * multiplier)
            return currentPrice < stopLevel

        case .entryAtrStop(let multiplier):
            // FAZE 2.2: Entry ATR bazlı stop
            let atr = entryPrice * 0.03
            let stopLevel = entryPrice - (atr * multiplier)
            return currentPrice < stopLevel
            
        case .rsiOverbought, .rsiOversold, .crossBelow, .crossAbove:
            // FAZE 2.2: Teknik göstergeler anlık hesaplanıyor
            switch trigger {
            case .rsiOverbought(let threshold):
                if let rsiValue = rsi {
                    return rsiValue > threshold
                }
                return false
                
            case .rsiOversold(let threshold):
                if let rsiValue = rsi {
                    return rsiValue < threshold
                }
                return false
                
            case .crossBelow(let indicator):
                return checkCross(trigger: .crossBelow(indicator: indicator), symbol: grandDecision?.symbol ?? "")
                
            case .crossAbove(let indicator):
                return checkCross(trigger: .crossAbove(indicator: indicator), symbol: grandDecision?.symbol ?? "")
                
            default: return false
            }
            
        case .councilActionChanged, .councilConfidenceDropped, .orionScoreDropped, .deltaExceeds:
            // FAZE 2.2: Council değişikliği trigger'ları
            guard let gd = grandDecision else { return false }
            
            switch trigger {
            case .councilActionChanged(let from, let to):
                return gd.action != from // Basit kontrol: action değişti mi?
                
            case .councilConfidenceDropped(let threshold):
                // Confidence kontrolü
                // Note: confidence'yi grandDecision'dan almalıyız
                return false // Şimdilik false, ileride implement edilecek
                
            case .orionScoreDropped(let points):
                // Orion score düştü mü kontrolü
                let currentOrion = gd.orionDetails?.score ?? 50
                // Note: Bu kontrol için historical data gerek
                return false // Şimdilik false, ileride implement edilecek
                
            case .deltaExceeds(let threshold):
                // Delta score kontrolü
                // Note: Delta verisi Athena'dan gelir
                return false // Şimdilik false, ileride implement edilecek
                
            default: return false
            }
            
        case .earningsWithin(let days):
            // EventCalendarService ile kontrol edilmeli
            let check = EventCalendarService.shared.hasEarningsWithin(symbol: grandDecision?.symbol ?? "", days: days)
            return check.hasEarnings
            
        case .marketModeChanged, .vixAbove, .vixBelow, .spyDropped:
            // İLERİ TARİHLİ GÖREV 4: Piyasa verisi trigger'ları
            // ChironRegimeEngine'den market mode al
            let currentRegime = ChironRegimeEngine.shared.globalResult.regime
            
            switch trigger {
            case .marketModeChanged(let mode):
                // Rejim değişimi kontrolü
                // MacroRegime enum'ına dönüştür
                let modeMatched: Bool
                switch mode {
                case .greed, .extremeGreed:
                    modeMatched = currentRegime == .trend
                case .neutral, .complacency:
                    modeMatched = currentRegime == .neutral
                case .fear, .extremeFear, .panic:
                    modeMatched = currentRegime == .riskOff || currentRegime == .chop
                }
                return modeMatched
                
            case .vixAbove(let v):
                // MacroEnvironment'dan VIX kontrolü
                // Şimdilik false, ileride implement edilecek
                return false // Şimdilik false
                
            case .vixBelow(let v):
                // MacroEnvironment'dan VIX kontrolü
                return false // Şimdilik false
                
            case .spyDropped(let pct):
                // SPY düşüşü kontrolü
                return false // Şimdilik false
                
            default: return false
            }
            
        default:
            return false
        }
    }
    
    private func checkCross(trigger: ActionTrigger, symbol: String) -> Bool {
        guard let candles = candleStore[symbol], candles.count >= 20 else { return false } 
        
        // Extract parameters
        let period: Int
        let isCrossAbove: Bool
        
        switch trigger {
        case .crossAbove(let ind):
            isCrossAbove = true
            // Parse text "SMA20" or similar
            if ind.lowercased().contains("sma") {
                let digits = ind.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                period = Int(digits) ?? 20
            } else {
                 return false 
            }
            
        case .crossBelow(let ind):
            isCrossAbove = false
             if ind.lowercased().contains("sma") {
                let digits = ind.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                period = Int(digits) ?? 20
            } else {
                 return false 
            }
        default: return false
        }
        
        guard candles.count > period + 1 else { return false }
        
        // Helper to calc SMA at offset (0 = recent)
        func getSMA(offset: Int) -> Double? {
             let endIndex = candles.count - 1 - offset
             let startIndex = endIndex - period + 1
             guard startIndex >= 0 else { return nil }
             
             let slice = candles[startIndex...endIndex]
             let sum = slice.reduce(0.0) { $0 + $1.close }
             return sum / Double(period)
        }
        
        guard let currentSMA = getSMA(offset: 0),
              let previousSMA = getSMA(offset: 1) else { return false }
              
        let currentPrice = candles.last!.close
        let previousPrice = candles[candles.count - 2].close
        
        if isCrossAbove {
            // Price crosses ABOVE SMA: PrevPrice < PrevSMA AND CurrPrice > CurrSMA
            return previousPrice < previousSMA && currentPrice > currentSMA
        } else {
             // Price crosses BELOW SMA: PrevPrice > PrevSMA AND CurrPrice < CurrSMA
            return previousPrice > previousSMA && currentPrice < currentSMA
        }
    }
    
    // MARK: - Thesis Generation
    
    private func generateThesis(for symbol: String, decision: ArgusGrandDecision) -> String {
        let actionText: String
        switch decision.action {
        case .aggressiveBuy: actionText = "Güçlü alım sinyali"
        case .accumulate: actionText = "Kademeli birikim"
        case .trim: actionText = "Azaltma"
        case .liquidate: actionText = "Çıkış"
        case .neutral: actionText = "Nötr bekleme"
        }
        
        return "\(actionText). \(decision.reasoning)"
    }
    
    private func generateInvalidation(for symbol: String, decision: ArgusGrandDecision) -> String {
        switch decision.action {
        case .aggressiveBuy, .accumulate:
            return "Konsey AZALT veya ÇIK sinyali verirse, ya da -%10 stop tetiklenirse"
        default:
            return "Beklenmedik negatif gelişme"
        }
    }

    private func movingAverage(from candles: [Candle], period: Int) -> Double? {
        guard candles.count >= period else { return nil }
        let slice = candles.suffix(period)
        let sum = slice.reduce(0.0) { $0 + $1.close }
        return sum / Double(period)
    }

    private func estimateATR(from candles: [Candle], period: Int = 14) -> Double? {
        guard candles.count >= (period + 1) else { return nil }
        let sample = Array(candles.suffix(period + 1))

        var trueRanges: [Double] = []
        for index in 1..<sample.count {
            let current = sample[index]
            let previousClose = sample[index - 1].close
            let trueRange = max(
                current.high - current.low,
                abs(current.high - previousClose),
                abs(current.low - previousClose)
            )
            trueRanges.append(trueRange)
        }

        guard !trueRanges.isEmpty else { return nil }
        return trueRanges.reduce(0, +) / Double(trueRanges.count)
    }

    private func estimateSupportResistance(from candles: [Candle], lookback: Int = 40) -> (support: Double?, resistance: Double?) {
        guard !candles.isEmpty else { return (nil, nil) }
        let slice = candles.suffix(lookback)
        let support = slice.map(\.low).min()
        let resistance = slice.map(\.high).max()
        return (support, resistance)
    }

    private func estimateTrend(from candles: [Candle], sma20: Double?, sma50: Double?) -> TrendDirection? {
        guard let lastClose = candles.last?.close else { return nil }
        guard let sma20, let sma50 else { return nil }

        if lastClose > sma20 && sma20 > sma50 { return .strongUp }
        if lastClose > sma20 { return .up }
        if lastClose < sma20 && sma20 < sma50 { return .strongDown }
        if lastClose < sma20 { return .down }
        return .sideways
    }
    
    // MARK: - Persistence
    
    private func savePlans() {
        do {
            let data = try JSONEncoder().encode(Array(plans.values))
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("❌ Plan kaydetme hatası: \(error)")
        }
    }
    
    private func loadPlans() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        
        do {
            let loadedPlans = try JSONDecoder().decode([PositionPlan].self, from: data)
            for plan in loadedPlans {
                plans[plan.tradeId] = plan
            }
            print("📋 \(loadedPlans.count) plan yüklendi")
        } catch {
            print("❌ Plan yükleme hatası: \(error)")
        }
    }
    
    // MARK: - Debug
    
    func printPlanSummary(for tradeId: UUID) {
        guard let plan = plans[tradeId] else {
            print("❌ Plan bulunamadı: \(tradeId)")
            return
        }
        
        print("═══════════════════════════════════════")
        print("📋 POZİSYON PLANI: \(plan.originalSnapshot.symbol)")
        print("═══════════════════════════════════════")
        print("Tez: \(plan.thesis)")
        print("Giriş: \(String(format: "%.2f", plan.originalSnapshot.entryPrice)) @ \(plan.originalSnapshot.capturedAt.formatted())")
        print("Miktar: \(String(format: "%.2f", plan.initialQuantity))")
        // print("Durum: \(plan.status.rawValue)") // Optional if status enum exists
        print("Niyet: \(plan.intent.rawValue)")
        print("───────────────────────────────────────")
        
        let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
        
        for scenario in scenarios {
            print("\(scenario.type.rawValue) (\(scenario.isActive ? "AKTİF" : "PASİF")):")
            for step in scenario.steps {
                let completed = plan.executedSteps.contains(step.id) ? "✅" : "⏳"
                print("  \(completed) \(step.trigger.displayText) → \(step.action.displayText)")
            }
        }
        print("═══════════════════════════════════════")
        if !plan.journeyLog.isEmpty {
            print("📜 PLAN GEÇMİŞİ:")
            for rev in plan.journeyLog {
                print("  - \(rev.timestamp.formatted()): \(rev.changeDescription) (\(rev.reason))")
            }
            print("═══════════════════════════════════════")
        }
    }
}
