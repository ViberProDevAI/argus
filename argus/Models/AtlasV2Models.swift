import Foundation

// MARK: - Atlas V2 Eğitim Motoru Veri Modelleri
// Her metrik için değer + açıklama + skor içerir

// MARK: - Kalite Bandı
enum AtlasQualityBand: String, Codable {
    case aPlus = "A+"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
    
    var description: String {
        switch self {
        case .aPlus: return "Mükemmel"
        case .a: return "Çok İyi"
        case .b: return "İyi"
        case .c: return "Orta"
        case .d: return "Zayıf"
        case .f: return "Kötü"
        }
    }
    
    var color: String {
        switch self {
        case .aPlus, .a: return "green"
        case .b: return "yellow"
        case .c: return "orange"
        case .d, .f: return "red"
        }
    }
    
    static func from(score: Double) -> AtlasQualityBand {
        switch score {
        case 85...: return .aPlus
        case 70..<85: return .a
        case 55..<70: return .b
        case 40..<55: return .c
        case 25..<40: return .d
        default: return .f
        }
    }
}

// MARK: - Metrik Durumu
enum AtlasMetricStatus: String, Codable {
    case excellent = "excellent"
    case good = "good"
    case neutral = "neutral"
    case warning = "warning"
    case bad = "bad"
    case critical = "critical"
    case noData = "noData"
    
    var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟢"
        case .neutral: return "🟡"
        case .warning: return "🟠"
        case .bad: return "🔴"
        case .critical: return "⛔"
        case .noData: return "⚪"
        }
    }
    
    var label: String {
        switch self {
        case .excellent: return "Mükemmel"
        case .good: return "İyi"
        case .neutral: return "Orta"
        case .warning: return "Dikkat"
        case .bad: return "Kötü"
        case .critical: return "Tehlikeli"
        case .noData: return "Veri Yok"
        }
    }
}

// MARK: - Tek Metrik
struct AtlasMetric: Identifiable, Codable {
    let id: String
    let name: String                    // "F/K (P/E)"
    let value: Double?                  // 28.5
    let formattedValue: String          // "28.5"
    let sectorAverage: Double?          // 32.0
    let status: AtlasMetricStatus       // .good
    let score: Double                   // 0-100
    let explanation: String             // "Sektöre göre %11 ucuz"
    let educationalNote: String         // "F/K, şirketin karına göre fiyatını ölçer..."
    let formula: String?                // "Fiyat / Hisse Başına Kar"
    
    init(
        id: String,
        name: String,
        value: Double?,
        sectorAverage: Double? = nil,
        status: AtlasMetricStatus,
        score: Double,
        explanation: String,
        educationalNote: String,
        formula: String? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.formattedValue = AtlasMetric.format(value)
        self.sectorAverage = sectorAverage
        self.status = status
        self.score = score
        self.explanation = explanation
        self.educationalNote = educationalNote
        self.formula = formula
    }
    
    static func format(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        if abs(v) >= 1_000_000_000_000 { return String(format: "%.1fT", v / 1_000_000_000_000) }
        if abs(v) >= 1_000_000_000 { return String(format: "%.1fB", v / 1_000_000_000) }
        if abs(v) >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if abs(v) >= 1000 { return String(format: "%.0f", v) }
        if abs(v) < 0.01 { return String(format: "%.4f", v) }
        return String(format: "%.2f", v)
    }
    
    static func formatPercent(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "%.1f%%", v)
    }
}

// MARK: - Bölüm Verileri

struct AtlasValuationData: Codable {
    let pe: AtlasMetric
    let pb: AtlasMetric
    let evEbitda: AtlasMetric
    let peg: AtlasMetric
    let forwardPE: AtlasMetric
    let priceToSales: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [pe, pb, evEbitda, peg, forwardPE, priceToSales].compactMap { $0 }
    }
}

struct AtlasProfitabilityData: Codable {
    let roe: AtlasMetric
    let roa: AtlasMetric
    let netMargin: AtlasMetric
    let grossMargin: AtlasMetric?
    let roic: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [roe, roa, netMargin, grossMargin, roic].compactMap { $0 }
    }
}

struct AtlasGrowthData: Codable {
    let revenueCAGR: AtlasMetric
    let netIncomeCAGR: AtlasMetric
    let forwardGrowth: AtlasMetric?
    let revenueGrowthYoY: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [revenueCAGR, netIncomeCAGR, forwardGrowth, revenueGrowthYoY].compactMap { $0 }
    }
}

struct AtlasHealthData: Codable {
    let debtToEquity: AtlasMetric
    let currentRatio: AtlasMetric
    let interestCoverage: AtlasMetric?
    let altmanZScore: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [debtToEquity, currentRatio, interestCoverage, altmanZScore].compactMap { $0 }
    }
}

struct AtlasCashData: Codable {
    let freeCashFlow: AtlasMetric
    let ocfToNetIncome: AtlasMetric
    let cashPosition: AtlasMetric?
    let netDebt: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [freeCashFlow, ocfToNetIncome, cashPosition, netDebt].compactMap { $0 }
    }
}

struct AtlasDividendData: Codable {
    let dividendYield: AtlasMetric
    let payoutRatio: AtlasMetric?
    let dividendGrowth: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [dividendYield, payoutRatio, dividendGrowth].compactMap { $0 }
    }
}

struct AtlasRiskData: Codable {
    let beta: AtlasMetric
    let week52High: AtlasMetric?
    let week52Low: AtlasMetric?
    let volatility: AtlasMetric?
    
    var allMetrics: [AtlasMetric] {
        [beta, week52High, week52Low, volatility].compactMap { $0 }
    }
}

// MARK: - Şirket Profili
struct AtlasCompanyProfile: Codable {
    let symbol: String
    let name: String
    let sector: String?
    let industry: String?
    let marketCap: Double?
    let formattedMarketCap: String
    let employees: Int?
    let description: String?
    let currency: String
    
    var marketCapTier: String {
        guard let cap = marketCap else { return "Bilinmiyor" }
        switch cap {
        case 200_000_000_000...: return "Mega Cap"
        case 10_000_000_000..<200_000_000_000: return "Large Cap"
        case 2_000_000_000..<10_000_000_000: return "Mid Cap"
        case 300_000_000..<2_000_000_000: return "Small Cap"
        default: return "Micro Cap"
        }
    }
}

// MARK: - Ana Sonuç
struct AtlasV2Result: Identifiable, Codable {
    let id: String
    let symbol: String
    let timestamp: Date
    
    // Şirket Profili
    let profile: AtlasCompanyProfile
    
    // Skorlar (0-100)
    let totalScore: Double
    let valuationScore: Double
    let profitabilityScore: Double
    let growthScore: Double
    let healthScore: Double
    let cashScore: Double
    let dividendScore: Double
    
    // Kalite Bandı
    let qualityBand: AtlasQualityBand
    
    // Detay Veriler
    let valuation: AtlasValuationData
    let profitability: AtlasProfitabilityData
    let growth: AtlasGrowthData
    let health: AtlasHealthData
    let cash: AtlasCashData
    let dividend: AtlasDividendData
    let risk: AtlasRiskData
    
    // Yorumlar
    let summary: String
    let highlights: [String]
    let warnings: [String]
    
    init(
        symbol: String,
        profile: AtlasCompanyProfile,
        totalScore: Double,
        valuationScore: Double,
        profitabilityScore: Double,
        growthScore: Double,
        healthScore: Double,
        cashScore: Double,
        dividendScore: Double,
        valuation: AtlasValuationData,
        profitability: AtlasProfitabilityData,
        growth: AtlasGrowthData,
        health: AtlasHealthData,
        cash: AtlasCashData,
        dividend: AtlasDividendData,
        risk: AtlasRiskData,
        summary: String,
        highlights: [String],
        warnings: [String]
    ) {
        self.id = "\(symbol)_\(Date().timeIntervalSince1970)"
        self.symbol = symbol
        self.timestamp = Date()
        self.profile = profile
        self.totalScore = totalScore
        self.valuationScore = valuationScore
        self.profitabilityScore = profitabilityScore
        self.growthScore = growthScore
        self.healthScore = healthScore
        self.cashScore = cashScore
        self.dividendScore = dividendScore
        self.qualityBand = AtlasQualityBand.from(score: totalScore)
        self.valuation = valuation
        self.profitability = profitability
        self.growth = growth
        self.health = health
        self.cash = cash
        self.dividend = dividend
        self.risk = risk
        self.summary = summary
        self.highlights = highlights
        self.warnings = warnings
    }
}

// MARK: - Sektör Benchmark Verileri
struct AtlasSectorBenchmark: Codable {
    let sector: String
    let avgPE: Double
    let avgPB: Double
    let avgROE: Double
    let avgNetMargin: Double
    let avgDebtToEquity: Double
    let avgDividendYield: Double
}
