import Foundation
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let tradeBrainBuyOrder = Notification.Name("tradeBrainBuyOrder")
    static let tradeBrainSellOrder = Notification.Name("tradeBrainSellOrder")
}

// MARK: - Trade Brain Executor
/// Council kararlarını alım/satım emirlerine çeviren uygulayıcı

class TradeBrainExecutor: ObservableObject {
    static let shared = TradeBrainExecutor()
    
    @Published var executionLogs: [String] = []
    @Published var isEnabled: Bool = true
    @Published var lastMultiHorizonDecisions: [String: MultiHorizonDecision] = [:]
    @Published var lastContradictionAnalyses: [String: ContradictionAnalysis] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    private var lastExecutionTime: [String: Date] = [:]
    
    private let baseCooldownSeconds: TimeInterval = 300
    
    private let horizonEngine = HorizonEngine.shared
    private let selfQuestionEngine = SelfQuestionEngine.shared
    private let confidenceCalibration = ConfidenceCalibrationService.shared
    private let eventMemory = EventMemoryService.shared
    private let regimeMemory = RegimeMemoryService.shared
    private let learningService = TradeBrainLearningService.shared
    
    private init() {}

    // MARK: - Symbol Profile

    private struct SymbolExecutionProfile {
        enum RiskTier: String {
            case defensive = "DEFANSİF"
            case balanced = "DENGELİ"
            case offensive = "ATAK"
        }

        let symbol: String
        let tier: RiskTier
        let allocationMultiplier: Double
        let cooldownMultiplier: Double
        let minDecisionConfidence: Double
        let notes: [String]
    }
    
    // MARK: - Main Execution Loop
    
    /// Council kararlarını değerlendir ve gerekirse işlem yap
    func evaluateDecisions(
        decisions: [String: ArgusGrandDecision],
        portfolio: [Trade],
        quotes: [String: Quote],
        balance: Double,
        bistBalance: Double,
        orionScores: [String: OrionScoreResult],
        candles: [String: [Candle]]
    ) async {
        guard isEnabled else { return }
        
        print("⚖️ TradeBrainExecutor: \(decisions.count) karar değerlendiriliyor...")
        
        let openTrades = portfolio.filter { $0.isOpen }
        let openSymbols = Set(openTrades.map { $0.symbol })
        
        print("📦 TradeBrainExecutor: \(openSymbols.count) açık pozisyon")
        
        var processedCount = 0
        var skippedCooldown = 0
        var skippedLowConfidence = 0
        var skippedNoPrice = 0
        
        for (symbol, decision) in decisions {
            processedCount += 1

            let symbolCandles = candles[symbol] ?? []
            let profile = await buildExecutionProfile(
                symbol: symbol,
                decision: decision,
                portfolio: portfolio,
                quote: quotes[symbol],
                candles: symbolCandles
            )
            let cooldownSeconds = baseCooldownSeconds * profile.cooldownMultiplier
            print(
                "🧬 TradeBrainProfile[\(symbol)] tier=\(profile.tier.rawValue) " +
                "alloc×\(String(format: "%.2f", profile.allocationMultiplier)) " +
                "cooldown×\(String(format: "%.2f", profile.cooldownMultiplier)) " +
                "minConf=\(String(format: "%.2f", profile.minDecisionConfidence))"
            )
            
            // Cooldown kontrolü
            if let lastTime = lastExecutionTime[symbol],
               Date().timeIntervalSince(lastTime) < cooldownSeconds {
                skippedCooldown += 1
                debugSkip(symbol: symbol, reason: "cooldown aktif")
                continue
            }
            
            let currentPrice = quotes[symbol]?.currentPrice ?? symbolCandles.last?.close ?? 0
            guard currentPrice > 0 else { 
                skippedNoPrice += 1
                debugSkip(symbol: symbol, reason: "fiyat yok (quote/candle)")
                continue 
            }
            
            let hasOpenPosition = openSymbols.contains(symbol)
            
            print("💡 TradeBrainExecutor: \(symbol) - Action: \(decision.action.rawValue), OpenPos: \(hasOpenPosition)")
            
            // ALIM KARARLARI
            if !hasOpenPosition {
                if decision.action == .aggressiveBuy || decision.action == .accumulate {
                    if decision.confidence < profile.minDecisionConfidence {
                        skippedLowConfidence += 1
                        debugSkip(
                            symbol: symbol,
                            reason: "güven düşük (\(String(format: "%.2f", decision.confidence)) < \(String(format: "%.2f", profile.minDecisionConfidence)))"
                        )
                        continue
                    }
                    print("✅ TradeBrainExecutor: ALIM yapılıyor: \(symbol)")
                    await executeBuy(
                        symbol: symbol,
                        decision: decision,
                        currentPrice: currentPrice,
                        balance: balance,
                        bistBalance: bistBalance,
                        portfolio: portfolio,
                        quotes: quotes,
                        orionScore: orionScores[symbol]?.score ?? 50,
                        candles: symbolCandles,
                        profile: profile
                    )
                } else {
                    print("⚠️ TradeBrainExecutor: \(symbol) - Action \(decision.action.rawValue) alım için değil")
                    debugSkip(symbol: symbol, reason: "aksiyon alım değil (\(decision.action.rawValue))")
                }
            } else {
                print("⚠️ TradeBrainExecutor: \(symbol) - Zaten açık pozisyon var, alım yapılmayacak")
                debugSkip(symbol: symbol, reason: "zaten açık pozisyon var")
            }
            
            // SATIM KARARLARI (Plan bazlı - Trade Brain)
            // Not: Satım artık PositionPlanStore.checkTriggers() ile yapılıyor
            // Burada sadece acil durum satışları (liquidate) yapalım
            if hasOpenPosition && decision.action == .liquidate {
                if let trade = openTrades.first(where: { $0.symbol == symbol }) {
                    print("🔴 TradeBrainExecutor: ACİL SATIŞ: \(symbol)")
                    await executeEmergencySell(
                        trade: trade,
                        decision: decision,
                        currentPrice: currentPrice
                    )
                }
            }
        }
        
        print(
            "📊 TradeBrainExecutor: Özet - İşlenen: \(processedCount), " +
            "Cooldown: \(skippedCooldown), Güven: \(skippedLowConfidence), Fiyat Yok: \(skippedNoPrice)"
        )
    }
    
    // MARK: - Buy Execution
    
    private func executeBuy(
        symbol: String,
        decision: ArgusGrandDecision,
        currentPrice: Double,
        balance: Double,
        bistBalance: Double,
        portfolio: [Trade],
        quotes: [String: Quote],
        orionScore: Double,
        candles: [Candle],
        profile: SymbolExecutionProfile
    ) async {
        print("💰 executeBuy: \(symbol) - Fiyat: \(currentPrice)")
        
        let isBist = SymbolResolver.shared.isBistSymbol(symbol)
        let availableBalance = isBist ? bistBalance : balance
        
        print("💰 executeBuy: Available Balance = \(availableBalance), isBist = \(isBist)")
        
        // 1. ALLOCATION HESAPLA
        // Rejim × Aether çarpanı hesapla
        let regimeAetherScore = MacroRegimeService.shared.getCachedRating()?.numericScore ?? 50
        let currentRegime = ChironRegimeEngine.shared.globalResult.regime
        let regimeMultiplier = RegimePositionSizer.multiplier(aetherScore: regimeAetherScore, regime: currentRegime)

        guard regimeMultiplier > 0 else {
            log("🛑 \(symbol): Rejim bloğu — Aether:\(Int(regimeAetherScore)) Rejim:\(currentRegime.rawValue)")
            print("🛑 executeBuy: Rejim bloğu — alım durduruldu (Aether:\(Int(regimeAetherScore)), Rejim:\(currentRegime.rawValue))")
            return
        }

        let allocation: Double
        let minTradeAmount: Double

        if isBist {
            let basePercent = 0.05
            let adjustedPercent = basePercent * profile.allocationMultiplier * regimeMultiplier
            allocation = availableBalance * adjustedPercent
            minTradeAmount = 1000.0
            print(
                "💰 executeBuy: BIST Allocation = %\(Int(adjustedPercent * 100)) " +
                "(\(String(format: "%.2f", profile.allocationMultiplier))x profile, " +
                "\(String(format: "%.2f", regimeMultiplier))x rejim) of ₺\(availableBalance) = ₺\(allocation)"
            )
        } else {
            let basePercent = 0.10
            let adjustedPercent = basePercent * profile.allocationMultiplier * regimeMultiplier
            allocation = availableBalance * adjustedPercent
            minTradeAmount = 50.0
            print(
                "💰 executeBuy: Global Allocation = %\(Int(adjustedPercent * 100)) " +
                "(\(String(format: "%.2f", profile.allocationMultiplier))x profile, " +
                "\(String(format: "%.2f", regimeMultiplier))x rejim) of $\(availableBalance) = $\(allocation)"
            )
        }
        
        guard allocation >= minTradeAmount else {
            log("⚠️ \(symbol): Yetersiz bakiye (gereken: \(minTradeAmount), mevcut: \(allocation))")
            print("🛑 executeBuy: Yetersiz bakiye - Gereken: \(minTradeAmount), Mevcut: \(allocation)")
            return
        }

        var proposedQuantity = allocation / currentPrice

        // 2. RİSK KONTROLÜ
        // FIX: portfolioValue sadece aynı pazar trade'lerini içermeli (BIST veya Global ayrı)
        let marketFilteredPortfolio = portfolio.filter { $0.isOpen && SymbolResolver.shared.isBistSymbol($0.symbol) == isBist }
        let portfolioValue = marketFilteredPortfolio.reduce(0) { sum, trade in
            let price = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (trade.quantity * price)
        }

        let totalEquity = availableBalance + portfolioValue

        // 2B. PORTFÖY ISI KAPISI
        let heatLevel = PortfolioHeatGate.assess(portfolio: marketFilteredPortfolio, quotes: quotes, equity: totalEquity)
        let heatMultiplier = PortfolioHeatGate.positionMultiplier(for: heatLevel)
        guard heatMultiplier > 0 else {
            log("🔥 \(symbol): Portföy ısı limiti (\(heatLevel.rawValue)) — yeni alım durduruldu")
            print("🔥 executeBuy: Portföy ısı bloğu (\(heatLevel.rawValue)) — alım iptal")
            return
        }
        if heatMultiplier < 1.0 {
            proposedQuantity *= heatMultiplier
            print("🌡️ executeBuy: Portföy ısısı (\(heatLevel.rawValue)) — miktar \(String(format: "%.0f%%", heatMultiplier * 100)) küçültüldü")
        }
        let marketOpenCount = marketFilteredPortfolio.count
        print("🛡️ executeBuy: \(isBist ? "BIST" : "GLOBAL") açık pozisyon sayısı = \(marketOpenCount)")
        
        let riskCheck = PortfolioRiskManager.shared.checkBuyRisk(
            symbol: symbol,
            proposedAmount: allocation,
            currentPrice: currentPrice,
            portfolio: marketFilteredPortfolio,
            cashBalance: availableBalance,
            totalEquity: totalEquity
        )
        
        print("🛡️ executeBuy: Risk Check - CanTrade: \(riskCheck.canTrade), Blockers: \(riskCheck.blockers)")
        
        if !riskCheck.canTrade {
            log("🛑 \(symbol): Risk engeli - \(riskCheck.blockers.joined(separator: ", "))")
            print("🛑 executeBuy: Risk engeli - \(riskCheck.blockers.joined(separator: ", "))")
            return
        }
        
        // Uyarıları logla
        for warning in riskCheck.warnings {
            log("⚠️ \(symbol): \(warning)")
            print("⚠️ executeBuy: \(warning)")
        }
        
        if let adjustedQty = riskCheck.adjustedQuantity {
            proposedQuantity = adjustedQty
            print("📊 executeBuy: Quantity adjusted to \(adjustedQty)")
        }
        
        // Uyarıları logla
        for warning in riskCheck.warnings {
            log("⚠️ \(symbol): \(warning)")
        }
        
        if let adjustedQty = riskCheck.adjustedQuantity {
            proposedQuantity = adjustedQty
        }
        
        // 3. GOVERNOR KONTROLÜ (YENİ - Execution Logic Centralization)
        if isBist {
            // BIST Vali (BistExecutionGovernor) Kontrolü
            print("🇹🇷 executeBuy: BIST Vali kontrolü yapılıyor...")
            if let bistDecision = decision.bistDetails {
                let snapshot = BistExecutionGovernor.shared.audit(
                    decision: bistDecision,
                    grandDecisionID: bistDecision.id,
                    currentPrice: currentPrice,
                    portfolio: portfolio,
                    lastTradeTime: nil // Executor zaten cooldown kontrolü yapıyor
                )
                
                print("🇹🇷 executeBuy: BIST Vali kararı - Action: \(snapshot.action), Reason: \(snapshot.reason)")
                
                if snapshot.action != .buy {
                    log("🇹🇷 BIST Vali VETO: \(symbol) -> \(snapshot.reason)")
                    print("🛑 executeBuy: BIST Vali VETO - \(snapshot.reason)")
                    return // İŞLEM İPTAL
                } else {
                    log("🇹🇷 BIST Vali ONAY: \(symbol)")
                    print("✅ executeBuy: BIST Vali ONAY")
                }
            } else {
                log("⚠️ \(symbol): BIST detayı eksik, Vali kontrolü atlanıyor.")
                print("⚠️ executeBuy: BIST detayı eksik")
            }
        }
        
        // 3. TAKVİM KONTROLÜ
        print("📅 executeBuy: Takvim kontrolü yapılıyor...")
        let eventRisk = EventCalendarService.shared.assessPositionRisk(symbol: symbol)
        
        print("📅 executeBuy: Event Risk - ShouldAvoid: \(eventRisk.shouldAvoidNewPosition)")
        
        if eventRisk.shouldAvoidNewPosition {
            log("📅 \(symbol): Takvim engeli - Yaklaşan kritik olay")
            print("🛑 executeBuy: Takvim engeli")
            for warning in eventRisk.warnings {
                log("   ⚠️ \(warning)")
                print("   ⚠️ \(warning)")
            }
            return
        }
        
        // 4. GOVERNOR KONTROLÜ
        let scores = (
            atlas: FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore,
            orion: orionScore as Double?,
            aether: MacroRegimeService.shared.getCachedRating()?.numericScore,
            hermes: nil as Double?
        )
        
        let signal = AutoPilotSignal(
            action: .buy,
            quantity: proposedQuantity,
            reason: decision.reasoning,
            stopLoss: nil,
            takeProfit: nil,
            strategy: .pulse,
            trimPercentage: nil
        )
        
        let governorDecision = await ExecutionGovernor.shared.review(
            signal: signal,
            symbol: symbol,
            quantity: proposedQuantity,
            portfolio: marketFilteredPortfolio,
            equity: totalEquity,
            scores: (scores.atlas, scores.orion, scores.aether, nil)
        )
        
        print("🛡️ executeBuy: Governor input - Market: \(isBist ? "BIST" : "GLOBAL"), Equity: \(String(format: "%.2f", totalEquity)), OpenPos: \(marketFilteredPortfolio.count)")
        
        print("🛡️ executeBuy: ExecutionGovernor karar bekleniyor...")
        
        switch governorDecision {
        case .approved(_, let adjustedQty):
            proposedQuantity = adjustedQty
            print("✅ executeBuy: ExecutionGovernor ONAY - Quantity: \(adjustedQty)")
            
        case .rejected(let reason):
            log("🛡️ \(symbol): Governor VETO - \(reason)")
            print("🛑 executeBuy: ExecutionGovernor VETO - \(reason)")
            return
        }
        
        // 5. ALIM YAP - Notification ile TradingViewModel'e bildir
        // Not: TradingViewModel.shared kullanılamıyor, NotificationCenter ile çözüyoruz
        print("📨 executeBuy: Notification gönderiliyor - Symbol: \(symbol), Qty: \(proposedQuantity), Price: \(currentPrice)")
        
        NotificationCenter.default.post(
            name: .tradeBrainBuyOrder,
            object: nil,
            userInfo: [
                "symbol": symbol,
                "quantity": proposedQuantity,
                "price": currentPrice
            ]
        )
        
        log("✅ \(symbol): ALIM - \(String(format: "%.2f", proposedQuantity)) adet @ \(String(format: "%.2f", currentPrice))")
        log("   📋 Karar: \(decision.action.rawValue) (\(String(format: "%.0f", decision.confidence * 100))%)")
        
        print("✅ executeBuy: ALIM EMRİ GÖNDERİLDİ - \(symbol): \(proposedQuantity) @ \(currentPrice)")
        
        // Cooldown ayarla
        lastExecutionTime[symbol] = Date()
        print("⏱️ executeBuy: Cooldown ayarlandı - \(symbol)")
    }
    
    // MARK: - Emergency Sell (Liquidate Only)
    
    private func executeEmergencySell(
        trade: Trade,
        decision: ArgusGrandDecision,
        currentPrice: Double
    ) async {
        // Council LIQUIDATE dedi - acil çıkış
        NotificationCenter.default.post(
            name: .tradeBrainSellOrder,
            object: nil,
            userInfo: [
                "tradeId": trade.id.uuidString,
                "price": currentPrice,
                "reason": "🚨 Council LIQUIDATE: \(decision.reasoning)"
            ]
        )
        
        log("🚨 \(trade.symbol): ACİL SATIŞ - Council LIQUIDATE kararı")
        log("   📋 Sebep: \(decision.reasoning)")
        
        // Plan tamamla
        PositionPlanStore.shared.completePlan(tradeId: trade.id)
        
        // Cooldown
        lastExecutionTime[trade.symbol] = Date()
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.executionLogs.insert(logEntry, at: 0)
            if self.executionLogs.count > 100 {
                self.executionLogs = Array(self.executionLogs.prefix(100))
            }
        }
        
        print("🧠 Trade Brain: \(message)")
    }

    private func debugSkip(symbol: String, reason: String) {
        print("🟡 AUTOPILOT-SKIP: \(symbol) -> \(reason)")
    }

    private func buildExecutionProfile(
        symbol: String,
        decision: ArgusGrandDecision,
        portfolio: [Trade],
        quote: Quote?,
        candles: [Candle]
    ) async -> SymbolExecutionProfile {
        var allocationMultiplier = 1.0
        var cooldownMultiplier = 1.0
        var minConfidence = 0.55
        var notes: [String] = []

        let referencePrice = quote?.currentPrice ?? candles.last?.close ?? 0
        let volatility = estimateVolatility(candles: candles, referencePrice: referencePrice)
        if volatility > 0.05 {
            allocationMultiplier *= 0.68
            cooldownMultiplier *= 1.45
            minConfidence += 0.10
            notes.append("yüksek volatilite")
        } else if volatility < 0.02 {
            allocationMultiplier *= 1.10
            cooldownMultiplier *= 0.92
            notes.append("düşük volatilite")
        }

        let eventRisk = EventCalendarService.shared.assessPositionRisk(symbol: symbol)
        if eventRisk.shouldAvoidNewPosition {
            allocationMultiplier *= 0.45
            cooldownMultiplier *= 1.8
            minConfidence += 0.12
            notes.append("yakın kritik olay")
        } else if eventRisk.shouldReducePosition {
            allocationMultiplier *= 0.72
            cooldownMultiplier *= 1.25
            minConfidence += 0.06
            notes.append("olay riski")
        }

        let closedTrades = portfolio.filter { !$0.isOpen && $0.symbol == symbol && $0.exitPrice != nil }
        if !closedTrades.isEmpty {
            let winCount = closedTrades.filter { $0.profit > 0 }.count
            let winRate = Double(winCount) / Double(closedTrades.count)
            let avgPnL = closedTrades.map(\.profitPercentage).reduce(0, +) / Double(closedTrades.count)

            if winRate < 0.40 || avgPnL < -1.0 {
                allocationMultiplier *= 0.72
                cooldownMultiplier *= 1.20
                minConfidence += 0.08
                notes.append("zayıf sembol geçmişi")
            } else if winRate > 0.65 && avgPnL > 1.5 {
                allocationMultiplier *= 1.10
                cooldownMultiplier *= 0.90
                minConfidence -= 0.03
                notes.append("güçlü sembol geçmişi")
            }
        }

        let hasCustomWeights = await MainActor.run {
            ChironWeightStore.shared.hasCustomWeights(symbol: symbol)
        }
        if hasCustomWeights {
            allocationMultiplier *= 1.10
            cooldownMultiplier *= 0.90
            minConfidence -= 0.02
            notes.append("custom chiron ağırlığı")
        }

        if decision.action == .aggressiveBuy && decision.confidence > 0.78 {
            allocationMultiplier *= 1.06
            notes.append("hücum güveni yüksek")
        }

        allocationMultiplier = min(max(allocationMultiplier, 0.35), 1.45)
        cooldownMultiplier = min(max(cooldownMultiplier, 0.75), 2.5)
        minConfidence = min(max(minConfidence, 0.45), 0.85)

        let tier: SymbolExecutionProfile.RiskTier
        if allocationMultiplier <= 0.72 || minConfidence >= 0.72 {
            tier = .defensive
        } else if allocationMultiplier >= 1.15 && minConfidence <= 0.55 {
            tier = .offensive
        } else {
            tier = .balanced
        }

        return SymbolExecutionProfile(
            symbol: symbol,
            tier: tier,
            allocationMultiplier: allocationMultiplier,
            cooldownMultiplier: cooldownMultiplier,
            minDecisionConfidence: minConfidence,
            notes: notes
        )
    }

    private func estimateVolatility(candles: [Candle], referencePrice: Double) -> Double {
        guard candles.count >= 8, referencePrice > 0 else { return 0.03 }

        let sample = Array(candles.suffix(24))
        guard sample.count >= 2 else { return 0.03 }

        var ranges: [Double] = []
        for index in 1..<sample.count {
            let high = sample[index].high
            let low = sample[index].low
            let previousClose = sample[index - 1].close
            let trueRange = max(high - low, abs(high - previousClose), abs(low - previousClose))
            ranges.append(trueRange)
        }

        guard !ranges.isEmpty else { return 0.03 }
        let atr = ranges.reduce(0, +) / Double(ranges.count)
        return atr / referencePrice
    }
    
    // MARK: - Public API
    
    func clearLogs() {
        executionLogs.removeAll()
    }
    
    func resetCooldowns() {
        lastExecutionTime.removeAll()
    }
    
    // MARK: - Trade Brain 3.0 Enhanced Decision
    
    func makeEnhancedDecision(
        symbol: String,
        grandDecision: ArgusGrandDecision,
        candles: [Candle],
        orionScore: OrionScoreResult?,
        atlasScore: Double?
    ) async -> EnhancedTradeBrainDecision {
        
        let regimeContext = await regimeMemory.getRegimeContext()
        let eventContext = await eventMemory.getEventContextForDecision(symbol: symbol)
        
        let macroContext = MacroContext(
            vix: regimeContext.vix,
            regime: regimeContext.regime,
            trend: "Yatay",
            fearGreedIndex: 50
        )
        
        let multiHorizon = await horizonEngine.generateMultiHorizonDecision(
            symbol: symbol,
            candles: candles,
            orionScore: orionScore,
            atlasScore: atlasScore,
            macroContext: macroContext
        )
        
        let orionModule = OrionModuleDecision(
            trendSignal: grandDecision.action == .aggressiveBuy || grandDecision.action == .accumulate ? "buy" : 
                         grandDecision.action == .trim || grandDecision.action == .liquidate ? "sell" : "neutral",
            confidence: grandDecision.confidence,
            rsi: orionScore?.components.rsi ?? 50,
            macdSignal: orionScore?.components.macdHistogram != nil ? (orionScore!.components.macdHistogram! > 0 ? "bullish" : "bearish") : "notr"
        )
        
        let atlasModule = atlasScore.map { AtlasModuleDecision(
            action: grandDecision.action == .aggressiveBuy || grandDecision.action == .accumulate ? "buy" : "sell",
            confidence: Double($0) / 100.0,
            score: $0
        )}
        
        let aetherModule = AetherModuleDecision(
            stance: regimeContext.regime == "Risk On" ? "risk_on" : regimeContext.regime == "Risk Off" ? "risk_off" : "neutral",
            confidence: regimeContext.historicalWinRate,
            riskLevel: regimeContext.riskScore
        )
        
        let hermesModule: HermesModuleDecision? = nil
        
        let contradictionAnalysis = await selfQuestionEngine.analyzeContradictions(
            orionDecision: orionModule,
            atlasDecision: atlasModule,
            aetherDecision: aetherModule,
            hermesDecision: hermesModule
        )
        
        let calibratedConfidence: Double
        if contradictionAnalysis.hasContradictions {
            calibratedConfidence = max(0.1, multiHorizon.calibratedConfidence - contradictionAnalysis.suggestedConfidenceDrop)
        } else {
            calibratedConfidence = multiHorizon.calibratedConfidence
        }
        
        await MainActor.run {
            self.lastMultiHorizonDecisions[symbol] = multiHorizon
            self.lastContradictionAnalyses[symbol] = contradictionAnalysis
        }
        
        await learningService.observeDecision(
            symbol: symbol,
            multiHorizon: multiHorizon,
            contradictionAnalysis: contradictionAnalysis,
            macroContext: macroContext,
            finalAction: grandDecision.action.rawValue,
            finalConfidence: calibratedConfidence
        )
        
        return EnhancedTradeBrainDecision(
            symbol: symbol,
            grandDecision: grandDecision,
            multiHorizon: multiHorizon,
            contradictionAnalysis: contradictionAnalysis,
            regimeContext: regimeContext,
            eventContext: eventContext,
            calibratedConfidence: calibratedConfidence,
            timestamp: Date()
        )
    }
    
    func recordTradeOutcome(
        symbol: String,
        wasCorrect: Bool,
        pnlPercent: Double,
        holdingDays: Int
    ) async {
        guard let multiHorizon = lastMultiHorizonDecisions[symbol],
              let contradiction = lastContradictionAnalyses[symbol] else {
            return
        }
        
        await confidenceCalibration.recordOutcome(
            confidence: multiHorizon.calibratedConfidence,
            wasCorrect: wasCorrect,
            pnlPercent: pnlPercent
        )
        
        print("TradeBrain: \(symbol) sonuc kaydedildi - \(wasCorrect ? "BASARILI" : "BASARISIZ")")
    }
}

struct EnhancedTradeBrainDecision {
    let symbol: String
    let grandDecision: ArgusGrandDecision
    let multiHorizon: MultiHorizonDecision
    let contradictionAnalysis: ContradictionAnalysis
    let regimeContext: RegimeDecisionContext
    let eventContext: EventDecisionContext
    let calibratedConfidence: Double
    let timestamp: Date
    
    var shouldProceed: Bool {
        calibratedConfidence > 0.45 && !contradictionAnalysis.hasContradictions || contradictionAnalysis.severity != .high
    }
    
    var riskWarning: String? {
        if contradictionAnalysis.hasContradictions {
            return contradictionAnalysis.recommendation
        }
        if eventContext.hasHighImpactEvent {
            return "Yuksek etkili olay yaklasti"
        }
        if regimeContext.riskScore > 0.6 {
            return "Piyasa risk ortami yuksek"
        }
        return nil
    }
}
