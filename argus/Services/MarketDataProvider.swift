import Foundation
import Combine

// MARK: - Data Health Report (Inline)
enum DataHealthStatus: String {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case unhealthy = "Unhealthy"
}

struct DataHealthReport {
    var timestamp: Date
    var overallStatus: DataHealthStatus
    var apiLatency: Double
    var dataFreshness: Double
    var activeProvider: String
    var errors: [String]
}

/// "The Hydra" - Legacy Provider Manager -> Streaming Engine
/// Refactored to be a Streaming-Only Service. Data is pushed to MarketDataStore.
/// Fetch logic has moved to MarketDataStore (SSoT).
class MarketDataProvider: ObservableObject {
    static let shared = MarketDataProvider()
    
    // MARK: - Services (Heads of the Hydra)
    private let twelveData = TwelveDataService.shared
    
    // MARK: - Streaming Publisher
    // We keep this for now to avoid breaking too many listeners, 
    // but ideally listeners should observe MarketDataStore.
    let priceUpdate = PassthroughSubject<Quote, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - State
    @Published var dataHealth = DataHealthReport(
        timestamp: Date(),
        overallStatus: .healthy,
        apiLatency: 0,
        dataFreshness: 0,
        activeProvider: "Twelve Data",
        errors: []
    )
    
    private init() {
        setupStreaming()
    }
    
    // MARK: - Streaming Logic
    
    private func setupStreaming() {
        // Primary: Twelve Data
        twelveData.priceUpdate
            .sink { [weak self] quote in
                self?.handleIncomingStream(quote, source: "Twelve Data (Stream)")
            }
            .store(in: &cancellables)
    }
    
    private func handleIncomingStream(_ quote: Quote, source: String) {
        // K4 fail-closed: timestamp yoksa veya 15s'den eskiyse güncelleme yap.
        // Motive: timestamp=nil Date(0) default'u "her zaman taze" gibi davranıyordu;
        // sessiz stale tick'leri SSoT'ye yazıp trigger'ları tetikliyordu.
        guard let ts = quote.timestamp, Date().timeIntervalSince(ts) <= 15 else {
            return
        }
        
        // 1. Update Internal Publisher (Legacy)
        DispatchQueue.main.async {
            self.priceUpdate.send(quote)
            self.dataHealth.activeProvider = source
            self.dataHealth.dataFreshness = 0
            
            // 2. PUSH TO SSOT (Unified Store)
            // This ensures anyone observing the Store gets the update
            Task { @MainActor in
                MarketDataStore.shared.injectLiveQuote(quote, source: source)
            }
        }
    }
    
    func connectStream(symbols: [String]) {
        twelveData.subscribe(symbols: symbols)
    }
    
    // MARK: - DEPRECATED / REMOVED METHODS
    // These methods have been moved to MarketDataStore or HeimdallOrchestrator to ensure SSoT.
    // Leaving Stubs/Deprecations if needed, but for "Senior Architect" refactor we clean them up.
    // If strict compilation is required, we might need these to prevent build errors until ViewModel is fixed.
    // I will REMOVE them and fix the errors in ViewModel.
    
    // MARK: - Yahoo Search Implementation
    private struct YahooSearchResponse: Codable {
        let quotes: [YahooSearchResult]
    }
    private struct YahooSearchResult: Codable {
        let symbol: String
        let shortname: String?
        let longname: String?
        let typeDisp: String?
        let exchange: String?
    }

    func searchSymbols(query: String) async throws -> [SearchResult] {
        let urlString = "https://query1.finance.yahoo.com/v1/finance/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: urlString) else { return [] }

        // Y2: timeout + explicit status guard. Yahoo rate-limit durumunda 429/401
        // dönüp boş JSON gönderebiliyor; decode başarılı ama liste boş görünüyor ve
        // kullanıcı "arama bozuk" mu, "sonuç yok" mu ayırt edemiyordu.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "Yahoo search HTTP \(code)"
            ])
        }

        let decoded = try JSONDecoder().decode(YahooSearchResponse.self, from: data)

        return decoded.quotes.map { q in
            SearchResult(
                symbol: q.symbol,
                description: q.longname ?? q.shortname ?? q.symbol
            )
        }
    }
    
    // Helper to evaluate health (Pure Logic)
    func evaluateDataHealth(symbol: String) async -> DataHealth {
        var h = DataHealth(symbol: symbol)
        h.technical = CoverageComponent.present(quality: 0.5)
        return h
    }
}
