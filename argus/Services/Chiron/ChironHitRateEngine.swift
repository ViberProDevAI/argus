import Foundation

// MARK: - Chiron Hit Rate Engine
/// Modül bazlı isabet oranlarını hesaplar ve takip eder

actor ChironHitRateEngine {
    static let shared = ChironHitRateEngine()
    
    private let dataLake = ChironDataLakeService.shared
    
    // MARK: - Types
    
    struct ModuleHitRate: Codable, Sendable {
        let module: String          // orion, atlas, aether, phoenix, hermes
        let symbol: String
        let totalSignals: Int
        let correctSignals: Int
        let hitRate: Double         // 0.0 - 1.0
        let avgScoreWhenCorrect: Double
        let avgScoreWhenWrong: Double
        let lastUpdated: Date
    }
    
    struct HitRateReport: Codable, Sendable {
        let symbol: String
        let moduleRates: [ModuleHitRate]
        let overallHitRate: Double
        let bestModule: String?
        let worstModule: String?
        let totalAnalyzedTrades: Int
        let generatedAt: Date
    }
    
    // MARK: - Calculation
    
    /// Belirli bir sembol için tüm modüllerin hit rate'lerini hesaplar
    func calculateHitRates(for symbol: String) async -> HitRateReport {
        let trades = await dataLake.loadTradeHistory(symbol: symbol)
        
        guard !trades.isEmpty else {
            return HitRateReport(
                symbol: symbol,
                moduleRates: [],
                overallHitRate: 0,
                bestModule: nil,
                worstModule: nil,
                totalAnalyzedTrades: 0,
                generatedAt: Date()
            )
        }
        
        var moduleRates: [ModuleHitRate] = []
        
        // Orion Hit Rate
        let orionRate = calculateModuleRate(
            module: "orion",
            symbol: symbol,
            trades: trades,
            scoreExtractor: { $0.orionScoreAtEntry }
        )
        moduleRates.append(orionRate)
        
        // Atlas Hit Rate
        let atlasRate = calculateModuleRate(
            module: "atlas",
            symbol: symbol,
            trades: trades,
            scoreExtractor: { $0.atlasScoreAtEntry }
        )
        moduleRates.append(atlasRate)
        
        // Aether Hit Rate
        let aetherRate = calculateModuleRate(
            module: "aether",
            symbol: symbol,
            trades: trades,
            scoreExtractor: { $0.aetherScoreAtEntry }
        )
        moduleRates.append(aetherRate)
        
        // Phoenix Hit Rate
        let phoenixRate = calculateModuleRate(
            module: "phoenix",
            symbol: symbol,
            trades: trades,
            scoreExtractor: { $0.phoenixScoreAtEntry }
        )
        moduleRates.append(phoenixRate)
        
        // Genel hit rate
        let validRates = moduleRates.filter { $0.totalSignals > 0 }
        let overallHitRate = validRates.isEmpty ? 0 : validRates.map { $0.hitRate }.reduce(0, +) / Double(validRates.count)
        
        // En iyi ve en kötü modül
        let sortedRates = validRates.sorted { $0.hitRate > $1.hitRate }
        let bestModule = sortedRates.first?.module
        let worstModule = sortedRates.last?.module
        
        return HitRateReport(
            symbol: symbol,
            moduleRates: moduleRates,
            overallHitRate: overallHitRate,
            bestModule: bestModule,
            worstModule: worstModule,
            totalAnalyzedTrades: trades.count,
            generatedAt: Date()
        )
    }
    
    /// Tüm semboller için global hit rate özeti
    func calculateGlobalHitRates() async -> [String: Double] {
        // Tüm modüller için ortalama hit rate
        var globalRates: [String: [Double]] = [
            "orion": [],
            "atlas": [],
            "aether": [],
            "phoenix": []
        ]
        
        // Tüm trade dosyalarını tara
        let fm = FileManager.default
        let tradesPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ChironDataLake/trades")
        
        if let files = try? fm.contentsOfDirectory(atPath: tradesPath.path) {
            for file in files where file.hasSuffix("_history.json") {
                let symbol = file.replacingOccurrences(of: "_history.json", with: "")
                let report = await calculateHitRates(for: symbol)
                
                for rate in report.moduleRates where rate.totalSignals > 0 {
                    globalRates[rate.module]?.append(rate.hitRate)
                }
            }
        }
        
        // Ortalamaları hesapla
        var result: [String: Double] = [:]
        for (module, rates) in globalRates {
            if !rates.isEmpty {
                result[module] = rates.reduce(0, +) / Double(rates.count)
            } else {
                result[module] = 0.5 // Varsayılan
            }
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private func calculateModuleRate(
        module: String,
        symbol: String,
        trades: [TradeOutcomeRecord],
        scoreExtractor: (TradeOutcomeRecord) -> Double?
    ) -> ModuleHitRate {
        var correctSignals = 0
        var totalSignals = 0
        var scoresWhenCorrect: [Double] = []
        var scoresWhenWrong: [Double] = []
        
        for trade in trades {
            guard let score = scoreExtractor(trade) else { continue }
            
            totalSignals += 1
            
            // Doğruluk Kriteri:
            // - Modül > 65 ve trade kazanç → Doğru
            // - Modül < 45 ve trade kayıp → Doğru
            // - Aksi → Yanlış
            
            let isCorrect: Bool
            if score > 65 && trade.pnlPercent > 0 {
                isCorrect = true
            } else if score < 45 && trade.pnlPercent < 0 {
                isCorrect = true
            } else if score >= 45 && score <= 65 && abs(trade.pnlPercent) < 2 {
                // Nötr bölge: küçük hareket doğru kabul
                isCorrect = true
            } else {
                isCorrect = false
            }
            
            if isCorrect {
                correctSignals += 1
                scoresWhenCorrect.append(score)
            } else {
                scoresWhenWrong.append(score)
            }
        }
        
        let hitRate = totalSignals > 0 ? Double(correctSignals) / Double(totalSignals) : 0.5
        let avgCorrect = scoresWhenCorrect.isEmpty ? 0 : scoresWhenCorrect.reduce(0, +) / Double(scoresWhenCorrect.count)
        let avgWrong = scoresWhenWrong.isEmpty ? 0 : scoresWhenWrong.reduce(0, +) / Double(scoresWhenWrong.count)
        
        return ModuleHitRate(
            module: module,
            symbol: symbol,
            totalSignals: totalSignals,
            correctSignals: correctSignals,
            hitRate: hitRate,
            avgScoreWhenCorrect: avgCorrect,
            avgScoreWhenWrong: avgWrong,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Güvenilirlik Matrisi
    
    /// Sembol × Modül güvenilirlik matrisi oluşturur (Dashboard için)
    func buildReliabilityMatrix() async -> [String: [String: Double]] {
        var matrix: [String: [String: Double]] = [:]
        
        let fm = FileManager.default
        let tradesPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ChironDataLake/trades")
        
        if let files = try? fm.contentsOfDirectory(atPath: tradesPath.path) {
            for file in files where file.hasSuffix("_history.json") {
                let symbol = file.replacingOccurrences(of: "_history.json", with: "")
                let report = await calculateHitRates(for: symbol)
                
                var symbolRates: [String: Double] = [:]
                for rate in report.moduleRates {
                    symbolRates[rate.module] = rate.hitRate
                }
                matrix[symbol] = symbolRates
            }
        }
        
        return matrix
    }
}
