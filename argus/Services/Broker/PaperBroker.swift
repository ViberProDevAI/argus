import Foundation

fileprivate extension ExecutionModel {
    static var defaultModel: ExecutionModel { .marketWrapper } // plain, non-isolated default
}

// MARK: - Paper Broker
/// Simulated broker for paper trading - gerçek para kullanmadan test

actor PaperBroker: BrokerProtocol {
    static let shared = PaperBroker()
    
    // MARK: - Properties
    
    let name = "Paper Broker"
    
    private var cash: Double = 100_000.0
    private var positions: [String: PaperPosition] = [:]
    private var orderStateMachine = OrderStateMachine()
    private var executionModel: ExecutionModel = .defaultModel // Safe default, configured later
    private var tradeHistory: [PaperTrade] = []
    
    var isConnected: Bool { true }
    
    // MARK: - Configuration
    
    func configure(initialCash: Double, executionModel: ExecutionModel) {
        self.cash = initialCash
        self.executionModel = executionModel
    }
    
    func reset() {
        cash = 100_000.0
        positions = [:]
        tradeHistory = []
    }
    
    // MARK: - Order Execution
    
    func placeMarketOrder(
        symbol: String,
        side: OrderSide,
        quantity: Double
    ) async throws -> OrderResult {
        
        // Get current quote (simulated)
        let quote = try await getQuote(symbol: symbol)
        
        // Calculate execution price with slippage
        let executionPrice: Double = {
            switch side {
            case .buy:
                return executionModel.calculateBuyPrice(marketPrice: quote.ask)
            case .sell:
                return executionModel.calculateSellPrice(marketPrice: quote.bid)
            }
        }()
        
        // Validate
        try validateOrder(symbol: symbol, side: side, quantity: quantity, price: executionPrice)
        
        // Create order
        var order = await orderStateMachine.createOrder(
            symbol: symbol,
            side: side,
            type: .market,
            quantity: quantity
        )
        
        // Simulate instant fill for market order
        let tradeValue = executionPrice * quantity
        let commission = executionModel.calculateCommission(tradeValue: tradeValue)
        
        // Update positions and cash
        switch side {
        case .buy:
            cash -= (tradeValue + commission)
            updatePosition(symbol: symbol, quantity: quantity, price: executionPrice)
            
        case .sell:
            cash += (tradeValue - commission)
            updatePosition(symbol: symbol, quantity: -quantity, price: executionPrice)
        }
        
        // Fill the order
        await orderStateMachine.fill(order.id, quantity: quantity, price: executionPrice)
        order = await orderStateMachine.getOrder(order.id) ?? order
        
        // Record trade
        let trade = PaperTrade(
            id: UUID(),
            orderId: order.id,
            symbol: symbol,
            side: side,
            quantity: quantity,
            price: executionPrice,
            commission: commission,
            timestamp: Date()
        )
        tradeHistory.append(trade)
        
        // Log to audit
        Task {
            await AuditLogService.shared.recordTrade(
                symbol: symbol,
                action: side == .buy ? .buy : .sell,
                requestedQuantity: quantity,
                executedQuantity: quantity,
                requestedPrice: side == .buy ? quote.ask : quote.bid,
                executedPrice: executionPrice,
                slippage: abs(executionPrice - (side == .buy ? quote.ask : quote.bid)) * quantity,
                commission: commission,
                decisionId: nil,
                triggerReason: "Paper Trade - Market Order",
                moduleScoresAtEntry: nil
            )
        }
        
        // ADD NOTIFICATION (NEW!)
        let notification = ArgusNotification(
            symbol: symbol,
            headline: side == .buy ? "📈 \(symbol) ALINDI" : "📉 \(symbol) SATILDI",
            summary: "\(Int(quantity)) adet \(side == .buy ? "alındı" : "satıldı") @ $\(String(format: "%.2f", executionPrice))",
            detailedReport: """
                ## 💰 İşlem Detayları
                
                **Sembol:** \(symbol)
                **İşlem:** \(side == .buy ? "ALIM" : "SATIM")
                **Miktar:** \(Int(quantity)) adet
                **Fiyat:** $\(String(format: "%.2f", executionPrice))
                **Toplam:** $\(String(format: "%.2f", tradeValue))
                **Komisyon:** $\(String(format: "%.2f", commission))
                
                ---
                *Paper Trading - Simülasyon*
                """,
            score: 100,
            type: .tradeExecuted
        )
        NotificationStore.shared.addNotification(notification)
        
        print("📝 Paper: \(side.rawValue) \(Int(quantity)) \(symbol) @ \(String(format: "%.2f", executionPrice))")
        
        return OrderResult(
            orderId: order.id,
            status: .filled,
            message: "Market order filled",
            filledQuantity: quantity,
            avgFillPrice: executionPrice,
            commission: commission,
            timestamp: Date()
        )
    }
    
    func placeLimitOrder(
        symbol: String,
        side: OrderSide,
        quantity: Double,
        limitPrice: Double
    ) async throws -> OrderResult {
        
        // Validate
        try validateOrder(symbol: symbol, side: side, quantity: quantity, price: limitPrice)
        
        // Create order (pending)
        let order = await orderStateMachine.createOrder(
            symbol: symbol,
            side: side,
            type: .limit,
            quantity: quantity,
            price: limitPrice
        )
        
        await orderStateMachine.updateStatus(order.id, status: .submitted)
        
        print("📝 Paper: Limit \(side.rawValue) \(Int(quantity)) \(symbol) @ \(String(format: "%.2f", limitPrice)) submitted")
        
        // Note: Limit orders would be checked periodically against market price
        // For now, we just submit them
        
        return OrderResult(
            orderId: order.id,
            status: .submitted,
            message: "Limit order submitted",
            filledQuantity: 0,
            avgFillPrice: nil,
            commission: 0,
            timestamp: Date()
        )
    }
    
    func placeStopOrder(
        symbol: String,
        side: OrderSide,
        quantity: Double,
        stopPrice: Double
    ) async throws -> OrderResult {
        
        // Validate
        try validateOrder(symbol: symbol, side: side, quantity: quantity, price: stopPrice)
        
        // Create order (pending)
        let order = await orderStateMachine.createOrder(
            symbol: symbol,
            side: side,
            type: .stop,
            quantity: quantity,
            stopPrice: stopPrice
        )
        
        await orderStateMachine.updateStatus(order.id, status: .submitted)
        
        print("📝 Paper: Stop \(side.rawValue) \(Int(quantity)) \(symbol) @ \(String(format: "%.2f", stopPrice)) submitted")
        
        return OrderResult(
            orderId: order.id,
            status: .submitted,
            message: "Stop order submitted",
            filledQuantity: 0,
            avgFillPrice: nil,
            commission: 0,
            timestamp: Date()
        )
    }
    
    func cancelOrder(orderId: String) async throws -> Bool {
        guard let order = await orderStateMachine.getOrder(orderId) else {
            throw BrokerError.orderNotFound(orderId)
        }
        
        guard !order.status.isTerminal else {
            return false
        }
        
        await orderStateMachine.updateStatus(orderId, status: .cancelled)
        print("📝 Paper: Order \(orderId) cancelled")
        return true
    }
    
    func getOrderStatus(orderId: String) async throws -> OrderStatus {
        guard let order = await orderStateMachine.getOrder(orderId) else {
            throw BrokerError.orderNotFound(orderId)
        }
        return order.status
    }
    
    func getOpenOrders() async throws -> [Order] {
        await orderStateMachine.getOpenOrders()
    }
    
    // MARK: - Position Management
    
    private func updatePosition(symbol: String, quantity: Double, price: Double, engine: AutoPilotEngine = .pulse, exitReason: String = "Manual", scores: (orion: Double?, atlas: Double?, aether: Double?, phoenix: Double?) = (nil, nil, nil, nil)) {
        if var existing = positions[symbol] {
            let newQty = existing.quantity + quantity
            
            if abs(newQty) < 0.0001 {
                // Position closed - LOG TO CHIRON!
                let entryPrice = existing.avgCost
                let exitPrice = price
                let pnlPercent = entryPrice > 0 ? ((exitPrice - entryPrice) / entryPrice) * 100.0 : 0
                
                let tradeRecord = TradeOutcomeRecord(
                    id: UUID(),
                    symbol: symbol,
                    engine: existing.engine,
                    entryDate: existing.entryDate,
                    exitDate: Date(),
                    entryPrice: entryPrice,
                    exitPrice: exitPrice,
                    pnlPercent: pnlPercent,
                    exitReason: exitReason,
                    orionScoreAtEntry: existing.orionScoreAtEntry,
                    atlasScoreAtEntry: existing.atlasScoreAtEntry,
                    aetherScoreAtEntry: existing.aetherScoreAtEntry,
                    phoenixScoreAtEntry: existing.phoenixScoreAtEntry,
                    allModuleScores: nil,
                    systemDecision: nil,
                    ignoredWarnings: nil,
                    regime: nil
                )
                
                // Save to Chiron DataLake
                Task {
                    await ChironDataLakeService.shared.logTrade(tradeRecord)
                    print("🧠 Chiron: Trade logged - \(symbol) PnL: \(String(format: "%.1f", pnlPercent))%")
                }
                
                positions.removeValue(forKey: symbol)
            } else {
                // Update average cost
                let newAvgCost: Double
                if quantity > 0 {
                    // Adding to position
                    newAvgCost = (existing.avgCost * existing.quantity + price * quantity) / newQty
                } else {
                    // Reducing position (keep same avgCost)
                    newAvgCost = existing.avgCost
                }
                
                existing = PaperPosition(
                    symbol: symbol,
                    quantity: newQty,
                    avgCost: newAvgCost,
                    entryDate: existing.entryDate,
                    engine: existing.engine,
                    orionScoreAtEntry: existing.orionScoreAtEntry,
                    atlasScoreAtEntry: existing.atlasScoreAtEntry,
                    aetherScoreAtEntry: existing.aetherScoreAtEntry,
                    phoenixScoreAtEntry: existing.phoenixScoreAtEntry
                )
                positions[symbol] = existing
            }
        } else if quantity > 0 {
            // New position - capture entry scores
            positions[symbol] = PaperPosition(
                symbol: symbol,
                quantity: quantity,
                avgCost: price,
                entryDate: Date(),
                engine: engine,
                orionScoreAtEntry: scores.orion,
                atlasScoreAtEntry: scores.atlas,
                aetherScoreAtEntry: scores.aether,
                phoenixScoreAtEntry: scores.phoenix
            )
        }
    }
    
    func getPositions() async throws -> [BrokerPosition] {
        var result: [BrokerPosition] = []
        
        for (symbol, pos) in positions {
            let quote = try await getQuote(symbol: symbol)
            let marketValue = pos.quantity * quote.last
            let unrealizedPnL = (quote.last - pos.avgCost) * pos.quantity
            let unrealizedPnLPct = pos.avgCost > 0 ? (quote.last - pos.avgCost) / pos.avgCost * 100 : 0
            
            result.append(BrokerPosition(
                symbol: symbol,
                quantity: pos.quantity,
                avgCost: pos.avgCost,
                currentPrice: quote.last,
                marketValue: marketValue,
                unrealizedPnL: unrealizedPnL,
                unrealizedPnLPct: unrealizedPnLPct
            ))
        }
        
        return result
    }
    
    // MARK: - Account Info
    
    func getAccountInfo() async throws -> AccountInfo {
        let positions = try await getPositions()
        let portfolioValue = positions.reduce(0.0) { $0 + $1.marketValue }
        
        return AccountInfo(
            accountId: "PAPER_001",
            currency: "USD",
            equity: cash + portfolioValue,
            cash: cash,
            buyingPower: cash,
            portfolioValue: portfolioValue,
            dayTradeCount: 0,
            patternDayTrader: false,
            tradingBlocked: false,
            updatedAt: Date()
        )
    }
    
    // MARK: - Market Data (Simulated)
    
    func getQuote(symbol: String) async throws -> BrokerQuote {
        // In real implementation, this would fetch from market data provider
        // For paper trading, we need to integrate with existing data sources
        
        // Placeholder - should be replaced with actual data fetch
        let basePrice = 100.0 // Would come from Yahoo/other provider
        let spread = basePrice * 0.001 // 0.1% spread
        
        return BrokerQuote(
            symbol: symbol,
            bid: basePrice - spread / 2,
            ask: basePrice + spread / 2,
            last: basePrice,
            volume: 1_000_000,
            timestamp: Date()
        )
    }
    
    // MARK: - Validation
    
    private func validateOrder(symbol: String, side: OrderSide, quantity: Double, price: Double) throws {
        switch side {
        case .buy:
            let requiredCash = price * quantity * 1.01 // 1% buffer for commission
            if cash < requiredCash {
                throw BrokerError.insufficientFunds
            }
            
        case .sell:
            let currentQty = positions[symbol]?.quantity ?? 0
            if currentQty < quantity {
                throw BrokerError.insufficientShares
            }
        }
        
        if quantity <= 0 {
            throw BrokerError.orderRejected("Quantity must be positive")
        }
    }
    
    // MARK: - Trade History
    
    func getTradeHistory(limit: Int = 50) -> [PaperTrade] {
        Array(tradeHistory.suffix(limit).reversed())
    }
    
    func getTradeHistory(for symbol: String) -> [PaperTrade] {
        tradeHistory.filter { $0.symbol == symbol }
    }
    
    // MARK: - Performance Metrics
    
    func calculatePerformance() async throws -> PaperPerformance {
        let account = try await getAccountInfo()
        let initialValue = 100_000.0
        
        let totalReturn = (account.equity - initialValue) / initialValue * 100
        
        let wins = tradeHistory.filter { trade in
            // Simplified - would need to match entry/exit trades
            true
        }.count
        
        let winRate = tradeHistory.isEmpty ? 0 : Double(wins) / Double(tradeHistory.count) * 100
        
        var totalCommission = 0.0
        let totalSlippage = 0.0 // Placeholder
        
        for trade in tradeHistory {
            totalCommission += trade.commission
            // Slippage would need to be calculated from original quote
        }
        
        return PaperPerformance(
            initialValue: initialValue,
            currentValue: account.equity,
            totalReturn: totalReturn,
            totalTrades: tradeHistory.count,
            winRate: winRate,
            totalCommission: totalCommission,
            totalSlippage: totalSlippage,
            generatedAt: Date()
        )
    }
}

// MARK: - Paper Trading Models

struct PaperPosition {
    let symbol: String
    var quantity: Double
    var avgCost: Double
    
    // Entry tracking for Chiron learning
    var entryDate: Date = Date()
    var engine: AutoPilotEngine = .pulse
    var orionScoreAtEntry: Double? = nil
    var atlasScoreAtEntry: Double? = nil
    var aetherScoreAtEntry: Double? = nil
    var phoenixScoreAtEntry: Double? = nil
}

struct PaperTrade: Codable, Identifiable {
    let id: UUID
    let orderId: String
    let symbol: String
    let side: OrderSide
    let quantity: Double
    let price: Double
    let commission: Double
    let timestamp: Date
    
    var value: Double {
        quantity * price
    }
}

struct PaperPerformance: Codable {
    let initialValue: Double
    let currentValue: Double
    let totalReturn: Double
    let totalTrades: Int
    let winRate: Double
    let totalCommission: Double
    let totalSlippage: Double
    let generatedAt: Date
}

