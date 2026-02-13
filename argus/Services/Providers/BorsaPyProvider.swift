import Foundation

// MARK: - Models (Tüm projedeki bağımlılıklar korunuyor)

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
        guard totalAnalysts > 0 else { return 50.0 }
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
    
    // Backward-compat computed properties
    var peRatio: Double? { pe }
    
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
    case backendUnavailable
    case timeout
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .requestFailed: return "İstek başarısız"
        case .invalidResponse: return "Geçersiz yanıt"
        case .missingApiKey: return "API anahtarı eksik"
        case .dataUnavailable: return "Veri bulunamadı"
        case .backendUnavailable: return "BorsaPy backend erişilemez"
        case .timeout: return "İstek zaman aşımına uğradı"
        case .rateLimited: return "BorsaPy hız limiti aşıldı"
        case .serverError(let statusCode): return "Sunucu hatası (\(statusCode))"
        default: return "Bir hata oluştu"
        }
    }
}

enum GoldType: String {
    case gramAltin = "gram-altin"
    case ons = "ons"
}

// Global request gate to prevent BorsaPy bursts from starving modules.
private actor BorsaPyRequestGate {
    static let shared = BorsaPyRequestGate(maxConcurrent: 3, minIntervalSeconds: 0.12)

    private let maxConcurrent: Int
    private let minIntervalNanos: UInt64
    private var activeCount: Int = 0
    private var lastRequestStartedAtNanos: UInt64 = 0

    init(maxConcurrent: Int, minIntervalSeconds: TimeInterval) {
        self.maxConcurrent = max(1, maxConcurrent)
        self.minIntervalNanos = UInt64(max(0, minIntervalSeconds) * 1_000_000_000)
    }

    func acquire() async {
        while activeCount >= maxConcurrent {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        let now = DispatchTime.now().uptimeNanoseconds
        if lastRequestStartedAtNanos > 0, now > lastRequestStartedAtNanos {
            let elapsed = now - lastRequestStartedAtNanos
            if elapsed < minIntervalNanos {
                try? await Task.sleep(nanoseconds: minIntervalNanos - elapsed)
            }
        }

        activeCount += 1
        lastRequestStartedAtNanos = DispatchTime.now().uptimeNanoseconds
    }

    func release() {
        activeCount = max(0, activeCount - 1)
    }
}

// MARK: - BorsaPyProvider (borsapy FastAPI Backend Entegrasyonu)
/// borsapy Python backend'ine HTTP üzerinden bağlanır.
/// Backend: Scripts/borsapy_server/main.py
actor BorsaPyProvider {
    static let shared = BorsaPyProvider()
    
    // MARK: - Backend Config
    nonisolated private static let infoPlistBackendURLKey = "BORSAPY_URL"
    nonisolated private static let fallbackBaseURLs: [String] = [
        "https://argus-borsapy.onrender.com",
        "http://localhost:8899",
        "http://127.0.0.1:8899",
        "http://localhost:8899",
        "http://localhost:8899"
    ]
    nonisolated private static var canUseLocalNetworkFallbacks: Bool {
#if targetEnvironment(simulator) || targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }
    
    // Cache
    private var quoteCache: [String: (quote: BistQuote, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 120
    
    private var preferredBackendBaseURL: String?
    private var blockedBackendsUntil: [String: Date] = [:]
    private let backendCooldownSeconds: TimeInterval = 30
    private let requestTimeoutSeconds: TimeInterval = 20
    private let slowRequestThresholdSeconds: TimeInterval = 4
    private let maxAttemptsPerBackend = 3
    private let initialRetryDelaySeconds: TimeInterval = 0.35
    private let requestGate = BorsaPyRequestGate.shared
    
    private init() {
        // no-op
    }
    
    // MARK: - Public API: Quote
    
    func getBistQuote(symbol: String) async throws -> BistQuote {
        let clean = cleanSymbol(symbol)
        
        // Cache Check
        if let cached = quoteCache[clean], Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.quote
        }
        
        let json = try await fetchJSON(path: "/ticker/\(clean)/quote")
        
        let quote = BistQuote(
            symbol: clean,
            last: json["last"] as? Double ?? 0,
            open: json["open"] as? Double ?? 0,
            high: json["high"] as? Double ?? 0,
            low: json["low"] as? Double ?? 0,
            previousClose: json["previousClose"] as? Double ?? 0,
            volume: json["volume"] as? Double ?? 0,
            change: json["change"] as? Double ?? 0,
            bid: 0, ask: 0,
            timestamp: Date()
        )
        
        quoteCache[clean] = (quote, Date())
        return quote
    }
    
    func getXU100() async throws -> BistQuote {
        try await getBistQuote(symbol: "XU100")
    }
    
    func getSectorIndex(code: String) async throws -> BistQuote {
        try await getBistQuote(symbol: code)
    }
    
    // MARK: - Public API: History
    
    func getBistHistory(symbol: String, days: Int = 30) async throws -> [BorsaPyCandle] {
        let clean = cleanSymbol(symbol)
        let period = periodFromDays(days)
        
        let json = try await fetchJSON(path: "/ticker/\(clean)/history?period=\(period)&interval=1d")
        
        guard let candlesArray = json["candles"] as? [[String: Any]] else {
            throw BorsaPyError.dataUnavailable
        }
        
        let candles = candlesArray.compactMap { parseCandle($0) }
        guard !candles.isEmpty else { throw BorsaPyError.dataUnavailable }
        return candles
    }
    
    // MARK: - Public API: FX
    
    func getFXRate(asset: String) async throws -> FXRate {
        let mapped = mapFXSymbol(asset)
        let json = try await fetchJSON(path: "/fx/\(mapped)")
        
        return FXRate(
            symbol: asset,
            last: json["last"] as? Double
                ?? json["satis"] as? Double
                ?? json["selling"] as? Double ?? 0,
            open: json["open"] as? Double ?? 0,
            high: json["high"] as? Double ?? 0,
            low: json["low"] as? Double ?? 0,
            timestamp: Date()
        )
    }
    
    func getBrentPrice() async throws -> FXRate {
        let json = try await fetchJSON(path: "/gold/BRENT")
        return FXRate(
            symbol: "BRENT",
            last: json["last"] as? Double ?? 0,
            open: json["open"] as? Double ?? 0,
            high: json["high"] as? Double ?? 0,
            low: json["low"] as? Double ?? 0,
            timestamp: Date()
        )
    }
    
    // MARK: - Public API: Gold
    
    func getGoldPrice(type: GoldType = .gramAltin) async throws -> FXRate {
        let json = try await fetchJSON(path: "/gold/\(type.rawValue)")
        return FXRate(
            symbol: type.rawValue,
            last: json["last"] as? Double ?? 0,
            open: json["open"] as? Double ?? 0,
            high: json["high"] as? Double ?? 0,
            low: json["low"] as? Double ?? 0,
            timestamp: Date()
        )
    }
    
    // MARK: - Public API: Financials
    
    func getFinancialStatements(symbol: String) async throws -> BistFinancials {
        let clean = cleanSymbol(symbol)
        let json = try await fetchJSON(path: "/ticker/\(clean)/financials")
        return parseFinancials(json, symbol: clean)
    }
    
    func getFinancialStatements(symbol: String, year: Int, period: Int) async throws -> BistFinancials {
        // Backend çeyreklik veri destekliyorsa quarterly parametresi ile
        let clean = cleanSymbol(symbol)
        let quarterly = (period != 12)
        let json = try await fetchJSON(path: "/ticker/\(clean)/financials?quarterly=\(quarterly)")
        return parseFinancials(json, symbol: clean)
    }
    
    // MARK: - Public API: Dividends
    
    func getDividends(symbol: String) async throws -> [BistDividend] {
        let clean = cleanSymbol(symbol)
        let json = try await fetchJSON(path: "/ticker/\(clean)/dividends")
        
        guard let items = json["dividends"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item -> BistDividend? in
            let dateRaw = item["date"] as? String ?? item["Date"] as? String ?? item["index"] as? String
            guard let dateStr = dateRaw, let date = parseAnyDate(dateStr) else { return nil }
            return BistDividend(
                date: date,
                grossRate: item["grossRate"] as? Double
                    ?? item["GrossRate"] as? Double
                    ?? item["Brüt Kar Payı Oranı (%)"] as? Double ?? 0,
                netRate: item["netRate"] as? Double
                    ?? item["NetRate"] as? Double
                    ?? item["Net Kar Payı Oranı (%)"] as? Double ?? 0,
                totalAmount: item["totalAmount"] as? Double
                    ?? item["TotalDividend"] as? Double
                    ?? item["Toplam Kar Payı Tutarı (TL)"] as? Double ?? 0,
                perShare: item["perShare"] as? Double
                    ?? item["Amount"] as? Double
                    ?? item["Hisse Başına Kar Payı (TL)"] as? Double ?? 0
            )
        }
    }
    
    // MARK: - Public API: Capital Increases (Splits)
    
    func getCapitalIncreases(symbol: String) async throws -> [BistCapitalIncrease] {
        let clean = cleanSymbol(symbol)
        let json = try await fetchJSON(path: "/ticker/\(clean)/splits")
        
        guard let items = json["splits"] as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item -> BistCapitalIncrease? in
            guard let dateStr = item["date"] as? String ?? item["index"] as? String,
                  let date = parseAnyDate(dateStr) else { return nil }
            return BistCapitalIncrease(
                date: date,
                capitalAfter: item["capitalAfter"] as? Double ?? item["Capital"] as? Double ?? 0,
                rightsIssueRate: item["rightsIssueRate"] as? Double ?? item["RightsIssue"] as? Double ?? 0,
                bonusFromCapitalRate: item["bonusFromCapitalRate"] as? Double ?? item["BonusFromCapital"] as? Double ?? 0,
                bonusFromDividendRate: item["bonusFromDividendRate"] as? Double ?? item["BonusFromDividend"] as? Double ?? 0
            )
        }
    }
    
    // MARK: - Public API: Analyst Recommendations
    
    func getAnalystRecommendations(symbol: String) async throws -> BistAnalystConsensus {
        let clean = cleanSymbol(symbol)
        let json = try await fetchJSON(path: "/ticker/\(clean)/analysts")
        
        let targets = json["priceTargets"] as? [String: Any] ?? [:]
        let recs = json["recommendations"] as? [String: Any] ?? [:]
        
        let avgTarget = targets["targetMeanPrice"] as? Double
            ?? targets["mean"] as? Double
            ?? targets["averageTargetPrice"] as? Double
        let highTarget = targets["targetHighPrice"] as? Double
            ?? targets["high"] as? Double
        let lowTarget = targets["targetLowPrice"] as? Double
            ?? targets["low"] as? Double
        
        let buyCount = (recs["buy"] as? Int ?? 0) + (recs["strongBuy"] as? Int ?? 0)
        let holdCount = recs["hold"] as? Int ?? 0
        let sellCount = (recs["sell"] as? Int ?? 0) + (recs["strongSell"] as? Int ?? 0)
        
        let recommendation = recs["recommendationKey"] as? String
            ?? recs["consensus"] as? String
            ?? derivedConsensusLabel(buy: buyCount, hold: holdCount, sell: sellCount)
        
        // Potansiyel getiri hesapla
        var potentialReturn = 0.0
        if let target = avgTarget {
            let currentQuote = try? await getBistQuote(symbol: clean)
            if let price = currentQuote?.last, price > 0 {
                potentialReturn = ((target - price) / price) * 100.0
            }
        }
        
        return BistAnalystConsensus(
            symbol: clean,
            averageTargetPrice: avgTarget,
            highTargetPrice: highTarget,
            lowTargetPrice: lowTarget,
            potentialReturn: potentialReturn,
            recommendation: recommendation,
            buyCount: buyCount,
            holdCount: holdCount,
            sellCount: sellCount,
            timestamp: Date()
        )
    }
    
    // MARK: - Enflasyon (Typed)

    /// Güncel TÜFE enflasyon verisi (yıllık + aylık)
    func getInflationData() async throws -> BistInflationData {
        let json = try await fetchJSON(path: "/inflation")
        guard let yearly = json["yearly_inflation"] as? Double,
              let monthly = json["monthly_inflation"] as? Double else {
            throw BorsaPyError.decodingError
        }
        return BistInflationData(
            date: json["date"] as? String ?? "",
            yearlyInflation: yearly,
            monthlyInflation: monthly,
            type: json["type"] as? String ?? "TUFE"
        )
    }

    /// Eski untyped versiyon (geriye uyumluluk)
    func getInflation() async throws -> [String: Any] {
        return try await fetchJSON(path: "/inflation")
    }

    // MARK: - TCMB Politika Faizi

    /// Merkez Bankası güncel politika faiz oranı
    func getPolicyRate() async throws -> Double {
        let json = try await fetchJSON(path: "/tcmb/policy-rate")
        guard let rate = json["rate"] as? Double else {
            throw BorsaPyError.decodingError
        }
        return rate
    }

    // MARK: - Teknik Sinyaller (TradingView)

    /// 28 teknik göstergenin toplu sinyal analizi
    func getTechnicalSignals(symbol: String, timeframe: String = "1d") async throws -> BistTechnicalSignals {
        let clean = cleanSymbol(symbol)
        let json = try await fetchJSON(path: "/ticker/\(clean)/ta-signals?timeframe=\(timeframe)")

        // Summary
        let summaryDict = json["summary"] as? [String: Any] ?? [:]
        let summary = TASummary(
            recommendation: summaryDict["recommendation"] as? String ?? "NEUTRAL",
            buy: summaryDict["buy"] as? Int ?? 0,
            sell: summaryDict["sell"] as? Int ?? 0,
            neutral: summaryDict["neutral"] as? Int ?? 0
        )

        // Oscillators & Moving Averages
        func parseGroup(_ key: String) -> TAIndicatorGroup {
            let groupDict = json[key] as? [String: Any] ?? [:]
            let rec = groupDict["recommendation"] as? String ?? "NEUTRAL"
            let valuesDict = groupDict["values"] as? [String: [String: Any]] ?? [:]
            var values: [String: TAIndicatorValue] = [:]
            for (name, vDict) in valuesDict {
                values[name] = TAIndicatorValue(
                    value: vDict["value"] as? Double,
                    signal: vDict["signal"] as? String ?? "NEUTRAL"
                )
            }
            return TAIndicatorGroup(recommendation: rec, values: values)
        }

        return BistTechnicalSignals(
            symbol: clean,
            timeframe: timeframe,
            summary: summary,
            oscillators: parseGroup("oscillators"),
            movingAverages: parseGroup("movingAverages"),
            timestamp: json["timestamp"] as? String ?? ""
        )
    }

    // MARK: - Tahvil Faizleri

    func getBondYields() async throws -> [[String: Any]] {
        let json = try await fetchJSON(path: "/bond")
        return json["yields"] as? [[String: Any]] ?? []
    }
    
    // MARK: - NEW: News (KAP Haberleri)
    
    struct BistNewsItem: Codable, Identifiable {
        let id: String
        let title: String
        let summary: String
        let date: String
        let source: String
        
        init(id: String = UUID().uuidString, title: String, summary: String, date: String, source: String) {
            self.id = id
            self.title = title
            self.summary = summary
            self.date = date
            self.source = source
        }
    }
    
    func getNews(symbol: String) async throws -> [BistNewsItem] {
        let clean = cleanSymbol(symbol)
        let json = try await fetchJSON(path: "/ticker/\(clean)/news")
        let newsArray = json["news"] as? [[String: Any]] ?? []
        
        return newsArray.compactMap { item in
            guard let title = item["title"] as? String ?? item["Title"] as? String else { return nil }
            let summary = item["summary"] as? String
                ?? item["Summary"] as? String
                ?? item["URL"] as? String
                ?? ""
            return BistNewsItem(
                title: title,
                summary: summary,
                date: item["date"] as? String ?? item["Date"] as? String ?? "",
                source: item["source"] as? String ?? "KAP"
            )
        }
    }
    
    // MARK: - Internal: HTTP Client
    
    private func fetchJSON(path: String) async throws -> [String: Any] {
        let candidates = await activeBackendCandidates()
        guard !candidates.isEmpty else {
            throw BorsaPyError.backendUnavailable
        }
        
        var lastError: Error = BorsaPyError.backendUnavailable
        for baseURL in candidates {
            var backendError: Error = BorsaPyError.backendUnavailable
            for attempt in 1...maxAttemptsPerBackend {
                do {
                    let json = try await requestJSON(baseURL: baseURL, path: path)
                    preferredBackendBaseURL = baseURL
                    blockedBackendsUntil.removeValue(forKey: baseURL)
                    return json
                } catch {
                    backendError = error
                    lastError = error

                    if attempt < maxAttemptsPerBackend, shouldRetryOnSameBackend(error) {
                        let delay = retryDelay(for: error, attempt: attempt)
                        print("BorsaPyProvider: Retry \(attempt + 1)/\(maxAttemptsPerBackend) in \(String(format: "%.2f", delay))s — \(baseURL)\(path)")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }

                    break
                }
            }

            if shouldTryNextBackend(for: backendError) {
                // Tek backend varsa cooldown'a alma; aksi halde 30sn boyunca tüm istekler boşta kalıyor.
                if candidates.count > 1 {
                    blockedBackendsUntil[baseURL] = Date().addingTimeInterval(backendCooldownSeconds)
                }
                continue
            }

            throw backendError
        }
        
        if let borsaError = lastError as? BorsaPyError {
            throw borsaError
        }
        throw BorsaPyError.backendUnavailable
    }
    
    private func requestJSON(baseURL: String, path: String) async throws -> [String: Any] {
        let urlString = baseURL + path
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString) else {
            throw BorsaPyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let data: Data
        let response: URLResponse
        let startedAt = Date()

        await requestGate.acquire()
        defer {
            Task {
                await requestGate.release()
            }
        }

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            print("BorsaPyProvider: Zaman aşımı — \(baseURL) — \(urlError.localizedDescription)")
            throw BorsaPyError.timeout
        } catch {
            print("BorsaPyProvider: Backend erişilemez — \(baseURL) — \(error.localizedDescription)")
            throw BorsaPyError.backendUnavailable
        }
        
        let elapsed = Date().timeIntervalSince(startedAt)
        if elapsed >= slowRequestThresholdSeconds {
            print("BorsaPyProvider: Yavaş yanıt (\(String(format: "%.2f", elapsed))s) — \(urlString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BorsaPyError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw BorsaPyError.missingApiKey
            }
            if httpResponse.statusCode == 429 {
                let retryAfter = parseRetryAfterHeader(httpResponse.value(forHTTPHeaderField: "Retry-After"))
                throw BorsaPyError.rateLimited(retryAfter: retryAfter)
            }
            if (500...599).contains(httpResponse.statusCode) {
                throw BorsaPyError.serverError(statusCode: httpResponse.statusCode)
            }
            print("BorsaPyProvider: HTTP \(httpResponse.statusCode) — \(urlString)")
            throw BorsaPyError.requestFailed
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BorsaPyError.invalidResponse
        }
        
        return json
    }
    
    private func shouldTryNextBackend(for error: Error) -> Bool {
        guard let borsaError = error as? BorsaPyError else {
            return true
        }
        
        switch borsaError {
        case .backendUnavailable, .requestFailed, .invalidResponse, .timeout, .rateLimited, .serverError:
            return true
        case .missingApiKey:
            return false
        default:
            return false
        }
    }

    private func shouldRetryOnSameBackend(_ error: Error) -> Bool {
        guard let borsaError = error as? BorsaPyError else {
            return true
        }

        switch borsaError {
        case .missingApiKey, .invalidURL, .decodingError, .dataUnavailable:
            return false
        case .backendUnavailable, .requestFailed, .invalidResponse, .timeout, .rateLimited, .serverError:
            return true
        }
    }

    private func retryDelay(for error: Error, attempt: Int) -> TimeInterval {
        if case .rateLimited(let retryAfter) = error as? BorsaPyError,
           let retryAfter,
           retryAfter > 0 {
            return min(retryAfter, 8.0)
        }

        let exp = initialRetryDelaySeconds * pow(2.0, Double(max(0, attempt - 1)))
        let jitter = Double.random(in: 0...0.2)
        return min(exp + jitter, 5.0)
    }

    private func parseRetryAfterHeader(_ rawValue: String?) -> TimeInterval? {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if let seconds = TimeInterval(raw), seconds >= 0 {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        if let date = formatter.date(from: raw) {
            return max(0, date.timeIntervalSinceNow)
        }

        return nil
    }
    
    private func activeBackendCandidates() async -> [String] {
        let now = Date()
        var candidates = await configuredBackendCandidates()
        
        candidates = candidates.filter { baseURL in
            guard let blockedUntil = blockedBackendsUntil[baseURL] else { return true }
            return blockedUntil <= now
        }
        
        if let preferred = preferredBackendBaseURL, let idx = candidates.firstIndex(of: preferred), idx != 0 {
            candidates.remove(at: idx)
            candidates.insert(preferred, at: 0)
        }
        
        if candidates.isEmpty,
           let preferred = preferredBackendBaseURL,
           (blockedBackendsUntil[preferred] ?? .distantPast) <= now {
            candidates = [preferred]
        }
        
        return candidates
    }
    
    private func configuredBackendCandidates() async -> [String] {
        var candidates: [String] = []
        appendBackendCandidate(from: Bundle.main.object(forInfoDictionaryKey: Self.infoPlistBackendURLKey) as? String, to: &candidates)
        appendBackendCandidate(from: ProcessInfo.processInfo.environment[Self.infoPlistBackendURLKey], to: &candidates)
        
        let fallbackList: [String]
        if Self.canUseLocalNetworkFallbacks {
            fallbackList = Self.fallbackBaseURLs
        } else {
            fallbackList = ["https://argus-borsapy.onrender.com"]
        }
        
        for fallback in fallbackList {
            appendBackendCandidate(from: fallback, to: &candidates)
        }
        
        if let preferred = preferredBackendBaseURL, !candidates.contains(preferred) {
            candidates.insert(preferred, at: 0)
        }
        
        return candidates
    }
    
    private func appendBackendCandidate(from rawValue: String?, to candidates: inout [String]) {
        guard let normalized = Self.normalizeBaseURL(rawValue), !candidates.contains(normalized) else {
            return
        }
        candidates.append(normalized)
    }
    
    nonisolated private static func normalizeBaseURL(_ rawValue: String?) -> String? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        
        if !value.contains("://") {
            value = "https://\(value)"
        }
        
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }
        
        components.query = nil
        components.fragment = nil
        var path = components.path
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }
        if path == "/" { path = "" }
        components.path = path
        
        guard let normalized = components.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else {
            return nil
        }
        
        return normalized
    }
    
    // MARK: - Internal: Helpers
    
    private func cleanSymbol(_ symbol: String) -> String {
        return symbol.uppercased()
            .replacingOccurrences(of: ".IS", with: "")
            .replacingOccurrences(of: ".E", with: "")
    }
    
    private func mapFXSymbol(_ asset: String) -> String {
        let clean = asset.uppercased().replacingOccurrences(of: "/", with: "")
        if clean.contains("USDTRY") || clean == "USD" { return "USD" }
        if clean.contains("EURTRY") || clean == "EUR" { return "EUR" }
        if clean.contains("GBPTRY") || clean == "GBP" { return "GBP" }
        if clean.contains("BRENT") || clean.contains("BRN") { return "BRENT" }
        return clean
    }
    
    private func parseAnyDate(_ raw: String) -> Date? {
        if let d = ISO8601DateFormatter().date(from: raw) {
            return d
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: raw) {
                return d
            }
        }
        return nil
    }
    
    private func derivedConsensusLabel(buy: Int, hold: Int, sell: Int) -> String {
        if buy >= hold && buy >= sell { return "BUY" }
        if sell >= buy && sell >= hold { return "SELL" }
        return "HOLD"
    }
    
    private func periodFromDays(_ days: Int) -> String {
        switch days {
        case 0...7: return "1h"
        case 8...35: return "1ay"
        case 36...100: return "3ay"
        case 101...370: return "1y"
        default: return "max"
        }
    }
    
    private func parseCandle(_ dict: [String: Any]) -> BorsaPyCandle? {
        guard let dateStr = dict["date"] as? String else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: dateStr)
            ?? ISO8601DateFormatter().date(from: dateStr)
            ?? Date()
        
        return BorsaPyCandle(
            date: date,
            open: dict["open"] as? Double ?? 0,
            high: dict["high"] as? Double ?? 0,
            low: dict["low"] as? Double ?? 0,
            close: dict["close"] as? Double ?? 0,
            volume: dict["volume"] as? Double ?? 0
        )
    }
    
    private func parseFinancials(_ json: [String: Any], symbol: String) -> BistFinancials {
        let ratios = json["ratios"] as? [String: Any] ?? [:]
        let balanceItems = json["balanceSheet"] as? [[String: Any]] ?? []
        let incomeItems = json["incomeStatement"] as? [[String: Any]] ?? []
        
        // Helper: bilanço/gelir tablosundan değer çek
        func val(from items: [[String: Any]], keys: [String]) -> Double? {
            for item in items {
                if let idx = item["index"] as? String {
                    for key in keys {
                        if idx.localizedCaseInsensitiveContains(key) {
                            // İlk sütun değerini bul (index dışındaki)
                            for (k, v) in item where k != "index" {
                                if let d = v as? Double { return d }
                            }
                        }
                    }
                }
            }
            return nil
        }
        
        let revenue = val(from: incomeItems, keys: ["Satış Gelirleri", "Hasılat", "Revenue"])
        let netProfit = val(from: incomeItems, keys: ["Dönem Karı", "Net Profit", "Net Income"])
        let grossProfit = val(from: incomeItems, keys: ["Brüt Kar", "Gross Profit"])
        let operatingProfit = val(from: incomeItems, keys: ["Esas Faaliyet", "Operating"])
        let ebitda = val(from: incomeItems, keys: ["FAVÖK", "EBITDA"])
        
        let totalAssets = val(from: balanceItems, keys: ["Toplam Varlık", "Total Assets"])
        let totalEquity = val(from: balanceItems, keys: ["Toplam Özkaynak", "Total Equity"])
        let totalDebt = val(from: balanceItems, keys: ["Toplam Yükümlülük", "Total Liabilities"])
        let cash = val(from: balanceItems, keys: ["Nakit", "Cash"])
        let currentAssets = val(from: balanceItems, keys: ["Dönen Varlık", "Current Assets"])
        let shortTermDebt = val(from: balanceItems, keys: ["Kısa Vadeli", "Short Term"])
        let longTermDebt = val(from: balanceItems, keys: ["Uzun Vadeli", "Long Term"])
        let operatingCashFlow = val(from: incomeItems, keys: ["İşletme Faaliyet", "Operating Cash"])
        
        let pe = ratios["pe"] as? Double
        let marketCap = ratios["marketCap"] as? Double
        
        return BistFinancials(
            symbol: symbol,
            period: "latest",
            netProfit: netProfit,
            ebitda: ebitda,
            revenue: revenue,
            grossProfit: grossProfit,
            operatingProfit: operatingProfit,
            totalAssets: totalAssets,
            totalEquity: totalEquity,
            totalDebt: totalDebt,
            shortTermDebt: shortTermDebt,
            longTermDebt: longTermDebt,
            currentAssets: currentAssets,
            cash: cash,
            operatingCashFlow: operatingCashFlow,
            revenueGrowth: nil,
            netProfitGrowth: nil,
            roe: (netProfit != nil && totalEquity != nil && totalEquity! > 0)
                ? (netProfit! / totalEquity!) * 100 : nil,
            roa: (netProfit != nil && totalAssets != nil && totalAssets! > 0)
                ? (netProfit! / totalAssets!) * 100 : nil,
            currentRatio: (currentAssets != nil && shortTermDebt != nil && shortTermDebt! > 0)
                ? currentAssets! / shortTermDebt! : nil,
            debtToEquity: (totalDebt != nil && totalEquity != nil && totalEquity! > 0)
                ? totalDebt! / totalEquity! : nil,
            netMargin: (netProfit != nil && revenue != nil && revenue! > 0)
                ? (netProfit! / revenue!) * 100 : nil,
            pe: pe,
            pb: nil,
            marketCap: marketCap,
            eps: (netProfit != nil && marketCap != nil && pe != nil && pe! > 0)
                ? marketCap! / pe! : nil,
            timestamp: Date()
        )
    }
}
