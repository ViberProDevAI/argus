import Foundation

final class YahooFinanceProvider: HeimdallProvider {
    static let shared = YahooFinanceProvider()
    nonisolated var name: String { "Yahoo" }
    
    nonisolated var capabilities: [HeimdallDataField] {
        return [.quote, .candles, .screener, .macro]
    }
    
    private init() {}
    
    func fetchQuote(symbol: String) async throws -> Quote {
        // Use Global Symbol Resolver (SSoT)
        // This handles "SILVER" -> "SI=F", "DXY" -> "DX-Y.NYB" etc.
        let ySymbol = SymbolResolver.shared.resolve(symbol, for: .yahoo)
        
        // Encode for URL (e.g. ^VIX -> %5EVIX, but careful with = chars)
        let encodedSymbol = encodeYahooSymbolForPath(ySymbol)
        
        // Reverting to v8 Chart Endpoint (No Auth Required usually)
        // FORCE RANGE: 5d to ensure we have previous close data even if meta is broken.
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(encodedSymbol)?interval=1d&range=5d"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let data = try await HeimdallNetwork.request(
            url: url,
            engine: .market,
            provider: .yahoo,
            symbol: symbol
        )
        
        struct YChartResponse: Codable {
            struct Chart: Codable {
                struct Result: Codable {
                    struct Meta: Codable {
                        let regularMarketPrice: Double?
                        let previousClose: Double?
                        let currency: String?
                        let symbol: String?
                    }
                    let meta: Meta
                    
                    struct Indicators: Codable {
                        struct QuoteIndicator: Codable {
                            let close: [Double?]?
                        }
                        let quote: [QuoteIndicator]
                    }
                    let indicators: Indicators? // Optional because sometimes it's missing on error
                }
                let result: [Result]?
                let error: YError?
            }
            struct YError: Codable { let description: String? }
            let chart: Chart
        }
        
        do {
            let resp = try JSONDecoder().decode(YChartResponse.self, from: data)
            
            if let err = resp.chart.error {
                print("⚠️ Yahoo API Error Message: \(err.description ?? "Unknown")")
                throw URLError(.resourceUnavailable)
            }
            
            guard let res = resp.chart.result?.first,
                  let price = res.meta.regularMarketPrice else {
                throw URLError(.resourceUnavailable)
            }
            
            let prev = res.meta.previousClose ?? price
            var change = price - prev
            var pct = prev != 0 ? (change / prev) * 100 : 0.0
            
            // FALLBACK: If prev is 0 or price == prev (0.00% change suspicious), check historical bars
            if (pct == 0.0 || prev == 0), let closes = res.indicators?.quote.first?.close {
                let validCloses = closes.compactMap { $0 }
                if validCloses.count >= 2 {
                    // Last is current price (roughly), second to last is previous day
                    let lastIndex = validCloses.count - 1
                    // Ensure the last close roughly matches current price (yahoo updates live)
                    // We take the second to last as "Reference Previous Close"
                     let referencePrev = validCloses[lastIndex - 1]
                     if referencePrev > 0 {
                         change = price - referencePrev
                         pct = (change / referencePrev) * 100.0
                     }
                }
            }
            
            var q = Quote(
                c: price,
                d: change,
                dp: pct,
                currency: res.meta.currency ?? "USD",
                shortName: res.meta.symbol,
                symbol: symbol // Critical for UI Identification
            )
            q.previousClose = prev
            return q
        } catch {
            print("⚠️ Yahoo Decode Error (v8): \(error)")
            throw error // Triggers failover
        }
    }
    
    // MARK: - Batch Quote (Single Request for Multiple Symbols)
    /// Tek bir HTTP isteğinde birden fazla sembol için quote çeker
    /// 50 sembol için 50 istek yerine 1 istek - Rate limit sorunu çözümü
    func fetchBatchQuotes(symbols: [String]) async throws -> [String: Quote] {
        guard !symbols.isEmpty else { return [:] }
        
        // Sembolleri Yahoo formatına çevir ve URL encode et
        let yahooSymbols = symbols.map { SymbolResolver.shared.resolve($0, for: .yahoo) }
        let symbolsParam = yahooSymbols.joined(separator: ",")
        
        // URL encode (virgül korunmalı)
        guard let encodedSymbols = symbolsParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw URLError(.badURL)
        }
        
        let urlString = "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(encodedSymbols)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("📡 Yahoo Batch: \(symbols.count) sembol tek istekte çekiliyor...")
        
        let data = try await HeimdallNetwork.request(
            url: url,
            engine: .market,
            provider: .yahoo,
            symbol: symbols.first ?? "BATCH"
        )
        
        // Parse response
        struct BatchResponse: Codable {
            struct QuoteResponse: Codable {
                struct Result: Codable {
                    let symbol: String
                    let regularMarketPrice: Double?
                    let regularMarketChange: Double?
                    let regularMarketChangePercent: Double?
                    let regularMarketPreviousClose: Double?
                    let currency: String?
                    let shortName: String?
                    let marketCap: Double?
                }
                let result: [Result]?
                let error: YError?
            }
            struct YError: Codable { let description: String? }
            let quoteResponse: QuoteResponse
        }
        
        do {
            let resp = try JSONDecoder().decode(BatchResponse.self, from: data)
            
            if let err = resp.quoteResponse.error {
                print("⚠️ Yahoo Batch Error: \(err.description ?? "Unknown")")
                throw URLError(.badServerResponse)
            }
            
            guard let results = resp.quoteResponse.result else {
                print("⚠️ Yahoo Batch: Boş sonuç")
                return [:]
            }
            
            var quotes: [String: Quote] = [:]
            for r in results {
                // Orijinal sembolü bul (Yahoo sembolü farklı olabilir)
                let originalSymbol = symbols.first { 
                    SymbolResolver.shared.resolve($0, for: .yahoo) == r.symbol 
                } ?? r.symbol
                
                var q = Quote(
                    c: r.regularMarketPrice ?? 0,
                    d: r.regularMarketChange ?? 0,
                    dp: r.regularMarketChangePercent ?? 0,
                    currency: r.currency ?? "USD",
                    shortName: r.shortName,
                    symbol: originalSymbol
                )
                q.previousClose = r.regularMarketPreviousClose
                q.marketCap = r.marketCap
                quotes[originalSymbol] = q
            }
            
            print("✅ Yahoo Batch: \(quotes.count)/\(symbols.count) sembol alındı")
            return quotes
            
        } catch {
            print("❌ Yahoo Batch Decode Error: \(error)")
            throw error
        }
    }

    
    // MARK: - Helpers
    private func encodeYahooSymbolForPath(_ symbol: String) -> String {
        // Special handling for Yahoo Tickers with characters like ^, =, @
        // Standard .urlPathAllowed preserves some of these, but Yahoo expects strict percent-encoding for ^ and =.
        
        // 1. Map known problematic characters manually if needed, or use a custom set.
        // The user specifically requested ^ -> %5E and = -> %3D.
        
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "^=@") // Remove chars we want to force encode
        
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return symbol // Should rarely happen, fallback to raw
        }
        return encoded
    }
    
    // mapToYahooSymbol removed - logic moved to SymbolResolver.swift
    
    func fetchTopLosers(limit: Int = 5) async throws -> [(String, Quote)] {
        return try await fetchScreener(id: "day_losers", limit: limit)
    }
    
    func fetchTopGainers(limit: Int = 5) async throws -> [(String, Quote)] {
        return try await fetchScreener(id: "day_gainers", limit: limit)
    }
    
    func fetchMostActive(limit: Int = 5) async throws -> [(String, Quote)] {
        return try await fetchScreener(id: "most_actives", limit: limit)
    }
    
    private func fetchScreener(id: String, limit: Int) async throws -> [(String, Quote)] {
        // Try API First
        do {
             let urlString = "https://query2.finance.yahoo.com/v1/finance/screener/predefined/saved/screener/\(id)?count=\(limit)&scrIds=\(id)"
             guard let url = URL(string: urlString) else { throw URLError(.badURL) }
             
             let data = try await HeimdallNetwork.request(
                 url: url,
                 engine: .phoenix, // Screener is Phoenix engine
                 provider: .yahoo,
                 symbol: "SCREENER"
             )
             
             struct ScreenerResponse: Codable {
                 struct Finance: Codable {
                     struct Result: Codable {
                         struct QuoteItem: Codable {
                              let symbol: String
                              let regularMarketPrice: Double
                              let regularMarketChange: Double
                              let regularMarketChangePercent: Double
                              let regularMarketPreviousClose: Double?
                              let currency: String?
                              let shortName: String?
                         }
                         let quotes: [QuoteItem]
                     }
                     let result: [Result]
                 }
                 let finance: Finance
             }
             
             let resp = try JSONDecoder().decode(ScreenerResponse.self, from: data)
             guard let items = resp.finance.result.first?.quotes else { throw URLError(.badServerResponse) }
             
             return items.map { item in
                 var q = Quote(
                    c: item.regularMarketPrice,
                    d: item.regularMarketChange,
                    dp: item.regularMarketChangePercent,
                    currency: item.currency ?? "USD",
                    shortName: item.shortName ?? item.symbol,
                    symbol: item.symbol
                 )
                 q.previousClose = item.regularMarketPreviousClose
                 return (item.symbol, q)
             }
             
        } catch {
            print("⚠️ Phoenix: Yahoo Screener API failed (\(id)). Initiating Local Scan Fallback.")
            return await performLocalScan(type: id, limit: limit)
        }
    }
    
    // MARK: - Local Market Scanner (Phoenix Patch)
    private func performLocalScan(type: String, limit: Int) async -> [(String, Quote)] {
        // 1. Define Static Major Universe (The "Big Board")
        let universe = [
            "SPY", "QQQ", "IWM", "DIA", // Indices
            "AAPL", "MSFT", "NVDA", "AMZN", "GOOGL", "META", "TSLA", "AVGO", "COST", // Tech/Growth
            "JPM", "BAC", "V", "MA", // Finance
            "LLY", "JNJ", "UNH", "PFE", // Health
            "XOM", "CVX", // Energy
            "PG", "KO", "PEP", "WMT", // Consumer
            "BTC-USD", "ETH-USD" // Crypto
        ]
        
        // 2. Fetch Quotes in Parallel
        // We use a task group to fetch as many as possible without blocking
        var quotes: [(String, Quote)] = []
        
        await withTaskGroup(of: (String, Quote?).self) { group in
            for sym in universe {
                 group.addTask {
                     return (sym, try? await self.fetchQuote(symbol: sym))
                 }
            }
            
            for await (sym, q) in group {
                if let validQuote = q {
                    quotes.append((sym, validQuote))
                }
            }
        }
        
        // 3. Sort by Criteria
        switch type {
        case "day_gainers":
            quotes.sort { ($0.1.dp ?? 0) > ($1.1.dp ?? 0) }
        case "day_losers":
            quotes.sort { ($0.1.dp ?? 0) < ($1.1.dp ?? 0) }
        case "most_actives":
            // We don't have volume in Quote struct usually (it needs to be added or assumed).
            // Fallback: Sort by absolute Change % as proxy for volatility/activity
            quotes.sort { abs($0.1.dp ?? 0) > abs($1.1.dp ?? 0) }
        default:
            break
        }
        
        return Array(quotes.prefix(limit))
    }

    
    func fetchCandles(symbol: String, interval: String, outputSize: Int) async throws -> [Candle] {
        // Delegated to dedicated Adapter (Heimdall 4.0)
        let (candles, hash) = try await YahooCandleAdapter.shared.fetchCandles(symbol: symbol, timeframe: interval, limit: outputSize)
        
        // Context Propagation (Black Box V0)
        ArgusLedger.shared.cacheSnapshotRef(symbol: symbol, type: "CANDLES_OHLCV", hash: hash)
        
        return candles
    }
    func fetchNews(symbol: String) async throws -> [NewsArticle] {
        // Real news source (Google News RSS via YahooFinanceNewsProvider)
        return try await YahooFinanceNewsProvider.shared.fetchNews(symbol: symbol, limit: 12)
    }
    
    // MARK: - Heimdall Protocol Adapters
    
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] {
        // Map "1d" -> "1day", "15m" -> "15min" for internal method
        let internalInterval: String
        switch timeframe {
        case "1d": internalInterval = "1day"
        case "1h": internalInterval = "1hour"
        case "1m": internalInterval = "1min"
        default: internalInterval = timeframe
        }
        return try await fetchCandles(symbol: symbol, interval: internalInterval, outputSize: limit)
    }
    
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] {
        let items: [(String, Quote)]
        switch type {
        case .gainers: items = try await fetchTopGainers(limit: limit)
        case .losers: items = try await fetchTopLosers(limit: limit)
        case .mostActive: items = try await fetchMostActive(limit: limit)
        case .etf: throw URLError(.unsupportedURL)
        }
        return items.map { $0.1 }
    }
    
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator {
        // Map generic macro symbols to Yahoo Tickers
        let ySymbol: String
        switch symbol {
        case "VIX": ySymbol = "^VIX"
        case "DXY": ySymbol = "DX-Y.NYB"
        case "US10Y": ySymbol = "^TNX"
        default: ySymbol = symbol
        }
        
        let q = try await fetchQuote(symbol: ySymbol)
        return HeimdallMacroIndicator(
            symbol: symbol,
            value: q.c,
            change: q.d,
            changePercent: q.dp,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Atlas: Real Fundamentals Implementation
    
    func fetchFundamentals(symbol: String) async throws -> FinancialsData {
        // Retry wrapper for 401 handling
        do {
            return try await _fetchFundamentalsInternal(symbol: symbol, isRetry: false)
        } catch {
            // Check if it's a 401 error (Invalid Crumb)
            if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                print("🔐 Yahoo: 401 detected. Invalidating crumb...")
                await YahooAuthenticationService.shared.invalidate()
                // Brief pause before retry to avoid hammering
                try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) 
                return try await _fetchFundamentalsInternal(symbol: symbol, isRetry: true)
            }
            throw error
        }
    }
    
    private func _fetchFundamentalsInternal(symbol: String, isRetry: Bool) async throws -> FinancialsData {
        // Keep fundamentals lookup consistent with quote/candle symbol mapping.
        // This prevents Atlas failures for aliases and BIST symbols without `.IS`.
        let ySymbol = SymbolResolver.shared.resolve(symbol, for: .yahoo)
        let encoded = encodeYahooSymbolForPath(ySymbol)
        
        // 1. Authenticate (Get Crumb & Cookie) to Fix 401
        let (crumb, cookie) = try await YahooAuthenticationService.shared.getCrumb()
        
        // The Real "Atlas" Modules
        let modules = "assetProfile,financialData,defaultKeyStatistics,balanceSheetHistory,incomeStatementHistory,cashflowStatementHistory,earnings"
        let urlString = "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(encoded)?modules=\(modules)&crumb=\(crumb)"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Use HeimdallNetwork with Authenticated Request
        var request = URLRequest(url: url)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        
        let data = try await HeimdallNetwork.request(
            url: url,
            engine: .atlas,
            provider: .yahoo,
            symbol: symbol,
            explicitRequest: request
        )
        
        // Internal Decodable Structs for QuoteSummary (Yahoo v10)
        struct QSResponse: Codable {
            struct QuoteSummary: Codable {
                struct Result: Codable {
                    struct ValidDouble: Codable { let raw: Double? }
                    
                    struct FinancialData: Codable {
                        let totalRevenue: ValidDouble?
                        let ebitda: ValidDouble?
                        let totalCash: ValidDouble?
                        let totalDebt: ValidDouble?
                        let revenueGrowth: ValidDouble?
                        let earningsGrowth: ValidDouble?
                        let freeCashflow: ValidDouble?
                        let marketCapitalization: ValidDouble?
                        
                        // Analyst Expectations
                        let targetMeanPrice: ValidDouble?
                        let targetHighPrice: ValidDouble?
                        let targetLowPrice: ValidDouble?
                        let recommendationMean: ValidDouble?  // 1.0=Strong Buy, 5.0=Sell
                        let numberOfAnalystOpinions: ValidDouble?
                    }
                    
                    struct DefaultKeyStatistics: Codable {
                        let forwardPE: ValidDouble?
                        let trailingPE: ValidDouble?
                        let priceToBook: ValidDouble?
                        let enterpriseToEbitda: ValidDouble?
                        let beta: ValidDouble?
                        let enterpriseValue: ValidDouble? // Added
                    }
                    
                    struct AssetProfile: Codable {
                        let currency: String?
                        let sector: String?
                    }
                    
                    struct History: Codable {
                        struct Item: Codable {
                            let endDate: ValidDouble?
                            let totalRevenue: ValidDouble?
                            let netIncome: ValidDouble?
                            let totalStockholderEquity: ValidDouble?
                            let operatingCashflow: ValidDouble?
                            let capitalExpenditures: ValidDouble?
                            let longTermDebt: ValidDouble?
                            let shortLongTermDebt: ValidDouble?
                        }
                        let incomeStatementHistory: [Item]?
                        let balanceSheetHistory: [Item]?
                        let cashflowStatementHistory: [Item]?
                    }
                    
                    struct SummaryDetail: Codable {
                         let marketCap: ValidDouble?
                         let dividendYield: ValidDouble?
                         let trailingPE: ValidDouble?
                    }
                    
                    let financialData: FinancialData?
                    let defaultKeyStatistics: DefaultKeyStatistics?
                    let summaryDetail: SummaryDetail? // Added
                    let assetProfile: AssetProfile?
                    let incomeStatementHistory: History?
                    let balanceSheetHistory: History?
                    let cashflowStatementHistory: History?
                }
                let result: [Result]?
                let error: String? // Or complicated object
            }
            let quoteSummary: QuoteSummary
        }
        
        let resp = try JSONDecoder().decode(QSResponse.self, from: data)
        guard let res = resp.quoteSummary.result?.first else {
            print("🔍 ATLAS AUDIT: \(symbol) -> Empty Result")
            throw URLError(.resourceUnavailable)
        }
        
        // --- 🔍 ATLAS AUDIT LOG (Minimal) ---
        // print("\n=== 🔍 ATLAS AUDIT: \(symbol) ===")
        // Only log if critical modules are missing
        if res.financialData == nil {
             print("⚠️ Yahoo/Atlas: Missing financialData for \(symbol)")
        }
        // ---------------------------
        
        let fin = res.financialData
        let stats = res.defaultKeyStatistics
        let profile = res.assetProfile
        let income = res.incomeStatementHistory?.incomeStatementHistory ?? []
        let balance = res.balanceSheetHistory?.balanceSheetHistory ?? []
        let cash = res.cashflowStatementHistory?.cashflowStatementHistory ?? []
        
        let lastIncome = income.first
        let lastBalance = balance.first
        let lastCash = cash.first // Yahoo returns Newest First usually
        
        // Critical Checks
        let totalRev = fin?.totalRevenue?.raw ?? lastIncome?.totalRevenue?.raw
        let netInc = lastIncome?.netIncome?.raw
        
        // Forward Growth estimate
        let revGrowth = fin?.revenueGrowth?.raw ?? 0
        let earnGrowth = fin?.earningsGrowth?.raw ?? 0
        let fwdGrowth = (revGrowth + earnGrowth) / 2.0 * 100.0
        
        // Helper to simplify complex init
        let revHistory = income.prefix(4).compactMap { $0.totalRevenue?.raw }
        let netIncHistory = income.prefix(4).compactMap { $0.netIncome?.raw }
        
        // --- FALLBACK LOGIC (The "MacGyver" Patch) ---
        // 1. Equity Fallback: If Balance Sheet is empty, use Market Cap / PriceToBook
        var finalEquity = lastBalance?.totalStockholderEquity?.raw
        let summary = res.summaryDetail
        
        if finalEquity == nil {
            if let mCap = summary?.marketCap?.raw ?? stats?.enterpriseValue?.raw, // Use SummaryDetail MarketCap
               let pb = stats?.priceToBook?.raw, pb > 0 {
                finalEquity = mCap / pb
                print("🔧 YahooProvider: Derived Equity from P/B (\(Int(finalEquity!)))")
            }
        }
        
        // 2. Cash Flow Fallback: If Cashflow Statement is empty, use FCF + CapEx
        var finalOpCash = lastCash?.operatingCashflow?.raw
        let capEx = lastCash?.capitalExpenditures?.raw
        if finalOpCash == nil, let fcf = fin?.freeCashflow?.raw {
            // FCF = OpCash - CapEx  =>  OpCash = FCF + CapEx
            // If CapEx is unknown, assume 0 for approximation (better than nil)
            finalOpCash = fcf + (capEx ?? 0)
            print("🔧 YahooProvider: Derived OpCash from FCF (\(Int(finalOpCash!)))")
        }
        
        // 3. Market Cap Fallback to "summaryDetail" if missing in "financialData"
        // (Note: `financialData` doesn't have marketCap in struct above, `assetProfile`? No `summaryDetail`)
        // The inline struct defined `FinancialData` with `totalRevenue` etc but `SummaryDetail` struct is missing in the bottom method!
        // Wait, looking at struct definition in Lines 353+:
        // DefaultKeyStatistics has `enterpriseValue`.
        // SummaryDetail is NOT defined in `QSResponse.QuoteSummary.Result`.
        // This is a BUG. `marketCap` is usually in `summaryDetail` or `price` module.
        // I need to add `summaryDetail` to the struct to get Market Cap properly.
        
        return FinancialsData(
            symbol: symbol,
            currency: profile?.currency ?? "USD",
            lastUpdated: Date(),
            totalRevenue: totalRev,
            netIncome: netInc,
            totalShareholderEquity: finalEquity,
            marketCap: summary?.marketCap?.raw,
            revenueHistory: revHistory,
            netIncomeHistory: netIncHistory,
            ebitda: fin?.ebitda?.raw,
            shortTermDebt: lastBalance?.shortLongTermDebt?.raw,
            longTermDebt: lastBalance?.longTermDebt?.raw,
            operatingCashflow: finalOpCash,
            capitalExpenditures: capEx,
            cashAndCashEquivalents: fin?.totalCash?.raw,
            peRatio: stats?.trailingPE?.raw ?? summary?.trailingPE?.raw,
            forwardPERatio: stats?.forwardPE?.raw,
            priceToBook: stats?.priceToBook?.raw,
            evToEbitda: stats?.enterpriseToEbitda?.raw,
            dividendYield: summary?.dividendYield?.raw, 
            forwardGrowthEstimate: fwdGrowth,
            isETF: profile?.sector?.contains("ETF") ?? false,
            // Extended Metrics for Atlas Council
            grossMargin: nil, // Yahoo financialData doesn't have this
            operatingMargin: nil,
            profitMargin: calculateProfitMargin(netIncome: netInc, revenue: totalRev),
            returnOnEquity: calculateROE(netIncome: netInc, equity: finalEquity),
            returnOnAssets: nil,
            debtToEquity: calculateDebtToEquity(shortDebt: lastBalance?.shortLongTermDebt?.raw, longDebt: lastBalance?.longTermDebt?.raw, equity: finalEquity),
            currentRatio: nil,
            freeCashFlow: fin?.freeCashflow?.raw,
            enterpriseValue: stats?.enterpriseValue?.raw,
            pegRatio: nil,
            priceToSales: nil,
            revenueGrowth: (fin?.revenueGrowth?.raw ?? 0) * 100, // Convert to percentage
            earningsGrowth: (fin?.earningsGrowth?.raw ?? 0) * 100,
            targetMeanPrice: fin?.targetMeanPrice?.raw,
            targetHighPrice: fin?.targetHighPrice?.raw,
            targetLowPrice: fin?.targetLowPrice?.raw,
            recommendationMean: fin?.recommendationMean?.raw,
            numberOfAnalystOpinions: Int(fin?.numberOfAnalystOpinions?.raw ?? 0)
        )
    }
    
    // MARK: - Helper Calculations for Extended Metrics
    private func calculateROE(netIncome: Double?, equity: Double?) -> Double? {
        guard let ni = netIncome, let eq = equity, eq > 0 else { return nil }
        return (ni / eq) * 100
    }
    
    private func calculateProfitMargin(netIncome: Double?, revenue: Double?) -> Double? {
        guard let ni = netIncome, let rev = revenue, rev > 0 else { return nil }
        return (ni / rev) * 100
    }
    
    private func calculateDebtToEquity(shortDebt: Double?, longDebt: Double?, equity: Double?) -> Double? {
        guard let eq = equity, eq > 0 else { return nil }
        let totalDebt = (shortDebt ?? 0) + (longDebt ?? 0)
        return totalDebt / eq
    }
}
