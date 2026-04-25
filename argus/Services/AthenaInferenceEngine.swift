import Foundation

/// Athena Inference Engine (AI Core)
/// Responsible for taking raw factor features and producing a prediction
/// using a learned model (or heuristic weights initially).
final class AthenaInferenceEngine {
    static let shared = AthenaInferenceEngine()
    
    // Default weights (can be updated via training)
    private var currentWeights: AthenaModelWeights
    
    private init() {
        // Ağırlıklar önce bundle'daki JSON config'ten yüklenir (izlenebilir + dışarıdan
        // tweak edilebilir); başarısız olursa hardcoded expert baseline fallback.
        if let loaded = Self.loadWeightsFromBundle() {
            self.currentWeights = loaded
        } else {
            self.currentWeights = AthenaModelWeights(
                version: "Athena-V1-Expert-Fallback",
                bias: 0.0,
                valueWeight: 0.20,
                qualityWeight: 0.25,
                momentumWeight: 0.25,
                sizeWeight: 0.15,
                riskWeight: 0.15
            )
        }
    }

    /// Bundle'daki `AthenaModelWeights.json`'dan ağırlıkları okur.
    /// JSON formatı `AthenaModelWeights` Codable yapısıyla birebir eşleşmelidir.
    /// Dosya yoksa, parse başarısızsa veya ağırlıklar tutarsızsa nil döner.
    private static func loadWeightsFromBundle() -> AthenaModelWeights? {
        guard let url = Bundle.main.url(forResource: "AthenaModelWeights", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        // lastUpdated YYYY-MM-DD ISO formatında tanımlı — Date decoding özelleştir
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        decoder.dateDecodingStrategy = .formatted(fmt)
        guard let parsed = try? decoder.decode(AthenaModelWeights.self, from: data) else {
            return nil
        }
        // Sağlık kontrolü: ağırlıkların hepsi non-negative ve makul aralıkta olmalı
        let all = [parsed.valueWeight, parsed.qualityWeight, parsed.momentumWeight,
                   parsed.sizeWeight, parsed.riskWeight]
        guard all.allSatisfy({ $0 >= 0 && $0 <= 1 }) else { return nil }
        return parsed
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
        // Güven, faktörlerin hizalanmasıyla (düşük varyans) ve ekstrem skorlardan uzaklıkla artar.
        //
        // Eski sürüm sabit 0.85 dönüyordu — model ne der ne durumda olursa olsun güven
        // asla değişmiyordu, bu da downstream decision engines'in "yüksek güvenle al"
        // sinyallerini nötr/korku durumlarında bile üretmesine neden oluyordu.
        //
        // Yeni formül:
        //   1) Hizalanma (alignment): Faktör skorlarının standart sapması düştükçe güven artar.
        //      Varyans 0 → alignment 1.0; varyans 50+ → alignment 0.0.
        //   2) Ekstremlik (extremity): Ortalamanın 50'den uzaklığı (0..1) güveni azıcık artırır.
        //      Nötr skorlar (~50) belirsiz, uçlar (0 veya 100) net sinyal.
        //
        // Sonuç [0.50, 0.95] aralığında clamp edilir; bu "hiçbir zaman tamamen emin değilim"
        // ilkesini korur (kalibre edilmemiş modelde aşırı güven riskli).

        let scores: [Double] = [
            features.valueScore,
            features.qualityScore,
            features.momentumScore,
            features.sizeScore,
            features.riskScore
        ]

        guard !scores.isEmpty else { return 0.70 }

        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(scores.count)
        let std = sqrt(variance)

        // Alignment: std 0 → 1.0, std 25 → 0.0 (lineer ceza)
        let alignment = max(0.0, 1.0 - (std / 25.0))

        // Extremity: |mean - 50| / 50 ∈ [0, 1]
        let extremity = min(1.0, abs(mean - 50.0) / 50.0)

        // Ağırlıklı birleşim: alignment daha önemli (%70), extremity %30
        let combined = 0.70 * alignment + 0.30 * extremity

        // Clamp to [0.50, 0.95]
        return min(0.95, max(0.50, 0.50 + combined * 0.45))
    }
}
