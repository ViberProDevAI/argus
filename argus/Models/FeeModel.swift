import Foundation

/// Standardized Fee Model for Algo-Trading
struct FeeModel {
    static let shared = FeeModel()
    
    // Configurable Rates
    let rate: Double // e.g., 0.001 for 0.1%
    let minFee: Double // Minimum fee in base currency (USD)
    
    init(rate: Double = 0.001, minFee: Double = 1.0) {
        self.rate = rate
        self.minFee = minFee
    }
    
    /// Calculates the commission fee for a given trade amount.
    /// - Parameter amount: The total trade value (Price * Quantity).
    /// - Returns: The calculated fee, respecting the minimum.
    func calculate(amount: Double) -> Double {
        let calculated = amount * rate
        return max(minFee, calculated)
    }
}
