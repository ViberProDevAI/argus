import Foundation

/// Represents a cached "Smart Atlas" snapshot of a company's fundamentals.
/// Used to avoid frequent API calls and ensure trading safety around earnings.
struct FundamentalSnapshot: Codable, Sendable {
    let symbol: String
    let fetchDate: Date
    let nextEarningsDate: Date?
    
    // Core Metrics needed for quick checks
    let marketCap: Double?
    let epsTTM: Double?
    let peRatio: Double?
    let priceToBook: Double?
    let bookValuePerShare: Double?
    
    // Financial Safety
    let totalDebt: Double?
    let totalEquity: Double?
    let cashAndEquivalents: Double?
    
    // MARK: - Calculated Properties
    
    /// Returns the number of days until the next earnings report.
    /// Returns nil if the date is unknown.
    var daysUntilEarnings: Int? {
        guard let earningsDate = nextEarningsDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: earningsDate)
        return components.day
    }
    
    /// Determines if it is "safe" to trade based on earnings proximity.
    /// Default safety buffer: 5 days.
    var isTradingSafe: Bool {
        guard let days = daysUntilEarnings else { return true } // Unknown date = assume safe (conservative: or risky? standard practice: safe but warn)
        // If earnings are within 5 days (past or future proximity, usually future), risky.
        // Assuming nextEarningsDate is FUTURE. If API returns past date, we might need logic.
        // For 'next' earnings, we care if it's coming effectively "soon".
        return days > 5
    }
    
    var debtToEquityRatio: Double? {
        guard let debt = totalDebt, let equity = totalEquity, equity > 0 else { return nil }
        return debt / equity
    }
    
    // Validity Check (Cache Expiry Logic usually handles this, but good to have)
    func isValid(maxAgeSeconds: TimeInterval = 86400 * 3) -> Bool {
        return Date().timeIntervalSince(fetchDate) < maxAgeSeconds
    }
}
