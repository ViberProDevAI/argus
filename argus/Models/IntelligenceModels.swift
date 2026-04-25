import Foundation

/// Unified snapshot for Smart Money signals
struct MarketIntelligenceSnapshot: Codable {
    let symbol: String
    let fetchDate: Date
    
    // MARK: - Analyst Data (Wall St)
    /// Mean Target Price from Analysts
    let targetMeanPrice: Double?
    /// Mean Recommendation (1.0 Strong Buy - 5.0 Strong Sell)
    let recommendationMean: Double?
    
    // MARK: - Insider Data (Corporate)
    /// Net Insider Buy Sentiment (Derived from transaction volume)
    /// Positive = Net Buying, Negative = Net Selling
    let netInsiderBuySentiment: Double
    /// Date of the last relevant insider transaction
    let lastInsiderTransactionDate: Date?
    
    // MARK: - Init
    init(symbol: String,
         fetchDate: Date = Date(),
         targetMeanPrice: Double?,
         recommendationMean: Double?,
         netInsiderBuySentiment: Double,
         lastInsiderTransactionDate: Date?) {
        self.symbol = symbol
        self.fetchDate = fetchDate
        self.targetMeanPrice = targetMeanPrice
        self.recommendationMean = recommendationMean
        self.netInsiderBuySentiment = netInsiderBuySentiment
        self.lastInsiderTransactionDate = lastInsiderTransactionDate
    }
}

// MARK: - Internal Decoding Models (Yahoo Finance)
extension MarketIntelligenceSnapshot {
    struct YahooQuoteSummaryResponse: Codable {
        struct QuoteSummary: Codable {
            struct Result: Codable {
                struct FinancialData: Codable {
                    struct RawDouble: Codable {
                        let raw: Double?
                        let fmt: String?
                    }
                    let targetMeanPrice: RawDouble?
                    let recommendationMean: RawDouble?
                    let currentPrice: RawDouble? // Sometimes useful for validation
                }
                let financialData: FinancialData?
            }
            let result: [Result]?
            let error: YahooError?
        }
        struct YahooError: Codable {
            let description: String?
        }
        let quoteSummary: QuoteSummary
    }
}

// MARK: - Internal Decoding Models (Finnhub)
extension MarketIntelligenceSnapshot {
    struct FinnhubInsiderSentimentResponse: Codable {
        struct SentimentData: Codable {
            let symbol: String
            let year: Int
            let month: Int
            let change: Double // Net shares changed
            let mspr: Double // Monthly Share Purchase Ratio
        }
        let data: [SentimentData]?
        let symbol: String?
    }
}
