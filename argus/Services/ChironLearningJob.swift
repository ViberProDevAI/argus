import Foundation

// MARK: - Chiron Learning Job
/// Periodic learning cycle that analyzes performance and updates weights
@MainActor
final class ChironLearningJob {
    static let shared = ChironLearningJob()
    
    private let dataLake = ChironDataLakeService.shared
    private let weightStore = ChironWeightStore.shared
    
    private var lastAnalysisDate: Date?
    private var isRunning = false
    
    private init() {}
    
    // MARK: - Public API
    
    /// Trigger a learning analysis for a specific symbol
    func analyzeSymbol(_ symbol: String) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        
        print("🧠 Chiron Learning: Analyzing \(symbol)...")
        
        // 1. Load trade history - MİNİMUM ÖRNEKLEM KONTROLÜ
        let trades = await dataLake.loadTradeHistory(symbol: symbol)
        let minTradesRequired = 5 // Daha erken öğrenme başlasın

        guard trades.count >= minTradesRequired else {
            print("⏳ Yetersiz örneklem: \(symbol) için \(trades.count)/\(minTradesRequired) trade - öğrenme atlanıyor")
            return
        }

        // İstatistiksel güven aralığı kontrolü
        let pnls = trades.compactMap { $0.pnlPercent }
        guard pnls.count >= minTradesRequired else {
            print("⏳ Yetersiz PnL verisi: \(symbol) - öğrenme atlanıyor")
            return
        }

        let mean = pnls.reduce(0, +) / Double(pnls.count)
        let variance = pnls.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pnls.count)
        let stdDev = sqrt(variance)
        let confidenceInterval = 1.96 * stdDev / sqrt(Double(pnls.count)) // %95 güven aralığı

        // Güven aralığı çok geniş ise öğrenme güvenilir değil
        if confidenceInterval > 15.0 { // %15'ten büyük güven aralığı = belirsiz sonuçlar (gevşetildi)
            print("⚠️ Güven aralığı çok geniş (\(String(format: "%.1f", confidenceInterval))%) - öğrenme ertelendi")
            return
        }

        print("✅ Örneklem yeterli: \(trades.count) trade, güven aralığı: ±\(String(format: "%.1f", confidenceInterval))%")
        
        // 2. Analyze performance by engine
        let corseTrades = trades.filter { $0.engine == .corse }
        let pulseTrades = trades.filter { $0.engine == .pulse }
        let corseAnalysis = analyzeEngine(trades: corseTrades)
        let pulseAnalysis = analyzeEngine(trades: pulseTrades)
        
        // 3. Generate weight recommendations (LLM for 10+ trades, deterministic otherwise)
        if corseTrades.count >= 5 {
            // Use LLM for intelligent analysis
            let currentCorse = weightStore.getWeights(symbol: symbol, engine: .corse)
            if let llmWeights = await ChironLLMAdapter.shared.recommendWeights(
                symbol: symbol,
                engine: .corse,
                tradeHistory: corseTrades,
                currentWeights: currentCorse
            ) {
                weightStore.updateWeights(symbol: symbol, engine: .corse, weights: llmWeights)
                await logLearningEvent(symbol: symbol, engine: .corse, weights: llmWeights)
                print("🤖 Chiron: LLM weight recommendation applied for \(symbol) CORSE")
            }
        } else if let corseWeights = await generateWeightRecommendation(symbol: symbol, engine: .corse, analysis: corseAnalysis) {
            weightStore.updateWeights(symbol: symbol, engine: .corse, weights: corseWeights)
            await logLearningEvent(symbol: symbol, engine: .corse, weights: corseWeights)
        }
        
        if pulseTrades.count >= 5 {
            // Use LLM for intelligent analysis
            let currentPulse = weightStore.getWeights(symbol: symbol, engine: .pulse)
            if let llmWeights = await ChironLLMAdapter.shared.recommendWeights(
                symbol: symbol,
                engine: .pulse,
                tradeHistory: pulseTrades,
                currentWeights: currentPulse
            ) {
                weightStore.updateWeights(symbol: symbol, engine: .pulse, weights: llmWeights)
                await logLearningEvent(symbol: symbol, engine: .pulse, weights: llmWeights)
                print("🤖 Chiron: LLM weight recommendation applied for \(symbol) PULSE")
            }
        } else if let pulseWeights = await generateWeightRecommendation(symbol: symbol, engine: .pulse, analysis: pulseAnalysis) {
            weightStore.updateWeights(symbol: symbol, engine: .pulse, weights: pulseWeights)
            await logLearningEvent(symbol: symbol, engine: .pulse, weights: pulseWeights)
        }
        
        lastAnalysisDate = Date()
        print("✅ Chiron Learning: \(symbol) analysis complete")
    }
    
    /// Run full analysis on all symbols with trade history
    func runFullAnalysis() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        
        print("🧠 Chiron Learning: Starting full analysis...")
        
        // Get all symbols with trade history
        let fm = FileManager.default
        let tradesPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ChironDataLake/trades")
        
        guard let files = try? fm.contentsOfDirectory(at: tradesPath, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            let symbol = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_history", with: "")
            await analyzeSymbol(symbol)
        }
        
        lastAnalysisDate = Date()
        print("✅ Chiron Learning: Full analysis complete")
    }
    
    // MARK: - Analysis Logic
    
    private struct EngineAnalysis {
        let tradeCount: Int
        let winRate: Double
        let avgPnl: Double
        let modulePerformance: [String: Double] // module -> correlation with wins
    }
    
    private func analyzeEngine(trades: [TradeOutcomeRecord]) -> EngineAnalysis {
        guard !trades.isEmpty else {
            return EngineAnalysis(tradeCount: 0, winRate: 0, avgPnl: 0, modulePerformance: [:])
        }
        
        let wins = trades.filter { $0.pnlPercent > 0 }
        let winRate = Double(wins.count) / Double(trades.count)
        let avgPnl = trades.map { $0.pnlPercent }.reduce(0, +) / Double(trades.count)
        
        // Calculate module correlations with wins
        var modulePerformance: [String: Double] = [:]
        
        // Orion correlation
        let orionWins = wins.compactMap { $0.orionScoreAtEntry }
        let orionLosses = trades.filter { $0.pnlPercent <= 0 }.compactMap { $0.orionScoreAtEntry }
        if !orionWins.isEmpty && !orionLosses.isEmpty {
            let avgOrionWin = orionWins.reduce(0, +) / Double(orionWins.count)
            let avgOrionLoss = orionLosses.reduce(0, +) / Double(orionLosses.count)
            modulePerformance["orion"] = avgOrionWin - avgOrionLoss // Higher = better predictor
        }
        
        // Atlas correlation
        let atlasWins = wins.compactMap { $0.atlasScoreAtEntry }
        let atlasLosses = trades.filter { $0.pnlPercent <= 0 }.compactMap { $0.atlasScoreAtEntry }
        if !atlasWins.isEmpty && !atlasLosses.isEmpty {
            let avgAtlasWin = atlasWins.reduce(0, +) / Double(atlasWins.count)
            let avgAtlasLoss = atlasLosses.reduce(0, +) / Double(atlasLosses.count)
            modulePerformance["atlas"] = avgAtlasWin - avgAtlasLoss
        }
        
        // Phoenix correlation
        let phoenixWins = wins.compactMap { $0.phoenixScoreAtEntry }
        let phoenixLosses = trades.filter { $0.pnlPercent <= 0 }.compactMap { $0.phoenixScoreAtEntry }
        if !phoenixWins.isEmpty && !phoenixLosses.isEmpty {
            let avgPhoenixWin = phoenixWins.reduce(0, +) / Double(phoenixWins.count)
            let avgPhoenixLoss = phoenixLosses.reduce(0, +) / Double(phoenixLosses.count)
            modulePerformance["phoenix"] = avgPhoenixWin - avgPhoenixLoss
        }
        
        return EngineAnalysis(
            tradeCount: trades.count,
            winRate: winRate,
            avgPnl: avgPnl,
            modulePerformance: modulePerformance
        )
    }
    
    private func generateWeightRecommendation(
        symbol: String,
        engine: AutoPilotEngine,
        analysis: EngineAnalysis
    ) async -> ChironModuleWeights? {
        guard analysis.tradeCount >= 3 else { return nil }
        
        // Get current weights as baseline
        let current = weightStore.getWeights(symbol: symbol, engine: engine)
        
        // 1. Bayesian Smoothing for each module
        // Posterior = (Alpha + Wins) / (Alpha + Beta + Total)
        // Prior: Alpha=5, Beta=5 (Neutral, weight ~0.5)
        
        func calculateBayesianScore(module: String) async -> Double {
            // Load global accuracy for this module (to check general reliability)
            let records = await dataLake.loadModuleAccuracy(module: module)
            
            // Filter for this symbol to be specific (Concept Drift handling)
            let symbolRecords = records.filter { $0.symbol == symbol }
            
            // If not enough symbol specific data, mix with global data (Shrinkage)
            let relevantRecords = symbolRecords.count < 5 ? records : symbolRecords
            
            guard !relevantRecords.isEmpty else { return 0.5 }
            
            let wins = Double(relevantRecords.filter { $0.wasCorrect }.count)
            let total = Double(relevantRecords.count)
            
            let alpha = 5.0
            let beta = 5.0
            
            return (alpha + wins) / (alpha + beta + total)
        }
        
        let orionScore = await calculateBayesianScore(module: "orion")
        let atlasScore = await calculateBayesianScore(module: "atlas")
        let phoenixScore = await calculateBayesianScore(module: "phoenix")
        let aetherScore = await calculateBayesianScore(module: "aether")
        
        // 2. Map Scores to Weights (Dynamic Ranges)
        // Base Ranges:
        // Orion: 0.10 - 0.40
        // Atlas: 0.10 - 0.40
        // Phoenix: 0.10 - 0.35
        
        func mapScoreToWeight(score: Double, minW: Double, maxW: Double) -> Double {
            // Score 0.0 -> minW
            // Score 0.5 -> mid
            // Score 1.0 -> maxW
            let range = maxW - minW
            return minW + (score * range)
        }
        
        var orion = mapScoreToWeight(score: orionScore, minW: 0.15, maxW: 0.45)
        var atlas = mapScoreToWeight(score: atlasScore, minW: 0.15, maxW: 0.45)
        var phoenix = mapScoreToWeight(score: phoenixScore, minW: 0.10, maxW: 0.35)
        var aether = mapScoreToWeight(score: aetherScore, minW: 0.10, maxW: 0.30)
        
        // Normalize basics
        let totalDynamic = orion + atlas + phoenix + aether
        
        // Keep fixed/minor modules steady but normalize
        let hermes = current.hermes // News usually manual/static
        let demeter = current.demeter
        let athena = current.athena
        let fixedTotal = hermes + demeter + athena
        
        if totalDynamic + fixedTotal > 1.0 {
            // Scale down dynamic parts to fit
            let available = 1.0 - fixedTotal
            let scale = available / totalDynamic
            orion *= scale
            atlas *= scale
            phoenix *= scale
            aether *= scale
        }
        
        // Anlaşılır Türkçe açıklama oluştur
        let winRateInt = Int(analysis.winRate * 100)
        
        var summaryParts: [String] = []
        summaryParts.append("Bayesian Analiz (% \(winRateInt) Başarı)")
        
        if orionScore > 0.6 { summaryParts.append("Orion Güvenilir (Skor: \(String(format: "%.2f", orionScore)))") }
        if atlasScore > 0.6 { summaryParts.append("Atlas Güçlü (Skor: \(String(format: "%.2f", atlasScore)))") }
        if orionScore < 0.4 { summaryParts.append("Orion Zayıf") }
        
        let reasoning = summaryParts.joined(separator: ". ")
        
        return ChironModuleWeights(
            orion: orion,
            atlas: atlas,
            phoenix: phoenix,
            aether: aether,
            hermes: hermes,
            demeter: demeter,
            athena: athena,
            updatedAt: Date(),
            confidence: min(0.95, (Double(analysis.tradeCount) * 0.05) + 0.5),
            reasoning: reasoning
        )
    }
    
    private func logLearningEvent(symbol: String, engine: AutoPilotEngine, weights: ChironModuleWeights) async {
        let event = ChironLearningEvent(
            eventType: .weightUpdate,
            symbol: symbol,
            engine: engine,
            description: "Ağırlık güncellendi: O:\(Int(weights.orion*100))% A:\(Int(weights.atlas*100))% P:\(Int(weights.phoenix*100))%",
            reasoning: weights.reasoning,
            confidence: weights.confidence
        )
        await dataLake.logLearningEvent(event)
    }
}
