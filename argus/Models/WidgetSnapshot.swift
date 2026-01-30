// Deprecated. Models are now defined in WidgetDataService.swift and locally in ArgusWidget bundle.
// Keeping file as placeholder to verify no other dependencies exist, but commenting out content to fix redeclaration.

/*
import Foundation

// MARK: - Shared Widget Snapshot Model

struct WidgetSnapshot: Codable {
    var macro: WidgetMacroData
    var topSignals: [WidgetSignal]
    var portfolio: WidgetPortfolioData
    var orion: WidgetOrionData? // New Orion Data
    var lastUpdated: Date
}

struct WidgetMacroData: Codable {
    let letterGrade: String
    let numericScore: Double
    let regime: String // "riskOn", "riskOff", "neutral"
    let summary: String
}

struct WidgetOrionData: Codable {
    let symbol: String
    let orionScore: Double
    let orionLetter: String
    let actionHint: String
    let fundScore: Double
    let fundLetter: String
    let techScore: Double
    let aetherLetter: String
}

struct WidgetSignal: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let action: String // "AL", "SAT", "BEKLE"
    let score: Double
    let message: String?
}

struct WidgetPortfolioData: Codable {
    let totalEquity: Double
    let dailyPnL: Double
    let openPositionsCount: Int
}
*/
