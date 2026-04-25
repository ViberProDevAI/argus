import Foundation

/// Serves Financial Snaphots for Atlas Council and UI.
/// Bridges the gap between Raw Provider Data (FinancialsData) and Domain Model (FinancialSnapshot).
actor FinancialSnapshotService {
    static let shared = FinancialSnapshotService()
    
    // Enforce Yahoo as the source for Fundamentals (Atlas requires it)
    private var provider: YahooFinanceProvider { YahooFinanceProvider.shared }
    
    private init() {}
    
    /// Fetches a complete financial snapshot for a symbol
    func fetchSnapshot(symbol: String) async throws -> FinancialSnapshot {
        // 1. Fetch Fundamentals (Atlas Data)
        // This includes extended metrics like margins, growth, and now analyst targets.
        let financials = try await provider.fetchFundamentals(symbol: symbol)
        
        // 2. Fetch Current Price (Quote)
        // Snapshot needs the latest price for valuation metrics update if needed
        let quote = try await provider.fetchQuote(symbol: symbol)
        
        // 3. Map to Domain Model
        return mapToSnapshot(data: financials, quote: quote)
    }
    
    /// Fetches raw data AND snapshot in one go (for efficient reuse)
    func fetchComprehensiveData(symbol: String) async throws -> (financials: FinancialsData, quote: Quote, snapshot: FinancialSnapshot) {
        let financials = try await provider.fetchFundamentals(symbol: symbol)
        let quote = try await provider.fetchQuote(symbol: symbol)
        let snapshot = mapToSnapshot(data: financials, quote: quote)
        return (financials, quote, snapshot)
    }
    
    private func mapToSnapshot(data: FinancialsData, quote: Quote) -> FinancialSnapshot {
        return FinancialSnapshot(
            symbol: data.symbol,
            marketCap: data.marketCap ?? data.enterpriseValue, // Fallback to EV if Cap missing
            price: quote.c,
            
            // Valuation
            peRatio: data.peRatio,
            forwardPE: data.forwardPERatio,
            pbRatio: data.priceToBook,
            psRatio: data.priceToSales,
            evToEbitda: data.evToEbitda,
            
            // Growth
            revenueGrowth: data.revenueGrowth,
            earningsGrowth: data.earningsGrowth,
            epsGrowth: nil, // Not directly in FinancialsData yet
            
            // Quality
            roe: data.returnOnEquity,
            roa: data.returnOnAssets,
            debtToEquity: data.debtToEquity,
            currentRatio: data.currentRatio,
            grossMargin: data.grossMargin,
            operatingMargin: data.operatingMargin,
            netMargin: data.profitMargin,
            
            // Dividend
            dividendYield: data.dividendYield,
            payoutRatio: nil, // Not mapped yet
            dividendGrowth: nil,
            
            // Other
            beta: nil, // Could be in stats but not in FinancialsData struct explicitly named beta? Check struct.
            sharesOutstanding: nil,
            floatShares: nil,
            insiderOwnership: nil,
            institutionalOwnership: nil,
            
            // Sector (Not available in pure FinancialsData, needs Profile)
            sectorPE: nil,
            sectorPB: nil,
            
            // Analyst Expectations
            targetMeanPrice: data.targetMeanPrice,
            targetHighPrice: data.targetHighPrice,
            targetLowPrice: data.targetLowPrice,
            recommendationMean: data.recommendationMean,
            analystCount: data.numberOfAnalystOpinions
        )
    }
}
