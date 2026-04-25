import Foundation

// MARK: - Fundamental Score Store
@MainActor
class FundamentalScoreStore {
    static let shared = FundamentalScoreStore()
    
    private var scores: [String: FundamentalScoreResult] = [:]
    private var rawData: [String: FinancialsData] = [:]
    
    private init() {}
    
    func saveScore(_ score: FundamentalScoreResult) {
        scores[score.symbol] = score
        if let raw = score.financials {
            rawData[score.symbol] = raw
        }
    }
    
    func setScore(_ score: FundamentalScoreResult) {
        saveScore(score)
    }
    
    func getScore(for symbol: String) -> FundamentalScoreResult? {
        return scores[symbol]
    }
    
    func getRawData(for symbol: String) -> FinancialsData? {
        return rawData[symbol]
    }
    
    func setRawData(symbol: String, data: FinancialsData) {
        rawData[symbol] = data
    }
    
    func hasValidData(for symbol: String) -> Bool {
        return scores[symbol] != nil
    }
}
