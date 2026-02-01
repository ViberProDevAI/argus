import Foundation

// MARK: - Legacy Models (Restored)
// Bu modeller projenin diğer kısımlarında kullanıldığı için geri getirildi.

struct BistQuote: Codable {
    let symbol: String
    let last: Double
    let open: Double
    let high: Double
    let low: Double
    let previousClose: Double
    let volume: Double
    let change: Double
    let bid: Double
    let ask: Double
    let timestamp: Date
    
    var changePercent: Double { change }
}

struct FXRate: Codable {
    let symbol: String
    let last: Double
    let open: Double
    let high: Double
    let low: Double
    let timestamp: Date
}

struct BorsaPyCandle: Codable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct FXCandle: Codable {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

struct BistDividend: Codable, Identifiable {
    let date: Date
    let grossRate: Double
    let netRate: Double
    let totalAmount: Double
    let perShare: Double
    
    var id: Date { date }
    
    var year: Int {
        Calendar.current.component(.year, from: date)
    }
}

struct BistCapitalIncrease: Codable, Identifiable {
    let date: Date
    let capitalAfter: Double
    let rightsIssueRate: Double
    let bonusFromCapitalRate: Double
    let bonusFromDividendRate: Double
    
    var id: Date { date }
    
    var totalBonusRate: Double {
        bonusFromCapitalRate + bonusFromDividendRate
    }
}

struct BistAnalystConsensus: Codable {
    let symbol: String
    let averageTargetPrice: Double?
    let highTargetPrice: Double?
    let lowTargetPrice: Double?
    let potentialReturn: Double
    let recommendation: String
    
    let buyCount: Int
    let holdCount: Int
    let sellCount: Int
    
    let timestamp: Date
    
    var totalAnalysts: Int { buyCount + holdCount + sellCount }
    
    var consensusScore: Double {
        guard totalAnalysts > 0 else { return 50.0 } // Neutral default
        // Simple weighted score: Buy=100, Hold=50, Sell=0
        let score = (Double(buyCount) * 1.0 + Double(holdCount) * 0.5) / Double(totalAnalysts)
        return score * 100.0
    }
    
    func upsidePotential(currentPrice: Double) -> Double? {
        guard let target = averageTargetPrice, currentPrice > 0 else { return nil }
        return ((target - currentPrice) / currentPrice) * 100.0
    }
}

struct BistFinancials: Codable {
    let symbol: String
    let period: String
    let netProfit: Double?
    let ebitda: Double?
    let revenue: Double?
    let grossProfit: Double?
    let operatingProfit: Double?
    let totalAssets: Double?
    let totalEquity: Double?
    let totalDebt: Double?
    let shortTermDebt: Double?
    let longTermDebt: Double?
    let currentAssets: Double?
    let cash: Double?
    let operatingCashFlow: Double?
    let revenueGrowth: Double?
    let netProfitGrowth: Double?
    let roe: Double?
    let roa: Double?
    let currentRatio: Double?
    let debtToEquity: Double?
    let netMargin: Double?
    let pe: Double?
    let pb: Double?
    let marketCap: Double?
    let eps: Double?
    let timestamp: Date
    
    var cashRatio: Double? {
        guard let c = cash, let d = shortTermDebt, d > 0 else { return nil }
        return c / d
    }
    
    var grossMargin: Double? {
        guard let g = grossProfit, let r = revenue, r > 0 else { return nil }
        return g / r
    }
    
    var operatingMargin: Double? {
        guard let o = operatingProfit, let r = revenue, r > 0 else { return nil }
        return o / r
    }
}

enum BorsaPyError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case decodingError
    case missingApiKey
    case dataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .requestFailed: return "İstek başarısız"
        case .invalidResponse: return "Geçersiz yanıt"
        case .missingApiKey: return "API anahtarı eksik"
        case .dataUnavailable: return "Veri bulunamadı"
        default: return "Bir hata oluştu"
        }
    }
}

enum GoldType: String {
    case gramAltin = "gram-altin"
    case ons = "ons"
}

// MARK: - BorsaPyProvider (Renamed from BorsaDataService for Compatibility)
/// Hem yeni Is Yatırım temel analiz fonksiyonlarını hem de eski legacy çağrı fonksiyonlarını içerir.
/// İleride refactor edilecek.
actor BorsaPyProvider {
    static let shared = BorsaPyProvider()
    
    // MARK: - Endpoints
    private let baseURL = "https://www.isyatirim.com.tr"
    private let stockInfoURL = "https://www.isyatirim.com.tr/_layouts/15/IsYatirim.Website/StockInfo/CompanyInfoAjax.aspx"
    private let maliTabloURL = "https://www.isyatirim.com.tr/_Layouts/15/IsYatirim.Website/Common/Data.aspx/MaliTablo"
    private let isyatirimBaseURL = "https://www.isyatirim.com.tr/_Layouts/15/IsYatirim.Website/Common"
    
    // Cache
    private var quoteCache: [String: (quote: BistQuote, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 120
    
    private init() {}
    
    // MARK: - NEW: Fundamentals (Sermaye, Temettü, Bilanço)
    
    func getCapitalIncreases(symbol: String) async throws -> [BistCapitalIncrease] {
         let result = try await getCapitalAndDividends(symbol: symbol)
         return result.increases
    }
    
    func getDividends(symbol: String) async throws -> [BistDividend] {
        let result = try await getCapitalAndDividends(symbol: symbol)
        return result.dividends
    }
    
    private func getCapitalAndDividends(symbol: String) async throws -> (dividends: [BistDividend], increases: [BistCapitalIncrease]) {
        let cleanSymbol = cleanSymbol(symbol)
        guard let url = URL(string: "\(stockInfoURL)/GetSermayeArttirimlari") else { throw BorsaPyError.invalidURL }
        
        let payload: [String: Any] = [
            "hisseKodu": cleanSymbol,
            "hisseTanimKodu": "",
            "yil": 0,
            "zaman": "HEPSI",
            "endeksKodu": "09",
            "sektorKodu": ""
        ]
        
        // İş Yatırım genellikle "d" parametresi içinde JSON string döndürür
        let rawData = try await performRequest(url: url, method: "POST", payload: payload, referer: stockPageURL(symbol: cleanSymbol))
        
        // Response formatı: {"d": "[{...}, {...}]"}
        guard let jsonObject = try JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let jsonString = jsonObject["d"] as? String,
              let jsonData = jsonString.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return ([], [])
        }
        
        return (parseDividends(from: items), parseCapitalIncreases(from: items))
    }
    
    func getFinancialStatements(symbol: String) async throws -> BistFinancials {
        // En son açıklanan dönemi bulmaya çalışalım (Örn: 2024/9)
        // Basitlik için hardcoded deneme yapıyoruz veya parametrik olmalıydı.
        // Legacy uyumluluğu için parametresiz signature tutuyoruz, içeride mantık kuruyoruz.
        
        let year = Calendar.current.component(.year, from: Date())
        // Genelde bir önceki yılın son çeyreği veya bu yılın ilk çeyreği.
        // Şimdilik 2024/9'u deneyelim (daha dinamik olmalı)
        return try await getFinancialStatements(symbol: symbol, year: year, period: 9)
    }
    
    func getFinancialStatements(symbol: String, year: Int, period: Int) async throws -> BistFinancials {
        let cleanSymbol = cleanSymbol(symbol)
        
        guard let url = URL(string: maliTabloURL) else { throw BorsaPyError.invalidURL }
        
        let payload: [String: Any] = [
            "companyCode": cleanSymbol,
            "exchange": "TRY",
            "financialGroup": "XI_29",
            "kur": "",
            "isConsolidated": true,
            "year1": year,
            "period1": period,
            "year2": year - 1,
            "period2": period
        ]
        
        let rawData = try await performRequest(url: url, method: "POST", payload: payload, referer: stockPageURL(symbol: cleanSymbol))
        
        var items: [[String: Any]] = []
        if let jsonObject = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] {
             if let dString = jsonObject["d"] as? String,
                let data = dString.data(using: .utf8),
                let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                 items = list
             } else if let value = jsonObject["value"] as? [[String: Any]] {
                 items = value
             }
        } else if let list = try? JSONSerialization.jsonObject(with: rawData) as? [[String: Any]] {
            items = list
        }
        
        guard !items.isEmpty else { throw BorsaPyError.invalidResponse }
        
        return parseFinancials(from: items, symbol: cleanSymbol, period: "\(year)/\(period)")
    }
    
    // MARK: - Legacy Compatibility Methods (BistQuote, FX, History)
    
    /// BIST Hisse Anlık Fiyat (Eski Endpoint deneniyor, çalışmazsa fallback)
    func getBistQuote(symbol: String) async throws -> BistQuote {
        let cleanSymbol = cleanSymbol(symbol)
        
        // Cache Check
        if let cached = quoteCache[cleanSymbol], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.quote
        }
        
        // Burası eski endpoint, muhtemelen çalışmayacak ama kodun derlenmesi için tutuyoruz.
        // Gerçek implementasyon TradingView WebSocket olmalı.
        // Şimdilik boş değer veya hata.
        // Projeyi kırmamak için dummy veri dönelim veya eski endpointi deneyelim.
        
        let url = URL(string: "\(isyatirimBaseURL)/ChartData.aspx/OneEndeks?endeks=\(cleanSymbol)")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let quote = BistQuote(
                    symbol: cleanSymbol,
                    last: json["son"] as? Double ?? json["last"] as? Double ?? 0,
                    open: json["acilis"] as? Double ?? 0,
                    high: json["yuksek"] as? Double ?? 0,
                    low: json["dusuk"] as? Double ?? 0,
                    previousClose: json["oncekiKapanis"] as? Double ?? 0,
                    volume: json["hacim"] as? Double ?? 0,
                    change: json["yuzdeDegisim"] as? Double ?? 0,
                    bid: 0, ask: 0, timestamp: Date()
                )
                quoteCache[cleanSymbol] = (quote, Date())
                return quote
            }
        } catch {}
        
        // Failover
        throw BorsaPyError.requestFailed
    }
    
    func getXU100() async throws -> BistQuote { try await getBistQuote(symbol: "XU100") }
    
    func getSectorIndex(code: String) async throws -> BistQuote { try await getBistQuote(symbol: code) }
    
    func getFXRate(asset: String) async throws -> FXRate {
        let ySymbol = mapYahooSymbol(for: asset)
        let candles = try await YahooFinanceProvider.shared.fetchCandles(symbol: ySymbol, timeframe: "1d", limit: 1)
        guard let latest = candles.first else { throw BorsaPyError.dataUnavailable }
        return FXRate(
            symbol: asset,
            last: latest.close,
            open: latest.open,
            high: latest.high,
            low: latest.low,
            timestamp: latest.date
        )
    }
    
    func getBrentPrice() async throws -> FXRate {
         try await getFXRate(asset: "BRENT")
    }
    
    func getBistHistory(symbol: String, days: Int = 30) async throws -> [BorsaPyCandle] {
        let s = normalizeBistYahooSymbol(symbol)
        let candles = try await YahooFinanceProvider.shared.fetchCandles(symbol: s, timeframe: "1d", limit: days)
        guard !candles.isEmpty else { throw BorsaPyError.dataUnavailable }
        return candles.map { candle in
            BorsaPyCandle(
                date: candle.date,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                volume: candle.volume
            )
        }
    }
    
    func getAnalystRecommendations(symbol: String) async throws -> BistAnalystConsensus {
        let key = APIKeyStore.shared.getKey(for: .fmp) ?? Secrets.fmpKey
        guard !key.isEmpty else { throw BorsaPyError.missingApiKey }
        
        let clean = cleanSymbol(symbol)
        let fmpSymbol = clean.contains(".") ? clean : "\(clean).IS"
        
        let grades = try await fetchFMPGradesConsensus(symbol: fmpSymbol, apiKey: key)
        let targets = try await fetchFMPPriceTargetConsensus(symbol: fmpSymbol, apiKey: key)
        
        let strongBuy = grades.strongBuy
        let buy = grades.buy
        let hold = grades.hold
        let sell = grades.sell
        let strongSell = grades.strongSell
        
        let buyCount = strongBuy + buy
        let sellCount = strongSell + sell
        let holdCount = hold
        let total = buyCount + holdCount + sellCount
        
        if total == 0 && targets.average == nil && targets.high == nil && targets.low == nil {
            throw BorsaPyError.dataUnavailable
        }
        
        let currentPrice = (try? await getBistQuote(symbol: clean)).map { $0.last }
        let potentialReturn = computePotentialReturn(currentPrice: currentPrice, target: targets.average)
        
        return BistAnalystConsensus(
            symbol: clean,
            averageTargetPrice: targets.average,
            highTargetPrice: targets.high,
            lowTargetPrice: targets.low,
            potentialReturn: potentialReturn,
            recommendation: grades.recommendation ?? "N/A",
            buyCount: buyCount,
            holdCount: holdCount,
            sellCount: sellCount,
            timestamp: Date()
        )
    }

    // MARK: - Internal Helpers
    
    private func cleanSymbol(_ symbol: String) -> String {
        return symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")
            .replacingOccurrences(of: ".E", with: "")
    }
    
    private func stockPageURL(symbol: String) -> String {
        return "\(baseURL)/tr-tr/analiz/hisse/Sayfalar/sirket-karti.aspx?hisse=\(symbol)"
    }

    private func mapYahooSymbol(for asset: String) -> String {
        let clean = asset.uppercased().replacingOccurrences(of: "/", with: "")
        if clean.contains("USDTRY") || clean == "USD" {
            return "USDTRY=X"
        }
        if clean.contains("EURTRY") || clean == "EUR" {
            return "EURTRY=X"
        }
        if clean.contains("GBPTRY") || clean == "GBP" {
            return "GBPTRY=X"
        }
        if clean.contains("BRENT") || clean.contains("BRN") {
            return "BZ=F"
        }
        return asset
    }

    private func normalizeBistYahooSymbol(_ symbol: String) -> String {
        let s = symbol.uppercased()
        if s.hasSuffix(".IS") { return s }
        return "\(s).IS"
    }

    private func computePotentialReturn(currentPrice: Double?, target: Double?) -> Double {
        guard let price = currentPrice, let target = target, price > 0 else { return 0 }
        return ((target - price) / price) * 100
    }

    private struct FMPGradesConsensus {
        let strongBuy: Int
        let buy: Int
        let hold: Int
        let sell: Int
        let strongSell: Int
        let recommendation: String?
    }
    
    private struct FMPPriceTargets {
        let average: Double?
        let high: Double?
        let low: Double?
    }
    
    private func fetchFMPGradesConsensus(symbol: String, apiKey: String) async throws -> FMPGradesConsensus {
        let stableURL = try fmpURL(path: "stable/grades-consensus", symbol: symbol, apiKey: apiKey)
        if let first = try? await fetchFMPFirstObject(url: stableURL) {
            let strongBuy = intValue(first, keys: ["strongBuy", "strong_buy", "analystRatingsStrongBuy"])
            let buy = intValue(first, keys: ["buy", "analystRatingsBuy"])
            let hold = intValue(first, keys: ["hold", "analystRatingsHold", "neutral"])
            let sell = intValue(first, keys: ["sell", "analystRatingsSell"])
            let strongSell = intValue(first, keys: ["strongSell", "strong_sell", "analystRatingsStrongSell"])
            let recommendation = stringValue(first, keys: ["consensus", "recommendation"])
            return FMPGradesConsensus(
                strongBuy: strongBuy,
                buy: buy,
                hold: hold,
                sell: sell,
                strongSell: strongSell,
                recommendation: recommendation
            )
        }
        
        let legacyURL = try fmpURL(path: "api/v3/analyst-stock-recommendations/\(symbol)", apiKey: apiKey)
        if let first = try? await fetchFMPFirstObject(url: legacyURL) {
            let strongBuy = intValue(first, keys: ["strongBuy", "analystRatingsStrongBuy"])
            let buy = intValue(first, keys: ["buy", "analystRatingsBuy"])
            let hold = intValue(first, keys: ["hold", "analystRatingsHold", "neutral"])
            let sell = intValue(first, keys: ["sell", "analystRatingsSell"])
            let strongSell = intValue(first, keys: ["strongSell", "analystRatingsStrongSell"])
            let recommendation = stringValue(first, keys: ["consensus", "recommendation"])
            return FMPGradesConsensus(
                strongBuy: strongBuy,
                buy: buy,
                hold: hold,
                sell: sell,
                strongSell: strongSell,
                recommendation: recommendation
            )
        }
        
        return FMPGradesConsensus(strongBuy: 0, buy: 0, hold: 0, sell: 0, strongSell: 0, recommendation: nil)
    }
    
    private func fetchFMPPriceTargetConsensus(symbol: String, apiKey: String) async throws -> FMPPriceTargets {
        let stableURL = try fmpURL(path: "stable/price-target-consensus", symbol: symbol, apiKey: apiKey)
        if let first = try? await fetchFMPFirstObject(url: stableURL) {
            let average = doubleValue(first, keys: ["priceTarget", "targetPrice", "targetConsensus", "averageTargetPrice", "targetMeanPrice"])
            let high = doubleValue(first, keys: ["targetHigh", "targetHighPrice", "highPriceTarget"])
            let low = doubleValue(first, keys: ["targetLow", "targetLowPrice", "lowPriceTarget"])
            return FMPPriceTargets(average: average, high: high, low: low)
        }
        
        let legacyURL = try fmpURL(path: "api/v3/price-target-consensus/\(symbol)", apiKey: apiKey)
        if let first = try? await fetchFMPFirstObject(url: legacyURL) {
            let average = doubleValue(first, keys: ["priceTarget", "targetMeanPrice", "targetPrice", "averageTargetPrice"])
            let high = doubleValue(first, keys: ["targetHighPrice", "highPriceTarget"])
            let low = doubleValue(first, keys: ["targetLowPrice", "lowPriceTarget"])
            return FMPPriceTargets(average: average, high: high, low: low)
        }
        
        return FMPPriceTargets(average: nil, high: nil, low: nil)
    }
    
    private func fmpURL(path: String, symbol: String? = nil, apiKey: String) throws -> URL {
        var components: URLComponents
        if path.hasPrefix("http") {
            components = URLComponents(string: path) ?? URLComponents()
        } else if path.hasPrefix("api/v3") {
            components = URLComponents(string: "https://financialmodelingprep.com/\(path)") ?? URLComponents()
        } else {
            components = URLComponents(string: "https://financialmodelingprep.com/\(path)") ?? URLComponents()
        }
        var items = components.queryItems ?? []
        if let symbol { items.append(URLQueryItem(name: "symbol", value: symbol)) }
        items.append(URLQueryItem(name: "apikey", value: apiKey))
        components.queryItems = items
        guard let url = components.url else { throw BorsaPyError.invalidURL }
        return url
    }
    
    private func fmpURL(path: String, apiKey: String) throws -> URL {
        guard let url = URL(string: "https://financialmodelingprep.com/\(path)?apikey=\(apiKey)") else {
            throw BorsaPyError.invalidURL
        }
        return url
    }
    
    private func fetchFMPFirstObject(url: URL) async throws -> [String: Any]? {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BorsaPyError.invalidResponse
        }
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        if let arr = json as? [[String: Any]] {
            return arr.first
        }
        if let obj = json as? [String: Any] {
            return obj
        }
        return nil
    }
    
    private func intValue(_ dict: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let v = dict[key] as? Int { return v }
            if let v = dict[key] as? Double { return Int(v) }
            if let v = dict[key] as? String, let i = Int(v) { return i }
        }
        return 0
    }
    
    private func doubleValue(_ dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let v = dict[key] as? Double { return v }
            if let v = dict[key] as? Int { return Double(v) }
            if let v = dict[key] as? String, let d = Double(v) { return d }
        }
        return nil
    }
    
    private func stringValue(_ dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let v = dict[key] as? String, !v.isEmpty { return v }
        }
        return nil
    }
    
    private func performRequest(url: URL, method: String, payload: [String: Any]? = nil, referer: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        
        if let payload = payload {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BorsaPyError.requestFailed
        }
        
        guard httpResponse.statusCode == 200 else {
            print("HTTP Error: \(httpResponse.statusCode)")
            throw BorsaPyError.requestFailed
        }
        
        return data
    }
    
    // Parsers (Same as before)
    private func parseDividends(from items: [[String: Any]]) -> [BistDividend] {
        var dividends: [BistDividend] = []
        for item in items {
            guard let type = item["SHT_KODU"] as? String, type == "04",
                  let timestamp = item["SHHE_TARIH"] as? Double else { continue }
            
            let date = Date(timeIntervalSince1970: timestamp / 1000)
            let grossRate = (item["SHHE_NAKIT_TM_ORAN"] as? Double) ?? 0
            
            dividends.append(BistDividend(
                date: date,
                grossRate: grossRate,
                netRate: (item["SHHE_NAKIT_TM_ORAN_NET"] as? Double) ?? 0,
                totalAmount: (item["SHHE_NAKIT_TM_TUTAR"] as? Double) ?? 0,
                perShare: grossRate / 100.0
            ))
        }
        return dividends.sorted { $0.date > $1.date }
    }
    
    private func parseCapitalIncreases(from items: [[String: Any]]) -> [BistCapitalIncrease] {
        var increases: [BistCapitalIncrease] = []
        for item in items {
            guard let type = item["SHT_KODU"] as? String, ["03", "09"].contains(type),
                  let timestamp = item["SHHE_TARIH"] as? Double else { continue }
            
            let date = Date(timeIntervalSince1970: timestamp / 1000)
            
            increases.append(BistCapitalIncrease(
                date: date,
                capitalAfter: (item["HSP_BOLUNME_SONRASI_SERMAYE"] as? Double) ?? 0,
                rightsIssueRate: (item["SHHE_BDLI_ORAN"] as? Double) ?? 0,
                bonusFromCapitalRate: (item["SHHE_BDSZ_IK_ORAN"] as? Double) ?? 0,
                bonusFromDividendRate: (item["SHHE_BDSZ_TM_ORAN"] as? Double) ?? 0
            ))
        }
        return increases.sorted { $0.date > $1.date }
    }
    
    private func parseFinancials(from items: [[String: Any]], symbol: String, period: String) -> BistFinancials {
        func val(_ keys: [String]) -> Double? {
            for item in items {
                if let desc = item["itemDescTr"] as? String {
                    for key in keys {
                        if desc.localizedCaseInsensitiveContains(key) {
                            return item["value1"] as? Double
                        }
                    }
                }
            }
            return nil
        }
        let revenue = val(["Satış Gelirleri", "Hasılat"])
        let netProfit = val(["Dönem Karı", "DÖNEM KARI"])
        
        return BistFinancials(
            symbol: symbol,
            period: period,
            netProfit: netProfit,
            ebitda: val(["FAVÖK"]),
            revenue: revenue,
            grossProfit: val(["Brüt Kar"]),
            operatingProfit: val(["Esas Faaliyet Karı"]),
            totalAssets: val(["Toplam Varlıklar"]),
            totalEquity: val(["Toplam Özkaynaklar"]),
            totalDebt: val(["Toplam Yükümlülükler"]),
            shortTermDebt: nil,
            longTermDebt: nil,
            currentAssets: nil,
            cash: val(["Nakit ve Nakit Benzerleri"]),
            operatingCashFlow: val(["İşletme Faaliyetlerinden"]),
            revenueGrowth: nil,
            netProfitGrowth: nil,
            roe: nil,
            roa: nil,
            currentRatio: nil,
            debtToEquity: nil,
            netMargin: (netProfit != nil && revenue != nil && revenue! > 0) ? (netProfit! / revenue!) * 100 : nil,
            pe: nil,
            pb: nil,
            marketCap: nil,
            eps: nil,
            timestamp: Date()
        )
    }
}
