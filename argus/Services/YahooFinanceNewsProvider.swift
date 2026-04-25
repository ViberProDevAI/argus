import Foundation

/// Fetches real news from Google News RSS feeds.
/// Supports both Global (English) and BIST (Turkish) news automatically based on symbol.
final class YahooFinanceNewsProvider: NewsProvider {
    static let shared = YahooFinanceNewsProvider()
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle] {
        // Semantic Routing: GLOBAL vs BIST
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        // Clean Symbol for Query (Remove .IS for search)
        let query = symbol.replacingOccurrences(of: ".IS", with: "")
        
        // Construct Google News RSS URL
        // Global: English (US)
        // BIST: Turkish (TR)
        let baseUrl = "https://news.google.com/rss/search"
        let langParams = isBist ? "hl=tr-TR&gl=TR&ceid=TR:tr" : "hl=en-US&gl=US&ceid=US:en"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        guard let url = URL(string: "\(baseUrl)?q=\(encodedQuery)&count=\(limit)&\(langParams)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; ArgusBot/1.0)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             throw URLError(.badServerResponse)
        }
        
        // Google News RSS XML parsing using existing parser
        // Note: RSSParser must handle generic RSS 2.0 (Google uses standard RSS)
        let parser = RSSParser(limit: limit, sourceName: "Google News")
        let articles = parser.parse(data: data)
        
        return articles.map { article in
            NewsArticle(
                id: article.id,
                symbol: symbol,
                source: article.source.isEmpty ? "Google News" : article.source,
                headline: article.headline,
                summary: article.summary,
                url: article.url,
                publishedAt: article.publishedAt,
                fetchedAt: article.fetchedAt
            )
        }
    }
}
