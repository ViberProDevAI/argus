import Foundation

/// Argus Narrative Engine 2.0 🧠
/// "Wall Street" standardında, profesyonel, bütünsel ve eğitici piyasa analizleri üretir.
struct ArgusNarrativeEngine {
    
    // MARK: - API
    
    static func generateReport(symbol: String, viewModel: TradingViewModel) -> String {
        var report = ""
        
        // Veri Seti
        let decision = viewModel.grandDecisions[symbol]
        let atlas = viewModel.getFundamentalScore(for: symbol)
        let orion = viewModel.orionScores[symbol]
        let news = viewModel.newsInsightsBySymbol[symbol] ?? []
        let strategy = viewModel.patterns[symbol] // Formasyonlar
        
        // 1. MANŞET (The Lead)
        // Gazetecilik stili: En önemli haberi en başa koy.
        report += generateLeadParagraph(symbol: symbol, decision: decision, atlas: atlas, orion: orion)
        report += "\n\n"
        
        // 2. GÖVDE (The Context)
        // Teknik ve Temel verilerin sentezi (Modül ismi vermeden)
        report += generateSynthesisBody(atlas: atlas, orion: orion, strategy: strategy)
        report += "\n\n"
        
        // 3. PİYASA ALGISI (The Sentiment)
        if !news.isEmpty {
            report += generateSentimentSection(news: news)
            report += "\n\n"
        }
        
        // 4. SONUÇ & AKSİYON (The Bottom Line)
        if let d = decision {
            report += "SONUÇ: \(d.action.rawValue.uppercased()) (% \(Int(d.confidence * 100)) Güven)\n"
            report += generateActionAdvice(action: d.action)
        }
        
        report += "\n\n"
        report += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" // Ayırıcı çizgi
        
        // 5. ARGUS AKADEMİ (The Knowledge)
        // Rastgele veya duruma özel bir bilgi kartı
        let tip = ArgusKnowledgeBase.getRelevantTip(decision: decision, orion: orion)
        report += "💡 BİLGİ NOTU: \(tip.title)\n"
        report += "\(tip.content)\n"
        
        return report
    }
    
    // MARK: - Generators
    
    private static func generateLeadParagraph(symbol: String, decision: ArgusGrandDecision?, atlas: FundamentalScoreResult?, orion: OrionScoreResult?) -> String {
        guard let d = decision else { return "\(symbol) için veriler toplanıyor..." }
        
        var lead = "# ARGUS ÖZEL RAPORU: \(symbol)\n\n"
        
        switch d.action {
        case .aggressiveBuy:
            lead += "\(symbol), hem mali yapısındaki güçlülük hem de teknik göstergelerdeki ivme ile piyasadan pozitif ayrışıyor. Sistemlerimiz bu hisse için 'Yüksek Potansiyel' sinyali üretti."
        case .accumulate:
            lead += "\(symbol) hissesinde orta vadeli bir toparlanma emareleri görülüyor. Fiyat cazip seviyelerde ve kademeli alım için uygun bir zemin oluşmuş durumda."
        case .liquidate:
            lead += "Dikkat: \(symbol) üzerindeki satış baskısı tehlikeli boyutlara ulaştı. Risk göstergeleri kırmızı alarm veriyor ve sermaye koruma moduna geçilmesi öneriliyor."
        case .trim:
            lead += "\(symbol) hissesinde momentum kaybı yaşanıyor. Mevcut karların realize edilmesi veya riskin azaltılması mantıklı bir hamle olabilir."
        default:
            lead += "\(symbol) şu anda kararsız bir seyir izliyor. Ne belirgin bir yükseliş trendi ne de sert bir düşüş emaresi var. En doğru strateji 'Bekle ve Gör' olacaktır."
        }
        
        return lead
    }
    
    private static func generateSynthesisBody(atlas: FundamentalScoreResult?, orion: OrionScoreResult?, strategy: [OrionChartPattern]?) -> String {
        var text = ""
        
        // Temel + Teknik Sentezi
        if let a = atlas, let o = orion {
            // Senaryo 1: Güçlü Temel + Güçlü Teknik
            if a.totalScore > 70 && o.score > 70 {
                text += "Şirketin güçlü karlılık yapısı ve sağlam bilançosu, mevcut yükseliş trendini temelden destekliyor. Bu yükselişin spekülatif değil, reel bir değerlemeye dayandığını söyleyebiliriz. Fiyat hareketleri hacimli ve kararlı."
            }
            // Senaryo 2: İyi Temel + Kötü Teknik (Fırsat?)
            else if a.totalScore > 70 && o.score < 40 {
                text += "Şirket finansal olarak oldukça sağlıklı (karlı ve ucuz), ancak piyasa fiyatlaması bu gerçeği henüz yansıtmıyor. Teknik göstergelerin aşırı satım bölgesinde olması, buranın değer yatırımcıları için bir 'dip toplama' fırsatı olabileceğini gösteriyor."
            }
            // Senaryo 3: Kötü Temel + İyi Teknik (Spekülatif Ralli)
            else if a.totalScore < 40 && o.score > 70 {
                text += "Fiyat teknik olarak yükseliyor olsa da, şirketin zayıf finansalları bu hareketi desteklemiyor. Bu durum, yükselişin haber kaynaklı veya spekülatif olabileceğini gösterir. Trendin tersine dönmesi durumunda düşüş sert olabilir, stop-loss seviyelerine sadık kalınmalı."
            }
            // Senaryo 4: Kötü Temel + Kötü Teknik
            else {
                text += "Hem şirketin mali tablolarındaki bozulma hem de teknik göstergelerdeki negatif görünüm, hisse üzerindeki baskının devam edeceğini işaret ediyor. Alıcıların iştahsız olduğu bu ortamda aceleci olmamak gerekir."
            }
            
            // RSI ve Aşırılık Durumu (Cümle içine yedirme)
            if let rsi = o.components.rsi {
                if rsi > 75 {
                    text += " Ancak kısa vadede fiyatın aşırı ısındığını (RSI > 75) ve bir kar realizasyonu/düzeltme ihtimalinin masada olduğunu unutmamak gerekir."
                } else if rsi < 25 {
                    text += " Diğer yandan, teknik indikatörlerin dip seviyelerde olması, satıcıların yorulduğunu ve bir tepki yükselişinin yakın olabileceğini fısıldıyor."
                }
            }
        }
        
        // Formasyon (Varsa)
        if let patterns = strategy, let best = patterns.first {
            text += "\n\nGrafiklerde göze çarpan \(best.type.rawValue) formasyonu ise, \(best.type.isBullish ? "yukarı" : "aşağı") yönlü hareket beklentisini teknik olarak teyit ediyor."
        }
        
        return text
    }
    
    private static func generateSentimentSection(news: [NewsInsight]) -> String {
        // En önemli haberi bul
        guard let topNews = news.max(by: { $0.impactScore < $1.impactScore }) else { return "" }
        
        var text = "Piyasa gündeminde ise \"\(topNews.headline)\" haberi öne çıkıyor. "
        
        if topNews.sentiment == .strongPositive {
            text += "Bu gelişme, yatırımcı algısını pozitif yönde etkileyen bir katalizör görevi görüyor."
        } else if topNews.sentiment == .strongNegative {
            text += "Piyasa bu haberi risk unsuru olarak fiyatlıyor ve baskı yaratıyor."
        } else {
            text += "Haber akışı şu an için nötr seyrediyor, fiyata dramatik bir etkisi yok."
        }
        
        return text
    }
    
    private static func generateActionAdvice(action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy:
            return "Öneri: Mevcut fiyattan pozisyon açılabilir. Trend güçlü."
        case .accumulate:
            return "Öneri: Düşüşlerde kademeli alım yapılabilir. Vadeli düşünülmeli."
        case .liquidate:
            return "Öneri: Varsa pozisyonlar kapatılmalı, nakde geçilmeli."
        case .trim:
            return "Öneri: Karın bir kısmı realize edilip risk masadan kaldırılmalı."
        default:
            return "Öneri: Yeni işlem açmadan mevcut durum korunmalı."
        }
    }
}

// MARK: - Argus Akademi (Knowledge Base)

struct ArgusKnowledgeBase {
    struct Tip {
        let title: String
        let content: String
        let category: Category
        
        enum Category {
            case psychology
            case technical
            case fundamental
            case risk
        }
    }
    
    static let library: [Tip] = [
        // PSİKOLOJİ
        Tip(title: "FOMO (Fırsat Kaçırma Korkusu)", content: "Hızla yükselen bir hisseyi tepeden almak, borsadaki en büyük kayıp sebebidir. Fırsatlar bitmez; biri kaçarsa diğeri gelir. Planınıza sadık kalın.", category: .psychology),
        Tip(title: "Zararı Kabullenmek", content: "Yanılmak suç değildir, yanıldığını kabul etmemek hatadır. Küçük zararı kesip atmak (Stop-Loss), büyük sermayeyi kurtarır.", category: .psychology),
        Tip(title: "Sabır Yönetimi", content: "Borsa, sabırsızların parasının sabırlılara transfer edildiği yerdir. Bazen en iyi işlem, hiçbir şey yapmamaktır.", category: .psychology),
        Tip(title: "Sürü Psikolojisi", content: "Herkes aynı şeyi konuşuyorsa, trendin sonuna gelinmiş olabilir. Profesyoneller, herkes korkarken alır, herkes coşkuluyken satar.", category: .psychology),
        
        // TEKNİK
        Tip(title: "Trend Dostunuzdur", content: "Akıntıya karşı yüzmeyin. Fiyat yükseliyorsa düşüşler alım fırsatıdır; düşüyorsa yükselişler satış fırsatıdır.", category: .technical),
        Tip(title: "Hacim Onayı", content: "Hacimsiz yükseliş, yakıtsız arabaya benzer; yolda kalır. Gerçek trendler, artan işlem hacmiyle desteklenmelidir.", category: .technical),
        Tip(title: "RSI Uyumsuzluğu", content: "Fiyat yeni zirve yaparken RSI yapamıyorsa (Negatif Uyumsuzluk), yükselişin gücü tükeniyor demektir. Düşüş yakındır.", category: .technical),
        Tip(title: "Destek ve Direnç", content: "Destekler, alıcıların geldiği 'ucuz' bölgeler; dirençler ise satıcıların beklediği 'pahalı' bölgelerdir. Kırılana kadar bu sınırlar geçerlidir.", category: .technical),
        
        // RİSK
        Tip(title: "Yüzde 2 Kuralı", content: "Tek bir işlemde toplam sermayenizin %2'sinden fazlasını riske atmayın. Bu sayede arka arkaya 10 kez yanilsanız bile oyunda kalırsınız.", category: .risk),
        Tip(title: "Kar Realizasyonu", content: "Kağıt üzerindeki kar, cebe girmeden kar değildir. Hedefe ulaşıldığında kademeli satış yapmak, açgözlülüğü yener.", category: .risk),
        
        // TEMEL
        Tip(title: "Fiyat vs Değer", content: "Fiyat, ödediğinizdir; değer, aldığınızdır. İyi bir şirket, kötü bir fiyattan alınırsa kötü bir yatırım olur.", category: .fundamental),
        Tip(title: "Net Kar Marjı", content: "Cironun büyümesi yetmez, ne kadarının cebe kaldığı önemlidir. Artan kar marjı, şirketin rekabet gücünün arttığını gösterir.", category: .fundamental)
    ]
    
    static func getRelevantTip(decision: ArgusGrandDecision?, orion: OrionScoreResult?) -> Tip {
        // 1. Contextual Selection (Duruma özel)
        
        // Düşüş/Satış Durumu -> Psikoloji veya Risk ver
        if let d = decision, (d.action == .liquidate || d.action == .trim) {
            let riskTips = library.filter { $0.category == .risk || $0.title.contains("Zarar") }
            return riskTips.randomElement() ?? library.first!
        }
        
        // Aşırı Alım Durumu -> Teknik ver
        if let o = orion, let rsi = o.components.rsi, rsi > 75 {
            return library.first(where: { $0.title.contains("RSI") || $0.title.contains("Hacim") }) ?? library.first!
        }
        
        // 2. Random fallback (Context yoksa rastgele eğitici bilgi)
        return library.randomElement()!
    }
}
