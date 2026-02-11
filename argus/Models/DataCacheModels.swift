import Foundation

enum DataFieldKind: String, Codable, Sendable {
    case price         // Quote
    case candles       // [Candle]
    case fundamentals  // Financials
    case macro         // Macro data
    case news          // News insights
    case technical     // Technical indicators
}

struct CachedDataEntry: Codable, Sendable {
    let data: Data // Encoded JSON of the value
    let source: String
    let receivedAt: Date
    let symbol: String
    let kind: DataFieldKind
}

struct CachedField<T: Sendable>: Sendable {
    let value: T
    let source: String
    let receivedAt: Date
    let symbol: String
    let kind: DataFieldKind
}
