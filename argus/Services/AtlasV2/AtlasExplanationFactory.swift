import Foundation

// MARK: - Atlas Yorum Fabrikası
// Her metrik için dinamik, eğitici açıklamalar üretir

final class AtlasExplanationFactory {
    static let shared = AtlasExplanationFactory()
    
    private init() {}
    
    // MARK: - F/K (P/E) Açıklamaları
    
    func explainPE(value: Double?, sectorAvg: Double) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let pe = value, pe > 0 else {
            return (.noData, 0, "F/K hesaplanamıyor - şirket zarar ediyor veya veri yok.", 
                    "F/K oranı, hisse fiyatının yıllık kara bölünmesiyle bulunur. Negatif kar durumunda hesaplanamaz.")
        }
        
        let deviation = ((pe - sectorAvg) / sectorAvg) * 100
        
        switch pe {
        case ..<8:
            return (.excellent, 95, 
                    "Çok ucuz! Sektör ortalamasının çok altında (\(String(format: "%.0f", abs(deviation)))% indirimli).",
                    "Bu kadar düşük F/K ya büyük bir fırsat ya da ciddi bir sorun işareti olabilir. Dikkatli araştır.")
        case 8..<12:
            return (.good, 80,
                    "Ucuz. Değer yatırımcıları için cazip (\(String(format: "%.0f", abs(deviation)))% indirimli).",
                    "Düşük F/K genellikle olgun, yavaş büyüyen şirketlerde görülür. Temettü potansiyeli yüksek olabilir.")
        case 12..<18:
            return (.good, 70,
                    "Makul fiyatlanmış. Sektör ortalamasına yakın.",
                    "Bu aralık çoğu sağlıklı şirket için normaldir. Ne aşırı ucuz ne de pahalı.")
        case 18..<25:
            return (deviation < 0 ? .good : .neutral, 60,
                    deviation < 0 ? "Sektöre göre hala makul." : "Sektör ortalamasında.",
                    "Orta düzey F/K, istikrarlı büyüme beklentisini yansıtır.")
        case 25..<35:
            return (deviation > 20 ? .warning : .neutral, 45,
                    deviation > 20 ? "Pahalı! Sektörün \(String(format: "%.0f", deviation))% üstünde." : "Biraz pahalı ama büyüme beklentisi var.",
                    "Yüksek F/K, piyasanın güçlü büyüme beklediği anlamına gelir. Bu beklenti karşılanmazsa fiyat düşebilir.")
        case 35..<50:
            return (.warning, 30,
                    "Çok pahalı! Yüksek büyüme beklentisi fiyata yansımış.",
                    "Bu seviyede alım yaparken, şirketin gerçekten hızlı büyüyeceğinden emin olmalısın.")
        default:
            return (.bad, 15,
                    "Aşırı pahalı! F/K > 50 nadiren sürdürülebilir.",
                    "Bu kadar yüksek F/K, spekülatif bir fiyatlamayı gösterir. Düzeltme riski yüksek.")
        }
    }
    
    // MARK: - PD/DD (P/B) Açıklamaları
    
    func explainPB(value: Double?, sectorAvg: Double) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let pb = value, pb > 0 else {
            return (.noData, 0, "PD/DD hesaplanamıyor.",
                    "PD/DD, piyasa değerinin defter değerine oranıdır. Şirketin varlıklarına göre ne kadar fiyatlandığını gösterir.")
        }
        
        switch pb {
        case ..<1.0:
            return (.excellent, 90,
                    "Defter değerinin altında! Potansiyel değer fırsatı.",
                    "PD/DD < 1, şirketi tasfiye etsen bile para kazanabilirsin demek. Ama neden bu kadar ucuz, araştır.")
        case 1.0..<2.0:
            return (.good, 75,
                    "Makul. Varlıklarına göre uygun fiyatlı.",
                    "Bu aralık bankalar, sanayi şirketleri için normaldir.")
        case 2.0..<4.0:
            return (.neutral, 60,
                    "Orta seviye. Marka değeri fiyata yansımış.",
                    "Teknoloji ve tüketici şirketleri için kabul edilebilir.")
        case 4.0..<8.0:
            return (.neutral, 45,
                    "Yüksek. Güçlü marka veya patent değeri olabilir.",
                    "Apple, Microsoft gibi şirketlerin yüksek PD/DD'si normaldir - fiziksel varlıktan çok fikri mülkiyet.")
        default:
            return (.warning, 25,
                    "Çok yüksek! Varlıklarının \(Int(pb))x fiyatlanmış.",
                    "Bu seviye sadece olağanüstü büyüme beklentisiyle haklı çıkabilir.")
        }
    }
    
    // MARK: - ROE Açıklamaları
    
    func explainROE(value: Double?, sectorAvg: Double) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let roe = value else {
            return (.noData, 0, "ROE hesaplanamıyor.",
                    "ROE (Özkaynak Karlılığı), şirketin yatırılan sermayeden ne kadar kar ettiğini gösterir.")
        }
        
        switch roe {
        case ..<0:
            return (.critical, 0,
                    "Negatif ROE! Şirket sermayesini eritiyor.",
                    "Negatif ROE, şirketin zarar ettiği ve özkaynaklarının azaldığı anlamına gelir. Çok tehlikeli!")
        case 0..<5:
            return (.bad, 20,
                    "Çok düşük karlılık. Faiz oranlarından bile az.",
                    "Bu seviye, paranı bankada tutsan daha iyi olacağı anlamına gelebilir.")
        case 5..<10:
            return (.warning, 40,
                    "Düşük karlılık. Sermaye verimsiz kullanılıyor.",
                    "Şirket kar ediyor ama rakiplerine göre zayıf performans gösteriyor.")
        case 10..<15:
            return (.neutral, 55,
                    "Orta seviye karlılık. Kabul edilebilir.",
                    "Çoğu sanayi şirketi için bu seviye normaldir.")
        case 15..<25:
            return (.good, 75,
                    "İyi karlılık. Sektör ortalamasının üstünde.",
                    "Güçlü yönetim ve rekabet avantajı işareti.")
        case 25..<40:
            return (.excellent, 90,
                    "Mükemmel! Her 100₺ sermaye \(Int(roe))₺ kar üretiyor.",
                    "Bu seviye, şirketin güçlü bir 'ekonomik hendeği' olduğunu gösterir. Warren Buffett bunu sever!")
        default:
            return (.excellent, 95,
                    "Olağanüstü ROE! Sektörün yıldızı.",
                    "Bu kadar yüksek ROE nadirdir. Ancak sürdürülebilir mi, araştır.")
        }
    }
    
    // MARK: - Borç/Özkaynak Açıklamaları
    
    func explainDebtToEquity(value: Double?) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let de = value else {
            return (.noData, 0, "Borç/Özkaynak hesaplanamıyor.",
                    "Bu oran, şirketin ne kadar borçla finanse edildiğini gösterir.")
        }
        
        switch de {
        case ..<0.3:
            return (.excellent, 95,
                    "Neredeyse borçsuz! Finansal kaleye benzer.",
                    "Düşük borç, ekonomik krizlere karşı büyük avantaj sağlar.")
        case 0.3..<0.5:
            return (.excellent, 85,
                    "Çok düşük borç. Konservatif finansal yapı.",
                    "Şirket kendi kaynaklarıyla büyüyor. Faiz giderlerinden etkilenmez.")
        case 0.5..<1.0:
            return (.good, 70,
                    "Sağlıklı borç seviyesi.",
                    "Borç ve özkaynak dengeli. Çoğu şirket için ideal.")
        case 1.0..<1.5:
            return (.neutral, 55,
                    "Orta düzey borç. Dikkatli izlenmeli.",
                    "Faiz oranları yükselirse karlılık etkilenebilir.")
        case 1.5..<2.0:
            return (.warning, 40,
                    "Yüksek borç! Her 1₺ özkaynağa \(String(format: "%.1f", de))₺ borç.",
                    "Bu seviye risk taşır. Nakit akışı güçlü olmalı.")
        case 2.0..<3.0:
            return (.bad, 25,
                    "Tehlikeli borç seviyesi!",
                    "Şirket ağırlıklı olarak borçla finanse ediliyor. İflas riski artmış.")
        default:
            return (.critical, 10,
                    "Kritik borç yükü! İflas riski çok yüksek.",
                    "Bu kadar borçlu şirketler ekonomik daralmalarda ilk çökenler olur.")
        }
    }
    
    // MARK: - Serbest Nakit Akışı Açıklamaları
    
    func explainFCF(value: Double?, marketCap: Double?) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let fcf = value else {
            return (.noData, 0, "Serbest nakit akışı verisi yok.",
                    "FCF, şirketin yatırımlardan sonra kalan nakididir. Temettü, geri alım veya yatırım için kullanılır.")
        }
        
        let fcfFormatted = AtlasMetric.format(abs(fcf))
        
        if fcf < 0 {
            return (.bad, 20,
                    "Negatif nakit akışı! Şirket nakit yakıyor (-\(fcfFormatted)).",
                    "Negatif FCF kısa vadede kabul edilebilir (büyüme yatırımları) ama uzun vadede sorun.")
        }
        
        // FCF yield hesapla
        if let cap = marketCap, cap > 0 {
            let fcfYield = (fcf / cap) * 100
            switch fcfYield {
            case 8...:
                return (.excellent, 95,
                        "Mükemmel nakit üretimi! FCF Verimi: %\(String(format: "%.1f", fcfYield)).",
                        "Bu kadar yüksek FCF yield, şirketin değerinin altında fiyatlandığını gösterebilir.")
            case 5..<8:
                return (.good, 80,
                        "Güçlü nakit üretimi. FCF Verimi: %\(String(format: "%.1f", fcfYield)).",
                        "Sağlıklı nakit akışı. Temettü artışı veya geri alım beklenebilir.")
            case 3..<5:
                return (.neutral, 60,
                        "Normal nakit üretimi. FCF: \(fcfFormatted).",
                        "Yeterli nakit akışı var.")
            default:
                return (.warning, 40,
                        "Düşük nakit üretimi. FCF Verimi: %\(String(format: "%.1f", fcfYield)).",
                        "Nakit akışı piyasa değerine göre düşük. Büyüme mi, sorun mu araştır.")
            }
        }
        
        return (.good, 60, "Pozitif nakit akışı: \(fcfFormatted).", 
                "Şirket kar edip nakde dönüştürüyor. Bu sağlıklı bir işaret.")
    }
    
    // MARK: - Temettü Verimi Açıklamaları
    
    func explainDividendYield(value: Double?) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let yield = value else {
            return (.noData, 0, "Temettü verisi yok.",
                    "Temettü verimi, yıllık temettünün hisse fiyatına oranıdır.")
        }
        
        let yieldPercent = yield * 100 // Yahoo bazen 0-1 arası verir
        let displayYield = yieldPercent > 1 ? yieldPercent : yield * 100
        
        switch displayYield {
        case ..<0.5:
            return (.neutral, 30,
                    "Düşük temettü (%\(String(format: "%.1f", displayYield))). Büyüme hissesi.",
                    "Düşük temettü, şirketin karını büyümeye yatırdığı anlamına gelebilir.")
        case 0.5..<2.0:
            return (.neutral, 50,
                    "Mütevazı temettü (%\(String(format: "%.1f", displayYield))).",
                    "Temettü var ama gelir odaklı yatırımcılar için yetersiz.")
        case 2.0..<4.0:
            return (.good, 75,
                    "İyi temettü verimi (%\(String(format: "%.1f", displayYield))).",
                    "Düzenli gelir arayanlar için cazip.")
        case 4.0..<6.0:
            return (.excellent, 90,
                    "Yüksek temettü (%\(String(format: "%.1f", displayYield)))! Gelir odaklılar için ideal.",
                    "Bu seviye REITs ve utility şirketlerinde yaygın.")
        default:
            return (.warning, 60,
                    "Çok yüksek temettü (%\(String(format: "%.1f", displayYield))). Sürdürülebilir mi?",
                    "Aşırı yüksek temettü, ya fiyat düşmüş ya da temettü kesimi gelebilir işareti olabilir.")
        }
    }
    
    // MARK: - Büyüme (CAGR) Açıklamaları
    
    func explainCAGR(value: Double?, type: String) -> (status: AtlasMetricStatus, score: Double, explanation: String, educational: String) {
        guard let cagr = value else {
            return (.noData, 0, "\(type) CAGR verisi yok.",
                    "CAGR, yıllık bileşik büyüme oranıdır. 3-5 yıllık süreçte ortalama büyümeyi gösterir.")
        }
        
        switch cagr {
        case ..<(-10):
            return (.critical, 10,
                    "Ciddi daralma! \(type) yılda %\(String(format: "%.0f", abs(cagr))) azalıyor.",
                    "Şirket küçülüyor. Sektörel sorun mu, şirkete özel mi araştır.")
        case (-10)..<0:
            return (.bad, 30,
                    "Negatif büyüme. \(type) geriliyor.",
                    "Düşüş trendi var. Toparlanma planı önemli.")
        case 0..<5:
            return (.neutral, 50,
                    "Yavaş büyüme (%\(String(format: "%.0f", cagr))).",
                    "Olgun şirketler için normal. Temettü odaklı olabilir.")
        case 5..<10:
            return (.neutral, 60,
                    "Orta düzey büyüme (%\(String(format: "%.0f", cagr))).",
                    "Enflasyonun üstünde büyüme. Kabul edilebilir.")
        case 10..<20:
            return (.good, 75,
                    "İyi büyüme (%\(String(format: "%.0f", cagr))). Sektör ortalamasının üstünde.",
                    "Güçlü organik büyüme işareti.")
        case 20..<30:
            return (.excellent, 90,
                    "Güçlü büyüme! Yılda %\(String(format: "%.0f", cagr)) artış.",
                    "Bu hız, şirketin pazar payını hızla artırdığını gösterir.")
        default:
            return (.excellent, 95,
                    "Hiper büyüme! %\(String(format: "%.0f", cagr)) yıllık artış.",
                    "Bu seviye nadirdir ve genellikle yeni teknolojilerde görülür. Sürdürülebilirliği sorgula.")
        }
    }
}
