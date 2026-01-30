import Foundation

/// Deterministic Scoring Configuration for Aether 4.0
struct AetherScoringConfig: Codable {
    let version: String
    let weights: Weights
    let thresholds: Thresholds
    let grade_scale: GradeScale
    
    struct Weights: Codable {
        let rates: Double
        let trend: Double
        let vix: Double
        let btc: Double
        let gld: Double
        let cpi: Double
        let labor: Double
        let growth: Double
    }
    
    struct Thresholds: Codable {
        let cpi_stale_days: Int
        let labor_stale_days: Int
        let growth_stale_days: Int
        let rates_stale_days: Int
        let market_stale_hours: Int
    }
    
    struct GradeScale: Codable {
        let A: Double
        let B: Double
        let C: Double
        let D: Double
    }
    
    static func load() -> AetherScoringConfig {
        guard let url = Bundle.main.url(forResource: "AetherScoringConfig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AetherScoringConfig.self, from: data) else {
            print("⚠️ Aether: Failed to load config. Using Hardcoded Fallback.")
            return fallback
        }
        return config
    }
    
    static let fallback = AetherScoringConfig(
        version: "4.0-Fallback",
        weights: Weights(rates: 0.16, trend: 0.14, vix: 0.14, btc: 0.12, gld: 0.10, cpi: 0.12, labor: 0.12, growth: 0.10),
        thresholds: Thresholds(cpi_stale_days: 60, labor_stale_days: 60, growth_stale_days: 120, rates_stale_days: 3, market_stale_hours: 24),
        grade_scale: GradeScale(A: 80, B: 70, C: 60, D: 50)
    )
}
