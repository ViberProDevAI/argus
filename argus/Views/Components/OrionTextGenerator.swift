import Foundation
import SwiftUI

// MARK: - Orion Text Generator (Enhanced)
// Generates sophisticated, granular, and professional analysis text.

struct OrionTextGenerator {
    
    // MARK: - Trend Analysis Text
    static func generateTrendText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let trendScore = analysis.components.trend
        let adx = analysis.components.trendStrength ?? 0
        
        var segments: [TextSegment] = []
        
        // Context 1: Direction & Strength
        segments.append(TextSegment(text: "Piyasa şu anda ", color: .gray))
        
        if trendScore >= 25 {
            segments.append(TextSegment(text: "parabolik yükseliş (Strong Bull)", color: .green, isBold: true))
            segments.append(TextSegment(text: " trendinde. Fiyat ortalamalardan agresif şekilde uzaklaşıyor.", color: .gray))
        } else if trendScore >= 18 {
            segments.append(TextSegment(text: "sağlıklı yükseliş", color: .green, isBold: true))
            segments.append(TextSegment(text: " kanalında ilerliyor. Geri çekilmeler alım fırsatı yaratabilir.", color: .gray))
        } else if trendScore >= 12 {
            segments.append(TextSegment(text: "toparlanma (Recovery)", color: .cyan, isBold: true))
            segments.append(TextSegment(text: " evresinde, ancak henüz tam teyit alınmış değil.", color: .gray))
        } else if trendScore >= 8 {
            segments.append(TextSegment(text: "kararsız/yatay", color: .white, isBold: true))
            segments.append(TextSegment(text: " seyrediyor. Yön arayışı sürüyor.", color: .gray))
        } else if trendScore >= 4 {
            segments.append(TextSegment(text: "zayıf düşüş", color: .orange, isBold: true))
            segments.append(TextSegment(text: " baskısı altında. Tepki alımları sınırlı kalıyor.", color: .gray))
        } else {
            segments.append(TextSegment(text: "güçlü düşüş (Bearish)", color: .red, isBold: true))
            segments.append(TextSegment(text: " trendinde. Destek seviyeleri test ediliyor.", color: .gray))
        }
        
        // Context 2: ADX Insight
        if adx > 30 {
            segments.append(TextSegment(text: " Trend gücü (ADX) oldukça yüksek, mevcut hareket kalıcı olabilir.", color: .gray))
        } else if adx < 15 {
            segments.append(TextSegment(text: " Trend gücü zayıf, ani yön değişimlerine (Whipsaw) dikkat edilmeli.", color: .gray))
        }
        
        return DynamicAnalysisText(segments: segments)
    }
    
    // MARK: - Momentum Analysis Text
    static func generateMomentumText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let rsi = analysis.components.rsi ?? 50
        var segments: [TextSegment] = []
        
        segments.append(TextSegment(text: "Momentum osilatörleri ", color: .gray))
        
        if rsi >= 80 {
            segments.append(TextSegment(text: "ekstrem aşırı alım", color: .red, isBold: true))
            segments.append(TextSegment(text: " bölgesinde. Fiyat köpük yapmış olabilir, düzeltme riski çok yüksek.", color: .gray))
        } else if rsi >= 70 {
            segments.append(TextSegment(text: "aşırı alım (Overbought)", color: .orange, isBold: true))
            segments.append(TextSegment(text: " bölgesinde ancak trend güçlüyse bu durum sürebilir.", color: .gray))
        } else if rsi >= 55 {
            segments.append(TextSegment(text: "pozitif (Bullish)", color: .green, isBold: true))
            segments.append(TextSegment(text: " bölgede ve yukarı yönlü ivmeyi destekliyor.", color: .gray))
        } else if rsi >= 45 {
            segments.append(TextSegment(text: "nötr/dengeli", color: .white, isBold: true))
            segments.append(TextSegment(text: " bölgede. Alıcılar ve satıcılar dengede.", color: .gray))
        } else if rsi >= 30 {
            segments.append(TextSegment(text: "negatif (Bearish)", color: .orange, isBold: true))
            segments.append(TextSegment(text: " bölgede. Satış baskısı hakim.", color: .gray))
        } else {
            segments.append(TextSegment(text: "aşırı satım (Oversold)", color: .green, isBold: true))
            segments.append(TextSegment(text: " bölgesinde. Dip oluşumu ve tepki yükselişi beklenebilir.", color: .gray))
        }
        
        return DynamicAnalysisText(segments: segments)
    }
    
    // MARK: - Structure Analysis Text (Formerly Volume)
    static func generateStructureText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let structScore = analysis.components.structure
        var segments: [TextSegment] = []
        
        segments.append(TextSegment(text: "Piyasa yapısı ve hacim ", color: .gray))
        
        if structScore >= 66 {
            segments.append(TextSegment(text: "destek bölgesinde (Support)", color: .green, isBold: true))
            segments.append(TextSegment(text: " kurumsal alımlarla güçleniyor. Hacim artışı dönüşü teyit ediyor.", color: .gray))
        } else if structScore >= 33 {
            segments.append(TextSegment(text: "kanal ortasında (Mid-Range)", color: .white, isBold: true))
            segments.append(TextSegment(text: " ve işlem hacmi ortalama seviyelerde. Net bir yapı kırılımı henüz yok.", color: .gray))
        } else {
            segments.append(TextSegment(text: "direnç bölgesinde (Resistance)", color: .red, isBold: true))
            segments.append(TextSegment(text: " satıcılarla karşılaşıyor. Hacimli bir kırılım olmadan giriş riskli.", color: .gray))
        }
        
        return DynamicAnalysisText(segments: segments)
    }

    // MARK: - Pattern Analysis Text
    static func generatePatternText(for analysis: OrionScoreResult) -> DynamicAnalysisText {
        let patternDesc = analysis.components.patternDesc
        let isEmpty = patternDesc.isEmpty || patternDesc.contains("Yok")
        var segments: [TextSegment] = []
        
        if isEmpty {
            segments.append(TextSegment(text: "Grafikte şu an ", color: .gray))
             segments.append(TextSegment(text: "tanımlanabilir majör bir formasyon", color: .white, isBold: true))
             segments.append(TextSegment(text: " bulunmuyor. Fiyat hareketi standart volatilite aralığında (Random Walk) seyrediyor. Trend ve Momentum göstergelerine odaklanın.", color: .gray))
        } else {
             segments.append(TextSegment(text: "Algoritma ", color: .gray))
             segments.append(TextSegment(text: patternDesc, color: .purple, isBold: true))
             segments.append(TextSegment(text: " formasyonu tespit etti. Bu yapı genellikle trendin devamı veya dönüşü için güçlü bir öncü sinyaldir. Kırılım yönü takip edilmeli.", color: .gray))
        }
        return DynamicAnalysisText(segments: segments)
    }
}

// MARK: - Models
struct TextSegment: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
    var isBold: Bool = false
}

struct DynamicAnalysisText {
    let segments: [TextSegment]
}
