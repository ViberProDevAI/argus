import Foundation

// MARK: - Options Models

public struct OptionsChain: Codable, Sendable {
    public let symbol: String
    public let underlyingPrice: Double
    public let expirationDates: [String]
    public let strikes: [Double]
    public let calls: [OptionContract]
    public let puts: [OptionContract]
    public let timestamp: Date
}

public struct OptionContract: Codable, Identifiable, Sendable {
    public var id: String { contractSymbol }
    public let contractSymbol: String
    public let strike: Double
    public let currency: String
    public let lastPrice: Double
    public let change: Double
    public let percentChange: Double
    public let volume: Int
    public let openInterest: Int
    public let bid: Double
    public let ask: Double
    public let impliedVolatility: Double
    public let inTheMoney: Bool
    public let contractSize: String
    public let expiration: String // "2025-06-20"
    
    // Greeks
    public let delta: Double?
    public let gamma: Double?
    public let theta: Double?
    public let vega: Double?
    public let rho: Double?
}

// MARK: - Massive API Response Models (Internal)
struct MassiveChainResponse: Codable {
    let underlying: String
    let price: Double
    let options: [MassiveOption]
}

struct MassiveOption: Codable {
    let symbol: String
    let type: String // "call" / "put"
    let strike: Double
    let expiry: String
    let last: Double
    let vol: Int
    let open_int: Int
    let iv: Double?
}
