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
        macroScore: Double?,
        orionScores: [String: OrionScoreResult],
        candles: [String: [Candle]]
    ) async {
        guard isEnabled else { return }
        
        ArgusLogger.info("TradeBrainExecutor: \(decisions.count) karar değerlendiriliyor...", category: "TRADEBRAIN")
        
        let openTrades = portfolio.filter { $0.isOpen }
        let openSymbols = Set(openTrades.map { $0.symbol })
        let openTradeMap = Dictionary(uniqueKeysWithValues: openTrades.map { ($0.symbol, $0) })
        let aetherScore = macroScore ?? 50
        let policy = RiskEscapePolicy.from(aetherScore: aetherScore)

        // ── YENİ: Velocity Engine'e Aether kaydı ──────────────────────────
        await AetherVelocityEngine.shared.record(score: aetherScore)
        let velocityAnalysis = await AetherVelocityEngine.shared.analyze()
        if let alert = velocityAnalysis.crossingAlert {
            ArgusLogger.info("⚡ Aether Velocity: \(alert.description)", category: "TRADEBRAIN")
        }

        // ── YENİ: Kelly profili (async, cache'li) ─────────────────────────
        let kellyProfile = await KellyCache.shared.getSystemProfile()

        // ── YENİ: Korelasyon bazlı portföy ısısı ──────────────────────────
        let priceHistory: [String: [Double]] = Dictionary(uniqueKeysWithValues:
            candles.map { (sym, cndls) in (sym, cndls.map { $0.close }) }
        )
        let correlResult = CorrelationHeatGate.assess(portfolio: portfolio, priceHistory: priceHistory)
        if correlResult.concentrationRisk != .healthy {
            ArgusLogger.warn("📊 Korelasyon: \(correlResult.concentrationRisk.label) — \(correlResult.rawPositionCount) pozisyon → \(Int(correlResult.effectivePositionCount)) bağımsız risk", category: "TRADEBRAIN")
        }
        
        ArgusLogger.info("TradeBrainExecutor: \(openSymbols.count) açık pozisyon", category: "TRADEBRAIN")
        ArgusLogger.warn("TradeBrainPolicy: \(policy.mode.rawValue) | \(policy.reason)", category: "TRADEBRAIN")
        
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
            ArgusLogger.info(
                "TradeBrainProfile[\(symbol)] tier=\(profile.tier.rawValue) " +
                "alloc×\(String(format: "%.2f", profile.allocationMultiplier)) " +
                "cooldown×\(String(format: "%.2f", profile.cooldownMultiplier)) " +
                "minConf=\(String(format: "%.2f", profile.minDecisionConfidence))",
                category: "TRADEBRAIN"
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
            let isSafeSymbol = isSafeAsset(symbol)
            
            ArgusLogger.info("TradeBrainExecutor: \(symbol) - Action: \(decision.action.rawValue), OpenPos: \(hasOpenPosition)", category: "TRADEBRAIN")

            if hasOpenPosition,
               policy.mode != .normal,
               !isSafeSymbol,
               let trade = openTradeMap[symbol] {
                let trimPercent = forcedTrimPercent(
                    policy: policy,
                    trade: trade,
                    currentPrice: currentPrice,
                    volatility: estimateVolatility(candles: symbolCandles, referencePrice: currentPrice)
                )
                await executePolicyReduce(
                    trade: trade,
                    trimPercent: trimPercent,
                    currentPrice: currentPrice,
                    policy: policy
                )
                continue
            }
            
            // ALIM KARARLARI
            if !hasOpenPosition {
                if decision.action == .aggressiveBuy || decision.action == .accumulate {
                    if policy.blockRiskyBuys && !isSafeSymbol {
                        // ── YENİ: Velocity override — kriz'den çıkış başlıyorsa küçük giriş izni
                        let velocityAllowsEntry = velocityAnalysis.signal == .recoveringFast ||
                                                  velocityAnalysis.signal == .recovering
                        if !velocityAllowsEntry {
                            await OpportunityCostTracker.shared.recordSkip(
                                symbol: symbol, price: currentPrice,
                                reason: .aetherTooLow, aetherScore: aetherScore
                            )
                            debugSkip(symbol: symbol, reason: "policy riskli alimi kapatti (\(policy.mode.rawValue))")
                            continue
                        }
                        ArgusLogger.info("⚡ Velocity override: \(symbol) kriz'de ama Aether iyileşiyor (\(velocityAnalysis.signal.rawValue))", category: "TRADEBRAIN")
                    }

                    // ── YENİ: Korelasyon kontrolü
                    if correlResult.concentrationRisk == .critical {
                        await OpportunityCostTracker.shared.recordSkip(
                            symbol: symbol, price: currentPrice,
                            reason: .portfolioHot, aetherScore: aetherScore
                        )
                        debugSkip(symbol: symbol, reason: "korelasyon kritik: portföy tek risk faktörüne bağlı")
                        continue
                    }

                    if decision.confidence < profile.minDecisionConfidence {
                        skippedLowConfidence += 1
                        await OpportunityCostTracker.shared.recordSkip(
                            symbol: symbol, price: currentPrice,
                            reason: .lowConfidence, aetherScore: aetherScore
                        )
                        debugSkip(
                            symbol: symbol,
                            reason: "güven düşük (\(String(format: "%.2f", decision.confidence)) < \(String(format: "%.2f", profile.minDecisionConfidence)))"
                        )
                        continue
                    }
                    ArgusLogger.info("TradeBrainExecutor: ALIM yapılıyor: \(symbol)", category: "TRADEBRAIN")
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
                        profile: profile,
                        kellyProfile: kellyProfile,
                        velocityAnalysis: velocityAnalysis,
                        correlMultiplier: correlResult.positionMultiplier
                    )
                } else {
                    ArgusLogger.warn("TradeBrainExecutor: \(symbol) - Action \(decision.action.rawValue) alım için değil", category: "TRADEBRAIN")
                    debugSkip(symbol: symbol, reason: "aksiyon alım değil (\(decision.action.rawValue))")
                }
            } else {
                ArgusLogger.warn("TradeBrainExecutor: \(symbol) - Zaten açık pozisyon var, alım yapılmayacak", category: "TRADEBRAIN")
                debugSkip(symbol: symbol, reason: "zaten açık pozisyon var")
            }
            
            // SATIM KARARLARI (Plan bazlı - Trade Brain)
            // Not: Satım artık PositionPlanStore.checkTriggers() ile yapılıyor
            // Burada sadece acil durum satışları (liquidate) yapalım
            if hasOpenPosition && decision.action == .liquidate {
                if let trade = openTrades.first(where: { $0.symbol == symbol }) {
                    ArgusLogger.warn("TradeBrainExecutor: ACİL SATIŞ: \(symbol)", category: "TRADEBRAIN")
                    await executeEmergencySell(
                        trade: trade,
                        decision: decision,
                        currentPrice: currentPrice
                    )
                }
            }
        }
        
        ArgusLogger.info(
            "TradeBrainExecutor: Özet - İşlenen: \(processedCount), " +
            "Cooldown: \(skippedCooldown), Güven: \(skippedLowConfidence), Fiyat Yok: \(skippedNoPrice)",
            category: "TRADEBRAIN"
        )

        if policy.mode != .normal {
            for trade in openTrades where !decisions.keys.contains(trade.symbol) && !isSafeAsset(trade.symbol) {
                guard let currentPrice = quotes[trade.symbol]?.currentPrice, currentPrice > 0 else { continue }
                let symbolCandles = candles[trade.symbol] ?? []
                let trimPercent = forcedTrimPercent(
                    policy: policy,
                    trade: trade,
                    currentPrice: currentPrice,
                    volatility: estimateVolatility(candles: symbolCandles, referencePrice: currentPrice)
                )
                await executePolicyReduce(
                    trade: trade,
                    trimPercent: trimPercent,
                    currentPrice: currentPrice,
                    policy: policy
                )
            }
        }

        if policy.forceSafeOnlyBuys {
            executeSafeAllocationOrders(
                policy: policy,
                openSymbols: openSymbols,
                quotes: quotes,
                globalBalance: balance,
                bistBalance: bistBalance
            )
        }

        // ── YENİ: Crisis Alpha — kriz ortamında scalp fırsatları tara
        if aetherScore < 35 {
            let crisisContext = CrisisAlphaScanner.CrisisContext(
                aetherScore: aetherScore,
                isActiveCrisis: true
            )
            let watchlistSymbols = Array(decisions.keys.filter { !openSymbols.contains($0) })
            let alphaOpportunities = CrisisAlphaScanner.scan(
                symbols: watchlistSymbols,
                quotes: quotes,
                candleHistory: candles,
                context: crisisContext
            )
            for opp in alphaOpportunities {
                ArgusLogger.info("🎯 CrisisAlpha: \(opp.summary)", category: "TRADEBRAIN")
                guard let decision = decisions[opp.symbol] else { continue }
                let crisisProfile = SymbolExecutionProfile(
                    symbol: opp.symbol,
                    tier: .defensive,
                    allocationMultiplier: opp.positionSizeMultiplier,
                    cooldownMultiplier: 1.0,
                    minDecisionConfidence: 0.3,
                    notes: ["CrisisAlpha: \(opp.opportunityType.rawValue)"]
                )
                await executeBuy(
                    symbol: opp.symbol,
                    decision: decision,
                    currentPrice: opp.suggestedEntry,
                    balance: balance,
                    bistBalance: bistBalance,
                    portfolio: portfolio,
                    quotes: quotes,
                    orionScore: 50,
                    candles: candles[opp.symbol] ?? [],
                    profile: crisisProfile,
                    kellyProfile: nil,
                    velocityAnalysis: velocityAnalysis,
                    correlMultiplier: correlResult.positionMultiplier
                )
            }
        }
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
        profile: SymbolExecutionProfile,
        kellyProfile: KellyCriterionSizer.KellyProfile? = nil,
        velocityAnalysis: AetherVelocityEngine.VelocityAnalysis? = nil,
        correlMultiplier: Double = 1.0
    ) async {
        ArgusLogger.info("executeBuy: \(symbol) - Fiyat: \(currentPrice)", category: "TRADEBRAIN")

        let isBist = SymbolResolver.shared.isBistSymbol(symbol)
        let availableBalance = isBist ? bistBalance : balance

        ArgusLogger.info("executeBuy: Available Balance = \(availableBalance), isBist = \(isBist)", category: "TRADEBRAIN")

        // 1. ALLOCATION HESAPLA
        let regimeAetherScore = MacroRegimeService.shared.getCachedRating()?.numericScore ?? 50
        let currentRegime = ChironRegimeEngine.shared.globalResult.regime

        // Temel rejim çarpanı
        var regimeMultiplier = RegimePositionSizer.multiplier(aetherScore: regimeAetherScore, regime: currentRegime)

        // ── YENİ: Velocity düzeltmesi — kriz'den çıkışta veya bozulmada ayar
        if let vel = velocityAnalysis {
            regimeMultiplier = await AetherVelocityEngine.shared.velocityAdjustedMultiplier(base: regimeMultiplier)
            ArgusLogger.info("⚡ Velocity: \(vel.signal.rawValue) → çarpan: \(String(format: "%.2f", regimeMultiplier))", category: "TRADEBRAIN")
        }

        // ── YENİ: Kelly çarpanı — Alkindus geçmişine dayalı boyut
        let kellyMultiplier = kellyProfile?.positionMultiplier ?? 1.0

        // ── YENİ: Korelasyon çarpanı — portföy konsantrasyonu
        let finalMultiplier = regimeMultiplier * kellyMultiplier * correlMultiplier
        ArgusLogger.info("📐 Çarpanlar: Rejim×\(String(format: "%.2f", regimeMultiplier)) Kelly×\(String(format: "%.2f", kellyMultiplier)) Korel×\(String(format: "%.2f", correlMultiplier)) → Final×\(String(format: "%.2f", finalMultiplier))", category: "TRADEBRAIN")

        guard finalMultiplier > 0 else {
            log("🛑 \(symbol): Rejim bloğu — Aether:\(Int(regimeAetherScore)) Rejim:\(currentRegime.rawValue)")
            return
        }

        let allocation: Double
        let minTradeAmount: Double

        if isBist {
            let basePercent = 0.05
            let adjustedPercent = basePercent * profile.allocationMultiplier * finalMultiplier
            allocation = availableBalance * adjustedPercent
            minTradeAmount = 1000.0
            ArgusLogger.info(
                "executeBuy: BIST Allocation = %\(Int(adjustedPercent * 100)) " +
                "(\(String(format: "%.2f", profile.allocationMultiplier))x profile, " +
                "\(String(format: "%.2f", finalMultiplier))x final) of ₺\(availableBalance) = ₺\(allocation)",
                category: "TRADEBRAIN"
            )
        } else {
            let basePercent = 0.10
            let adjustedPercent = basePercent * profile.allocationMultiplier * finalMultiplier
            allocation = availableBalance * adjustedPercent
            minTradeAmount = 50.0
            ArgusLogger.info(
                "executeBuy: Global Allocation = %\(Int(adjustedPercent * 100)) " +
                "(\(String(format: "%.2f", profile.allocationMultiplier))x profile, " +
                "\(String(format: "%.2f", finalMultiplier))x final) of $\(availableBalance) = $\(allocation)",
                category: "TRADEBRAIN"
            )
        }
        
        guard allocation >= minTradeAmount else {
            log("⚠️ \(symbol): Yetersiz bakiye (gereken: \(minTradeAmount), mevcut: \(allocation))")
            ArgusLogger.error("executeBuy: Yetersiz bakiye - Gereken: \(minTradeAmount), Mevcut: \(allocation)", category: "TRADEBRAIN")
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
        ArgusLogger.info("executeBuy: \(isBist ? "BIST" : "GLOBAL") açık pozisyon sayısı = \(marketOpenCount)", category: "TRADEBRAIN")
        
        let riskCheck = PortfolioRiskManager.shared.checkBuyRisk(
            symbol: symbol,
            proposedAmount: allocation,
            currentPrice: currentPrice,
            portfolio: marketFilteredPortfolio,
            cashBalance: availableBalance,
            totalEquity: totalEquity
        )
        
        ArgusLogger.info("executeBuy: Risk Check - CanTrade: \(riskCheck.canTrade), Blockers: \(riskCheck.blockers)", category: "TRADEBRAIN")
        
        if !riskCheck.canTrade {
            log("🛑 \(symbol): Risk engeli - \(riskCheck.blockers.joined(separator: ", "))")
            ArgusLogger.error("executeBuy: Risk engeli - \(riskCheck.blockers.joined(separator: ", "))", category: "TRADEBRAIN")
            return
        }
        
        // Uyarıları logla
        for warning in riskCheck.warnings {
            log("⚠️ \(symbol): \(warning)")
            ArgusLogger.warn("executeBuy: \(warning)", category: "TRADEBRAIN")
        }
        
        if let adjustedQty = riskCheck.adjustedQuantity {
            proposedQuantity = adjustedQty
            ArgusLogger.info("executeBuy: Quantity adjusted to \(adjustedQty)", category: "TRADEBRAIN")
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
            ArgusLogger.info("executeBuy: BIST Vali kontrolü yapılıyor...", category: "TRADEBRAIN")
            if let bistDecision = decision.bistDetails {
                let snapshot = BistExecutionGovernor.shared.audit(
                    decision: bistDecision,
                    grandDecisionID: bistDecision.id,
                    currentPrice: currentPrice,
                    portfolio: portfolio,
                    lastTradeTime: nil // Executor zaten cooldown kontrolü yapıyor
                )
                
                ArgusLogger.info("executeBuy: BIST Vali kararı - Action: \(snapshot.action), Reason: \(snapshot.reason)", category: "TRADEBRAIN")
                
                if snapshot.action != .buy {
                    log("🇹🇷 BIST Vali VETO: \(symbol) -> \(snapshot.reason)")
                    ArgusLogger.error("executeBuy: BIST Vali VETO - \(snapshot.reason)", category: "TRADEBRAIN")
                    return // İŞLEM İPTAL
                } else {
                    log("🇹🇷 BIST Vali ONAY: \(symbol)")
                    ArgusLogger.info("executeBuy: BIST Vali ONAY", category: "TRADEBRAIN")
                }
            } else {
                log("⚠️ \(symbol): BIST detayı eksik, Vali kontrolü atlanıyor.")
                ArgusLogger.warn("executeBuy: BIST detayı eksik", category: "TRADEBRAIN")
            }
        }
        
        // 3. TAKVİM KONTROLÜ
        ArgusLogger.info("executeBuy: Takvim kontrolü yapılıyor...", category: "TRADEBRAIN")
        let eventRisk = EventCalendarService.shared.assessPositionRisk(symbol: symbol)
        
        ArgusLogger.info("executeBuy: Event Risk - ShouldAvoid: \(eventRisk.shouldAvoidNewPosition)", category: "TRADEBRAIN")
        
        if eventRisk.shouldAvoidNewPosition {
            log("📅 \(symbol): Takvim engeli - Yaklaşan kritik olay")
            ArgusLogger.error("executeBuy: Takvim engeli", category: "TRADEBRAIN")
            for warning in eventRisk.warnings {
                log("   ⚠️ \(warning)")
                ArgusLogger.warn("executeBuy: \(warning)", category: "TRADEBRAIN")
            }
            return
        }
        
        // 4. GOVERNOR KONTROLÜ
        let scores = (
            atlas: FundamentalScoreStore.shared.getScore(for: symbol)?.totalScore,
            orion: orionScore as Double?,
            aether: max(0, min(100, decision.aetherDecision.netSupport * 100.0)),
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
        
        ArgusLogger.info("executeBuy: Governor input - Market: \(isBist ? "BIST" : "GLOBAL"), Equity: \(String(format: "%.2f", totalEquity)), OpenPos: \(marketFilteredPortfolio.count)", category: "TRADEBRAIN")
        
        ArgusLogger.info("executeBuy: ExecutionGovernor karar bekleniyor...", category: "TRADEBRAIN")
        
        switch governorDecision {
        case .approved(_, let adjustedQty):
            proposedQuantity = adjustedQty
            ArgusLogger.info("executeBuy: ExecutionGovernor ONAY - Quantity: \(adjustedQty)", category: "TRADEBRAIN")
            
        case .rejected(let reason):
            log("🛡️ \(symbol): Governor VETO - \(reason)")
            ArgusLogger.error("executeBuy: ExecutionGovernor VETO - \(reason)", category: "TRADEBRAIN")
            return
        }
        
        // 5. ALIM YAP - Notification ile TradingViewModel'e bildir
        // Not: TradingViewModel.shared kullanılamıyor, NotificationCenter ile çözüyoruz
        ArgusLogger.info("executeBuy: Notification gönderiliyor - Symbol: \(symbol), Qty: \(proposedQuantity), Price: \(currentPrice)", category: "TRADEBRAIN")
        
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
        
        ArgusLogger.info("executeBuy: ALIM EMRİ GÖNDERİLDİ - \(symbol): \(proposedQuantity) @ \(currentPrice)", category: "TRADEBRAIN")
        
        // Cooldown ayarla
        lastExecutionTime[symbol] = Date()
        ArgusLogger.info("executeBuy: Cooldown ayarlandı - \(symbol)", category: "TRADEBRAIN")
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

    private func executePolicyReduce(
        trade: Trade,
        trimPercent: Double,
        currentPrice: Double,
        policy: RiskEscapePolicy
    ) async {
        if trimPercent >= 100 {
            NotificationCenter.default.post(
                name: .tradeBrainSellOrder,
                object: nil,
                userInfo: [
                    "tradeId": trade.id.uuidString,
                    "price": currentPrice,
                    "reason": "POLICY_\(policy.mode.rawValue)_LIQUIDATE"
                ]
            )
            log("🛡️ \(trade.symbol): Policy LIQUIDATE (\(policy.mode.rawValue))")
        } else {
            NotificationCenter.default.post(
                name: .tradeBrainSellOrder,
                object: nil,
                userInfo: [
                    "tradeId": trade.id.uuidString,
                    "price": currentPrice,
                    "trimPercentage": trimPercent,
                    "reason": "POLICY_\(policy.mode.rawValue)_TRIM_\(Int(trimPercent))"
                ]
            )
            log("🛡️ \(trade.symbol): Policy TRIM %\(Int(trimPercent)) (\(policy.mode.rawValue))")
        }
        lastExecutionTime[trade.symbol] = Date()
    }

    private func forcedTrimPercent(
        policy: RiskEscapePolicy,
        trade: Trade,
        currentPrice: Double,
        volatility: Double
    ) -> Double {
        guard trade.entryPrice > 0 else { return policy.minimumTrimPercent }
        let pnlPercent = ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100

        switch policy.mode {
        case .deepRiskOff:
            if pnlPercent <= -4 || volatility >= 0.06 { return 100 }
            return max(policy.minimumTrimPercent, 50)
        case .riskOff:
            if pnlPercent <= -6 || volatility >= 0.05 { return 40 }
            return max(policy.minimumTrimPercent, 25)
        case .normal:
            return 0
        }
    }

    private func executeSafeAllocationOrders(
        policy: RiskEscapePolicy,
        openSymbols: Set<String>,
        quotes: [String: Quote],
        globalBalance: Double,
        bistBalance: Double
    ) {
        let safeUniverse = SafeUniverseService.shared
        let (_, target) = AetherAllocationEngine.shared.determineAllocation(aetherScore: policy.aetherScore)

        let deployRatio: Double = (policy.mode == .deepRiskOff) ? 0.60 : 0.35
        let globalBudget = globalBalance * deployRatio

        let selectedBond = safeUniverse.getActiveAssets(by: .bond).first?.symbol
        let selectedGold = safeUniverse.getActiveAssets(by: .gold).first?.symbol
        let selectedHedge = safeUniverse.getActiveAssets(by: .hedge).first?.symbol

        var orders: [SafeAllocationOrder] = []
        if let bond = selectedBond {
            orders.append(SafeAllocationOrder(symbol: bond, amount: globalBudget * target.bond, type: .bond, reason: "SAFE_ALLOC_BOND"))
        }
        if let gold = selectedGold {
            orders.append(SafeAllocationOrder(symbol: gold, amount: globalBudget * target.gold, type: .gold, reason: "SAFE_ALLOC_GOLD"))
        }
        if policy.mode == .deepRiskOff, let hedge = selectedHedge {
            orders.append(SafeAllocationOrder(symbol: hedge, amount: globalBudget * 0.15, type: .hedge, reason: "SAFE_ALLOC_HEDGE"))
        }

        for order in orders where order.amount > 50 {
            guard !openSymbols.contains(order.symbol) else { continue }
            guard let quote = quotes[order.symbol], quote.currentPrice > 0 else { continue }
            let qty = order.amount / quote.currentPrice
            if qty <= 0 { continue }

            NotificationCenter.default.post(
                name: .tradeBrainBuyOrder,
                object: nil,
                userInfo: [
                    "symbol": order.symbol,
                    "quantity": qty,
                    "price": quote.currentPrice,
                    "reason": order.reason
                ]
            )
            ArgusLogger.info(
                "TradeBrainSafeAllocation: BUY \(order.symbol) amount=\(String(format: "%.2f", order.amount)) policy=\(policy.mode.rawValue)",
                category: "TRADEBRAIN"
            )
        }

        if bistBalance > 0, policy.mode != .normal {
            ArgusLogger.info(
                "TradeBrainSafeAllocation: TRY bakiye riskten korunma modunda nakitte tutuldu (\(String(format: "%.2f", bistBalance)))",
                category: "TRADEBRAIN"
            )
        }
    }

    private func isSafeAsset(_ symbol: String) -> Bool {
        guard let type = SafeUniverseService.shared.getUniverseType(for: symbol) else { return false }
        switch type {
        case .bond, .cashLike, .gold, .hedge:
            return true
        default:
            return false
        }
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
        
        ArgusLogger.info("Trade Brain: \(message)", category: "TRADEBRAIN")
    }

    private func debugSkip(symbol: String, reason: String) {
        ArgusLogger.info("AUTOPILOT-SKIP: \(symbol) -> \(reason)", category: "TRADEBRAIN")
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
        
        ArgusLogger.info("TradeBrain: \(symbol) sonuc kaydedildi - \(wasCorrect ? "BASARILI" : "BASARISIZ")", category: "TRADEBRAIN")
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
