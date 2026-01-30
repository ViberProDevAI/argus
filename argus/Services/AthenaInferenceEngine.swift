import Foundation

/// Athena Inference Engine (AI Core)
/// Responsible for taking raw factor features and producing a prediction
/// using a learned model (or heuristic weights initially).
final class AthenaInferenceEngine {
    static let shared = AthenaInferenceEngine()
    
    // Default weights (can be updated via training)
    private var currentWeights: AthenaModelWeights
    
    private init() {
        // Initialize with default heuristic weights (The "Expert System" Baseline)
        self.currentWeights = AthenaModelWeights(
            version: "Athena-V1-Expert",
            bias: 0.0,
            valueWeight: 0.20,
            qualityWeight: 0.25,
            momentumWeight: 0.25,
            sizeWeight: 0.15,
            riskWeight: 0.15
        )
    }
    
    /// Update weights (e.g. after training/learning)
    func updateWeights(_ newWeights: AthenaModelWeights) {
        self.currentWeights = newWeights
        print("🧠 Athena weights updated to version: \(newWeights.version)")
    }
    
    /// Run inference on a feature vector
    func predict(features: AthenaFeatureVector) -> AthenaPrediction {
        // Linear Combination (Dot Product)
        // Score = (w1*f1) + (w2*f2) + ... + bias
        
        let rawScore = (features.valueScore * currentWeights.valueWeight) +
                       (features.qualityScore * currentWeights.qualityWeight) +
                       (features.momentumScore * currentWeights.momentumWeight) +
                       (features.sizeScore * currentWeights.sizeWeight) +
                       (features.riskScore * currentWeights.riskWeight) +
                       currentWeights.bias
        
        // Normalize output to 0-100 range
        let finalScore = min(100.0, max(0.0, rawScore))
        
        // Determine detailed confidence/reasoning
        let dominantFactor = determineDominantFactor(features: features, weights: currentWeights)
        
        return AthenaPrediction(
            inputFeatures: features,
            predictedScore: finalScore,
            confidence: calculateConfidence(features: features),
            modelUsed: currentWeights.version,
            dominantFactor: dominantFactor
        )
    }
    
    private func determineDominantFactor(features: AthenaFeatureVector, weights: AthenaModelWeights) -> String {
        let contributions = [
            ("Value", features.valueScore * weights.valueWeight),
            ("Quality", features.qualityScore * weights.qualityWeight),
            ("Momentum", features.momentumScore * weights.momentumWeight),
            ("Size", features.sizeScore * weights.sizeWeight),
            ("Risk", features.riskScore * weights.riskWeight)
        ]
        
        // Return factor with highest contribution
        return contributions.max(by: { $0.1 < $1.1 })?.0 ?? "Unknown"
    }
    
    private func calculateConfidence(features: AthenaFeatureVector) -> Double {
        // High confidence if all factors align (low variance between high scores)
        // Or if data quality is high. For now, simple placeholder.
        return 0.85 // Baseline confidence
    }
}
