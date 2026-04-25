import Foundation

/// Phase 3: Mandatory Server-Side Execution (iOS Robustness)
/// Defines the strict contract for any Broker implementation used by Auto-Pilot.
protocol BrokerService {
    
    /// Establishes connection to the broker.
    func connect() async throws
    
    /// Returns the available buying power.
    func getBuyingPower() async throws -> Double
    
    /// ❌ BANNED: Primitive execute methods are forbidden for Auto-Pilot.
    /// func buy(...) -> Void
    /// func sell(...) -> Void
    
    /// ✅ REQUIRED: Places a robust Bracket Order (Entry + Stop Loss + Take Profit)
    /// This ensures checking mechanisms live on the Server, not the fragile iOS Background state.
    /// - Parameters:
    ///   - symbol: The asset symbol (e.g. "AAPL")
    ///   - qty: Quantity to buy
    ///   - limitPrice: The entry limit price (nil for Market)
    ///   - stopLossPrice: The OTO Stop Loss trigger price
    ///   - takeProfitPrice: The OTO Take Profit trigger price
    /// - Throws: OrderError if OTO is not supported or validation fails.
    func placeBracketOrder(
        symbol: String,
        qty: Double,
        limitPrice: Double?,
        stopLossPrice: Double,
        takeProfitPrice: Double
    ) async throws -> String // Returns Order ID
    
    /// Cancels an existing order or group.
    func cancelOrder(id: String) async throws
}

enum OrderError: Error {
    case otoNotSupported
    case invalidPrice
    case insufficientFunds
    case networkFailure
}

// Mock Implementation for now (User asked for the Protocol mainly)
class SimulationBroker: BrokerService {
    func connect() async throws {
        // Mock connection
    }
    
    func getBuyingPower() async throws -> Double {
        return 100000.0
    }
    
    func placeBracketOrder(symbol: String, qty: Double, limitPrice: Double?, stopLossPrice: Double, takeProfitPrice: Double) async throws -> String {
        print("🔐 BROKER: Placing Server-Side Bracket for \(symbol)")
        print("   - Entry: \(limitPrice ?? 0) (Limit)")
        print("   - Stop: \(stopLossPrice)")
        print("   - TP: \(takeProfitPrice)")
        
        // In a real app, this would hit Alpaca/IBKR API
        return UUID().uuidString
    }
    
    func cancelOrder(id: String) async throws {
        print("🔐 BROKER: Cancel \(id)")
    }
}
