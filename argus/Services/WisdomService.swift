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
        quotes = decoded.isEmpty ? defaultQuotes : decoded
    }
    
    func getQuote(for action: ArgusAction) -> WisdomQuote? {
        if quotes.isEmpty {
            return defaultQuotes.randomElement()
        }
        return quotes.randomElement()
    }

    func getAllQuotes() -> [WisdomQuote] {
        quotes.isEmpty ? defaultQuotes : quotes
    }
    
    func getDailyQuote() -> WisdomQuote? {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        guard !quotes.isEmpty else { return defaultQuotes.first }
        return quotes[dayOfYear % quotes.count]
    }
    
    private var defaultQuotes: [WisdomQuote] {
        [
            // MARK: - Risk (12 söz)
            WisdomQuote(quote: "Piyasada en tehlikeli dört kelime: Bu sefer farklı.", author: "John Templeton", category: "risk"),
            WisdomQuote(quote: "Kaybetmemek, kazanmaktan daha önemlidir.", author: "Warren Buffett", category: "risk"),
            WisdomQuote(quote: "Risk, ne yaptığını bilmemekten gelir.", author: "Warren Buffett", category: "risk"),
            WisdomQuote(quote: "Asla tüm yumurtalarını aynı sepete koyma.", author: "Atasözü", category: "risk"),
            WisdomQuote(quote: "Kaybedebileceğinden fazlasını asla riske atma.", author: "Jesse Livermore", category: "risk"),
            WisdomQuote(quote: "Piyasa, haklı olduğundan daha uzun süre irrasyonel kalabilir.", author: "John Maynard Keynes", category: "risk"),
            WisdomQuote(quote: "En büyük risk, hiç risk almamaktır.", author: "Mark Zuckerberg", category: "risk"),
            WisdomQuote(quote: "Riski yönetemeyen, getiriyi de yönetemez.", author: "Peter Lynch", category: "risk"),
            WisdomQuote(quote: "Düşen bıçağı tutmaya çalışma.", author: "Wall Street", category: "risk"),
            WisdomQuote(quote: "Kaldıraç, hem zenginliğin hem yıkımın anahtarıdır.", author: "Anonim", category: "risk"),
            WisdomQuote(quote: "Portföyün %10'undan fazlasını tek hisseye bağlama.", author: "Peter Lynch", category: "risk"),
            WisdomQuote(quote: "Volatilite arkadaşın değil, öğretmenindir.", author: "Benjamin Graham", category: "risk"),
            
            // MARK: - Psychology (12 söz)
            WisdomQuote(quote: "Korku ve açgözlülük arasındaki dengeyi bul.", author: "Warren Buffett", category: "psychology"),
            WisdomQuote(quote: "Piyasa, sabırsızlardan sabırlılara para aktarır.", author: "Warren Buffett", category: "psychology"),
            WisdomQuote(quote: "Başkaları korktuğunda açgözlü, açgözlü olduğunda korkak ol.", author: "Warren Buffett", category: "psychology"),
            WisdomQuote(quote: "En iyi yatırım, kendinize yaptığınız yatırımdır.", author: "Warren Buffett", category: "psychology"),
            WisdomQuote(quote: "Duygularınız portföyünüzü yönetmesin.", author: "Benjamin Graham", category: "psychology"),
            WisdomQuote(quote: "Piyasanın sizi zengin etmesi için zamanı vardır, aceleniz olmasın.", author: "Jesse Livermore", category: "psychology"),
            WisdomQuote(quote: "Kayıplardan ders al, kazançlardan öğren.", author: "Peter Lynch", category: "psychology"),
            WisdomQuote(quote: "En zor iş, hiçbir şey yapmamaktır.", author: "Warren Buffett", category: "psychology"),
            WisdomQuote(quote: "FOMO en pahalı duygudur.", author: "Kripto Atasözü", category: "psychology"),
            WisdomQuote(quote: "Pişmanlık, geriye bakarak yatırım yapmaktır.", author: "Anonim", category: "psychology"),
            WisdomQuote(quote: "Kayıp acısı, kazanç sevincinden iki kat güçlüdür.", author: "Daniel Kahneman", category: "psychology"),
            WisdomQuote(quote: "Piyasayı yenmek için önce kendini yen.", author: "Anonim", category: "psychology"),
            
            // MARK: - Patience (12 söz)
            WisdomQuote(quote: "Sabır, yatırımcının en büyük erdemidir.", author: "Benjamin Graham", category: "patience"),
            WisdomQuote(quote: "Zaman, kaliteli şirketlerin dostudur.", author: "Warren Buffett", category: "patience"),
            WisdomQuote(quote: "Bileşik getiri, dünyanın sekizinci harikasıdır.", author: "Albert Einstein", category: "patience"),
            WisdomQuote(quote: "Ağaç dikmek için en iyi zaman 20 yıl önceydi. İkinci en iyi zaman şimdi.", author: "Çin Atasözü", category: "patience"),
            WisdomQuote(quote: "Borsada para kazanmak, beklemeyi bilmektir.", author: "Jesse Livermore", category: "patience"),
            WisdomQuote(quote: "Hızlı zengin olma planları, genelde hızlı fakirleşme planlarıdır.", author: "Anonim", category: "patience"),
            WisdomQuote(quote: "Yavaş ve istikrarlı olan yarışı kazanır.", author: "Ezop", category: "patience"),
            WisdomQuote(quote: "10 yıl tutmayacaksan, 10 dakika bile tutma.", author: "Warren Buffett", category: "patience"),
            WisdomQuote(quote: "Piyasa zamanlama değil, piyasada kalma süresi önemlidir.", author: "Ken Fisher", category: "patience"),
            WisdomQuote(quote: "Kısa vadeli düşünen, uzun vadede kaybeder.", author: "Anonim", category: "patience"),
            WisdomQuote(quote: "Beklemek de bir stratejidir.", author: "Warren Buffett", category: "patience"),
            WisdomQuote(quote: "En iyi işlemler, yapmadığın işlemlerdir.", author: "Peter Lynch", category: "patience"),
            
            // MARK: - Strategy (14 söz)
            WisdomQuote(quote: "Fiyat ne ödediğiniz, değer ne aldığınızdır.", author: "Warren Buffett", category: "strategy"),
            WisdomQuote(quote: "Harika şirketleri makul fiyattan al.", author: "Warren Buffett", category: "strategy"),
            WisdomQuote(quote: "Trendin arkadaşın olsun.", author: "Wall Street", category: "strategy"),
            WisdomQuote(quote: "Planın olmadan piyasaya girme.", author: "Jesse Livermore", category: "strategy"),
            WisdomQuote(quote: "Zarar kes, kârı koştur.", author: "Wall Street", category: "strategy"),
            WisdomQuote(quote: "Ucuz olan daha da ucuzlayabilir.", author: "Peter Lynch", category: "strategy"),
            WisdomQuote(quote: "Anlamadığın şeye yatırım yapma.", author: "Warren Buffett", category: "strategy"),
            WisdomQuote(quote: "Diversifikasyon, bilgisizliğe karşı korumadır.", author: "Warren Buffett", category: "strategy"),
            WisdomQuote(quote: "Kazananları sat, kaybedenleri tut - bu yanlış.", author: "Peter Lynch", category: "strategy"),
            WisdomQuote(quote: "Piyasa haberlerini değil, bilanço okumayı öğren.", author: "Benjamin Graham", category: "strategy"),
            WisdomQuote(quote: "Ortalama düşürmek bazen mezar kazmaktır.", author: "Anonim", category: "strategy"),
            WisdomQuote(quote: "En iyi savunma, iyi bir hücumdur.", author: "Anonim", category: "strategy"),
            WisdomQuote(quote: "Spekülasyon değil, yatırım yap.", author: "Benjamin Graham", category: "strategy"),
            WisdomQuote(quote: "Küçük kazançlar bile zamanla büyük servet olur.", author: "Anonim", category: "strategy"),
            
            // MARK: - Growth (10 söz)
            WisdomQuote(quote: "Yatırım yapmak, bugün para harcayıp yarın daha fazlasını almaktır.", author: "Warren Buffett", category: "growth"),
            WisdomQuote(quote: "Finansal özgürlük, seçeneklere sahip olmaktır.", author: "Robert Kiyosaki", category: "growth"),
            WisdomQuote(quote: "Zenginlik, tasarruf edilen paranın yatırıma dönüşmesidir.", author: "Benjamin Franklin", category: "growth"),
            WisdomQuote(quote: "Para seni çalıştırmasın, sen parayı çalıştır.", author: "Robert Kiyosaki", category: "growth"),
            WisdomQuote(quote: "Gelirini artır, giderini azalt, farkını yatır.", author: "Anonim", category: "growth"),
            WisdomQuote(quote: "Zengin olmak zor değil, zengin kalmak zordur.", author: "Jesse Livermore", category: "growth"),
            WisdomQuote(quote: "Servet, yavaş yavaş inşa edilir.", author: "Warren Buffett", category: "growth"),
            WisdomQuote(quote: "Finansal okuryazarlık, 21. yüzyılın survival becerisidir.", author: "Robert Kiyosaki", category: "growth"),
            WisdomQuote(quote: "Küçük başla, tutarlı ol, büyük bitir.", author: "Anonim", category: "growth"),
            WisdomQuote(quote: "En iyi miras, finansal eğitimdir.", author: "Anonim", category: "growth")
        ]
    }
}
