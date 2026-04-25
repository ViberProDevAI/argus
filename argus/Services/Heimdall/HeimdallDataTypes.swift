import Foundation

// MARK: - Core Enums

enum HeimdallAssetType: String, Codable {
    case stock, etf, crypto, metal, forex, index, unknown
}

enum HeimdallDataField: String, Codable, CaseIterable {
    case quote // Realtime price
    case candles // History
    case fundamentals // Income, Balance, Cash
    case profile // Company info, sector
    case news // Articles
    case macro // Economic indicators (VIX, DXY)
    case screener // Top Gainers/Losers
    case holdings // ETF Holdings
    case options // Options Chain & Greeks
    case fx // Forex/Currency
    case chart // Interactive Chart / Sparkline
}

// MARK: - Request Model

struct HeimdallRequest {
    let symbol: String
    let assets: [HeimdallAssetType]
    let fields: [HeimdallDataField]
    let priority: Int // 0: Routine, 1: UI User Action, 2: Critical
    let budget: Int // Max provider attempts, default 2
    
    // Context
    let timeframe: String? // For candles
    let lookback: Int? // For candles count
}

// MARK: - Health & Scoring Models

struct HeimdallDataHealth: Codable {
    let field: HeimdallDataField
    let status: DataStatus
    let lastUpdated: Date?
    let source: String? // Provider Name
    let message: String?
    
    enum DataStatus: String, Codable {
        case ok
        case stale
        case missing
        case error
        case unsupported
    }
}

struct HeimdallMacroIndicator: Codable, Sendable {
    let symbol: String
    let value: Double
    let change: Double?
    let changePercent: Double?
    let lastUpdated: Date
}

struct ProviderScore: Codable {
    var successRate: Double // 0.0 - 1.0 (Rolling window)
    var latencyP50: Double // ms
    var errorCount: Int
    var penaltyScore: Double // Higher is worse (accumulated from 429s)
    var lastUpdated: Date
    
    nonisolated static let neutral = ProviderScore(successRate: 0.9, latencyP50: 300, errorCount: 0, penaltyScore: 0, lastUpdated: Date())
}

// MARK: - Helper


