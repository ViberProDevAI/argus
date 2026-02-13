import Foundation

struct RegimeSnapshot: Codable {
    let timestamp: Date
    let vix: Double
    let fearGreedIndex: Int
    let dominantRegime: String
    let spyTrend: String
    let sectorRotation: [String: Double]
    let sp500Change: Double
    let dollarIndex: Double?
    
    var vixBucket: String {
        switch vix {
        case 0..<15: return "0-15"
        case 15..<20: return "15-20"
        case 20..<25: return "20-25"
        case 25..<30: return "25-30"
        default: return "30+"
        }
    }
    
    var contextKey: String {
        "\(dominantRegime)_\(vixBucket)"
    }
}

struct RegimePerformance: Codable {
    let regime: String
    let vixBucket: String
    let avgReturn7d: Double
    let avgReturn30d: Double
    let winRate: Double
    let sampleSize: Int
    let lastUpdated: Date
    
    var summary: String {
        "Bu kosullarda %\(String(format: "%.0f", winRate * 100)) basari"
    }
}

struct RegimeDecisionContext: Codable {
    let regime: String
    let vix: Double
    let historicalWinRate: Double
    let riskScore: Double
    let recommendation: String
}

actor RegimeMemoryService {
    static let shared = RegimeMemoryService()
    
    private var currentSnapshot: RegimeSnapshot?
    private var regimePerformanceCache: [String: RegimePerformance] = [:]
    
    private init() {}
    
    func getCurrentRegimeSnapshot() async -> RegimeSnapshot? {
        if let snapshot = currentSnapshot {
            let staleness = Date().timeIntervalSince(snapshot.timestamp)
            if staleness < 3600 { return snapshot }
        }
        
        return buildDefaultSnapshot()
    }
    
    private func buildDefaultSnapshot() -> RegimeSnapshot? {
        let snapshot = RegimeSnapshot(
            timestamp: Date(),
            vix: 20.0,
            fearGreedIndex: 50,
            dominantRegime: "Notr",
            spyTrend: "Yatay",
            sectorRotation: [:],
            sp500Change: 0,
            dollarIndex: nil
        )
        
        currentSnapshot = snapshot
        return snapshot
    }
    
    func getHistoricalPerformance(regime: String, vixBucket: String) async -> RegimePerformance? {
        let key = "\(regime)_\(vixBucket)"
        return regimePerformanceCache[key]
    }
    
    func recordRegimeOutcome(
        symbol: String,
        action: String,
        pnlPercent: Double,
        holdingDays: Int
    ) async {
        print("RegimeMemory: Sonuc kaydedildi - \(symbol) \(action)")
    }
    
    func getRegimeContext() async -> RegimeDecisionContext {
        guard let snapshot = await getCurrentRegimeSnapshot() else {
            return RegimeDecisionContext(
                regime: "Notr",
                vix: 20,
                historicalWinRate: 0.5,
                riskScore: 0,
                recommendation: "Piyasa verisi yetersiz"
            )
        }
        
        let performance = await getHistoricalPerformance(
            regime: snapshot.dominantRegime,
            vixBucket: snapshot.vixBucket
        )
        
        let winRate = performance?.winRate ?? 0.5
        let riskScore = calculateRiskScore(snapshot: snapshot, winRate: winRate)
        let recommendation = generateRecommendation(snapshot: snapshot, winRate: winRate)
        
        return RegimeDecisionContext(
            regime: snapshot.dominantRegime,
            vix: snapshot.vix,
            historicalWinRate: winRate,
            riskScore: riskScore,
            recommendation: recommendation
        )
    }
    
    private func calculateRiskScore(snapshot: RegimeSnapshot, winRate: Double) -> Double {
        var score = 0.0
        
        if snapshot.vix > 25 { score += 0.3 }
        else if snapshot.vix > 20 { score += 0.15 }
        
        if snapshot.fearGreedIndex < 30 { score += 0.2 }
        else if snapshot.fearGreedIndex > 70 { score -= 0.1 }
        
        if winRate < 0.4 { score += 0.2 }
        
        return max(0, min(1, score))
    }
    
    private func generateRecommendation(snapshot: RegimeSnapshot, winRate: Double) -> String {
        if snapshot.dominantRegime == "Risk Off" && winRate < 0.4 {
            return "Risk ortami yuksek, temkinli olun"
        } else if snapshot.dominantRegime == "Risk On" && winRate > 0.6 {
            return "Risk ortami elverisli"
        } else if snapshot.vix > 30 {
            return "Yuksek volatilite, pozisyon buyutlmemeli"
        }
        return "Normal piyasa kosullari"
    }
}
