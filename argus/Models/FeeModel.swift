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

    /// Sembol tipine göre doğru FeeModel'i döner. Oranlar UserDefaults'tan
    /// okunur (Settings → İşlem Ayarları). Default 0.0 — modern aracıların
    /// çoğunda (Midas, Garanti, Alpaca, IBKR Lite) sıfır komisyon yaygın.
    /// Kullanıcı kendi aracısına göre oran girer.
    static func forSymbol(_ symbol: String) -> FeeModel {
        let upper = symbol.uppercased()
        let isBist = upper.hasSuffix(".IS") || upper.hasSuffix(".BIST")
        let rate = isBist
            ? UserDefaults.standard.bistCommissionRate
            : UserDefaults.standard.globalCommissionRate
        // Komisyon 0 ise minimum fee de uygulanmaz — sıfır komisyon aracılar
        // için "minimum 1$" gibi yapay floor olmasın.
        let minFee: Double = rate > 0 ? 1.0 : 0.0
        return FeeModel(rate: rate, minFee: minFee)
    }
}
