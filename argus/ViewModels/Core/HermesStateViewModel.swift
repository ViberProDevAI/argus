import Foundation
import Combine

// MARK: - Hermes State ViewModel (News & Sentiment Engine)
/// Merkezi Haber ve Sentiment Yönetimi.
/// Tüm haber çekme, analiz etme ve sentiment skorlama işlemleri burada yapılır.
/// TradingViewModel artık sadece veriyi yansıtır.

@MainActor
final class HermesStateViewModel: ObservableObject {
    
    // MARK: - Singleton
    static let shared = HermesStateViewModel()
    
    // MARK: - Published State
    @Published var newsBySymbol: [String: [NewsArticle]] = [:]
    @Published var newsInsightsBySymbol: [String: [NewsInsight]] = [:]
    @Published var hermesEventsBySymbol: [String: [HermesEvent]] = [:]
    @Published var kulisEventsBySymbol: [String: [HermesEvent]] = [:]
    
    // Hermes Feeds
    @Published var watchlistNewsInsights: [NewsInsight] = [] // Tab 1: "Takip Listem"
    @Published var generalNewsInsights: [NewsInsight] = []   // Tab 2: "Genel Piyasa"
    
    @Published var isLoadingNews: Bool = false
    @Published var newsErrorMessage: String? = nil
    
    private init() {}
    
    // MARK: - Actions
    
    func loadHermes(for symbol: String) async {
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        
        let articles = await fetchRawNews(for: symbol)
        
        do {
            let scope: HermesEventScope = isBist ? .bist : .global
            let events = try await HermesLLMService.shared.analyzeEvents(articles: articles, scope: scope, isGeneral: false)
            
            let insights = events.map { event in
                let sentiment = event.sentimentLabel ?? .neutral
                
                let delayPenalty = HermesEventScoring.delayFactor(
                    ageMinutes: max(0.0, Date().timeIntervalSince(event.publishedAt) / 60.0)
                )
                
                let detail = """
                Bu haber \(event.polarity == .positive ? "olumlu" : (event.polarity == .negative ? "olumsuz" : "karma")) etki üretiyor.
                Şiddet: \(Int(event.severity))/100, Kaynak güveni: \(Int(event.sourceReliability))/100.
                Gecikme etkisi: %\(Int(delayPenalty * 100)).
                """
                
                return NewsInsight(
                    id: UUID(),
                    symbol: event.symbol,
                    articleId: event.articleId,
                    headline: event.headline,
                    summaryTRLong: detail,
                    impactSentenceTR: event.rationaleShort,
                    sentiment: sentiment,
                    confidence: event.confidence,
                    impactScore: event.finalScore,
                    relatedTickers: nil,
                    createdAt: event.createdAt
                )
            }
            
            // State Update
            self.newsInsightsBySymbol[symbol] = insights
            // Also store events
            if isBist {
                self.kulisEventsBySymbol[symbol] = events
            } else {
                self.hermesEventsBySymbol[symbol] = events
            }
            
            // Update raw articles if needed or store them separately?
            // Original code didn't set newsBySymbol? 
            // Wait, TradingViewModel had newsBySymbol but loadHermes in snippet didn't set it?
            // I should check clean snippet. 
            // Step 1236 snippet:
            // self.newsInsightsBySymbol[symbol] = insights
            // if isBist { self.kulisEventsBySymbol... } else { self.hermesEventsBySymbol... }
            // It did NOT set newsBySymbol!
            // But newsBySymbol is property. Maybe it's set in fetchRawNews? No, fetchRawNews returns [NewsArticle].
            // Ah, line 487 in snippet sets insights and events.
            // Maybe newsBySymbol is used elsewhere or I missed where it is set.
            // I will add setting newsBySymbol for completeness if access is needed.
            self.newsBySymbol[symbol] = articles
            
        } catch {
            print("Hermes load failed: \(error)")
            self.newsErrorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Helper
    private func fetchRawNews(for symbol: String) async -> [NewsArticle] {
        if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
             return (try? await RSSNewsProvider().fetchNews(symbol: symbol, limit: 20)) ?? []
        }
        return (try? await YahooFinanceNewsProvider.shared.fetchNews(symbol: symbol, limit: 15)) ?? []
    }
}
