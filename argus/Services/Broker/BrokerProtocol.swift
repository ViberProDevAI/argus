import Foundation

// MARK: - Broker Protocol
/// Abstract broker interface - gerçek ve simüle broker'lar için ortak protokol

protocol BrokerProtocol: Actor {
    /// Broker ismi
    var name: String { get }
    
    /// Bağlantı durumu
    var isConnected: Bool { get async }
    
    /// Market order gönder
    func placeMarketOrder(
        symbol: String,
        side: OrderSide,
        quantity: Double
    ) async throws -> OrderResult
    
    /// Limit order gönder
    func placeLimitOrder(
        symbol: String,
        side: OrderSide,
        quantity: Double,
        limitPrice: Double
    ) async throws -> OrderResult
    
    /// Stop order gönder
    func placeStopOrder(
        symbol: String,
        side: OrderSide,
        quantity: Double,
        stopPrice: Double
    ) async throws -> OrderResult
    
    /// Order iptal et
    func cancelOrder(orderId: String) async throws -> Bool
    
    /// Order durumunu sorgula
    func getOrderStatus(orderId: String) async throws -> OrderStatus
    
    /// Açık orderları getir
    func getOpenOrders() async throws -> [Order]
    
    /// Pozisyonları getir
    func getPositions() async throws -> [BrokerPosition]
    
    /// Hesap bilgilerini getir
    func getAccountInfo() async throws -> AccountInfo
    
    /// Güncel fiyat al
    func getQuote(symbol: String) async throws -> BrokerQuote
}

// MARK: - Order Models

enum OrderSide: String, Codable, Sendable {
    case buy = "BUY"
    case sell = "SELL"
}

enum OrderType: String, Codable, Sendable {
    case market = "MARKET"
    case limit = "LIMIT"
    case stop = "STOP"
    case stopLimit = "STOP_LIMIT"
}

enum OrderStatus: String, Codable, Sendable {
    case pending = "PENDING"
    case submitted = "SUBMITTED"
    case partiallyFilled = "PARTIALLY_FILLED"
    case filled = "FILLED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
    case expired = "EXPIRED"
    
    var isTerminal: Bool {
        switch self {
        case .filled, .cancelled, .rejected, .expired: return true
        default: return false
        }
    }
}

struct Order: Codable, Identifiable {
    let id: String
    let symbol: String
    let side: OrderSide
    let type: OrderType
    let quantity: Double
    let filledQuantity: Double
    let price: Double?          // Limit price
    let stopPrice: Double?      // Stop price
    let avgFillPrice: Double?
    let status: OrderStatus
    let createdAt: Date
    let updatedAt: Date
    
    var remainingQuantity: Double {
        quantity - filledQuantity
    }
    
    var isFilled: Bool { status == .filled }
}

struct OrderResult: Codable {
    let orderId: String
    let status: OrderStatus
    let message: String?
    let filledQuantity: Double
    let avgFillPrice: Double?
    let commission: Double
    let timestamp: Date
    
    var isSuccess: Bool {
        status == .filled || status == .submitted || status == .partiallyFilled
    }
}

struct BrokerPosition: Codable, Identifiable {
    var id: String { symbol }
    
    let symbol: String
    let quantity: Double
    let avgCost: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedPnL: Double
    let unrealizedPnLPct: Double
    
    var side: OrderSide {
        quantity >= 0 ? .buy : .sell
    }
}

struct AccountInfo: Codable {
    let accountId: String
    let currency: String
    let equity: Double
    let cash: Double
    let buyingPower: Double
    let portfolioValue: Double
    let dayTradeCount: Int
    let patternDayTrader: Bool
    let tradingBlocked: Bool
    let updatedAt: Date
}

struct BrokerQuote: Codable {
    let symbol: String
    let bid: Double
    let ask: Double
    let last: Double
    let volume: Double
    let timestamp: Date
    
    var mid: Double { (bid + ask) / 2.0 }
    var spread: Double { ask - bid }
    var spreadPct: Double { spread / mid * 100.0 }
}

// MARK: - Broker Errors

enum BrokerError: Error, LocalizedError {
    case notConnected
    case invalidSymbol(String)
    case insufficientFunds
    case insufficientShares
    case orderRejected(String)
    case orderNotFound(String)
    case marketClosed
    case rateLimit
    case networkError(Error)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Broker'a bağlı değil"
        case .invalidSymbol(let symbol):
            return "Geçersiz sembol: \(symbol)"
        case .insufficientFunds:
            return "Yetersiz bakiye"
        case .insufficientShares:
            return "Yetersiz hisse"
        case .orderRejected(let reason):
            return "Order reddedildi: \(reason)"
        case .orderNotFound(let id):
            return "Order bulunamadı: \(id)"
        case .marketClosed:
            return "Market kapalı"
        case .rateLimit:
            return "Rate limit aşıldı"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        case .unknown(let msg):
            return "Bilinmeyen hata: \(msg)"
        }
    }
}

// MARK: - Order State Machine

actor OrderStateMachine {
    private var orders: [String: Order] = [:]
    
    func createOrder(
        symbol: String,
        side: OrderSide,
        type: OrderType,
        quantity: Double,
        price: Double? = nil,
        stopPrice: Double? = nil
    ) -> Order {
        let order = Order(
            id: UUID().uuidString,
            symbol: symbol,
            side: side,
            type: type,
            quantity: quantity,
            filledQuantity: 0,
            price: price,
            stopPrice: stopPrice,
            avgFillPrice: nil,
            status: .pending,
            createdAt: Date(),
            updatedAt: Date()
        )
        orders[order.id] = order
        return order
    }
    
    func updateStatus(_ orderId: String, status: OrderStatus) {
        guard var order = orders[orderId] else { return }
        order = Order(
            id: order.id,
            symbol: order.symbol,
            side: order.side,
            type: order.type,
            quantity: order.quantity,
            filledQuantity: order.filledQuantity,
            price: order.price,
            stopPrice: order.stopPrice,
            avgFillPrice: order.avgFillPrice,
            status: status,
            createdAt: order.createdAt,
            updatedAt: Date()
        )
        orders[orderId] = order
    }
    
    func fill(_ orderId: String, quantity: Double, price: Double) {
        guard var order = orders[orderId] else { return }
        
        let newFilledQty = order.filledQuantity + quantity
        let newStatus: OrderStatus = newFilledQty >= order.quantity ? .filled : .partiallyFilled
        
        // Calculate weighted average fill price
        let prevValue = (order.avgFillPrice ?? 0) * order.filledQuantity
        let newValue = price * quantity
        let avgPrice = (prevValue + newValue) / newFilledQty
        
        order = Order(
            id: order.id,
            symbol: order.symbol,
            side: order.side,
            type: order.type,
            quantity: order.quantity,
            filledQuantity: newFilledQty,
            price: order.price,
            stopPrice: order.stopPrice,
            avgFillPrice: avgPrice,
            status: newStatus,
            createdAt: order.createdAt,
            updatedAt: Date()
        )
        orders[orderId] = order
    }
    
    func getOrder(_ orderId: String) -> Order? {
        orders[orderId]
    }
    
    func getOpenOrders() -> [Order] {
        orders.values.filter { order in
            switch order.status {
            case .filled, .cancelled, .rejected, .expired: return false
            default: return true
            }
        }
    }
    
    func getAllOrders() -> [Order] {
        Array(orders.values)
    }
}
