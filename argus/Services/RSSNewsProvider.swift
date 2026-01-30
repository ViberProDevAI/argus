import Foundation

protocol NewsProvider {
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle]
}

// MARK: - XML Parser Delegate for RSS
class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [NewsArticle] = []
    private var currentElement = ""
    private var currentTitle: String = ""
    private var currentLink: String = ""
    private var currentDescription: String = ""
    private var currentPubDate: String = ""
    
    // Limits
    private let limit: Int
    private let sourceName: String
    
    init(limit: Int, sourceName: String) {
        self.limit = limit
        self.sourceName = sourceName
    }
    
    func parse(data: Data) -> [NewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }
    
    // MARK: - XMLParserDelegate Methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            if articles.count < limit {
                // Parse Date
                let formatter = DateFormatter()
                formatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z" // Standard RSS Date Format
                // Investing.com might vary, but this is standard
                let date = formatter.date(from: currentPubDate) ?? Date()
                
                let article = NewsArticle(
                    id: UUID().uuidString,
                    symbol: "MARKET", // General
                    source: sourceName,
                    headline: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                    publishedAt: date,
                    fetchedAt: Date()
                )
                articles.append(article)
            }
        }
    }
}

// MARK: - RSSNewsProvider
final class RSSNewsProvider: NewsProvider {
    
    // Comprehensive Source List (Economy, Politics, Mainstream, Independent)
    private let feedSources: [String: [(name: String, url: String)]] = [
        "BIST_MIX": [
            // --- EKONOMİ ODAKLI ---
            ("Bloomberg HT", "https://www.bloomberght.com/rss"),
            ("Investing TR", "https://tr.investing.com/rss/news_25.rss"),
            ("Investing Hisse", "https://tr.investing.com/rss/news_285.rss"),
            ("Ekonomim", "https://www.ekonomim.com/rss"),
            ("Patronlar Dünyası", "https://www.patronlardunyasi.com/rss"),
            ("Borsa Gündem", "https://www.borsagundem.com/rss"),
            ("Foreks Haber", "https://www.foreks.com/rss"),
            ("BigPara", "https://bigpara.hurriyet.com.tr/rss"),
            ("Para Analiz", "https://www.paraanaliz.com/feed/"),
            
            // --- BAĞIMSIZ & ELEŞTİREL (SİYASET/GENEL) ---
            ("BBC Türkçe", "http://feeds.bbci.co.uk/turkce/rss.xml"),
            ("Euronews TR", "https://tr.euronews.com/rss?format=xml"),
            ("DW Türkçe", "https://rss.dw.com/xml/rss-tr-all"),
            ("T24", "https://t24.com.tr/rss"),
            ("Gazete Duvar", "https://www.gazeteduvar.com.tr/rss"),
            ("Diken", "http://www.diken.com.tr/feed/"),
            ("BirGün", "https://www.birgun.net/xml/rss.xml"),
            ("Evrensel", "https://www.evrensel.net/rss/haber.xml"),
            ("Bianet", "https://bianet.org/rss"),
            ("Halk TV", "https://halktv.com.tr/rss"),
            ("Tele1", "https://tele1.com.tr/feed/"),
            ("Kısa Dalga", "https://kisadalga.net/rss"),
            
            // --- MERKEZ & ANA AKIM (DENGE İÇİN) ---
            ("Sözcü", "https://www.sozcu.com.tr/feeds-rss-category-gundem"),
            ("Sözcü Ekonomi", "https://www.sozcu.com.tr/feeds-rss-category-ekonomi"),
            ("Cumhuriyet", "https://www.cumhuriyet.com.tr/rss"),
            ("Habertürk", "https://www.haberturk.com/rss/manset.xml"),
            ("Habertürk Ekonomi", "https://www.haberturk.com/rss/ekonomi.xml"),
            ("NTV", "https://www.ntv.com.tr/gundem.rss"),
            ("NTV Ekonomi", "https://www.ntv.com.tr/ekonomi.rss"),
            ("CNN Türk", "https://www.cnnturk.com/feed/rss/all/news"),
            ("Milliyet Ekonomi", "https://www.milliyet.com.tr/rss/rssnew/ekonomi.xml"),
            ("Hürriyet Ekonomi", "https://www.hurriyet.com.tr/rss/ekonomi"),
            ("Karar", "https://www.karar.com/rss/rss.xml"),
            ("Gazete Oksijen", "https://gazeteoksijen.com/rss")
        ],
        "FOREX": [
            ("Investing Forex", "https://tr.investing.com/rss/news_1.rss"),
            ("Bloomberg HT", "https://www.bloomberght.com/rss"),
            ("Döviz.com", "https://www.doviz.com/rss/tum-haberler")
        ],
        "CRYPTO": [
            ("Investing Crypto", "https://tr.investing.com/rss/news_301.rss"),
            ("CoinDesk", "https://www.coindesk.com/arc/outboundfeeds/rss/"),
            ("CoinTelegraph TR", "https://tr.cointelegraph.com/rss")
        ]
    ]
    
    func fetchNews(symbol: String, limit: Int) async throws -> [NewsArticle] {
        // Decide category
        let categoryKey: String
        if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) || symbol == "GENERAL" {
            categoryKey = "BIST_MIX"
        } else if symbol.contains("BTC") || symbol.contains("ETH") {
            categoryKey = "CRYPTO"
        } else {
            categoryKey = "FOREX" // Default fallback for USD/EUR or Globals
        }
        
        guard let sources = feedSources[categoryKey] else { return [] }
        
        // Concurrent Fetching
        return await withTaskGroup(of: [NewsArticle].self) { group in
            for (name, urlStr) in sources {
                group.addTask {
                    return await self.fetchSingleFeed(name: name, urlStr: urlStr, limit: limit)
                }
            }
            
            var allArticles: [NewsArticle] = []
            for await articles in group {
                allArticles.append(contentsOf: articles)
            }
            
            // Deduplicate (by Headline) and Sort
            let uniqueArticles = Array(Dictionary(grouping: allArticles, by: { $0.headline }).values.compactMap { $0.first })
            let sorted = uniqueArticles.sorted { $0.publishedAt > $1.publishedAt }
            
            // Save to Cache (First 20 items to save space)
            let topArticles = Array(sorted.prefix(limit))
            if !topArticles.isEmpty {
                 DataCacheService.shared.save(value: topArticles, kind: .news, symbol: symbol, source: "Multi-Source")
            }
            return topArticles
        }
    }
    
    private func fetchSingleFeed(name: String, urlStr: String, limit: Int) async -> [NewsArticle] {
        guard let url = URL(string: urlStr) else { return [] }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 6 // Fast timeout per feed
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                return []
            }
            
            let parser = RSSParser(limit: limit, sourceName: name)
            return parser.parse(data: data)
        } catch {
            print("RSS Fail (\(name)): \(error.localizedDescription)")
            return []
        }
    }
}
