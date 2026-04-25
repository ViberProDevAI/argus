import Foundation

enum Severity: String, Codable {
    case low = "Dusuk"
    case medium = "Orta"
    case high = "Yuksek"
}

struct Contradiction: Identifiable, Codable {
    let id: String
    let module1: String
    let stance1: String
    let module2: String
    let stance2: String
    let description: String
    
    init(module1: String, stance1: String, module2: String, stance2: String, description: String) {
        self.id = "\(module1)_\(module2)"
        self.module1 = module1
        self.stance1 = stance1
        self.module2 = module2
        self.stance2 = stance2
        self.description = description
    }
}

struct ContradictionOutcome: Codable {
    let module1: String
    let module2: String
    let winRate: Double
    let avgPnL: Double
    let sampleSize: Int
    
    var summary: String {
        "Bu celiski \(sampleSize) kez yasandi, %\(String(format: "%.0f", winRate * 100)) kayip"
    }
}

struct ContradictionAnalysis: Codable {
    let contradictions: [Contradiction]
    let severity: Severity
    let historicalOutcome: ContradictionOutcome?
    let suggestedConfidenceDrop: Double
    let recommendation: String
    
    var hasContradictions: Bool {
        !contradictions.isEmpty
    }
}

actor SelfQuestionEngine {
    static let shared = SelfQuestionEngine()
    
    private init() {}
    
    // MARK: - Analyze Contradictions
    
    func analyzeContradictions(
        orionDecision: OrionModuleDecision,
        atlasDecision: AtlasModuleDecision?,
        aetherDecision: AetherModuleDecision,
        hermesDecision: HermesModuleDecision?
    ) async -> ContradictionAnalysis {
        
        var contradictions: [Contradiction] = []
        
        // Orion vs Aether
        if let contradiction = checkOrionVsAether(orion: orionDecision, aether: aetherDecision) {
            contradictions.append(contradiction)
        }
        
        // Atlas vs Aether
        if let atlas = atlasDecision, let contradiction = checkAtlasVsAether(atlas: atlas, aether: aetherDecision) {
            contradictions.append(contradiction)
        }
        
        // Orion vs Hermes
        if let hermes = hermesDecision, let contradiction = checkOrionVsHermes(orion: orionDecision, hermes: hermes) {
            contradictions.append(contradiction)
        }
        
        // Determine severity
        let severity = determineSeverity(contradictions: contradictions)
        
        // Get historical outcome
        let historicalOutcome = await getHistoricalContradictionOutcome(contradictions: contradictions)
        
        // Calculate confidence drop
        let suggestedDrop = calculateConfidenceDrop(
            contradictions: contradictions,
            severity: severity,
            historicalOutcome: historicalOutcome
        )
        
        // Generate recommendation
        let recommendation = generateRecommendation(
            contradictions: contradictions,
            severity: severity,
            historicalOutcome: historicalOutcome
        )
        
        return ContradictionAnalysis(
            contradictions: contradictions,
            severity: severity,
            historicalOutcome: historicalOutcome,
            suggestedConfidenceDrop: suggestedDrop,
            recommendation: recommendation
        )
    }
    
    // MARK: - Contradiction Checks
    
    private func checkOrionVsAether(orion: OrionModuleDecision, aether: AetherModuleDecision) -> Contradiction? {
        let orionAction = orion.trendSignal
        let aetherStance = aether.stance
        
        let isBuyInRiskOff = (orionAction == "buy" || orionAction == "strong_buy") && aetherStance == "risk_off"
        let isSellInRiskOn = (orionAction == "sell" || orionAction == "strong_sell") && aetherStance == "risk_on"
        
        if isBuyInRiskOff {
            return Contradiction(
                module1: "Orion",
                stance1: "AL",
                module2: "Aether",
                stance2: "Risk Off",
                description: "Teknik alim sinyali ama makro risk off"
            )
        }
        
        if isSellInRiskOn {
            return Contradiction(
                module1: "Orion",
                stance1: "SAT",
                module2: "Aether",
                stance2: "Risk On",
                description: "Teknik satis sinyali ama makro risk on"
            )
        }
        
        return nil
    }
    
    private func checkAtlasVsAether(atlas: AtlasModuleDecision, aether: AetherModuleDecision) -> Contradiction? {
        let atlasAction = atlas.action
        let aetherStance = aether.stance
        
        let isBuyInRiskOff = (atlasAction == "buy" || atlasAction == "strong_buy") && aetherStance == "risk_off"
        
        if isBuyInRiskOff {
            return Contradiction(
                module1: "Atlas",
                stance1: "AL",
                module2: "Aether",
                stance2: "Risk Off",
                description: "Temel alim sinyali ama makro risk off"
            )
        }
        
        return nil
    }
    
    private func checkOrionVsHermes(orion: OrionModuleDecision, hermes: HermesModuleDecision) -> Contradiction? {
        let orionAction = orion.trendSignal
        let hermesSentiment = hermes.sentiment
        
        let isBuyWithNegativeNews = (orionAction == "buy" || orionAction == "strong_buy") && 
                                     (hermesSentiment == "negative" || hermesSentiment == "strong_negative")
        let isSellWithPositiveNews = (orionAction == "sell" || orionAction == "strong_sell") && 
                                      (hermesSentiment == "positive" || hermesSentiment == "strong_positive")
        
        if isBuyWithNegativeNews {
            return Contradiction(
                module1: "Orion",
                stance1: "AL",
                module2: "Hermes",
                stance2: "Negatif Haber",
                description: "Teknik alim ama haberler olumsuz"
            )
        }
        
        if isSellWithPositiveNews {
            return Contradiction(
                module1: "Orion",
                stance1: "SAT",
                module2: "Hermes",
                stance2: "Pozitif Haber",
                description: "Teknik satis ama haberler olumlu"
            )
        }
        
        return nil
    }
    
    // MARK: - Severity
    
    private func determineSeverity(contradictions: [Contradiction]) -> Severity {
        if contradictions.count >= 3 { return .high }
        if contradictions.count >= 2 { return .medium }
        if contradictions.count == 1 { return .low }
        return .low
    }
    
    // MARK: - Historical Outcome
    
    private func getHistoricalContradictionOutcome(contradictions: [Contradiction]) async -> ContradictionOutcome? {
        guard let firstContradiction = contradictions.first else { return nil }
        
        let results = await AlkindusRAGEngine.shared.searchContradictionPatterns(
            module1: firstContradiction.module1,
            module2: firstContradiction.module2
        )
        
        guard let result = results.first else { return nil }
        
        var totalWinRate = 0.0
        var totalPnL = 0.0
        var totalSample = 0
        
        for res in results.prefix(5) {
            if let winRate = Double(res.metadata["win_rate"] ?? "0"),
               let pnl = Double(res.metadata["pnl"] ?? "0"),
               let sample = Int(res.metadata["sample_size"] ?? "0") {
                totalWinRate += winRate * Double(sample)
                totalPnL += pnl * Double(sample)
                totalSample += sample
            }
        }
        
        guard totalSample > 0 else { return nil }
        
        return ContradictionOutcome(
            module1: firstContradiction.module1,
            module2: firstContradiction.module2,
            winRate: totalWinRate / Double(totalSample),
            avgPnL: totalPnL / Double(totalSample),
            sampleSize: totalSample
        )
    }
    
    // MARK: - Confidence Adjustment
    
    private func calculateConfidenceDrop(
        contradictions: [Contradiction],
        severity: Severity,
        historicalOutcome: ContradictionOutcome?
    ) -> Double {
        var drop = 0.0
        
        // Base drop by severity
        switch severity {
        case .high: drop = 0.25
        case .medium: drop = 0.15
        case .low: drop = 0.08
        }
        
        // Adjust based on historical outcome
        if let outcome = historicalOutcome {
            if outcome.winRate < 0.4 {
                drop += 0.15
            } else if outcome.winRate < 0.5 {
                drop += 0.08
            }
        }
        
        return min(drop, 0.4)
    }
    
    // MARK: - Recommendation
    
    private func generateRecommendation(
        contradictions: [Contradiction],
        severity: Severity,
        historicalOutcome: ContradictionOutcome?
    ) -> String {
        if contradictions.isEmpty {
            return "Celiski tespit edilmedi"
        }
        
        if let outcome = historicalOutcome {
            if outcome.winRate < 0.4 {
                return "Gecmis veriler bu celiskide yuksek kayip riski gosteriyor"
            } else if outcome.winRate < 0.5 {
                return "Gecmis veriler kararsiz, temkinli olun"
            } else {
                return "Gecmis veriler olumlu ama dikkatli olun"
            }
        }
        
        switch severity {
        case .high:
            return "Coklu celiski var, pozisyon kucultun"
        case .medium:
            return "Celiski mevcut, guveni dusurun"
        case .low:
            return "Hafif celiski, dikkatli izleyin"
        }
    }
    
    // MARK: - Record Contradiction
    
    func recordContradiction(
        symbol: String,
        module1: String,
        stance1: String,
        module2: String,
        stance2: String,
        finalDecision: String,
        outcome: String,
        pnlPercent: Double
    ) async {
        await AlkindusRAGEngine.shared.syncContradiction(
            symbol: symbol,
            module1: module1,
            stance1: stance1,
            module2: module2,
            stance2: stance2,
            finalDecision: finalDecision,
            outcome: outcome,
            pnlPercent: pnlPercent
        )
        
        print("SelfQuestion: \(symbol) celiski sonucu kaydedildi")
    }
}

// MARK: - Module Decision Types

struct OrionModuleDecision: Codable {
    let trendSignal: String
    let confidence: Double
    let rsi: Double
    let macdSignal: String
}

struct AtlasModuleDecision: Codable {
    let action: String
    let confidence: Double
    let score: Double
}

struct AetherModuleDecision: Codable {
    let stance: String
    let confidence: Double
    let riskLevel: Double
}

struct HermesModuleDecision: Codable {
    let sentiment: String
    let confidence: Double
    let impactScore: Double
}
