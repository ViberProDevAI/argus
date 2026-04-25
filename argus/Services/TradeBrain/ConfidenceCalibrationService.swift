import Foundation

struct ConfidenceBucket: Identifiable, Codable {
    let id: String
    let range: ClosedRange<Double>
    var totalDecisions: Int
    var correctDecisions: Int
    var avgPnL: Double
    var lastUpdated: Date
    
    var winRate: Double {
        guard totalDecisions > 0 else { return 0 }
        return Double(correctDecisions) / Double(totalDecisions)
    }
    
    var displayRange: String {
        "\(Int(range.lowerBound * 100))-\(Int(range.upperBound * 100))%"
    }
}

struct CalibrationResult: Codable {
    let rawConfidence: Double
    let calibratedConfidence: Double
    let bucket: String
    let historicalWinRate: Double
    let sampleSize: Int
    let adjustment: Double
    
    var needsSignificantAdjustment: Bool {
        abs(adjustment) > 0.15
    }
}

actor ConfidenceCalibrationService {
    static let shared = ConfidenceCalibrationService()
    
    private var buckets: [String: ConfidenceBucket] = [:]
    private let bucketRanges: [(range: ClosedRange<Double>, id: String)] = [
        (0.0...0.1, "0-10"),
        (0.1...0.2, "10-20"),
        (0.2...0.3, "20-30"),
        (0.3...0.4, "30-40"),
        (0.4...0.5, "40-50"),
        (0.5...0.6, "50-60"),
        (0.6...0.7, "60-70"),
        (0.7...0.8, "70-80"),
        (0.8...0.9, "80-90"),
        (0.9...1.0, "90-100")
    ]
    
    private init() {
        initializeBuckets()
    }
    
    private func initializeBuckets() {
        for (range, id) in bucketRanges {
            buckets[id] = ConfidenceBucket(
                id: id,
                range: range,
                totalDecisions: 0,
                correctDecisions: 0,
                avgPnL: 0,
                lastUpdated: Date()
            )
        }
    }
    
    func calibrate(_ rawConfidence: Double) async -> CalibrationResult {
        let bucketId = confidenceToBucket(rawConfidence)
        let bucket = buckets[bucketId]
        
        let historicalWinRate = bucket?.winRate ?? rawConfidence
        let sampleSize = bucket?.totalDecisions ?? 0
        
        let calibratedConfidence: Double
        if sampleSize >= 10 {
            let confidenceDiff = rawConfidence - historicalWinRate
            if abs(confidenceDiff) > 0.2 {
                calibratedConfidence = rawConfidence - (confidenceDiff * 0.5)
            } else if abs(confidenceDiff) > 0.1 {
                calibratedConfidence = rawConfidence - (confidenceDiff * 0.3)
            } else {
                calibratedConfidence = rawConfidence - (confidenceDiff * 0.15)
            }
        } else {
            calibratedConfidence = rawConfidence
        }
        
        let adjustment = calibratedConfidence - rawConfidence
        
        return CalibrationResult(
            rawConfidence: rawConfidence,
            calibratedConfidence: max(0.1, min(0.95, calibratedConfidence)),
            bucket: bucketId,
            historicalWinRate: historicalWinRate,
            sampleSize: sampleSize,
            adjustment: adjustment
        )
    }
    
    func recordOutcome(
        confidence: Double,
        wasCorrect: Bool,
        pnlPercent: Double
    ) async {
        let bucketId = confidenceToBucket(confidence)
        
        guard var bucket = buckets[bucketId] else { return }
        
        bucket.totalDecisions += 1
        if wasCorrect {
            bucket.correctDecisions += 1
        }
        
        let n = Double(bucket.totalDecisions)
        bucket.avgPnL = (bucket.avgPnL * (n - 1) + pnlPercent) / n
        bucket.lastUpdated = Date()
        
        buckets[bucketId] = bucket
        
        await AlkindusRAGEngine.shared.syncCalibrationBucket(
            bucket: bucketId,
            actualWinRate: bucket.winRate,
            sampleSize: bucket.totalDecisions
        )
        
        print("ConfidenceCalibration: \(bucketId) bucket guncellendi - Win: \(String(format: "%.1f", bucket.winRate * 100))% (n=\(bucket.totalDecisions))")
    }
    
    func recordMultiHorizonOutcome(
        decisions: [(timeframe: TimeFrame, confidence: Double)],
        outcomes: [(timeframe: TimeFrame, wasCorrect: Bool, pnlPercent: Double)]
    ) async {
        for outcome in outcomes {
            if let decision = decisions.first(where: { $0.timeframe == outcome.timeframe }) {
                await recordOutcome(
                    confidence: decision.confidence,
                    wasCorrect: outcome.wasCorrect,
                    pnlPercent: outcome.pnlPercent
                )
            }
        }
    }
    
    func getBucketStats() async -> [ConfidenceBucket] {
        return bucketRanges.compactMap { buckets[$0.id] }
    }
    
    func getOverallStats() async -> CalibrationStats {
        var totalDecisions = 0
        var totalCorrect = 0
        var totalPnL = 0.0
        var biggestAdjustment: (bucket: String, adjustment: Double)? = nil
        
        for (id, bucket) in buckets {
            totalDecisions += bucket.totalDecisions
            totalCorrect += bucket.correctDecisions
            totalPnL += bucket.avgPnL * Double(bucket.totalDecisions)
            
            let expectedWinRate = (bucket.range.lowerBound + bucket.range.upperBound) / 2
            let adjustment = abs(bucket.winRate - expectedWinRate)
            
            if biggestAdjustment == nil || adjustment > biggestAdjustment!.adjustment {
                biggestAdjustment = (id, adjustment)
            }
        }
        
        return CalibrationStats(
            totalDecisions: totalDecisions,
            overallWinRate: totalDecisions > 0 ? Double(totalCorrect) / Double(totalDecisions) : 0,
            avgPnL: totalDecisions > 0 ? totalPnL / Double(totalDecisions) : 0,
            bucketCount: buckets.count,
            biggestAdjustmentBucket: biggestAdjustment?.bucket,
            biggestAdjustmentValue: biggestAdjustment?.adjustment ?? 0
        )
    }
    
    func resetCalibration() async {
        initializeBuckets()
        print("ConfidenceCalibration: Tum bucketlar sifirlandi")
    }
    
    private func confidenceToBucket(_ confidence: Double) -> String {
        let clamped = max(0.0, min(1.0, confidence))
        for (range, id) in bucketRanges {
            if range.contains(clamped) {
                return id
            }
        }
        return "50-60"
    }
}

struct CalibrationStats: Codable {
    let totalDecisions: Int
    let overallWinRate: Double
    let avgPnL: Double
    let bucketCount: Int
    let biggestAdjustmentBucket: String?
    let biggestAdjustmentValue: Double
    
    var summary: String {
        if totalDecisions == 0 {
            return "Henuz yeterli veri yok"
        }
        return "\(totalDecisions) karar, %\(String(format: "%.0f", overallWinRate * 100)) basari"
    }
}
