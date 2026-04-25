import Foundation

/// Provider for Options Data via Massive API
actor MassiveProvider: HeimdallProvider {
    static let shared = MassiveProvider()
    
    nonisolated let name = "Massive"
    nonisolated let capabilities: [HeimdallDataField] = [.options]
    
    private let baseURL = "https://api.massive.com/v1"
    private var token: String { APIKeyStore.shared.massiveToken }
    
    private init() {}
    
    // MARK: - HeimdallProvider Implementation
    
    func fetchOptions(symbol: String) async throws -> OptionsChain {
        let endpoint = "\(baseURL)/chains/\(symbol)"
        
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                throw URLError(.userAuthenticationRequired)
            }
            throw URLError(.badServerResponse)
        }
        
        do {
            let massiveResponse = try JSONDecoder().decode(MassiveChainResponse.self, from: data)
            return mapToCanonical(massiveResponse, symbol: symbol)
        } catch {
            print("❌ Massive Decode Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Mapper
    
    private func mapToCanonical(_ response: MassiveChainResponse, symbol: String) -> OptionsChain {
        var calls: [OptionContract] = []
        var puts: [OptionContract] = []
        var strikes: Set<Double> = []
        var expirations: Set<String> = []
        
        for opt in response.options {
            strikes.insert(opt.strike)
            expirations.insert(opt.expiry)
            
            let contract = OptionContract(
                contractSymbol: opt.symbol,
                strike: opt.strike,
                currency: "USD",
                lastPrice: opt.last,
                change: 0, // Not provided in simple endpoint
                percentChange: 0,
                volume: opt.vol,
                openInterest: opt.open_int,
                bid: 0,
                ask: 0,
                impliedVolatility: opt.iv ?? 0,
                inTheMoney: false, // Calc logic could be added
                contractSize: "100",
                expiration: opt.expiry,
                delta: nil, // Greeks require separate endpoint or calculation
                gamma: nil,
                theta: nil,
                vega: nil,
                rho: nil
            )
            
            if opt.type == "call" {
                calls.append(contract)
            } else {
                puts.append(contract)
            }
        }
        
        return OptionsChain(
            symbol: symbol,
            underlyingPrice: response.price,
            expirationDates: Array(expirations).sorted(),
            strikes: Array(strikes).sorted(),
            calls: calls,
            puts: puts,
            timestamp: Date()
        )
    }
    
    // Unsupported Methods
    func fetchQuote(symbol: String) async throws -> Quote { throw URLError(.unsupportedURL) }
    func fetchCandles(symbol: String, timeframe: String, limit: Int) async throws -> [Candle] { throw URLError(.unsupportedURL) }
    func fetchFundamentals(symbol: String) async throws -> FinancialsData { throw URLError(.unsupportedURL) }
    func fetchProfile(symbol: String) async throws -> AssetProfile { throw URLError(.unsupportedURL) }
    func fetchNews(symbol: String) async throws -> [NewsArticle] { throw URLError(.unsupportedURL) }
    func fetchMacro(symbol: String) async throws -> HeimdallMacroIndicator { throw URLError(.unsupportedURL) }
    func fetchScreener(type: ScreenerType, limit: Int) async throws -> [Quote] { throw URLError(.unsupportedURL) }
}
