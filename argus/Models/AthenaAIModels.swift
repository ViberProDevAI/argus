import Foundation

// MARK: - Athena AI Core Models
// Yapay zeka tabanlı "Smart Beta" ve "Factor Investing" modelleri.

/// Modelin girdisi olan özellik vektörü (High-Level Factors)
struct AthenaFeatureVector: Codable, Sendable {
    // 0-100 Normalized Factor Scores
    let valueScore: Double
    let qualityScore: Double
    let momentumScore: Double
    let sizeScore: Double
    let riskScore: Double
}

/// Modelin öğrendiği ağırlıklar (Weights)
struct AthenaModelWeights: Codable, Sendable {
    var version: String
    var lastUpdated: Date = Date()
    
    // Factor Weights
    var bias: Double
    var valueWeight: Double
    var qualityWeight: Double
    var momentumWeight: Double
    var sizeWeight: Double
    var riskWeight: Double
}

/// Model Tahmini
struct AthenaPrediction: Codable, Sendable {
    let inputFeatures: AthenaFeatureVector
    let predictedScore: Double      // 0-100 Final Score
    let confidence: Double          // 0-1 Model Confidence
    let modelUsed: String           // Model Version
    let dominantFactor: String      // Explainer
}

/// Eğitim Verisi (Experience Replay)
struct AthenaExperience: Codable {
    let date: Date
    let symbol: String
    let features: AthenaFeatureVector
    let outcome: Double             // Actual % Return
    let reward: Double              // Calculated Reward
}
