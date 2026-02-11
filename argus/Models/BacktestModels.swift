import Foundation

// MARK: - Backtest Configuration
struct BacktestConfig: Sendable {
    let initialCapital: Double
    let strategy: StrategyType
    let startDate: Date? // If nil, use all available
    let stopLossPct: Double
    let executionModel: ExecutionModelConfig // NEW: Realistic execution
    
    nonisolated init(
        initialCapital: Double = 10_000,
        strategy: StrategyType = .argusStandard,
        stopLossPct: Double = 0.07,
        startDate: Date? = nil,
        executionModel: ExecutionModelConfig = .realistic
    ) {
        self.initialCapital = initialCapital
        self.strategy = strategy
        self.stopLossPct = stopLossPct
        self.startDate = startDate
        self.executionModel = executionModel
    }
    
    enum StrategyType: String, CaseIterable, Sendable, Codable {
        case argusStandard = "Argus Standard"
        case orionV2 = "Orion V2 (Tech Only)"
        case aggressive = "Aggressive (Phoenix)"
        case conservative = "Conservative (Safe)"
        case buyAndHold = "Buy & Hold"
        
        // Advanced TA Strategies (Library Grade)
        case rsiMeanReversion = "RSI Reversion"
        case goldenCross = "Golden Cross"
        case bollingerBreakout = "Bollinger Breakout"
        case sarTrend = "Parabolic SAR"
        case phoenixChannel = "Phoenix Channel (Mean Rev)"
    }
}

// MARK: - Legacy Trade Action (Moved from ArgusBacktestEngine)
enum TradeAction: String, Sendable {
    case buy = "BUY"
    case sell = "SELL"
    case hold = "HOLD"
}

extension TradeAction: Codable {
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "buy": self = .buy
        case "sell": self = .sell
        default: self = .hold
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .buy: try container.encode("buy", forKey: .type)
        case .sell: try container.encode("sell", forKey: .type)
        case .hold: try container.encode("hold", forKey: .type)
        }
    }
}

// MARK: - Execution Model Config (Sendable wrapper)
struct ExecutionModelConfig: Sendable {
    let slippagePct: Double
    let commissionPct: Double
    let fixedCommission: Double
    
    static let ideal = ExecutionModelConfig(slippagePct: 0, commissionPct: 0, fixedCommission: 0)
    static let realistic = ExecutionModelConfig(slippagePct: 0.03, commissionPct: 0.10, fixedCommission: 0)
    static let conservative = ExecutionModelConfig(slippagePct: 0.08, commissionPct: 0.20, fixedCommission: 2.0)
    
    func calculateBuyPrice(marketPrice: Double) -> Double {
        marketPrice * (1.0 + slippagePct / 100.0)
    }
    
    func calculateSellPrice(marketPrice: Double) -> Double {
        marketPrice * (1.0 - slippagePct / 100.0)
    }
    
    func calculateCommission(tradeValue: Double) -> Double {
        fixedCommission + (tradeValue * commissionPct / 100.0)
    }
}

// MARK: - Backtest Log
struct BacktestDayLog: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let price: Double
    let score: Double
    let action: String
    let details: String
    
    init(date: Date, price: Double, score: Double, action: String, details: String) {
        self.id = UUID()
        self.date = date
        self.price = price
        self.score = score
        self.action = action
        self.details = details
    }
}

// MARK: - Backtest Result
struct BacktestResult: Identifiable, Sendable {
    let id = UUID()
    let symbol: String
    let config: BacktestConfig
    
    let finalCapital: Double
    let totalReturn: Double // Percentage
    let trades: [BacktestTrade]
    let winRate: Double
    let candles: [Candle] // For visualization
    let maxDrawdown: Double
    let equityCurve: [EquityPoint]
    let logs: [BacktestDayLog]
    
    // Execution Costs
    let totalSlippage: Double
    let totalCommission: Double
    
    init(symbol: String, config: BacktestConfig, finalCapital: Double, totalReturn: Double, trades: [BacktestTrade], winRate: Double, candles: [Candle], maxDrawdown: Double, equityCurve: [EquityPoint], logs: [BacktestDayLog], totalSlippage: Double = 0, totalCommission: Double = 0) {
        self.symbol = symbol
        self.config = config
        self.finalCapital = finalCapital
        self.totalReturn = totalReturn
        self.trades = trades
        self.winRate = winRate
        self.candles = candles
        self.maxDrawdown = maxDrawdown
        self.equityCurve = equityCurve
        self.logs = logs
        self.totalSlippage = totalSlippage
        self.totalCommission = totalCommission
    }
    
    // Trade Log Helper
    var tradeLog: [BacktestTrade] { trades }
    
    var profitFactor: Double {
        let wins = trades.filter { $0.pnl > 0 }.map(\.pnl).reduce(0, +)
        let losses = abs(trades.filter { $0.pnl < 0 }.map(\.pnl).reduce(0, +))
        return losses == 0 ? wins : wins / losses
    }
    
    var totalReturnPct: Double { totalReturn }
    var totalTrades: Int { trades.count }
    
    var totalExecutionCost: Double { totalSlippage + totalCommission }
    var executionCostPct: Double { 
        config.initialCapital > 0 ? totalExecutionCost / config.initialCapital * 100.0 : 0 
    }
    
    // Gross vs Net return
    var grossReturn: Double { totalReturn + executionCostPct }
    
    /// Convert to ModuleBacktestSummary for cache storage
    func toModuleSummary() -> ModuleBacktestSummary {
        ModuleBacktestSummary(
            winRate: winRate,
            tradeCount: trades.count,
            totalReturn: totalReturn,
            maxDrawdown: maxDrawdown,
            profitFactor: profitFactor,
            avgHoldingDays: nil,
            bestTrade: trades.max(by: { $0.pnlPercent < $1.pnlPercent })?.pnlPercent,
            worstTrade: trades.min(by: { $0.pnlPercent < $1.pnlPercent })?.pnlPercent
        )
    }
    
    // MARK: - Advanced Metrics for Walk-Forward Analysis
    
    var avgTrade: Double {
        guard !trades.isEmpty else { return 0.0 }
        let totalPnl = trades.map(\.pnl).reduce(0, +)
        return totalPnl / Double(trades.count)
    }
    
    var annualizedReturn: Double {
        guard let start = equityCurve.first?.date, let end = equityCurve.last?.date else { return 0.0 }
        let days = end.timeIntervalSince(start) / 86400.0
        guard days > 0 else { return 0.0 }
        let years = days / 365.25
        return pow((finalCapital / config.initialCapital), 1.0 / years) - 1.0
    }
    
    var volatility: Double {
        guard equityCurve.count > 1 else { return 0.0 }
        var dailyReturns: [Double] = []
        for i in 1..<equityCurve.count {
            let prev = equityCurve[i-1].value
            let curr = equityCurve[i].value
            let ret = (curr - prev) / prev
            dailyReturns.append(ret)
        }
        
        let mean = dailyReturns.reduce(0, +) / Double(dailyReturns.count)
        let sumSquaredDiffs = dailyReturns.map { pow($0 - mean, 2) }.reduce(0, +)
        let variance = sumSquaredDiffs / Double(dailyReturns.count - 1)
        return sqrt(variance) * sqrt(252) // Annualized Volatility
    }
    
    var sharpeRatio: Double {
        let vol = volatility
        return vol == 0 ? 0 : annualizedReturn / vol
    }
}

struct EquityPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Trade Record
typealias SimulatedTrade = BacktestTrade 

struct BacktestTrade: Identifiable, Sendable {
    let id = UUID()
    let entryDate: Date
    let exitDate: Date
    let entryPrice: Double
    let exitPrice: Double
    let quantity: Double
    let type: TradeType
    let exitReason: String
    
    // Execution costs
    let slippage: Double
    let commission: Double
    
    init(entryDate: Date, exitDate: Date, entryPrice: Double, exitPrice: Double, quantity: Double, type: TradeType, exitReason: String, slippage: Double = 0, commission: Double = 0) {
        self.entryDate = entryDate
        self.exitDate = exitDate
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.quantity = quantity
        self.type = type
        self.exitReason = exitReason
        self.slippage = slippage
        self.commission = commission
    }
    
    var grossPnl: Double {
        (exitPrice - entryPrice) * quantity
    }
    
    var pnl: Double {
        grossPnl - slippage - commission
    }
    
    var pnlPercent: Double {
        entryPrice > 0 ? pnl / (entryPrice * quantity) * 100.0 : 0
    }
    
    var executionCost: Double {
        slippage + commission
    }
    
    enum TradeType: String, Sendable {
        case long = "Long"
    }
}

