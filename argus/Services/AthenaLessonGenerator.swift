import Foundation

// MARK: - Athena Lesson Generator (Argus 3.0)
/// Trade kapandığında otomatik olarak "Ne Öğrendik?" dersi üretir.
/// Basit heuristik kurallar kullanır (AI değil, kural tabanlı).

final class AthenaLessonGenerator {
    static let shared = AthenaLessonGenerator()
    
    private init() {}
    
    // MARK: - Main API
    
    /// Trade kapandığında çağrılır, ders üretir ve weight adjustment önerir.
    func generateLesson(
        symbol: String,
        entryPrice: Double,
        exitPrice: Double,
        entryReason: String,
        dominantSignal: String,
        moduleScores: [String: Double], // Entry anındaki modül skorları
        regime: String? // Aether'dan gelen rejim: "trend", "riskOff", "sideways"
    ) -> LessonResult {
        let pnlPercent = ((exitPrice - entryPrice) / entryPrice) * 100.0
        let isProfit = pnlPercent > 0
        
        // 1. Sapma Analizi
        let deviation = analyzeDeviation(pnlPercent: pnlPercent, dominantSignal: dominantSignal, regime: regime)
        
        // 2. Ders Üretimi
        let lesson = generateLessonText(
            symbol: symbol,
            isProfit: isProfit,
            pnlPercent: pnlPercent,
            dominantSignal: dominantSignal,
            regime: regime,
            deviation: deviation
        )
        
        // 3. Weight Adjustment Önerisi
        let weightChanges = suggestWeightChanges(
            isProfit: isProfit,
            pnlPercent: pnlPercent,
            dominantSignal: dominantSignal,
            regime: regime
        )
        
        return LessonResult(
            lessonText: lesson,
            deviationPercent: deviation,
            suggestedWeightChanges: weightChanges
        )
    }
    
    // MARK: - Heuristics
    
    private func analyzeDeviation(pnlPercent: Double, dominantSignal: String, regime: String?) -> Double {
        // Basit sapma hesabı: Beklenen getiri vs gerçekleşen
        // Şimdilik sabit beklenti: BUY sinyali için +2%, SELL için -2%
        let expectedReturn = 2.0
        return abs(pnlPercent - expectedReturn)
    }
    
    private func generateLessonText(
        symbol: String,
        isProfit: Bool,
        pnlPercent: Double,
        dominantSignal: String,
        regime: String?,
        deviation: Double
    ) -> String {
        let regimeText = regime ?? "bilinmiyor"
        
        if isProfit {
            // Karlı işlem
            if deviation < 1.0 {
                return "\(symbol) işlemi beklentilere uygun kapandı. \(dominantSignal) sinyali \(regimeText) rejiminde güvenilir çalıştı."
            } else if deviation < 3.0 {
                return "\(symbol) karlı kapandı ama beklentinin altında. \(dominantSignal) sinyali yeterli olmadı, destekleyici sinyaller kontrol edilmeli."
            } else {
                return "\(symbol) karlı kapandı ama sapma yüksek. \(dominantSignal) sinyali tek başına yetersiz, kompozit skor daha ağırlıklı değerlendirilmeli."
            }
        } else {
            // Zararlı işlem
            if regime == "riskOff" {
                return "\(symbol) zararlı kapandı. Risk-Off rejiminde \(dominantSignal) sinyali güvenilir değil. Bu rejimlerde Quality ve Defensives ağırlığı artırılmalı."
            } else if dominantSignal == "Orion" || dominantSignal == "Momentum" {
                return "\(symbol) zararlı kapandı. Momentum sinyali yanlış yönlendirdi. Giriş öncesi Atlas (temel analiz) ve Aether (makro) onayı zorunlu hale getirilmeli."
            } else if dominantSignal == "Atlas" {
                return "\(symbol) zararlı kapandı. Temel analiz doğru ama zamanlama yanlış. Orion (teknik) onayı olmadan giriş yapılmamalı."
            } else {
                return "\(symbol) zararlı kapandı. \(dominantSignal) sinyali bu koşullarda çalışmadı. Modül ağırlıkları gözden geçirilmeli."
            }
        }
    }
    
    private func suggestWeightChanges(
        isProfit: Bool,
        pnlPercent: Double,
        dominantSignal: String,
        regime: String?
    ) -> [String: Double] {
        var changes: [String: Double] = [:]
        
        let adjustmentAmount = min(0.05, abs(pnlPercent) / 100.0) // Max 5% değişim
        
        if isProfit {
            // Karlıysa dominant sinyalin ağırlığını artır
            changes[dominantSignal] = adjustmentAmount
        } else {
            // Zararlıysa dominant sinyalin ağırlığını azalt
            changes[dominantSignal] = -adjustmentAmount
            
            // Risk-Off rejiminde Quality'yi artır
            if regime == "riskOff" {
                changes["Quality"] = adjustmentAmount
                changes["Momentum"] = -adjustmentAmount
            }
        }
        
        return changes
    }
}

// MARK: - Result Struct

struct LessonResult {
    let lessonText: String
    let deviationPercent: Double
    let suggestedWeightChanges: [String: Double]
}
