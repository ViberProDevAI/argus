import Foundation

// MARK: - Orion Component Snapshot
/// Trade anındaki tüm Orion bileşen skorlarını saklar.
/// Chiron'un hangi bileşenin başarılı olduğunu öğrenmesi için kullanılır.
struct OrionComponentSnapshot: Codable, Sendable, Equatable {
    let timestamp: Date
    let symbol: String
    
    // Bileşen Skorları (0-100 arası, ağırlık uygulanmadan önce)
    let structureScore: Double
    let trendScore: Double
    let momentumScore: Double
    let patternScore: Double
    let volatilityScore: Double
    
    // Toplam Orion Skoru
    let orionTotal: Double
    
    // O anki ağırlıklar (hangi config kullanıldı?)
    let usedWeights: OrionWeightSnapshot
    
    // MARK: - Factory Method
    
    /// OrionScoreResult'tan snapshot oluşturur
    static func from(result: OrionScoreResult, weights: OrionWeightSnapshot) -> OrionComponentSnapshot {
        OrionComponentSnapshot(
            timestamp: Date(),
            symbol: result.symbol,
            structureScore: result.components.structure,
            trendScore: result.components.trend,
            momentumScore: result.components.momentum,
            patternScore: result.components.pattern,
            volatilityScore: result.components.volatility,
            orionTotal: result.score,
            usedWeights: weights
        )
    }
    
    // MARK: - Analysis Helpers
    
    /// En yüksek skorlu bileşeni döndürür
    var dominantComponent: String {
        let components: [(String, Double)] = [
            ("structure", structureScore),
            ("trend", trendScore),
            ("momentum", momentumScore),
            ("pattern", patternScore),
            ("volatility", volatilityScore)
        ]
        return components.max(by: { $0.1 < $1.1 })?.0 ?? "unknown"
    }
    
    /// Tüm bileşenleri dictionary olarak döndürür
    var componentDict: [String: Double] {
        [
            "structure": structureScore,
            "trend": trendScore,
            "momentum": momentumScore,
            "pattern": patternScore,
            "volatility": volatilityScore
        ]
    }
}

// MARK: - Orion Weight Snapshot
/// Kullanılan ağırlık konfigürasyonunun anlık görüntüsü
struct OrionWeightSnapshot: Codable, Sendable, Equatable {
    let structure: Double
    let trend: Double
    let momentum: Double
    let pattern: Double
    let volatility: Double
    
    // MARK: - Defaults
    
    static var `default`: OrionWeightSnapshot {
        OrionWeightSnapshot(
            structure: 0.30,
            trend: 0.30,
            momentum: 0.25,
            pattern: 0.10,
            volatility: 0.05
        )
    }
    
    // MARK: - Normalization
    
    /// Ağırlıkların toplamının 1.0 olmasını sağlar
    func normalized() -> OrionWeightSnapshot {
        let sum = structure + trend + momentum + pattern + volatility
        guard sum > 0 else { return .default }
        
        return OrionWeightSnapshot(
            structure: structure / sum,
            trend: trend / sum,
            momentum: momentum / sum,
            pattern: pattern / sum,
            volatility: volatility / sum
        )
    }
    
    // MARK: - Factory
    
    /// OrionV2TuningConfig'den oluşturur
    static func from(config: OrionV2TuningConfig) -> OrionWeightSnapshot {
        OrionWeightSnapshot(
            structure: config.structureWeight,
            trend: config.trendWeight,
            momentum: config.momentumWeight,
            pattern: config.patternWeight,
            volatility: config.volatilityWeight
        )
    }
    
    // MARK: - Display
    
    var summary: String {
        "S:\(Int(structure * 100))% T:\(Int(trend * 100))% M:\(Int(momentum * 100))% P:\(Int(pattern * 100))% V:\(Int(volatility * 100))%"
    }
}
