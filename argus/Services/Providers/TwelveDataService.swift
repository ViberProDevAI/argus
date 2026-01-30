import Foundation
import Combine

/// Primary Provider for Streaming & Quotes (The Hydra: Head A)
/// Primary Provider for Streaming & Quotes (The Hydra: Head A)
final class TwelveDataService: NSObject, HeimdallProvider, @unchecked Sendable {
    static let shared = TwelveDataService()
    var name: String { "TwelveData" }
    
    var capabilities: [HeimdallDataField] {
        return [.quote, .candles, .fundamentals]
    }
    
    private let baseURL = "https://api.twelvedata.com"
    private let socketURL = URL(string: "wss://ws.twelvedata.com/v1/quotes?apikey=\(Secrets.shared.twelveData)")!
    
    // WebSocket State
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var subscriptions: Set<String> = []
    
    // Publishers
    let priceUpdate = PassthroughSubject<Quote, Never>()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Fundamentals (Atlas)
    func fetchFundamentals(symbol: String) async throws -> FinancialsData {
        let apiKey = Secrets.shared.twelveData
        // Using `statistics` endpoint for key ratios
        let urlString = "\(baseURL)/statistics?symbol=\(symbol)&apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let data = try await HeimdallNetwork.request(url: url, engine: .atlas, provider: .twelvedata, symbol: symbol)
        
        // Comprehensive mapping for TwelveData Statistics
        struct TDStatsResponse: Codable {
            struct Meta: Codable {
                let symbol: String?
                let name: String?
                let currency: String?
            }
            struct Statistics: Codable {
                struct Valuations: Codable {
                    let market_capitalization: Double?
                    let enterprise_value: Double?
                    let trailing_pe: Double?
                    let forward_pe: Double?
                    let peg_ratio: Double?
                    let price_to_sales_ttm: Double?
                    let price_to_book_mrq: Double?
                    let enterprise_to_revenue: Double?
                    let enterprise_to_ebitda: Double?
                }
                struct Financials: Codable {
                    let fiscal_year_ends: String?
                    let most_recent_quarter: String?
                    let gross_margin: Double?
                    let profit_margin: Double?
                    let operating_margin: Double?
                    let return_on_assets_ttm: Double?
                    let return_on_equity_ttm: Double?
                    struct IncomeStatement: Codable {
                        let revenue_ttm: Double?
                        let revenue_per_share_ttm: Double?
                        let quarterly_revenue_growth: Double?
                        let gross_profit_ttm: Double?
                        let ebitda: Double?
                        let net_income_to_common_ttm: Double?
                        let diluted_eps_ttm: Double?
                        let quarterly_earnings_growth_yoy: Double?
                    }
                    struct BalanceSheet: Codable {
                        let total_cash_mrq: Double?
                        let total_cash_per_share_mrq: Double?
                        let total_debt_mrq: Double?
                        let total_debt_to_equity_mrq: Double?
                        let current_ratio_mrq: Double?
                        let book_value_per_share_mrq: Double?
                    }
                    struct CashFlow: Codable {
                        let operating_cash_flow_ttm: Double?
                        let levered_free_cash_flow_ttm: Double?
                    }
                    let income_statement: IncomeStatement?
                    let balance_sheet: BalanceSheet?
                    let cash_flow: CashFlow?
                }
                struct DividendsAndSplits: Codable {
                    let forward_annual_dividend_rate: Double?
                    let forward_annual_dividend_yield: Double?
                    let trailing_annual_dividend_rate: Double?
                    let trailing_annual_dividend_yield: Double?
                    let payout_ratio: Double?
                }
                let valuations_metrics: Valuations?
                let financials: Financials?
                let dividends_and_splits: DividendsAndSplits?
            }
            let meta: Meta?
            let statistics: Statistics?
            let status: String?
            let message: String?
        }
        
        let res = try JSONDecoder().decode(TDStatsResponse.self, from: data)
        
        // Check for error response
        if res.status == "error" {
            print("❌ TwelveData Statistics Error: \(res.message ?? "Unknown")")
            throw URLError(.cannotParseResponse)
        }
        
        let v = res.statistics?.valuations_metrics
        let f = res.statistics?.financials
        let d = res.statistics?.dividends_and_splits
        let inc = f?.income_statement
        let bal = f?.balance_sheet
        let cf = f?.cash_flow
        
        return FinancialsData(
            symbol: symbol,
            currency: res.meta?.currency ?? "USD",
            lastUpdated: Date(),
            totalRevenue: inc?.revenue_ttm,
            netIncome: inc?.net_income_to_common_ttm,
            totalShareholderEquity: nil, // Not directly provided
            marketCap: v?.market_capitalization,
            revenueHistory: [],
            netIncomeHistory: [],
            ebitda: inc?.ebitda,
            shortTermDebt: nil,
            longTermDebt: bal?.total_debt_mrq,
            operatingCashflow: cf?.operating_cash_flow_ttm,
            capitalExpenditures: nil,
            cashAndCashEquivalents: bal?.total_cash_mrq,
            peRatio: v?.trailing_pe,
            forwardPERatio: v?.forward_pe,
            priceToBook: v?.price_to_book_mrq,
            evToEbitda: v?.enterprise_to_ebitda,
            dividendYield: d?.forward_annual_dividend_yield,
            forwardGrowthEstimate: inc?.quarterly_revenue_growth,
            isETF: false,
            // Extended fields for Atlas scoring
            grossMargin: f?.gross_margin,
            operatingMargin: f?.operating_margin,
            profitMargin: f?.profit_margin,
            returnOnEquity: f?.return_on_equity_ttm,
            returnOnAssets: f?.return_on_assets_ttm,
            debtToEquity: bal?.total_debt_to_equity_mrq,
            currentRatio: bal?.current_ratio_mrq,
            freeCashFlow: cf?.levered_free_cash_flow_ttm,
            enterpriseValue: v?.enterprise_value,
            pegRatio: v?.peg_ratio,
            priceToSales: v?.price_to_sales_ttm,
            revenueGrowth: inc?.quarterly_revenue_growth,
            earningsGrowth: inc?.quarterly_earnings_growth_yoy,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            numberOfAnalystOpinions: nil
        )
    }
    
    // MARK: - Quote (REST)
    func fetchQuote(symbol: String) async throws -> Quote {
        let apiKey = Secrets.shared.twelveData
        let urlString = "\(baseURL)/quote?symbol=\(symbol)&apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let data = try await HeimdallNetwork.request(url: url, engine: .market, provider: .twelvedata, symbol: symbol)
        
        struct TDQuote: Codable {
            let close: String
            let change: String
            let percent_change: String
            let currency: String?
            let timestamp: Int?
            let previous_close: String? // New
        }
        
        let q = try JSONDecoder().decode(TDQuote.self, from: data)
        guard let c = Double(q.close), let d = Double(q.change), let dp = Double(q.percent_change.replacingOccurrences(of: "%", with: "")) else {
            throw URLError(.cannotParseResponse)
        }
        
        var quote = Quote(c: c, d: d, dp: dp, currency: q.currency ?? "USD")
        
        if let pcStr = q.previous_close, let pc = Double(pcStr) {
            quote.previousClose = pc
        }
        
        quote.timestamp = Date() // Fresh fetch
        return quote
    }
    
    // MARK: - WebSocket (Live Streaming)
    
    func connect() {
        guard !isConnected else { return }
        print("🔌 TwelveData: Connecting...")
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: socketURL)
        webSocketTask?.resume()
        
        listen()
    }
    
    func subscribe(symbols: [String]) {
        if !isConnected { connect() }
        
        // Filter new
        let newSymbols = symbols.filter { !subscriptions.contains($0) }
        guard !newSymbols.isEmpty else { return }
        
        for s in newSymbols { subscriptions.insert(s) }
        
        // Send Subscribe Message
        // Format: { "action": "subscribe", "params": { "symbols": "AAPL,BTC/USD" } }
        let joined = newSymbols.joined(separator: ",")
        let msg = """
        {
            "action": "subscribe",
            "params": {
                "symbols": "\(joined)"
            }
        }
        """
        sendMessage(msg)
    }
    
    private func sendMessage(_ text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("❌ TwelveData Send Error: \(error)")
            }
        }
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("❌ TwelveData: Receive Error \(error)")
                self.isConnected = false
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                default: break
                }
                self.listen()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        // TD Returns: {"event":"price","symbol":"AAPL","currency":"USD","exchange":"NASDAQ","type":"Common Stock","timestamp":167...,"price":150.0,"day_volume":...}
        // Or heartbeat
        guard let data = text.data(using: .utf8) else { return }
        
        // Generic parse
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let event = json["event"] as? String {
                
                if event == "price" {
                    if let sym = json["symbol"] as? String,
                       let price = json["price"] as? Double { // TD sometimes sends numbers, sometimes strings? API docs say number for price event usually, but let's check.
                        
                        // Wait, check standard response. Sometimes price is number.
                        // If parsing fails, ignore.
                        
                        let q = Quote(
                            c: price,
                            d: 0, // Stream doesn't always send change, ViewModel calculates diff
                            dp: 0,
                            currency: json["currency"] as? String,
                            shortName: sym,
                            symbol: sym
                        )
                        // q.timestamp = ...
                        
                        DispatchQueue.main.async {
                            self.priceUpdate.send(q)
                        }
                    }
                } else if event == "heartbeat" {
                    // print("💓")
                }
            }
        } catch {
            print("Parser error: \(text)")
        }
    }
    
    // MARK: - Candles
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] {
        // Map interval
        // TD: 1min, 5min, 15min, 30min, 45min, 1h, 2h, 4h, 1day, 1week, 1month
        let tdInterval: String
        let interval = timeframe // Map param
        let outputSize = limit // Map param
        
        if interval.contains("hour") { tdInterval = "1h" }
        else if interval.contains("week") { tdInterval = "1week" }
        else if interval.contains("month") { tdInterval = "1month" }
        else { tdInterval = "1day" }
        
        let apiKey = Secrets.shared.twelveData
        let urlString = "\(baseURL)/time_series?symbol=\(symbol)&interval=\(tdInterval)&outputsize=\(outputSize)&apikey=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let data = try await HeimdallNetwork.request(url: url, engine: .market, provider: .twelvedata, symbol: symbol)
        
        struct TDCandleResp: Codable {
            struct Val: Codable {
                let datetime: String
                let open: String
                let high: String
                let low: String
                let close: String
                let volume: String
            }
            let values: [Val]?
            let status: String
            let message: String?
        }
        
        let resp = try JSONDecoder().decode(TDCandleResp.self, from: data)
        if resp.status == "error" || resp.values == nil {
            let msg = resp.message ?? "Unknown Error"
            print("❌ TwelveData: \(msg)")
            
            // Rate Limit Detection
            // "You have reached your request limit" or similar
            if msg.lowercased().contains("limit") {
                 // Trigger Circuit Breaker for 60s (via Orchestrator handling this error)
                 throw HeimdallCoreError(category: .rateLimited, code: 429, message: msg, bodyPrefix: "")
            }
            
            throw URLError(.cannotParseResponse) 
        }
        
        // Parse dates
        let formatter = DateFormatter()
        // TD sometimes returns HH:mm:ss for intraday?
        // Fallback or complex parser needed. For now assume daily.
        if tdInterval == "1day" || tdInterval == "1week" || tdInterval == "1month" {
             formatter.dateFormat = "yyyy-MM-dd"
        } else {
             formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        
        guard let values = resp.values else { return [] }

        let result: [Candle] = values.compactMap { v -> Candle? in
            guard let d = formatter.date(from: v.datetime),
                  let o = Double(v.open),
                  let h = Double(v.high),
                  let l = Double(v.low),
                  let c = Double(v.close),
                  let vol = Double(v.volume) else { return nil }
            
            return Candle(date: d, open: o, high: h, low: l, close: c, volume: vol)
        }
        
        return result.reversed() // TD returns newest first
    }
}

extension TwelveDataService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("🔌 TwelveData: Connected!")
        isConnected = true
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 TwelveData: Closed.")
        isConnected = false
    }
}
