import Foundation

/// "The Hospital" - Tracks provider health stats.
/// Persists to disk via DiskCacheService.
/// "The Hospital" - Tracks provider health stats.
/// Persists to disk via DiskCacheService.
actor HealthStore {
    static let shared = HealthStore()
    
    private let cacheKey = "heimdall_health_store"
    private var scores: [String: ProviderScore] = [:]
    
    private init() {
        Task { await loadscores() }
    }
    
    // MARK: - Core Logic
    
    func reset(provider: String) {
        scores.removeValue(forKey: provider)
        saveScores()
        print("🟢 HealthStore: Reset scores for \(provider)")
    }
    
    func getScore(for providerName: String) -> ProviderScore {
        return scores[providerName] ?? ProviderScore.neutral
    }
    
    func reportSuccess(provider: String, latency: Double) {
        var score = scores[provider] ?? ProviderScore.neutral
        score.lastUpdated = Date()
        
        // Decay old latency (Exponential Moving Average) alpha = 0.2
        score.latencyP50 = (score.latencyP50 * 0.8) + (latency * 0.2)
        
        // Boost success rate slightly towards 1.0
        score.successRate = min(1.0, score.successRate + 0.01)
        
        // Relax penalty over time
        score.penaltyScore = max(0, score.penaltyScore - 1.0)
        
        scores[provider] = score
        saveScores()
    }
    
    func reportError(provider: String, error: Error) {
        var score = scores[provider] ?? ProviderScore.neutral
        score.lastUpdated = Date()
        
        // HEIMDALL 6.1: Differentiate User Error vs Provider Error
        if let hErr = error as? HeimdallCoreError {
            switch hErr.category {
            case .symbolNotFound:
                // User queried invalid symbol. Provider is healthy.
                // Do not increment errorCount or penalty.
                print("ℹ️ HealthStore: Ignoring SymbolNotFound for \(provider) health.")
                // Should we count it as "neutral"?
                // Just return without modifying 'scores'.
                // But we must save if we modified 'lastUpdated' above? 
                // Actually, let's just return.
                return 
                
            case .authInvalid:
                 score.errorCount += 1
                 score.penaltyScore += 50.0 // Heavy
                 score.successRate *= 0.5
            case .entitlementDenied:
                 score.errorCount += 1
                 score.penaltyScore += 5.0 
            case .rateLimited:
                 score.errorCount += 1
                 score.penaltyScore += 20.0
                 score.successRate *= 0.9
            case .serverError:
                 score.errorCount += 1
                 score.penaltyScore += 10.0
            default:
                 score.errorCount += 1
                 score.penaltyScore += 2.0
            }
        } else if let urlError = error as? URLError {
             score.errorCount += 1
             if urlError.code == .userAuthenticationRequired { score.penaltyScore += 50.0 }
             else { score.penaltyScore += 5.0 }
        } else {
             score.errorCount += 1
             score.penaltyScore += 5.0
        }
        
        scores[provider] = score
        saveScores()
    }
    
    // MARK: - Persistence
    private func saveScores() {
        let snapshot = scores // Capture for async save
        Task { @MainActor in
            DiskCacheService.shared.save(key: "heimdall_health_store", data: snapshot, harvest: false)
        }
    }
    
    private func loadscores() async {
        if let stored = await MainActor.run(body: { DiskCacheService.shared.get(key: "heimdall_health_store", type: [String: ProviderScore].self, maxAge: 86400 * 7) }) {
            self.scores = stored
        }
    }
}
