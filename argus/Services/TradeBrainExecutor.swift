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
    
    private var cancellables = Set<AnyCancellable>()
    private var lastExecutionTime: [String: Date] = [:]  // Cooldown tracking
    
    private let cooldownSeconds: TimeInterval = 300  // 5 dakika
    
    private init() {}
    
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
        var skippedNoPrice = 0
        
        for (symbol, decision) in decisions {
            processedCount += 1
            
            // Cooldown kontrolü
            if let lastTime = lastExecutionTime[symbol],
               Date().timeIntervalSince(lastTime) < cooldownSeconds {
                skippedCooldown += 1
                debugSkip(symbol: symbol, reason: "cooldown aktif")
                continue
            }
            
            let currentPrice = quotes[symbol]?.currentPrice ?? candles[symbol]?.last?.close ?? 0
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
                        candles: candles[symbol] ?? []
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
        
        print("📊 TradeBrainExecutor: Özet - İşlenen: \(processedCount), Cooldown: \(skippedCooldown), Fiyat Yok: \(skippedNoPrice)")
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
        candles: [Candle]
    ) async {
        print("💰 executeBuy: \(symbol) - Fiyat: \(currentPrice)")
        
        let isBist = SymbolResolver.shared.isBistSymbol(symbol)
        let availableBalance = isBist ? bistBalance : balance
        
        print("💰 executeBuy: Available Balance = \(availableBalance), isBist = \(isBist)")
        
        // 1. ALLOCATION HESAPLA
        let allocation: Double
        let minTradeAmount: Double
        
        if isBist {
            allocation = availableBalance * 0.05  // %5
            minTradeAmount = 1000.0
            print("💰 executeBuy: BIST Allocation = %5 of ₺\(availableBalance) = ₺\(allocation)")
        } else {
            allocation = availableBalance * 0.10  // %10
            minTradeAmount = 50.0
            print("💰 executeBuy: Global Allocation = %10 of $\(availableBalance) = $\(allocation)")
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
            aether: nil as Double?,
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
    
    // MARK: - Public API
    
    func clearLogs() {
        executionLogs.removeAll()
    }
    
    func resetCooldowns() {
        lastExecutionTime.removeAll()
    }
}
