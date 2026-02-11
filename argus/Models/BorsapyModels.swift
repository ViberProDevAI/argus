
import Foundation

// MARK: - Teknik Sinyal Modelleri (TradingView ta_signals)

/// 28 teknik göstergenin toplu sinyal sonucu
struct BistTechnicalSignals: Codable {
    let symbol: String
    let timeframe: String
    let summary: TASummary
    let oscillators: TAIndicatorGroup
    let movingAverages: TAIndicatorGroup
    let timestamp: String

    /// Özet sinyali Türkçe'ye çevirir
    var sinyalTurkce: String {
        switch summary.recommendation {
        case "STRONG_BUY": return "Güçlü Al"
        case "BUY": return "Al"
        case "NEUTRAL": return "Nötr"
        case "SELL": return "Sat"
        case "STRONG_SELL": return "Güçlü Sat"
        default: return summary.recommendation
        }
    }

    var totalIndicators: Int { summary.buy + summary.sell + summary.neutral }
}

struct TASummary: Codable {
    let recommendation: String
    let buy: Int
    let sell: Int
    let neutral: Int
}

struct TAIndicatorGroup: Codable {
    let recommendation: String
    let values: [String: TAIndicatorValue]

    var sinyalTurkce: String {
        switch recommendation {
        case "STRONG_BUY": return "Güçlü Al"
        case "BUY": return "Al"
        case "NEUTRAL": return "Nötr"
        case "SELL": return "Sat"
        case "STRONG_SELL": return "Güçlü Sat"
        default: return recommendation
        }
    }
}

struct TAIndicatorValue: Codable {
    let value: Double?
    let signal: String

    var sinyalTurkce: String {
        switch signal {
        case "BUY": return "Al"
        case "SELL": return "Sat"
        case "NEUTRAL": return "Nötr"
        default: return signal
        }
    }
}

// MARK: - Enflasyon Modeli

/// TÜFE/ÜFE enflasyon verisi (BorsaPy /inflation endpoint'i)
struct BistInflationData: Codable {
    let date: String
    let yearlyInflation: Double
    let monthlyInflation: Double
    let type: String  // "TUFE" veya "UFE"

    enum CodingKeys: String, CodingKey {
        case date
        case yearlyInflation = "yearly_inflation"
        case monthlyInflation = "monthly_inflation"
        case type
    }
}

// MARK: - TCMB Politika Faizi

struct TCMBPolicyRateResponse: Codable {
    let rate: Double
    let timestamp: String
}

// MARK: - Institution Rates (Doviz.com)

/// Bir kurumun (banka veya kuyumcu) döviz/altın alış-satış fiyatları
struct InstitutionRate: Identifiable, Codable {
    var id: String { institution }
    let institution: String      // örn: "akbank", "kapalicarsi"
    let institutionName: String  // örn: "Akbank", "Kapalıçarşı"
    let asset: String            // örn: "gram-altin", "USD"
    let buy: Double
    let sell: Double
    let spread: Double?          // Alış-satış makası (%)
    let updateTime: Date?
}

// MARK: - Institution History

/// Kurum bazlı tarihsel fiyat verisi
struct InstitutionCandle: Identifiable, Codable {
    var id: Date { date }
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    
    // Bankalar genelde sadece Close verir, bu durumda OHLC aynı olabilir.
}

// MARK: - TEFAS Fund Models

/// Fon Detay Bilgileri
struct FundDetail: Codable {
    let code: String
    let name: String
    let price: Double
    let dailyReturn: Double
    let return1M: Double?
    let return3M: Double?
    let return6M: Double?
    let return1Y: Double?
    let return3Y: Double?
    let return5Y: Double?
    let riskValue: Int? // 1-7
    let categoryRank: String? // "20/181"
    let fundSize: Double?
    let investors: Int?
    let allocation: [FundAllocation]?
}

/// Fon Varlık Dağılımı
struct FundAllocation: Identifiable, Codable {
    var id: String { assetName }
    let assetType: String // örn: "HS" (Hisse Senedi)
    let assetName: String // örn: "Hisse Senedi"
    let weight: Double    // %
    let date: Date
}

/// Fon Tarihsel Fiyatı
struct FundPrice: Identifiable, Codable {
    var id: Date { date }
    let date: Date
    let price: Double
    let fundSize: Double?
    let investors: Int?
}

// MARK: - Risk Metrics

struct RiskMetrics: Codable {
    let annualizedReturn: Double
    let annualizedVolatility: Double
    let sharpeRatio: Double
    let sortinoRatio: Double
    let maxDrawdown: Double
}

// MARK: - Fund Price Data (For List View)

/// Fon için anlık fiyat ve getiri verileri
struct FundPriceData: Identifiable {
    var id: String { code }
    let code: String
    let currentPrice: Double
    let previousPrice: Double?
    let dailyChange: Double
    let dailyChangePercent: Double
    let fundSize: Double?
    let investors: Int?
    let lastUpdated: Date
    
    // Calculated returns
    let return1Week: Double?
    let return1Month: Double?
    let return3Month: Double?
    let return6Month: Double?
    let returnYTD: Double?
    let return1Year: Double?
    
    init(
        code: String,
        currentPrice: Double,
        previousPrice: Double? = nil,
        fundSize: Double? = nil,
        investors: Int? = nil,
        return1Week: Double? = nil,
        return1Month: Double? = nil,
        return3Month: Double? = nil,
        return6Month: Double? = nil,
        returnYTD: Double? = nil,
        return1Year: Double? = nil
    ) {
        self.code = code
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
        self.fundSize = fundSize
        self.investors = investors
        self.lastUpdated = Date()
        self.return1Week = return1Week
        self.return1Month = return1Month
        self.return3Month = return3Month
        self.return6Month = return6Month
        self.returnYTD = returnYTD
        self.return1Year = return1Year
        
        // Calculate daily change
        if let prev = previousPrice, prev > 0 {
            self.dailyChange = currentPrice - prev
            self.dailyChangePercent = ((currentPrice - prev) / prev) * 100
        } else {
            self.dailyChange = 0
            self.dailyChangePercent = 0
        }
    }
}

