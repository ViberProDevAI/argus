import Foundation

extension FinanceTermsRepository {
    static let macroTerms: [FinanceTerm] = [
        FinanceTerm(
            id: "enflasyon",
            term: "Enflasyon",
            fullName: nil,
            definition: "Genel fiyat düzeyinin sürekli artması. TÜFE ile ölçülür. Yüksek enflasyon satın alma gücünü düşürür ve merkez bankalarını faiz artırmaya zorlar.",
            formula: "Enflasyon = (TÜFE(t) - TÜFE(t-1)) / TÜFE(t-1) × 100",
            argusUsage: "Chiron motoru enflasyon verilerini makro rejim tespitinde kullanır.",
            relatedTerms: ["TÜFE", "Faiz", "Merkez Bankası"],
            category: .macro
        ),
        FinanceTerm(
            id: "tufe",
            term: "TÜFE",
            fullName: "Tüketici Fiyat Endeksi",
            definition: "Tüketici sepetindeki mal ve hizmetlerin fiyat değişimini ölçen endeks. Enflasyonun temel göstergesi.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Enflasyon", "ÜFE", "Sepet"],
            category: .macro
        ),
        FinanceTerm(
            id: "faiz",
            term: "Politika Faizi",
            fullName: nil,
            definition: "Merkez bankasının para politikası aracı olarak belirlediği referans faiz oranı. TCMB haftalık repo faizi, FED federal funds rate.",
            formula: nil,
            argusUsage: "Chiron motoru faiz kararlarını rejim değişikliği tetikleyicisi olarak izler. Faiz artışı genellikle borsa için negatif.",
            relatedTerms: ["TCMB", "FED", "Parasal Sıkılaştırma"],
            category: .macro
        ),
        FinanceTerm(
            id: "gsyh",
            term: "GSYH",
            fullName: "Gayri Safi Yurt İçi Hasıla",
            definition: "Bir ülkede belirli dönemde üretilen tüm mal ve hizmetlerin toplam değeri. Ekonomik büyümenin temel göstergesi.",
            formula: "GSYH = C + I + G + (X - M)",
            argusUsage: nil,
            relatedTerms: ["Büyüme", "Resesyon", "Ekonomik Döngü"],
            category: .macro
        ),
        FinanceTerm(
            id: "resesyon",
            term: "Resesyon",
            fullName: "Durgunluk",
            definition: "Ekonomik aktivitenin daraldığı dönem. Teknik tanım: Ardışık iki çeyrekte GSYH daralması.",
            formula: nil,
            argusUsage: "Chiron motoru resesyon sinyallerini RISK_OFF rejimi ile ilişkilendirir.",
            relatedTerms: ["GSYH", "Ekonomik Döngü", "Ayı Piyasası"],
            category: .macro
        ),
        FinanceTerm(
            id: "vix",
            term: "VIX",
            fullName: "Volatilite Endeksi",
            definition: "S&P 500 opsiyon fiyatlarından türetilen beklenen volatilite ölçüsü. 'Korku endeksi' olarak da bilinir. 20 üzeri yüksek belirsizlik.",
            formula: nil,
            argusUsage: "Chiron motoru VIX'i risk-on/risk-off tespitinde kullanır. VIX > 30 risk-off sinyali.",
            relatedTerms: ["Volatilite", "Risk", "Korku"],
            category: .macro
        ),
        FinanceTerm(
            id: "kurriski",
            term: "Kur Riski",
            fullName: nil,
            definition: "Döviz kurlarındaki değişimlerin yatırım getirilerini etkileme riski. İhracatçı ve ithalatçı şirketleri farklı etkiler.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Dolar/TL", "Hedge", "Döviz"],
            category: .macro
        ),
        FinanceTerm(
            id: "caridenge",
            term: "Cari Denge",
            fullName: nil,
            definition: "Bir ülkenin dış dünya ile yaptığı mal, hizmet ve transfer işlemlerinin dengesi. Cari açık döviz ihtiyacı anlamına gelir.",
            formula: "Cari Denge = İhracat - İthalat + Net Gelirler + Net Transferler",
            argusUsage: nil,
            relatedTerms: ["İhracat", "İthalat", "Dış Ticaret"],
            category: .macro
        ),
        FinanceTerm(
            id: "issizlik",
            term: "İşsizlik Oranı",
            fullName: nil,
            definition: "İşgücüne katılanlar içinde iş arayanların oranı. Ekonomik sağlığın önemli göstergesi.",
            formula: "İşsizlik = İşsiz Sayısı / İşgücü × 100",
            argusUsage: nil,
            relatedTerms: ["İstihdam", "GSYH", "Ekonomik Döngü"],
            category: .macro
        ),
        FinanceTerm(
            id: "parasal",
            term: "Parasal Genişleme",
            fullName: "QE - Quantitative Easing",
            definition: "Merkez bankasının piyasadan varlık satın alarak para arzını artırması. Faizleri düşürür, varlık fiyatlarını yükseltir.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Merkez Bankası", "Faiz", "Likidite"],
            category: .macro
        ),
        FinanceTerm(
            id: "tapering",
            term: "Tapering",
            fullName: nil,
            definition: "Merkez bankasının varlık alım programını kademeli olarak azaltması. Parasal sıkılaştırmanın ilk adımı.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Parasal Genişleme", "FED", "Faiz"],
            category: .macro
        ),
        FinanceTerm(
            id: "yabanciakisi",
            term: "Yabancı Yatırımcı",
            fullName: nil,
            definition: "Yerleşik olmayan yatırımcıların borsadaki alım-satım aktivitesi. Net alış pozitif, net satış negatif.",
            formula: nil,
            argusUsage: "Chiron motoru yabancı yatırımcı akışını trend gücü ve rejim tespitinde kullanır.",
            relatedTerms: ["Portföy Akışı", "BIST", "Likidite"],
            category: .macro
        ),
        FinanceTerm(
            id: "tcmb",
            term: "TCMB",
            fullName: "Türkiye Cumhuriyet Merkez Bankası",
            definition: "Türkiye'nin para politikasını belirleyen kurum. Fiyat istikrarı temel amacı. PPK kararları piyasalar için kritik.",
            formula: nil,
            argusUsage: "Argus ekonomi takviminde TCMB PPK toplantıları önemli olaylar olarak işaretlenir.",
            relatedTerms: ["Faiz", "Enflasyon", "Para Politikası"],
            category: .macro
        ),
        FinanceTerm(
            id: "fed",
            term: "FED",
            fullName: "ABD Merkez Bankası",
            definition: "ABD para politikasını belirleyen kurum. Kararları global piyasaları etkiler. FOMC toplantıları kritik.",
            formula: nil,
            argusUsage: "Argus ekonomi takviminde FED kararları yüksek etki olayları olarak işaretlenir.",
            relatedTerms: ["Faiz", "Dolar", "FOMC"],
            category: .macro
        )
    ]
}
