import Foundation
import Combine

enum SafeAssetType: String, Codable, CaseIterable {
    case stock = "Hisse" // Added for General Stocks
    case index = "Endeks" // General Market Indices
    case gold = "Gold"
    case commodity = "Emtia" // New Category
    case etf = "ETF" // New Category
    case crypto = "Kripto" // New Category
    case forex = "Forex" // New Category
    case bond = "Bond"
    case cashLike = "Cash-Like"
    case hedge = "Hedge" // Bear Market Protection
    
    var icon: String {
        switch self {
        case .stock: return "chart.bar.fill"
        case .index: return "chart.line.uptrend.xyaxis"
        case .gold: return "sun.max.fill"
        case .commodity: return "fuelpump.fill" // Or drop.fill
        case .etf: return "square.grid.2x2.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .forex: return "eurosign.circle.fill"
        case .bond: return "scroll.fill"
        case .cashLike: return "banknote.fill"
        case .hedge: return "shield.lefthalf.filled"
        }
    }
}

final class SafeUniverseService: ObservableObject {
    static let shared = SafeUniverseService()
    @Published var selectedAssets: Set<String> = []

    // Hardcoded Universe of "High Quality" Safe Assets
    let universe: [SafeAsset] = [
        // Gold / Precious Metals (Using Futures for tracking, ETFs for trading proxies if needed)
        SafeAsset(symbol: "GC=F", name: "Gold Futures", type: .gold, expenseRatio: 0.0),
        SafeAsset(symbol: "SI=F", name: "Silver Futures", type: .commodity, expenseRatio: 0.0),
        SafeAsset(symbol: "PL=F", name: "Platinum Futures", type: .commodity, expenseRatio: 0.0),
        
        // Energy Commodities
        SafeAsset(symbol: "CL=F", name: "Crude Oil (WTI)", type: .commodity, expenseRatio: 0.0),
        SafeAsset(symbol: "NG=F", name: "Natural Gas", type: .commodity, expenseRatio: 0.0),
        SafeAsset(symbol: "RB=F", name: "RBOB Gasoline", type: .commodity, expenseRatio: 0.0),
        
        // Industrial Metals
        SafeAsset(symbol: "HG=F", name: "Copper Futures", type: .commodity, expenseRatio: 0.0),
        
        // ETFs (Retained for allocation logic if needed, but Futures preferred for 'Market View')
        SafeAsset(symbol: "GLD", name: "SPDR Gold Shares", type: .gold, expenseRatio: 0.40),
        
        // Bonds (General & Treasury)
        SafeAsset(symbol: "BND", name: "Vanguard Total Bond Market", type: .bond, expenseRatio: 0.03),
        SafeAsset(symbol: "AGG", name: "iShares Core U.S. Aggregate Bond", type: .bond, expenseRatio: 0.03),
        SafeAsset(symbol: "TLT", name: "iShares 20+ Year Treasury Bond", type: .bond, expenseRatio: 0.15),
        SafeAsset(symbol: "IEF", name: "iShares 7-10 Year Treasury Bond", type: .bond, expenseRatio: 0.15),
        
        // Cash-Like / Short Term
        SafeAsset(symbol: "SHV", name: "iShares Short Treasury Bond", type: .cashLike, expenseRatio: 0.15),
        SafeAsset(symbol: "SGOV", name: "iShares 0-3 Month Treasury Bond", type: .cashLike, expenseRatio: 0.03),
        SafeAsset(symbol: "BIL", name: "SPDR Bloomberg 1-3 Month T-Bill", type: .cashLike, expenseRatio: 0.13),
        
        // Hedges (Inverse ETFs)
        SafeAsset(symbol: "SQQQ", name: "ProShares UltraPro Short QQQ", type: .hedge, expenseRatio: 0.95),
        SafeAsset(symbol: "SPXU", name: "ProShares UltraPro Short S&P500", type: .hedge, expenseRatio: 0.90),
        
        // Indices
        SafeAsset(symbol: "DXY", name: "US Dollar Index", type: .index, expenseRatio: 0.0), // DXY Standard
        SafeAsset(symbol: "SPY", name: "S&P 500 ETF", type: .index, expenseRatio: 0.09),
        SafeAsset(symbol: "QQQ", name: "Invesco QQQ", type: .index, expenseRatio: 0.20),
        
        // Crypto
        SafeAsset(symbol: "BTC-USD", name: "Bitcoin", type: .crypto, expenseRatio: 0.0)
    ]
    
    // UserDefaults Key
    private let selectionKey = "Argus_SafeUniverse_Selection"
    private let overrideKey = "Argus_AssetType_Overrides"
    
    // User Overrides for Asset Types (e.g. User forces "XAUUSD" to be .commodity)
    @Published var userOverrides: [String: SafeAssetType] = [:]
    
    private init() {
        loadSelection()
        loadOverrides()
    }
    
    // MARK: - User Override Logic
    func setUserOverride(for symbol: String, type: SafeAssetType) {
        userOverrides[symbol] = type
        saveOverrides()
    }
    
    func getUserOverride(for symbol: String) -> SafeAssetType? {
        return userOverrides[symbol]
    }
    
    func removeUserOverride(for symbol: String) {
        userOverrides.removeValue(forKey: symbol)
        saveOverrides()
    }
    
    // MARK: - Persistence for Overrides
    private func saveOverrides() {
        if let data = try? JSONEncoder().encode(userOverrides) {
            UserDefaults.standard.set(data, forKey: overrideKey)
        }
    }
    
    private func loadOverrides() {
        if let data = UserDefaults.standard.data(forKey: overrideKey),
           let decoded = try? JSONDecoder().decode([String: SafeAssetType].self, from: data) {
            self.userOverrides = decoded
        }
    }
    
    func toggleAsset(_ symbol: String) {
        if selectedAssets.contains(symbol) {
            selectedAssets.remove(symbol)
        } else {
            selectedAssets.insert(symbol)
        }
        saveSelection()
    }
    
    func isSelected(_ symbol: String) -> Bool {
        return selectedAssets.contains(symbol)
    }
    
    // Helper: Get selected assets by type (for rotation logic)
    func getSelectedAssets(by type: SafeAssetType) -> [SafeAsset] {
        return universe.filter { $0.type == type && selectedAssets.contains($0.symbol) }
    }
    
    // Check if a symbol is in the safe universe and return its type
    func getUniverseType(for symbol: String) -> SafeAssetType? {
        return universe.first(where: { $0.symbol == symbol })?.type
    }
    
    // Fallback: If user selects nothing, return defaults
    func getActiveAssets(by type: SafeAssetType) -> [SafeAsset] {
        let selected = getSelectedAssets(by: type)
        if !selected.isEmpty { return selected }
        
        // Default Logic (if empty selection)
        switch type {
        case .stock: return [] // No default "Safe Stock" logic
        case .gold: return universe.filter { $0.symbol == "GC=F" } // Default to Future
        case .commodity: return universe.filter { $0.symbol == "CL=F" }
        case .etf: return universe.filter { $0.symbol == "SPY" } // Default to SPY if asking for ETF generically
        case .bond: return universe.filter { $0.symbol == "BND" }
        case .cashLike: return universe.filter { $0.symbol == "SHV" }
        case .hedge: return universe.filter { $0.symbol == "SQQQ" }
        case .index: return universe.filter { $0.symbol == "SPY" }
        case .forex: return universe.filter { $0.symbol == "EURUSD=X" } // Default Forex
        case .crypto: return universe.filter { $0.symbol == "BTC-USD" }
        }
    }
    
    private func saveSelection() {
        if let data = try? JSONEncoder().encode(selectedAssets) {
            UserDefaults.standard.set(data, forKey: selectionKey)
        }
    }
    
    private func loadSelection() {
        if let data = UserDefaults.standard.data(forKey: selectionKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.selectedAssets = decoded
        } else {
            // Initial Defaults
            self.selectedAssets = ["GLD", "BND", "SHV"]
        }
    }
}
