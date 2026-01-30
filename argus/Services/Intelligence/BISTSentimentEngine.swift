import Foundation

// MARK: - BIST Sentiment Engine
// RSS haberlerinden Türkçe sentiment analizi yapar
// Finnhub yerine yerel/Türkçe kaynaklar kullanır

actor BISTSentimentEngine {
    static let shared = BISTSentimentEngine()
    
    // MARK: - Türkçe Sentiment Sözlüğü
    
    private let positiveKeywords: Set<String> = [
        // Finansal Olumlu
        "artış", "yükseliş", "büyüme", "kâr", "kar", "rekor", "olumlu", "güçlü",
        "beklentilerin üzerinde", "beklenti üstü", "alım", "hedef yükseltti",
        "temettü", "pozitif", "iyimser", "toparlanma", "ciro artışı",
        "ihracat", "sözleşme", "anlaşma", "ortaklık", "yatırım", "kapasite",
        "genişleme", "büyüme", "başarı", "liderlik", "pazar payı",
        "tut'tan al'a", "al tavsiyesi", "hedef fiyat yükseldi",
        // BIST Özel
        "ek bütçe", "destek paketi", "faiz indirimi", "dolar düştü",
        "enflasyon düştü", "rating yükseldi", "yabancı alımı"
    ]
    
    private let negativeKeywords: Set<String> = [
        // Finansal Olumsuz
        "düşüş", "gerileme", "zarar", "risk", "uyarı", "endişe", "satış",
        "beklentilerin altında", "beklenti altı", "hedef düşürdü", "azalış",
        "daralma", "kriz", "iflas", "borç", "tahsilat sorunu", "haciz",
        "dava", "ceza", "soruşturma", "manipülasyon", "dolandırıcılık",
        "al'dan tut'a", "al'dan sat'a", "sat tavsiyesi", "hedef fiyat düşürüldü",
        // BIST Özel
        "dolar yükseldi", "kur şoku", "enflasyon arttı", "faiz artırımı",
        "rating düşürüldü", "yabancı çıkışı", "sermaye kaçışı",
        "siyasi belirsizlik", "jeopolitik risk", "seçim belirsizliği"
    ]
    
    // Şirket isim eşleştirmesi (sembol → isim varyantları)
    private let companyNames: [String: [String]] = [
        "THYAO": ["türk hava yolları", "thy", "turkish airlines"],
        "GARAN": ["garanti", "garanti bankası", "garanti bbva"],
        "AKBNK": ["akbank"],
        "YKBNK": ["yapı kredi", "yapı ve kredi"],
        "ISCTR": ["iş bankası", "türkiye iş bankası", "isbank"],
        "SAHOL": ["sabancı", "sabancı holding"],
        "KCHOL": ["koç", "koç holding"],
        "TUPRS": ["tüpraş"],
        "EREGL": ["erdemir", "ereğli demir çelik"],
        "ASELS": ["aselsan"],
        "BIMAS": ["bim", "bim mağazaları"],
        "SISE": ["şişecam", "şişe cam"],
        "TOASO": ["tofaş"],
        "FROTO": ["ford otosan"],
        "TAVHL": ["tav havalimanları", "tav"],
        "PETKM": ["petkim"],
        "TCELL": ["turkcell"],
        "TTKOM": ["türk telekom"],
        "EKGYO": ["emlak konut"],
        "KOZAL": ["koza altın"],
        "ENKAI": ["enka"],
        "VAKBN": ["vakıfbank", "vakıf bankası"],
        "HALKB": ["halkbank", "halk bankası"],
        "ARCLK": ["arçelik"],
        "VESTL": ["vestel"]
    ]
    
    // Cache
    private var cache: [String: (result: BISTSentimentResult, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 900 // 15 dakika
    
    private init() {}
    
    // MARK: - Public API
    
    /// Sembol için sentiment analizi yapar
    func analyzeSentiment(for symbol: String) async throws -> BISTSentimentResult {
        let cleanSymbol = symbol.uppercased().replacingOccurrences(of: ".IS", with: "")
        
        // Cache kontrolü
        if let cached = cache[cleanSymbol],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            return cached.result
        }
        
        // 1. Haberleri çek
        let newsProvider = RSSNewsProvider()
        let articles = try await newsProvider.fetchNews(symbol: symbol, limit: 50)
        
        guard !articles.isEmpty else {
            let emptyResult = BISTSentimentResult.neutral(for: cleanSymbol)
            cache[cleanSymbol] = (emptyResult, Date())
            return emptyResult
        }
        
        // 2. Sembolle ilgili haberleri filtrele
        var relevantArticles = filterRelevantArticles(articles, for: cleanSymbol)
        var isGeneralMarket = false
        
        // FALLBACK: Eğer hisse özelinde haber yoksa, genel piyasa sentimentini kullan
        if relevantArticles.count < 2 {
            print("⚠️ BISTSentiment: \(cleanSymbol) için yeterli haber yok. Genel piyasa analizi yapılıyor.")
            relevantArticles = articles // Tüm BIST haberlerini kullan (zaten RSSNewsProvider BIST kategorisini getirdi)
            isGeneralMarket = true
        }
        
        // 3. Sentiment analizi yap
        var result = calculateSentiment(articles: relevantArticles, symbol: cleanSymbol)
        
        // Genel piyasa bayrağını işaretle
        if isGeneralMarket {
            result = BISTSentimentResult(
                symbol: symbol,
                overallScore: result.overallScore,
                bullishPercent: result.bullishPercent,
                bearishPercent: result.bearishPercent,
                neutralPercent: result.neutralPercent,
                newsVolume: result.newsVolume,
                relevantNewsCount: result.relevantNewsCount,
                keyHeadlines: result.keyHeadlines,
                mentionTrend: result.mentionTrend,
                lastUpdated: result.lastUpdated,
                isGeneralMarketSentiment: true
            )
        }
        
        // 4. Cache'e kaydet
        cache[cleanSymbol] = (result, Date())
        
        print("✅ BISTSentiment: \(cleanSymbol) analizi tamamlandı (Genel Piyasa: \(isGeneralMarket)). Skor: \(Int(result.overallScore))")
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func filterRelevantArticles(_ articles: [NewsArticle], for symbol: String) -> [NewsArticle] {
        let symbolLower = symbol.lowercased()
        let companyVariants = companyNames[symbol] ?? []
        
        return articles.filter { article in
            let combinedText = (article.headline + " " + (article.summary ?? "")).lowercased()
            
            // Sembol kontrolü
            if combinedText.contains(symbolLower) { return true }
            
            // Şirket adı kontrolü
            for variant in companyVariants {
                if combinedText.contains(variant) { return true }
            }
            
            return false
        }
    }
    
    private func calculateSentiment(articles: [NewsArticle], symbol: String) -> BISTSentimentResult {
        var positiveCount = 0
        var negativeCount = 0
        var keyHeadlines: [String] = []
        
        for article in articles {
            let combinedText = (article.headline + " " + (article.summary ?? "")).lowercased()
            
            // Kelime sayımı
            var articlePositive = 0
            var articleNegative = 0
            
            for keyword in positiveKeywords {
                if combinedText.contains(keyword) {
                    articlePositive += 1
                }
            }
            
            for keyword in negativeKeywords {
                if combinedText.contains(keyword) {
                    articleNegative += 1
                }
            }
            
            // Haber skoru
            if articlePositive > articleNegative {
                positiveCount += 1
            } else if articleNegative > articlePositive {
                negativeCount += 1
            }
            
            // Önemli başlıkları kaydet
            if articlePositive > 2 || articleNegative > 2 {
                keyHeadlines.append(article.headline)
            }
        }
        
        // Eğer hiç headline seçilmediyse rastgele 5 tane al (Haber akışı dolu görünsün)
        if keyHeadlines.isEmpty {
            keyHeadlines = articles.prefix(5).map { $0.headline }
        }
        
        let totalRelevant = positiveCount + negativeCount
        let neutralCount = articles.count - totalRelevant
        
        // Yüzdeleri hesapla
        let bullishPercent: Double
        let bearishPercent: Double
        let neutralPercent: Double
        
        if articles.isEmpty {
            bullishPercent = 50
            bearishPercent = 50
            neutralPercent = 0
        } else {
            bullishPercent = Double(positiveCount) / Double(articles.count) * 100
            bearishPercent = Double(negativeCount) / Double(articles.count) * 100
            neutralPercent = Double(neutralCount) / Double(articles.count) * 100
        }
        
        // Overall score hesapla (0-100, 50 = nötr)
        let overallScore: Double
        if totalRelevant == 0 {
            overallScore = 50
        } else {
            let ratio = Double(positiveCount - negativeCount) / Double(totalRelevant)
            overallScore = (ratio + 1) / 2 * 100 // -1...1 → 0...100
        }
        
        // Trend hesapla (son 6 saat vs önceki)
        let trend = calculateMentionTrend(articles: articles)
        
        return BISTSentimentResult(
            symbol: symbol,
            overallScore: overallScore,
            bullishPercent: bullishPercent,
            bearishPercent: bearishPercent,
            neutralPercent: neutralPercent,
            newsVolume: articles.count,
            relevantNewsCount: positiveCount + negativeCount + neutralCount,
            keyHeadlines: Array(keyHeadlines.prefix(5)),
            mentionTrend: trend,
            lastUpdated: Date(),
            isGeneralMarketSentiment: false
        )
    }
    
    private func calculateMentionTrend(articles: [NewsArticle]) -> MentionTrend {
        let sixHoursAgo = Date().addingTimeInterval(-6 * 3600)
        
        let recentCount = articles.filter { $0.publishedAt > sixHoursAgo }.count
        let olderCount = articles.count - recentCount
        
        if recentCount > olderCount * 2 {
            return .increasing
        } else if olderCount > recentCount * 2 {
            return .decreasing
        }
        return .stable
    }
}

// MARK: - Models

struct BISTSentimentResult {
    let symbol: String
    let overallScore: Double          // 0-100 (50 = nötr)
    let bullishPercent: Double        // Olumlu haber %
    let bearishPercent: Double        // Olumsuz haber %
    let neutralPercent: Double        // Nötr haber %
    let newsVolume: Int               // Toplam haber sayısı
    let relevantNewsCount: Int        // İlgili haber sayısı
    let keyHeadlines: [String]        // Öne çıkan başlıklar
    let mentionTrend: MentionTrend    // Artan/Azalan/Stabil
    let lastUpdated: Date
    let isGeneralMarketSentiment: Bool // True ise hisse özelinde haber yok, genel piyasa kullanıldı
    
    /// Sentiment durumu (UI için)
    var sentimentLabel: String {
        if overallScore >= 65 { return "Olumlu" }
        if overallScore >= 55 { return "Hafif Olumlu" }
        if overallScore >= 45 { return "Nötr" }
        if overallScore >= 35 { return "Hafif Olumsuz" }
        return "Olumsuz"
    }
    
    /// Nötr sonuç oluşturur
    static func neutral(for symbol: String) -> BISTSentimentResult {
        BISTSentimentResult(
            symbol: symbol,
            overallScore: 50,
            bullishPercent: 0,
            bearishPercent: 0,
            neutralPercent: 100,
            newsVolume: 0,
            relevantNewsCount: 0,
            keyHeadlines: [],
            mentionTrend: .stable,
            lastUpdated: Date(),
            isGeneralMarketSentiment: false
        )
    }
}

enum MentionTrend: String {
    case increasing = "Artıyor"
    case decreasing = "Azalıyor"
    case stable = "Stabil"
}
