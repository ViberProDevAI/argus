import Foundation

// MARK: - Alkindus Symbol Learner
/// Learns which modules perform best for specific symbols and sectors.
/// "Orion works great for AAPL, but Hermes is better for NVDA"

actor AlkindusSymbolLearner {
    static let shared = AlkindusSymbolLearner()
    
    private let filePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("alkindus_memory").appendingPathComponent("symbols.json")
    }()
    
    private init() {
        let dir = filePath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    // MARK: - Data Models
    
    struct SymbolData: Codable {
        var symbols: [String: SymbolStats]
        var sectors: [String: SectorStats]
        var markets: MarketComparison
        var lastUpdated: Date
        
        static var empty: SymbolData {
            SymbolData(symbols: [:], sectors: [:], markets: MarketComparison(), lastUpdated: Date())
        }
    }
    
    struct SymbolStats: Codable {
        var modulePerformance: [String: ModuleSymbolStats]
        var totalDecisions: Int
        var lastSeen: Date
    }
    
    struct ModuleSymbolStats: Codable {
        var attempts: Int
        var correct: Int
        var hitRate: Double { attempts > 0 ? Double(correct) / Double(attempts) : 0 }
    }
    
    struct SectorStats: Codable {
        var symbols: [String]
        var modulePerformance: [String: ModuleSymbolStats]
    }
    
    struct MarketComparison: Codable {
        var bist: MarketStats?
        var global: MarketStats?
    }
    
    struct MarketStats: Codable {
        var modulePerformance: [String: ModuleSymbolStats]
        var overallHitRate: Double { 
            let total = modulePerformance.values.reduce(0) { $0 + $1.attempts }
            let correct = modulePerformance.values.reduce(0) { $0 + $1.correct }
            return total > 0 ? Double(correct) / Double(total) : 0
        }
    }
    
    // MARK: - API
    
    /// Records a decision outcome for a symbol
    func recordOutcome(symbol: String, module: String, wasCorrect: Bool, isBist: Bool) async {
        var data = await loadData()
        
        // 1. Update symbol stats
        if data.symbols[symbol] == nil {
            data.symbols[symbol] = SymbolStats(modulePerformance: [:], totalDecisions: 0, lastSeen: Date())
        }
        if data.symbols[symbol]?.modulePerformance[module] == nil {
            data.symbols[symbol]?.modulePerformance[module] = ModuleSymbolStats(attempts: 0, correct: 0)
        }
        data.symbols[symbol]?.modulePerformance[module]?.attempts += 1
        if wasCorrect {
            data.symbols[symbol]?.modulePerformance[module]?.correct += 1
        }
        data.symbols[symbol]?.totalDecisions += 1
        data.symbols[symbol]?.lastSeen = Date()
        
        // 2. Update market stats
        if isBist {
            if data.markets.bist == nil {
                data.markets.bist = MarketStats(modulePerformance: [:])
            }
            if data.markets.bist?.modulePerformance[module] == nil {
                data.markets.bist?.modulePerformance[module] = ModuleSymbolStats(attempts: 0, correct: 0)
            }
            data.markets.bist?.modulePerformance[module]?.attempts += 1
            if wasCorrect {
                data.markets.bist?.modulePerformance[module]?.correct += 1
            }
        } else {
            if data.markets.global == nil {
                data.markets.global = MarketStats(modulePerformance: [:])
            }
            if data.markets.global?.modulePerformance[module] == nil {
                data.markets.global?.modulePerformance[module] = ModuleSymbolStats(attempts: 0, correct: 0)
            }
            data.markets.global?.modulePerformance[module]?.attempts += 1
            if wasCorrect {
                data.markets.global?.modulePerformance[module]?.correct += 1
            }
        }
        
        data.lastUpdated = Date()
        await saveData(data)
    }
    
    /// Gets best module for a symbol
    func getBestModule(for symbol: String) async -> (module: String, hitRate: Double)? {
        let data = await loadData()
        guard let stats = data.symbols[symbol] else { return nil }
        
        let best = stats.modulePerformance
            .filter { $0.value.attempts >= 5 }
            .max { $0.value.hitRate < $1.value.hitRate }
        
        return best.map { ($0.key, $0.value.hitRate) }
    }
    
    /// Gets symbol-specific insights
    func getSymbolInsights(for symbol: String) async -> SymbolInsight? {
        let data = await loadData()
        guard let stats = data.symbols[symbol],
              stats.totalDecisions >= 5 else { return nil }
        
        let sorted = stats.modulePerformance
            .filter { $0.value.attempts >= 3 }
            .sorted { $0.value.hitRate > $1.value.hitRate }
        
        guard let best = sorted.first, let worst = sorted.last else { return nil }
        
        return SymbolInsight(
            symbol: symbol,
            bestModule: best.key,
            bestHitRate: best.value.hitRate,
            worstModule: worst.key,
            worstHitRate: worst.value.hitRate,
            totalDecisions: stats.totalDecisions
        )
    }
    
    /// Gets market comparison
    func getMarketComparison() async -> (bist: Double, global: Double)? {
        let data = await loadData()
        guard let bist = data.markets.bist, let global = data.markets.global else { return nil }
        return (bist.overallHitRate, global.overallHitRate)
    }
    
    // MARK: - Private
    
    private func loadData() async -> SymbolData {
        guard let data = try? Data(contentsOf: filePath),
              let decoded = try? JSONDecoder().decode(SymbolData.self, from: data) else {
            return .empty
        }
        return decoded
    }
    
    private func saveData(_ data: SymbolData) async {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: filePath)
    }
}

// MARK: - Symbol Insight Model

struct SymbolInsight {
    let symbol: String
    let bestModule: String
    let bestHitRate: Double
    let worstModule: String
    let worstHitRate: Double
    let totalDecisions: Int
    
    var message: String {
        "\(symbol) için en iyi: \(bestModule.capitalized) (%\(Int(bestHitRate * 100)))"
    }
}
