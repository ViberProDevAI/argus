import Foundation

// MARK: - Protocol
protocol FundamentalsProvider {
    func fetchFinancials(symbol: String) async throws -> FinancialsData
}

// MARK: - Alpha Vantage Implementation
// MARK: - Heimdall Adapter Implementation
// Formerly AlphaVantageFundamentalsProvider, now routed through Heimdall for resilience.
// Keeping class name for compatibility with existing injection points.
class AlphaVantageFundamentalsProvider: FundamentalsProvider {
    static let shared = AlphaVantageFundamentalsProvider()
    
    private init() {}
    
    func fetchFinancials(symbol: String) async throws -> FinancialsData {
        // Route through Heimdall Orchestrator (likely Yahoo/EODHD)
        // This bypasses Alpha Vantage rate limits (4 calls per stock -> 0 calls).
        do {
            let data = try await HeimdallOrchestrator.shared.requestFundamentals(symbol: symbol)
            
            // Cache result for offline access
            DataCacheService.shared.save(value: data, kind: .fundamentals, symbol: symbol, source: "Heimdall")
            return data
        } catch {
            print("❌ Fundamentals Provider: Heimdall failed for \(symbol): \(error)")
            
            // Try Legacy Cache as last resort
            if let entry = await DataCacheService.shared.getEntry(kind: .fundamentals, symbol: symbol),
               let value = try? JSONDecoder().decode(FinancialsData.self, from: entry.data) {
                print("💾 Using Cached Financials for \(symbol) from \(entry.source)")
                return value
            }
            throw error
        }
    }
}

// MARK: - Alpha Vantage Response Models

struct AVOverviewResponse: Codable {
    let Symbol: String
    let Currency: String
    let EBITDA: String?
    let PERatio: String?
    let ForwardPE: String?
    let PriceToBookRatio: String?
    let PBRatio: String? // Alternative key
    let EVToEBITDA: String?
    let DividendYield: String?
    let QuarterlyRevenueGrowthYOY: String?
    let QuarterlyEarningsGrowthYOY: String?
}

struct AVIncomeStatementResponse: Codable {
    let annualReports: [AVIncomeReport]
}
struct AVIncomeReport: Codable {
    let fiscalDateEnding: String
    let totalRevenue: String?
    let netIncome: String?
    let ebitda: String?
}

struct AVBalanceSheetResponse: Codable {
    let annualReports: [AVBalanceReport]
}
struct AVBalanceReport: Codable {
    let fiscalDateEnding: String
    let totalShareholderEquity: String?
    let shortTermDebt: String?
    let longTermDebt: String?
}

struct AVCashFlowResponse: Codable {
    let annualReports: [AVCashReport]
}
struct AVCashReport: Codable {
    let fiscalDateEnding: String
    let operatingCashflow: String?
    let capitalExpenditures: String?
}
