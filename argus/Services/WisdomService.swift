import Foundation

final class WisdomService {
    static let shared = WisdomService()
    private var quotes: [WisdomQuote] = []
    
    private init() {
        loadQuotes()
    }
    
    private func loadQuotes() {
        guard let url = Bundle.main.url(forResource: "wisdom_quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WisdomQuote].self, from: data) else {
            quotes = defaultQuotes
            return
        }
        quotes = decoded
    }
    
    func getQuote(for action: ArgusAction) -> WisdomQuote? {
        quotes.randomElement()
    }
    
    func getDailyQuote() -> WisdomQuote? {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        guard !quotes.isEmpty else { return defaultQuotes.first }
        return quotes[dayOfYear % quotes.count]
    }
    
    private var defaultQuotes: [WisdomQuote] {
        [
            WisdomQuote(quote: "Piyasada en tehlikeli dort kelime: Bu sefer farkli.", author: "John Templeton", category: "risk"),
            WisdomQuote(quote: "Korku ve acgozluluk arasindaki dengeyi bul.", author: "Warren Buffett", category: "psychology"),
            WisdomQuote(quote: "Sabir, yatirimcinin en buyuk erdemidir.", author: "Benjamin Graham", category: "patience")
        ]
    }
}
