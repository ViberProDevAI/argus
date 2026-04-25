import Foundation
import WidgetKit

// MARK: - Widget Quote Summary
// Shared model for the widget to display without network calls.
struct WidgetQuoteSummary: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let lastPrice: Double
    let percentChange: Double
    let orionLetter: String? // A+, A, etc.
    let orionAction: String? // "AL", "SAT"
    let lastUpdated: Date
}

// MARK: - Argus Widget Manager
// Handles App Group storage for widget data.
class ArgusWidgetManager {
    static let shared = ArgusWidgetManager()
    
    // Replace with your actual App Group ID
    private let suiteName = "group.com.argus.Algo-Trading"
    
    private let symbolsKey = "widgetSymbols"
    private let summariesKey = "widgetQuoteSummaries"
    
    private init() {}
    
    // MARK: - Symbols Management
    
    func getWidgetSymbols() -> [String] {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return [] }
        return defaults.stringArray(forKey: symbolsKey) ?? []
    }
    
    func setWidgetSymbols(_ symbols: [String]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        // Limit to 6 symbols
        let limited = Array(symbols.prefix(6))
        defaults.set(limited, forKey: symbolsKey)
        
        // Trigger widget reload to reflect list changes (even if data isn't updated yet)
        WidgetCenter.shared.reloadTimelines(ofKind: "ArgusPriceWatchWidget")
    }
    
    func addSymbol(_ symbol: String) {
        var current = getWidgetSymbols()
        if !current.contains(symbol) {
            current.append(symbol)
            setWidgetSymbols(current)
        }
    }
    
    func removeSymbol(_ symbol: String) {
        var current = getWidgetSymbols()
        current.removeAll { $0 == symbol }
        setWidgetSymbols(current)
    }
    
    // MARK: - Summaries Management
    
    func getQuoteSummaries() -> [WidgetQuoteSummary] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: summariesKey),
              let summaries = try? JSONDecoder().decode([WidgetQuoteSummary].self, from: data) else {
            return []
        }
        return summaries
    }
    
    func saveQuoteSummaries(_ summaries: [WidgetQuoteSummary]) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(summaries) else { return }
        
        defaults.set(data, forKey: summariesKey)
        
        // Reload Widget
        WidgetCenter.shared.reloadTimelines(ofKind: "ArgusPriceWatchWidget")
    }
}
