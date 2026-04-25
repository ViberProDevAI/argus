import Foundation

// MARK: - Hermes Analyst Engine
// Aracı kurum önerilerini analiz eder ve konsensüs skoru hesaplar

actor HermesAnalystEngine {
    static let shared = HermesAnalystEngine()
    
    private init() {}
    
    /// BIST hissesi için analist konsensüs analizi yapar
    func analyze(symbol: String, currentPrice: Double) async throws -> HermesAnalystResult {
        let cleanSymbol = symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")
        
        // BorsaPy'dan analist önerilerini çek
        let consensus = try await BorsaPyProvider.shared.getAnalystRecommendations(symbol: cleanSymbol)
        
        guard consensus.totalAnalysts > 0 else {
            return HermesAnalystResult(
                symbol: cleanSymbol,
                consensus: consensus,
                currentPrice: currentPrice,
                upsidePotential: nil,
                confidenceScore: 0,
                verdict: "Analist Verisi Yok",
                metrics: [],
                timestamp: Date()
            )
        }
        
        var metrics: [HermesAnalystMetric] = []
        var totalScore: Double = 0
        
        // 1. Konsensüs Skoru (Max 40)
        let consensusVal = consensus.consensusScore
        let consensusScore: Double
        let consensusExplanation: String
        switch consensusVal {
        case 0.7...: consensusScore = 40; consensusExplanation = "Güçlü AL konsensüsü (\(consensus.buyCount)/\(consensus.totalAnalysts) analist)"
        case 0.4..<0.7: consensusScore = 35; consensusExplanation = "AL ağırlıklı görüş"
        case 0.1..<0.4: consensusScore = 25; consensusExplanation = "Hafif pozitif eğilim"
        case -0.1..<0.1: consensusScore = 20; consensusExplanation = "Bölünmüş görüş (TUT ağırlıklı)"
        case -0.4..<(-0.1): consensusScore = 15; consensusExplanation = "Hafif negatif eğilim"
        default: consensusScore = 5; consensusExplanation = "SAT ağırlıklı görüş"
        }
        metrics.append(HermesAnalystMetric(
            name: "Analist Konsensüsü",
            value: "\(consensus.buyCount) AL / \(consensus.holdCount) TUT / \(consensus.sellCount) SAT",
            numericValue: consensusVal * 100,
            score: consensusScore,
            maxScore: 40,
            explanation: consensusExplanation
        ))
        totalScore += consensusScore
        
        // 2. Hedef Fiyat Potansiyeli (Max 35)
        var upside: Double? = nil
        if let target = consensus.averageTargetPrice, currentPrice > 0 {
            upside = ((target - currentPrice) / currentPrice) * 100
            
            let upsideScore: Double
            let upsideExplanation: String
            switch upside! {
            case 50...: upsideScore = 35; upsideExplanation = "Çok yüksek potansiyel (₺\(String(format: "%.2f", target)))"
            case 30..<50: upsideScore = 30; upsideExplanation = "Yüksek potansiyel"
            case 20..<30: upsideScore = 25; upsideExplanation = "İyi potansiyel"
            case 10..<20: upsideScore = 20; upsideExplanation = "Orta potansiyel"
            case 0..<10: upsideScore = 15; upsideExplanation = "Düşük potansiyel"
            case -10..<0: upsideScore = 10; upsideExplanation = "Hedefe yakın"
            default: upsideScore = 5; upsideExplanation = "Hedefin üzerinde"
            }
            metrics.append(HermesAnalystMetric(
                name: "Yükseliş Potansiyeli",
                value: String(format: "%.1f%%", upside!),
                numericValue: upside!,
                score: upsideScore,
                maxScore: 35,
                explanation: upsideExplanation
            ))
            totalScore += upsideScore
        }
        
        // 3. Analist Güveni (Max 25)
        // Hedef fiyat dağılımı ne kadar dar ise analistler o kadar hemfikir
        if let high = consensus.highTargetPrice, let low = consensus.lowTargetPrice, let avg = consensus.averageTargetPrice, avg > 0 {
            let spread = (high - low) / avg * 100 // Yüzde olarak
            let confidenceScore: Double
            let confidenceExplanation: String
            
            switch spread {
            case ...10: confidenceScore = 25; confidenceExplanation = "Analistler hemfikir (dar aralık)"
            case 10..<20: confidenceScore = 20; confidenceExplanation = "Görüşler yakın"
            case 20..<30: confidenceScore = 15; confidenceExplanation = "Orta dağılım"
            case 30..<50: confidenceScore = 10; confidenceExplanation = "Görüşler ayrışık"
            default: confidenceScore = 5; confidenceExplanation = "Çok geniş aralık - düşük güven"
            }
            metrics.append(HermesAnalystMetric(
                name: "Analist Güveni",
                value: String(format: "%.1f%% dağılım", spread),
                numericValue: 100 - spread,
                score: confidenceScore,
                maxScore: 25,
                explanation: confidenceExplanation
            ))
            totalScore += confidenceScore
        }
        
        // Verdict
        let verdict: String
        if totalScore >= 80 { verdict = "Güçlü AL Konsensüsü" }
        else if totalScore >= 60 { verdict = "AL Eğilimli" }
        else if totalScore >= 40 { verdict = "Nötr/TUT" }
        else { verdict = "Dikkatli Ol" }
        
        return HermesAnalystResult(
            symbol: cleanSymbol,
            consensus: consensus,
            currentPrice: currentPrice,
            upsidePotential: upside,
            confidenceScore: totalScore,
            verdict: verdict,
            metrics: metrics,
            timestamp: Date()
        )
    }
}

// MARK: - Modeller

struct HermesAnalystResult: Sendable {
    let symbol: String
    let consensus: BistAnalystConsensus
    let currentPrice: Double
    let upsidePotential: Double?
    let confidenceScore: Double
    let verdict: String
    let metrics: [HermesAnalystMetric]
    let timestamp: Date
}

struct HermesAnalystMetric: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let value: String
    let numericValue: Double
    let score: Double
    let maxScore: Double
    let explanation: String
}
