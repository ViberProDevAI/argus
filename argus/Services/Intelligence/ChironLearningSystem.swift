import Foundation
import Combine

// MARK: - Chiron: BIST Öğrenme & Risk Yönetimi
// Reinforcement learning ile optimize weight'ler ve regime detection
actor ChironLearningSystem {
    static let shared = ChironLearningSystem()
    
    // MARK: - Models
    
    struct LearningState: Sendable {
        var weights: OrionWeights
        var regime: MarketRegime
        var regimeConfidence: Double // 0-1
        var healthScore: Double // 0-100
        var lastUpdated: Date
        
        var isHealthy: Bool {
            healthScore > 60
        }
    }
    
    struct OrionWeights: Sendable, Equatable {
        var trend: Double
        var momentum: Double
        var relativeStrength: Double
        var structure: Double
        var pattern: Double
        var volatility: Double
        
        var normalized: OrionWeights {
            let total = trend + momentum + relativeStrength + structure + pattern + volatility
            guard total > 0 else { return self }
            
            return OrionWeights(
                trend: trend / total,
                momentum: momentum / total,
                relativeStrength: relativeStrength / total,
                structure: structure / total,
                pattern: pattern / total,
                volatility: volatility / total
            )
        }
    }
    
    enum MarketRegime: String, CaseIterable, Sendable {
        case bull = "Boğa Piyasası"
        case bear = "Ayı Piyasası"
        case sideways = "Yatay Piyasa"
        case volatile = "Yüksek Volatilite"
        case crash = "Piyasa Çöküşü"
        
        var color: String {
            switch self {
            case .bull: return "green"
            case .bear: return "red"
            case .sideways: return "yellow"
            case .volatile: return "orange"
            case .crash: return "purple"
            }
        }
    }
    
    struct TradeExperience: Sendable {
        let timestamp: Date
        let symbol: String
        let weights: OrionWeights
        let outcome: TradeOutcome
        let duration: TimeInterval
        let profitPercent: Double
        
        enum TradeOutcome: String, Sendable {
            case winner = "Kazanan"
            case loser = "Kaybeden"
            case scratch = "Sıfır"
        }
    }
    
    // MARK: - State
    
    private var currentState: LearningState = LearningState(
        weights: OrionWeights(
            trend: 20.0,
            momentum: 20.0,
            relativeStrength: 20.0,
            structure: 10.0,
            pattern: 10.0,
            volatility: 20.0
        ),
        regime: .sideways,
        regimeConfidence: 0.5,
        healthScore: 50.0,
        lastUpdated: Date()
    )
    
    private var experienceHistory: [TradeExperience] = []
    private var regimeHistory: [(Date, MarketRegime)] = []
    
    // MARK: - Main Functions
    
    func getCurrentState() -> LearningState {
        return currentState
    }
    
    func recordTrade(
        symbol: String,
        weights: OrionWeights,
        outcome: TradeExperience.TradeOutcome,
        duration: TimeInterval,
        profitPercent: Double
    ) async {
        let experience = TradeExperience(
            timestamp: Date(),
            symbol: symbol,
            weights: weights,
            outcome: outcome,
            duration: duration,
            profitPercent: profitPercent
        )
        
        experienceHistory.append(experience)
        
        // Keep only last 1000 experiences
        if experienceHistory.count > 1000 {
            experienceHistory.removeFirst(experienceHistory.count - 1000)
        }
        
        // Update weights based on outcome
        await optimizeWeights(experience: experience)
        
        // Update health score
        await updateHealthScore()
        
        // Update regime
        await updateRegime()
        
        currentState = LearningState(
            weights: currentState.weights,
            regime: currentState.regime,
            regimeConfidence: currentState.regimeConfidence,
            healthScore: currentState.healthScore,
            lastUpdated: Date()
        )
        
        print("🧠 CHIRON: Trade recorded - \(symbol) (\(outcome.rawValue)) - New health: \(Int(currentState.healthScore))")
    }
    
    func predictRegime(symbol: String, recentReturns: [Double]) async -> MarketRegime {
        guard recentReturns.count >= 5 else {
            return currentState.regime
        }
        
        // Calculate regime indicators
        let returns = recentReturns
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let volatility = calculateVolatility(returns)
        let trend = calculateTrend(returns)
        
        // Detect regime
        if volatility > 3.0 {
            return .crash
        } else if volatility > 2.0 {
            return .volatile
        } else if avgReturn > 1.0 && trend > 0 {
            return .bull
        } else if avgReturn < -1.0 && trend < 0 {
            return .bear
        } else {
            return .sideways
        }
    }
    
    // MARK: - Learning Algorithms
    
    private func optimizeWeights(experience: TradeExperience) async {
        let learningRate = 0.05 // Yavaş öğrenme
        
        switch experience.outcome {
        case .winner:
            // Increase weights that contributed to win
            var newWeights = currentState.weights
            newWeights.trend += experience.weights.trend * learningRate
            newWeights.momentum += experience.weights.momentum * learningRate
            newWeights.relativeStrength += experience.weights.relativeStrength * learningRate
            
            // Decrease weights that might have hurt
            newWeights.pattern *= (1 - learningRate)
            newWeights.structure *= (1 - learningRate)
            
            currentState.weights = newWeights
            
        case .loser:
            // Decrease weights that likely caused loss
            var newWeights = currentState.weights
            newWeights.trend *= (1 - learningRate)
            newWeights.momentum *= (1 - learningRate)
            newWeights.pattern *= (1 - learningRate)
            
            // Increase weights that might help next time
            newWeights.relativeStrength += experience.weights.relativeStrength * learningRate
            newWeights.volatility += experience.weights.volatility * learningRate
            
            currentState.weights = newWeights
            
        case .scratch:
            // Slight adjustment based on experience
            let adjustment = experience.profitPercent > 0 ? 0.01 : -0.01
            currentState.weights.trend += adjustment
            currentState.weights.momentum += adjustment
        }
    }
    
    private func updateHealthScore() async {
        guard experienceHistory.count >= 10 else {
            return
        }
        
        // Calculate recent win rate
        let recentExperience = experienceHistory.suffix(50)
        let winCount = recentExperience.filter { $0.outcome == .winner }.count
        let winRate = Double(winCount) / Double(recentExperience.count)
        
        // Update health score based on win rate
        let targetHealth = winRate * 100
        currentState.healthScore = (currentState.healthScore * 0.8) + (targetHealth * 0.2)
        
        print("🧠 CHIRON: Win rate \(String(format: "%.1f%%", winRate)) -> Health: \(Int(currentState.healthScore))")
    }
    
    private func updateRegime() async {
        guard experienceHistory.count >= 20 else {
            return
        }
        
        // Calculate regime transitions
        let recentExperiences = experienceHistory.suffix(100)
        let regimes = recentExperiences.map { $0.weights }
        
        // Simple regime detection based on recent outcomes
        let winnerWeights = regimes.filter { experience in
            recentExperiences.contains { $0.outcome == .winner && $0.weights == experience }
        }
        
        if winnerWeights.count >= 5 {
            // Check which weights dominated
            let avgTrend = winnerWeights.reduce(0) { $0 + $1.trend } / Double(winnerWeights.count)
            let avgMomentum = winnerWeights.reduce(0) { $0 + $1.momentum } / Double(winnerWeights.count)
            let avgRelativeStrength = winnerWeights.reduce(0) { $0 + $1.relativeStrength } / Double(winnerWeights.count)
            
            if avgTrend > 25 && avgMomentum > 25 {
                currentState.regime = .bull
                currentState.regimeConfidence = 0.7
            } else if avgTrend < 15 && avgMomentum < 15 {
                currentState.regime = .bear
                currentState.regimeConfidence = 0.7
            } else {
                currentState.regime = .sideways
                currentState.regimeConfidence = 0.5
            }
        }
        
        // Add to regime history
        regimeHistory.append((Date(), currentState.regime))
        
        // Keep only last 1000 regimes
        if regimeHistory.count > 1000 {
            regimeHistory.removeFirst(regimeHistory.count - 1000)
        }
        
        print("🧠 CHIRON: Regime changed to \(currentState.regime.rawValue) (Confidence: \(String(format: "%.1f%%", currentState.regimeConfidence * 100)))")
    }
    
    // MARK: - Helper Functions
    
    private func calculateVolatility(_ returns: [Double]) -> Double {
        let avg = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - avg, 2) }.reduce(0, +) / Double(returns.count)
        return sqrt(variance)
    }
    
    private func calculateTrend(_ returns: [Double]) -> Double {
        guard returns.count >= 2 else { return 0 }
        
        let lastReturns = returns.suffix(5)
        let positiveReturns = lastReturns.filter { $0 > 0 }.count
        let negativeReturns = lastReturns.filter { $0 < 0 }.count
        
        return Double(positiveReturns - negativeReturns) / Double(positiveReturns + negativeReturns + 1)
    }
    
    // MARK: - Export Functions
    
    func exportLearningData() async -> [String: Any] {
        var data: [String: Any] = [:]
        
        data["currentWeights"] = [
            "trend": currentState.weights.trend,
            "momentum": currentState.weights.momentum,
            "relativeStrength": currentState.weights.relativeStrength,
            "structure": currentState.weights.structure,
            "pattern": currentState.weights.pattern,
            "volatility": currentState.weights.volatility
        ]
        
        data["regime"] = currentState.regime.rawValue
        data["regimeConfidence"] = currentState.regimeConfidence
        data["healthScore"] = currentState.healthScore
        data["experienceCount"] = experienceHistory.count
        
        return data
    }
    
    func reset() async {
        experienceHistory = []
        regimeHistory = []
        
        currentState = LearningState(
            weights: OrionWeights(
                trend: 20.0,
                momentum: 20.0,
                relativeStrength: 20.0,
                structure: 10.0,
                pattern: 10.0,
                volatility: 20.0
            ),
            regime: .sideways,
            regimeConfidence: 0.5,
            healthScore: 50.0,
            lastUpdated: Date()
        )
        
        print("🧠 CHIRON: System reset to initial state")
    }
}