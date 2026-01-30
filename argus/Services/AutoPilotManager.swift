import Foundation
import Combine

// MARK: - AutoPilot: BIST Otomatik Pozisyon Yönetimi
actor AutoPilotManager {
    static let shared = AutoPilotManager()
    
    // MARK: - Models
    
    struct AutoPilotConfig {
        let maxOpenPositions: Int // Maksimum açık pozisyon sayısı
        let maxCapitalPerPosition: Double // Her pozisyon için maksimum sermaye
        let stopLossPercent: Double // Stop-loss yüzdesi
        let takeProfitPercent: Double // Take-profit yüzdesi
        let maxTotalCapital: Double // Maksimum toplam sermaye
        let riskPerTrade: Double // Her işlem için risk yüzdesi
    }
    
    struct Position: Sendable, Identifiable {
        let id = UUID()
        let symbol: String
        let type: PositionType
        let entryPrice: Double
        let quantity: Double
        let entryDate: Date
        var currentPrice: Double
        var currentCapital: Double
        var unrealizedProfit: Double
        var unrealizedProfitPercent: Double
        var stopLoss: Double
        var takeProfit: Double
        var status: PositionStatus
        
        var trailingStopLoss: Double {
            // Trailing stop-loss: %2 profit = move stop-loss up
            let profit = unrealizedProfitPercent
            let initialStop = stopLoss
            return initialStop + (profit * 0.2) / 100 * entryPrice
        }
    }
    
    enum PositionType: String, Sendable {
        case long = "Uzun"
        case short = "Kısa"
    }
    
    enum PositionStatus: String, Sendable {
        case active = "Aktif"
        case stopLoss = "Stop-Loss"
        case takeProfit = "Take-Profit"
        case manual = "Manuel Kapat"
    }
    
    struct Portfolio: Sendable {
        let totalCapital: Double
        let availableCapital: Double
        let investedCapital: Double
        let unrealizedProfit: Double
        let realizedProfit: Double
        let openPositions: [Position]
        let positions: Int
    }
    
    // MARK: - State
    
    private var positions: [Position] = []
    private var initialCapital: Double = 100_000 // 100.000 TL başlangıç sermayesi
    private var availableCapital: Double = 100_000
    private var realizedProfit: Double = 0
    
    private let config: AutoPilotConfig = AutoPilotConfig(
        maxOpenPositions: 5,
        maxCapitalPerPosition: 20_000,
        stopLossPercent: 5.0,
        takeProfitPercent: 10.0,
        maxTotalCapital: 100_000,
        riskPerTrade: 2.0
    )
    
    // MARK: - Main Functions
    
    func getPortfolio() -> Portfolio {
        let investedCapital = positions.reduce(0) { $0 + $1.currentCapital }
        let unrealizedProfit = positions.reduce(0) { $0 + $1.unrealizedProfit }
        
        return Portfolio(
            totalCapital: initialCapital + realizedProfit,
            availableCapital: availableCapital,
            investedCapital: investedCapital,
            unrealizedProfit: unrealizedProfit,
            realizedProfit: realizedProfit,
            openPositions: positions,
            positions: positions.count
        )
    }
    
    func openPosition(
        symbol: String,
        type: PositionType,
        price: Double,
        quantity: Double,
        advice: String
    ) async throws -> Position {
        // Validate inputs
        guard quantity > 0 else {
            throw AutoPilotError.invalidQuantity
        }
        
        let positionValue = price * quantity
        guard positionValue <= availableCapital else {
            throw AutoPilotError.insufficientCapital
        }
        
        guard positions.count < config.maxOpenPositions else {
            throw AutoPilotError.maxPositionsReached
        }
        
        guard positionValue <= config.maxCapitalPerPosition else {
            throw AutoPilotError.positionTooLarge(maxAllowed: config.maxCapitalPerPosition)
        }
        
        // Calculate stop-loss and take-profit
        let stopLoss = type == .long ? price * (1 - config.stopLossPercent / 100) : price * (1 + config.stopLossPercent / 100)
        let takeProfit = type == .long ? price * (1 + config.takeProfitPercent / 100) : price * (1 - config.takeProfitPercent / 100)
        
        // Create position
        let position = Position(
            symbol: symbol,
            type: type,
            entryPrice: price,
            quantity: quantity,
            entryDate: Date(),
            currentPrice: price,
            currentCapital: positionValue,
            unrealizedProfit: 0,
            unrealizedProfitPercent: 0,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            status: .active
        )
        
        // Update state
        positions.append(position)
        availableCapital -= positionValue
        realizedProfit -= 20 // Commission (simplified)
        
        print("🤖 AUTOPILOT: Opened \(type.rawValue) position in \(symbol) @ \(price) (Qty: \(quantity)) - \(advice)")
        
        return position
    }
    
    func updatePositions(quotes: [String: Double]) async {
        var updatedPositions: [Position] = []
        
        for var position in positions {
            guard let currentPrice = quotes[position.symbol] else { continue }
            
            // Update current price
            position.currentPrice = currentPrice
            
            // Calculate unrealized profit
            if position.type == .long {
                let profit = (currentPrice - position.entryPrice) * position.quantity
                position.unrealizedProfit = profit
                position.unrealizedProfitPercent = (profit / (position.entryPrice * position.quantity)) * 100
                position.currentCapital = currentPrice * position.quantity
            } else {
                let profit = (position.entryPrice - currentPrice) * position.quantity
                position.unrealizedProfit = profit
                position.unrealizedProfitPercent = (profit / (position.entryPrice * position.quantity)) * 100
                position.currentCapital = currentPrice * position.quantity
            }
            
            // Check stop-loss and take-profit
            if position.status == .active {
                if position.type == .long {
                    if currentPrice <= position.stopLoss {
                        position.status = .stopLoss
                    } else if currentPrice >= position.takeProfit {
                        position.status = .takeProfit
                    }
                } else {
                    if currentPrice >= position.stopLoss {
                        position.status = .stopLoss
                    } else if currentPrice <= position.takeProfit {
                        position.status = .takeProfit
                    }
                }
            }
            
            updatedPositions.append(position)
        }
        
        positions = updatedPositions
        
        // Auto-close positions
        for position in positions where position.status != .active {
            try? await closePosition(positionId: position.id, reason: "Auto-close (\(position.status.rawValue))")
        }
    }
    
    func closePosition(positionId: UUID, reason: String = "Manuel") async throws {
        guard let index = positions.firstIndex(where: { $0.id == positionId }) else {
            throw AutoPilotError.positionNotFound
        }
        
        let position = positions[index]
        
        // Calculate final profit
        var finalProfit: Double
        if position.type == .long {
            finalProfit = (position.currentPrice - position.entryPrice) * position.quantity
        } else {
            finalProfit = (position.entryPrice - position.currentPrice) * position.quantity
        }
        
        // Update state
        positions.remove(at: index)
        availableCapital += position.currentCapital
        realizedProfit += finalProfit
        
        // Commission deduction
        realizedProfit -= 20
        
        print("🤖 AUTOPILOT: Closed \(position.type.rawValue) position in \(position.symbol) @ \(position.currentPrice) - Profit: \(String(format: "%.2f", finalProfit)) TL - \(reason)")
    }
    
    func closeAllPositions(reason: String = "Manuel kapatma") async {
        let positionIds = positions.map { $0.id }
        
        for positionId in positionIds {
            try? await closePosition(positionId: positionId, reason: reason)
        }
        
        print("🤖 AUTOPILOT: All positions closed - \(reason)")
    }
    
    func reset() async {
        positions = []
        availableCapital = initialCapital
        realizedProfit = 0
        
        print("🤖 AUTOPILOT: Reset to initial state")
    }
    
    // MARK: - Risk Management
    
    func calculateRisk() -> AutoPilotRiskMetrics {
        let portfolio = getPortfolio()
        let maxDrawdown = calculateMaxDrawdown()
        let totalRisk = positions.reduce(0) { $0 + abs($1.unrealizedProfit) }
        
        let riskPercent = portfolio.totalCapital > 0 ? (totalRisk / portfolio.totalCapital) * 100 : 0
        
        return AutoPilotRiskMetrics(
            totalCapital: portfolio.totalCapital,
            investedCapital: portfolio.investedCapital,
            availableCapital: portfolio.availableCapital,
            unrealizedProfit: portfolio.unrealizedProfit,
            realizedProfit: portfolio.realizedProfit,
            totalReturn: ((portfolio.totalCapital - initialCapital) / initialCapital) * 100,
            positionsCount: positions.count,
            maxDrawdown: maxDrawdown,
            currentRisk: riskPercent,
            riskLevel: riskLevel(for: riskPercent)
        )
    }
    
    private func calculateMaxDrawdown() -> Double {
        var peak = initialCapital
        var maxDrawdown = 0.0
        var runningCapital = initialCapital
        
        // Simulate drawdown from positions
        for position in positions {
            runningCapital = initialCapital - (position.currentCapital - position.entryPrice) * position.quantity
            
            if runningCapital > peak {
                peak = runningCapital
            } else if runningCapital < peak {
                let drawdown = (peak - runningCapital) / peak
                if drawdown > maxDrawdown {
                    maxDrawdown = drawdown
                }
            }
        }
        
        return maxDrawdown * 100
    }
    
    private func riskLevel(for riskPercent: Double) -> String {
        switch riskPercent {
        case 0..<10: return "Düşük"
        case 10..<25: return "Orta"
        case 25..<50: return "Yüksek"
        default: return "Kritik"
        }
    }
}

// MARK: - Risk Metrics

struct AutoPilotRiskMetrics: Sendable {
    let totalCapital: Double
    let investedCapital: Double
    let availableCapital: Double
    let unrealizedProfit: Double
    let realizedProfit: Double
    let totalReturn: Double
    let positionsCount: Int
    let maxDrawdown: Double
    let currentRisk: Double
    let riskLevel: String
}

// MARK: - Errors

enum AutoPilotError: Error, LocalizedError {
    case insufficientCapital
    case invalidQuantity
    case maxPositionsReached
    case positionTooLarge(maxAllowed: Double)
    case positionNotFound
    
    var errorDescription: String? {
        switch self {
        case .insufficientCapital:
            return "Yetersiz sermaye"
        case .invalidQuantity:
            return "Geçersiz miktar"
        case .maxPositionsReached:
            return "Maksimum pozisyon sayısına ulaşıldı"
        case .positionTooLarge(let max):
            return "Pozisyon çok büyük (maksimum: \(Int(max)) TL)"
        case .positionNotFound:
            return "Pozisyon bulunamadı"
        }
    }
}