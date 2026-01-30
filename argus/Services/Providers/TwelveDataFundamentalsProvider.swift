import Foundation

class TwelveDataFundamentalsProvider: FundamentalsProvider {
    static let shared = TwelveDataFundamentalsProvider()
    
    // API Configuration
    private let apiKey = Secrets.twelveDataKey // Valid Twelve Data Key (Demo/Free)
    private let baseURL = "https://api.twelvedata.com"
    
    private init() {}
    
    func fetchFinancials(symbol: String) async throws -> FinancialsData {
        // 1. Check Cache first (to save API calls)
        if let entry = await DataCacheService.shared.getEntry(kind: .fundamentals, symbol: symbol),
           let value = try? JSONDecoder().decode(FinancialsData.self, from: entry.data) {
            print("💾 Using Cached Financials for \(symbol) from \(entry.source)")
            return value
        }
        
        do {
            let data = try await fetchFromNetwork(symbol: symbol)
            // Success: Save to Cache
            DataCacheService.shared.save(value: data, kind: .fundamentals, symbol: symbol, source: "Twelve Data")
            return data
        } catch {
            print("❌ Twelve Data API failed for \(symbol): \(error)")
            throw error
        }
    }
    
    private func fetchFromNetwork(symbol: String) async throws -> FinancialsData {
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        // Twelve Data requires separate calls for Income, Balance, Cashflow, Statistics
        async let incomeTask = fetch(endpoint: "income_statement", symbol: symbol)
        async let balanceTask = fetch(endpoint: "balance_sheet", symbol: symbol)
        async let cashFlowTask = fetch(endpoint: "cash_flow", symbol: symbol)
        
        // Statistics endpoint is often empty or unreliable for BIST. Make it optional.
        async let statisticsTask = fetch(endpoint: "statistics", symbol: symbol)
        
        let (incomeData, balanceData, cashFlowData, statsData) = await (try? incomeTask, try? balanceTask, try? cashFlowTask, try? statisticsTask)
        
        // BIST RELAXED CHECK: If BIST, require only Income Statement. Balance/Cashflow are bonus.
        // GLOBAL STRICT CHECK: Require Income + Balance.
        
        if isBist {
            if incomeData == nil { throw URLError(.resourceUnavailable) }
        } else {
            guard incomeData != nil, balanceData != nil else {
                throw URLError(.resourceUnavailable)
            }
        }
        
        let decoder = JSONDecoder()
        
        // 1. Income Statement
        let incomeResp = try? decoder.decode(TDIncomeStatementResponse.self, from: incomeData ?? Data())
        let annualIncome = incomeResp?.income_statement ?? []
        
        // 2. Balance Sheet
        let balanceResp = try? decoder.decode(TDBalanceSheetResponse.self, from: balanceData ?? Data())
        let annualBalance = balanceResp?.balance_sheet ?? []
        
        // 3. Cash Flow
        let cashResp = try? decoder.decode(TDCashFlowResponse.self, from: cashFlowData ?? Data())
        let annualCash = cashResp?.cash_flow ?? []
        
        // 4. Statistics
        let statsResp = try? decoder.decode(TDStatisticsResponse.self, from: statsData ?? Data())
        let statistics = statsResp?.statistics
        
        guard let lastIncome = annualIncome.first else {
             throw URLError(.resourceUnavailable)
        }
        
        // Parsing Helpers
        func val(_ v: Double?) -> Double? { return v }
        func val(_ v: String?) -> Double? { return Double(v ?? "") }
        
        let totalRevenue = val(lastIncome.revenue) ?? val(lastIncome.sales)
        let netIncome = val(lastIncome.net_income)
        
        // For BIST, Balance Sheet might be missing or delayed. Handle gracefully.
        let lastBalance = annualBalance.first
        let totalShareholderEquity = lastBalance != nil ? (val(lastBalance?.total_equity) ?? val(lastBalance?.shareholders_equity)) : nil
        
        
        // Optional Data
        let ebitda = val(lastIncome.ebitda)
        let shortTermDiff = lastBalance != nil ? (val(lastBalance?.short_term_debt) ?? 0.0) : nil
        let longTermDiff = lastBalance != nil ? (val(lastBalance?.long_term_debt) ?? 0.0) : nil
        
        let lastCashFlow = annualCash.first
        let operatingCashflow = val(lastCashFlow?.operating_cash_flow)
        let capitalExpenditures = val(lastCashFlow?.capital_expenditures)
        
        // History
        let revenueHistory = annualIncome.prefix(4).compactMap { val($0.revenue) ?? val($0.sales) }
        let netIncomeHistory = annualIncome.prefix(4).compactMap { val($0.net_income) }
        
        // Valuation from Statistics
        let peRatio = val(statistics?.valuations_metrics.trailing_pe)
        let forwardPERatio = val(statistics?.valuations_metrics.forward_pe)
        let priceToBook = val(statistics?.valuations_metrics.price_to_book)
        let evToEbitda = val(statistics?.valuations_metrics.enterprise_value_to_ebitda)
        let dividendYield = val(statistics?.dividends_and_splits.dividend_yield) 
        
        return FinancialsData(
            symbol: symbol,
            currency: incomeResp?.meta.currency ?? (isBist ? "TRY" : "USD"),
            lastUpdated: Date(),
            totalRevenue: totalRevenue,
            netIncome: netIncome,
            totalShareholderEquity: totalShareholderEquity,
            marketCap: nil,
            revenueHistory: revenueHistory,
            netIncomeHistory: netIncomeHistory,
            ebitda: ebitda,
            shortTermDebt: shortTermDiff,
            longTermDebt: longTermDiff,
            operatingCashflow: operatingCashflow,
            capitalExpenditures: capitalExpenditures,
            cashAndCashEquivalents: nil,
            peRatio: peRatio,
            forwardPERatio: forwardPERatio,
            priceToBook: priceToBook,
            evToEbitda: evToEbitda,
            dividendYield: dividendYield,
            forwardGrowthEstimate: nil,
            isETF: false,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            numberOfAnalystOpinions: nil
        )
    }
    
    private func fetch(endpoint: String, symbol: String) async throws -> Data {
        let urlString = "\(baseURL)/\(endpoint)?symbol=\(symbol)&apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            // Log but don't throw immediately let fetchFromNetwork handle nil
             print("⚠️ TwelveData Error [\(endpoint)]: \(httpResponse.statusCode)")
             throw URLError(.badServerResponse)
        }
        
        return data
    }
}

// MARK: - Twelve Data Models

struct TDIncomeStatementResponse: Codable {
    let meta: TDMeta
    let income_statement: [TDIncomeReport]
}

struct TDBalanceSheetResponse: Codable {
    let meta: TDMeta
    let balance_sheet: [TDBalanceReport]
}

struct TDCashFlowResponse: Codable {
    let meta: TDMeta
    let cash_flow: [TDCashReport]
}

struct TDStatisticsResponse: Codable {
    let meta: TDMeta
    let statistics: TDStatistics
}

struct TDMeta: Codable {
    let symbol: String
    let currency: String
}

struct TDIncomeReport: Codable {
    let fiscal_date: String
    // Twelve Data can return either string or number depending on plan/endpoint version sometimes, usually string for fundamentals
    // Codable implementation should handle String primarily for fundamentals API
    let revenue: Double? // Or String?
    let sales: Double?   // Alternative
    let net_income: Double?
    let ebitda: Double?
    
    // Custom decoding to handle String -> Double conversion automatically if needed
    // For simplicity assuming Double or handling failure.
    // Actually, Twelve Data fundamentals usually return Strings/Ints/Doubles. Safer to use String and convert.
    // Let's rely on standard JSON behavior or simple DTOs.
    
    enum CodingKeys: String, CodingKey {
        case fiscal_date
        case revenue, sales
        case net_income
        case ebitda
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiscal_date = try container.decode(String.self, forKey: .fiscal_date)
        revenue = try? container.decodeDoubleAsDoubleOrString(forKey: .revenue)
        sales = try? container.decodeDoubleAsDoubleOrString(forKey: .sales)
        net_income = try? container.decodeDoubleAsDoubleOrString(forKey: .net_income)
        ebitda = try? container.decodeDoubleAsDoubleOrString(forKey: .ebitda)
    }
}

struct TDBalanceReport: Codable {
    let fiscal_date: String
    let total_equity: Double?
    let shareholders_equity: Double?
    let short_term_debt: Double?
    let long_term_debt: Double?
    
    enum CodingKeys: String, CodingKey {
        case fiscal_date
        case total_equity, shareholders_equity
        case short_term_debt, long_term_debt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiscal_date = try container.decode(String.self, forKey: .fiscal_date)
        total_equity = try? container.decodeDoubleAsDoubleOrString(forKey: .total_equity)
        shareholders_equity = try? container.decodeDoubleAsDoubleOrString(forKey: .shareholders_equity)
        short_term_debt = try? container.decodeDoubleAsDoubleOrString(forKey: .short_term_debt)
        long_term_debt = try? container.decodeDoubleAsDoubleOrString(forKey: .long_term_debt)
    }
}

struct TDCashReport: Codable {
    let fiscal_date: String
    let operating_cash_flow: Double?
    let capital_expenditures: Double?
    
    enum CodingKeys: String, CodingKey {
        case fiscal_date
        case operating_cash_flow
        case capital_expenditures
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiscal_date = try container.decode(String.self, forKey: .fiscal_date)
        operating_cash_flow = try? container.decodeDoubleAsDoubleOrString(forKey: .operating_cash_flow)
        capital_expenditures = try? container.decodeDoubleAsDoubleOrString(forKey: .capital_expenditures)
    }
}

struct TDStatistics: Codable {
    let valuations_metrics: TDValuationMetrics
    let dividends_and_splits: TDDividends
}

struct TDValuationMetrics: Codable {
    let trailing_pe: Double?
    let forward_pe: Double?
    let price_to_book: Double?
    let enterprise_value_to_ebitda: Double?
    
    enum CodingKeys: String, CodingKey {
        case trailing_pe = "trailing_pe"
        case forward_pe = "forward_pe"
        case price_to_book = "price_to_book"
        case enterprise_value_to_ebitda = "enterprise_value_to_ebitda"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trailing_pe = try? container.decodeDoubleAsDoubleOrString(forKey: .trailing_pe)
        forward_pe = try? container.decodeDoubleAsDoubleOrString(forKey: .forward_pe)
        price_to_book = try? container.decodeDoubleAsDoubleOrString(forKey: .price_to_book)
        enterprise_value_to_ebitda = try? container.decodeDoubleAsDoubleOrString(forKey: .enterprise_value_to_ebitda)
    }
}

struct TDDividends: Codable {
    let dividend_yield: Double?
    
    enum CodingKeys: String, CodingKey {
        case dividend_yield
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Dividend yield might be string like "1.5%"
        dividend_yield = try? container.decodeDoubleAsDoubleOrString(forKey: .dividend_yield)
    }
}

extension KeyedDecodingContainer {
    func decodeDoubleAsDoubleOrString(forKey key: K) throws -> Double? {
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            if stringValue == "null" || stringValue.isEmpty { return nil }
            return Double(stringValue.replacingOccurrences(of: "%", with: ""))
        }
        return nil
    }
}
