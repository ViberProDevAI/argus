import Foundation

// MARK: - 1. Financials Data Model
// Alpha Vantage API'den gelen verileri tutar.
struct FinancialsData: Codable, @unchecked Sendable {
    let symbol: String
    let currency: String
    let lastUpdated: Date
    
    // Critical Data
    let totalRevenue: Double?
    let netIncome: Double?
    let totalShareholderEquity: Double?
    let marketCap: Double? // Added for Athena (Size Factor)
    
    // History (CAGR Calculation)
    let revenueHistory: [Double]
    let netIncomeHistory: [Double]
    
    // Optional Data
    let ebitda: Double?
    let shortTermDebt: Double?
    let longTermDebt: Double?
    let operatingCashflow: Double?
    let capitalExpenditures: Double?
    let cashAndCashEquivalents: Double? // Added for Smart Atlas Safety Check
    
    // Valuation
    let peRatio: Double?
    let forwardPERatio: Double?
    let priceToBook: Double?
    let evToEbitda: Double?
    let dividendYield: Double?
    let earningsPerShare: Double? // NEW: BIST Scraper icin Hisse Basina Kar
    
    // Growth Estimate
    let forwardGrowthEstimate: Double?
    
    // Analyst Expectations (Added for FinancialSnapshot)
    let targetMeanPrice: Double?
    let targetHighPrice: Double?
    let targetLowPrice: Double?
    let recommendationMean: Double? // 1.0=Strong Buy, 5.0=Sell
    let numberOfAnalystOpinions: Int?
    
    // Extended Metrics (TwelveData Statistics)
    var grossMargin: Double?
    var operatingMargin: Double?
    var profitMargin: Double?
    var returnOnEquity: Double?
    var returnOnAssets: Double?
    var debtToEquity: Double?
    var currentRatio: Double?
    var freeCashFlow: Double?
    var enterpriseValue: Double?
    var pegRatio: Double?
    var priceToSales: Double?
    var revenueGrowth: Double?
    var earningsGrowth: Double?
    
    // Asset Type Flag
    var isETF: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case symbol, currency, lastUpdated
        case totalRevenue, netIncome, totalShareholderEquity, marketCap
        case revenueHistory, netIncomeHistory
        case ebitda, shortTermDebt, longTermDebt, operatingCashflow, capitalExpenditures, cashAndCashEquivalents
        case peRatio, forwardPERatio, priceToBook, evToEbitda, dividendYield, earningsPerShare
        case forwardGrowthEstimate, isETF
        case targetMeanPrice, targetHighPrice, targetLowPrice, recommendationMean, numberOfAnalystOpinions
        case grossMargin, operatingMargin, profitMargin, returnOnEquity, returnOnAssets
        case debtToEquity, currentRatio, freeCashFlow, enterpriseValue, pegRatio, priceToSales
        case revenueGrowth, earningsGrowth
    }
    
    // Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        self.totalRevenue = try container.decodeIfPresent(Double.self, forKey: .totalRevenue)
        self.netIncome = try container.decodeIfPresent(Double.self, forKey: .netIncome)
        self.totalShareholderEquity = try container.decodeIfPresent(Double.self, forKey: .totalShareholderEquity)
        self.marketCap = try container.decodeIfPresent(Double.self, forKey: .marketCap)
        self.revenueHistory = try container.decode([Double].self, forKey: .revenueHistory)
        self.netIncomeHistory = try container.decode([Double].self, forKey: .netIncomeHistory)
        self.ebitda = try container.decodeIfPresent(Double.self, forKey: .ebitda)
        self.shortTermDebt = try container.decodeIfPresent(Double.self, forKey: .shortTermDebt)
        self.longTermDebt = try container.decodeIfPresent(Double.self, forKey: .longTermDebt)
        self.operatingCashflow = try container.decodeIfPresent(Double.self, forKey: .operatingCashflow)
        self.capitalExpenditures = try container.decodeIfPresent(Double.self, forKey: .capitalExpenditures)
        self.cashAndCashEquivalents = try container.decodeIfPresent(Double.self, forKey: .cashAndCashEquivalents)
        self.peRatio = try container.decodeIfPresent(Double.self, forKey: .peRatio)
        self.forwardPERatio = try container.decodeIfPresent(Double.self, forKey: .forwardPERatio)
        self.priceToBook = try container.decodeIfPresent(Double.self, forKey: .priceToBook)
        self.evToEbitda = try container.decodeIfPresent(Double.self, forKey: .evToEbitda)
        self.dividendYield = try container.decodeIfPresent(Double.self, forKey: .dividendYield)
        self.earningsPerShare = try container.decodeIfPresent(Double.self, forKey: .earningsPerShare)
        self.forwardGrowthEstimate = try container.decodeIfPresent(Double.self, forKey: .forwardGrowthEstimate)
        self.targetMeanPrice = try container.decodeIfPresent(Double.self, forKey: .targetMeanPrice)
        self.targetHighPrice = try container.decodeIfPresent(Double.self, forKey: .targetHighPrice)
        self.targetLowPrice = try container.decodeIfPresent(Double.self, forKey: .targetLowPrice)
        self.recommendationMean = try container.decodeIfPresent(Double.self, forKey: .recommendationMean)
        self.numberOfAnalystOpinions = try container.decodeIfPresent(Int.self, forKey: .numberOfAnalystOpinions)
        // Extended Metrics
        self.grossMargin = try container.decodeIfPresent(Double.self, forKey: .grossMargin)
        self.operatingMargin = try container.decodeIfPresent(Double.self, forKey: .operatingMargin)
        self.profitMargin = try container.decodeIfPresent(Double.self, forKey: .profitMargin)
        self.returnOnEquity = try container.decodeIfPresent(Double.self, forKey: .returnOnEquity)
        self.returnOnAssets = try container.decodeIfPresent(Double.self, forKey: .returnOnAssets)
        self.debtToEquity = try container.decodeIfPresent(Double.self, forKey: .debtToEquity)
        self.currentRatio = try container.decodeIfPresent(Double.self, forKey: .currentRatio)
        self.freeCashFlow = try container.decodeIfPresent(Double.self, forKey: .freeCashFlow)
        self.enterpriseValue = try container.decodeIfPresent(Double.self, forKey: .enterpriseValue)
        self.pegRatio = try container.decodeIfPresent(Double.self, forKey: .pegRatio)
        self.priceToSales = try container.decodeIfPresent(Double.self, forKey: .priceToSales)
        self.revenueGrowth = try container.decodeIfPresent(Double.self, forKey: .revenueGrowth)
        self.earningsGrowth = try container.decodeIfPresent(Double.self, forKey: .earningsGrowth)
        // Default to false
        self.isETF = try container.decodeIfPresent(Bool.self, forKey: .isETF) ?? false
    }
    
    // Default Memberwise Init
    init(symbol: String, currency: String, lastUpdated: Date, totalRevenue: Double?, netIncome: Double?, totalShareholderEquity: Double?, marketCap: Double?, revenueHistory: [Double], netIncomeHistory: [Double], ebitda: Double?, shortTermDebt: Double?, longTermDebt: Double?, operatingCashflow: Double?, capitalExpenditures: Double?, cashAndCashEquivalents: Double?, peRatio: Double?, forwardPERatio: Double?, priceToBook: Double?, evToEbitda: Double?, dividendYield: Double?, earningsPerShare: Double? = nil, forwardGrowthEstimate: Double?, isETF: Bool = false, grossMargin: Double? = nil, operatingMargin: Double? = nil, profitMargin: Double? = nil, returnOnEquity: Double? = nil, returnOnAssets: Double? = nil, debtToEquity: Double? = nil, currentRatio: Double? = nil, freeCashFlow: Double? = nil, enterpriseValue: Double? = nil, pegRatio: Double? = nil, priceToSales: Double? = nil, revenueGrowth: Double? = nil, earningsGrowth: Double? = nil, targetMeanPrice: Double? = nil, targetHighPrice: Double? = nil, targetLowPrice: Double? = nil, recommendationMean: Double? = nil, numberOfAnalystOpinions: Int? = nil) {
        self.symbol = symbol
        self.currency = currency
        self.lastUpdated = lastUpdated
        self.totalRevenue = totalRevenue
        self.netIncome = netIncome
        self.totalShareholderEquity = totalShareholderEquity
        self.marketCap = marketCap
        self.revenueHistory = revenueHistory
        self.netIncomeHistory = netIncomeHistory
        self.ebitda = ebitda
        self.shortTermDebt = shortTermDebt
        self.longTermDebt = longTermDebt
        self.operatingCashflow = operatingCashflow
        self.capitalExpenditures = capitalExpenditures
        self.cashAndCashEquivalents = cashAndCashEquivalents
        self.peRatio = peRatio
        self.forwardPERatio = forwardPERatio
        self.priceToBook = priceToBook
        self.evToEbitda = evToEbitda
        self.dividendYield = dividendYield
        self.earningsPerShare = earningsPerShare
        self.forwardGrowthEstimate = forwardGrowthEstimate
        self.isETF = isETF
        self.grossMargin = grossMargin
        self.operatingMargin = operatingMargin
        self.profitMargin = profitMargin
        self.returnOnEquity = returnOnEquity
        self.returnOnAssets = returnOnAssets
        self.debtToEquity = debtToEquity
        self.currentRatio = currentRatio
        self.freeCashFlow = freeCashFlow
        self.enterpriseValue = enterpriseValue
        self.pegRatio = pegRatio
        self.priceToSales = priceToSales
        self.revenueGrowth = revenueGrowth
        self.earningsGrowth = earningsGrowth
        self.targetMeanPrice = targetMeanPrice
        self.targetHighPrice = targetHighPrice
        self.targetLowPrice = targetLowPrice
        self.recommendationMean = recommendationMean
        self.numberOfAnalystOpinions = numberOfAnalystOpinions
    }
    // MARK: - Factory Methods
    
    static func missing(symbol: String, reason: String = "Unknown") -> FinancialsData {
        return FinancialsData(
            symbol: symbol,
            currency: "USD",
            lastUpdated: Date(),
            totalRevenue: nil,
            netIncome: nil,
            totalShareholderEquity: nil,
            marketCap: nil,
            revenueHistory: [],
            netIncomeHistory: [],
            ebitda: nil,
            shortTermDebt: nil,
            longTermDebt: nil,
            operatingCashflow: nil,
            capitalExpenditures: nil,
            cashAndCashEquivalents: nil,
            peRatio: nil,
            forwardPERatio: nil,
            priceToBook: nil,
            evToEbitda: nil,
            dividendYield: nil,
            earningsPerShare: nil,
            forwardGrowthEstimate: nil,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            numberOfAnalystOpinions: nil
        )
    }
}

// MARK: - 2. Fundamental Score Result
// Hesaplanan skor ve detaylarını tutar.
struct FundamentalScoreResult: Codable, Identifiable, Sendable {
    var id: String { symbol }
    let symbol: String
    let date: Date
    
    // Ana Skorlar (0-100)
    let totalScore: Double
    let realizedScore: Double
    let forwardScore: Double?
    
    // Alt Kategori Skorları
    let profitabilityScore: Double?
    let growthScore: Double?
    let leverageScore: Double?
    let cashQualityScore: Double?
    
    // Detaylar
    let dataCoverage: Double // 0-100
    let summary: String
    let highlights: [String]
    let proInsights: [String] // AI-like insights
    let calculationDetails: String // Detailed breakdown for sheet
    
    // New Metrics
    let valuationGrade: String? // "Ucuz", "Makul", "Pahalı"
    let riskScore: Double? // 0-100 Volatility Score
    var isETF: Bool = false
    
    // Raw Data Access for Atlas Council
    let financials: FinancialsData?
    
    enum CodingKeys: String, CodingKey {
        case symbol, date, totalScore, realizedScore, forwardScore
        case profitabilityScore, growthScore, leverageScore, cashQualityScore
        case dataCoverage, summary, highlights, proInsights, calculationDetails
        case valuationGrade, riskScore, isETF
        case financials // Added
    }
    
    // Custom Decoding to handle legacy cache missing 'isETF'
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.date = try container.decode(Date.self, forKey: .date)
        self.totalScore = try container.decode(Double.self, forKey: .totalScore)
        self.realizedScore = try container.decode(Double.self, forKey: .realizedScore)
        self.forwardScore = try container.decodeIfPresent(Double.self, forKey: .forwardScore)
        self.profitabilityScore = try container.decodeIfPresent(Double.self, forKey: .profitabilityScore)
        self.growthScore = try container.decodeIfPresent(Double.self, forKey: .growthScore)
        self.leverageScore = try container.decodeIfPresent(Double.self, forKey: .leverageScore)
        self.cashQualityScore = try container.decodeIfPresent(Double.self, forKey: .cashQualityScore)
        self.dataCoverage = try container.decode(Double.self, forKey: .dataCoverage)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.highlights = try container.decode([String].self, forKey: .highlights)
        self.proInsights = try container.decode([String].self, forKey: .proInsights)
        self.calculationDetails = try container.decode(String.self, forKey: .calculationDetails)
        self.valuationGrade = try container.decodeIfPresent(String.self, forKey: .valuationGrade)
        self.riskScore = try container.decodeIfPresent(Double.self, forKey: .riskScore)
        // Default to false if missing
        self.isETF = try container.decodeIfPresent(Bool.self, forKey: .isETF) ?? false
        // Try to decode financials
        self.financials = try container.decodeIfPresent(FinancialsData.self, forKey: .financials)
    }
    
    // Default Memberwise Initializer
    init(symbol: String, date: Date, totalScore: Double, realizedScore: Double, forwardScore: Double?, profitabilityScore: Double?, growthScore: Double?, leverageScore: Double?, cashQualityScore: Double?, dataCoverage: Double, summary: String, highlights: [String], proInsights: [String], calculationDetails: String, valuationGrade: String?, riskScore: Double?, isETF: Bool = false, financials: FinancialsData? = nil) {
        self.symbol = symbol
        self.date = date
        self.totalScore = totalScore
        self.realizedScore = realizedScore
        self.forwardScore = forwardScore
        self.profitabilityScore = profitabilityScore
        self.growthScore = growthScore
        self.leverageScore = leverageScore
        self.cashQualityScore = cashQualityScore
        self.dataCoverage = dataCoverage
        self.summary = summary
        self.highlights = highlights
        self.proInsights = proInsights
        self.calculationDetails = calculationDetails
        self.valuationGrade = valuationGrade
        self.riskScore = riskScore
        self.isETF = isETF
        self.financials = financials
    }
    
    // UI Yardımcısı: Renk
    var colorName: String {
        if totalScore >= 75 { return "Green" }
        else if totalScore >= 50 { return "Yellow" }
        else { return "Red" }
    }
}

// MARK: - Quality Grade
enum QualityGrade: String, Codable {
    case A_Plus = "A+"
    case A = "A"
    case A_Minus = "A-"
    case B_Plus = "B+"
    case B = "B"
    case B_Minus = "B-"
    case C_Plus = "C+"
    case C = "C"
    case C_Minus = "C-"
    case D = "D"
    case F = "F"
    
    var color: String {
        switch self {
        case .A_Plus, .A, .A_Minus: return "Green"
        case .B_Plus, .B, .B_Minus: return "Blue"
        case .C_Plus, .C, .C_Minus: return "Yellow"
        case .D, .F: return "Red"
        }
    }
}

extension FundamentalScoreResult {
    var qualityLetter: String {
        switch totalScore {
        case 92...100: return "A+"
        case 85..<92: return "A"
        case 80..<85: return "A-"
        case 74..<80: return "B+"
        case 68..<74: return "B"
        case 62..<68: return "B-"
        case 55..<62: return "C+"
        case 48..<55: return "C"
        case 42..<48: return "C-"
        case 35..<42: return "D"
        default: return "F"
        }
    }
    
    var qualityBand: String {
        switch totalScore {
        case 80...100: return "Yüksek Kalite"
        case 62..<80: return "Orta-İyi Kalite"
        case 42..<62: return "Orta-Zayıf Kalite"
        default: return "Düşük Kalite"
        }
    }
}
// MARK: - 3. Athena Factor Result
// "Smart Beta" stili faktör analizi (Value, Quality, Momentum, Risk).
struct AthenaFactorResult: Codable, Identifiable, Sendable {
    var id: String { symbol }
    let symbol: String
    let date: Date
    
    // Factor Scores (0-100)
    let valueFactorScore: Double
    let qualityFactorScore: Double
    let momentumFactorScore: Double
    let sizeFactorScore: Double?  // NEW: Size Factor (SMB - Small Minus Big)
    let riskFactorScore: Double
    
    // Final Factor Score
    let factorScore: Double
    
    // UI Label e.g. "Athena: Cheap + Quality + Momentum"
    let styleLabel: String
    
    // Helper for UI color
    var totalScore: Double { factorScore }
    
    var colorName: String {
        if factorScore >= 70 { return "Green" }
        else if factorScore >= 40 { return "Blue" } // Neutral/Mid
        else { return "Gray" }
    }
}
