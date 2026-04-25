import Foundation

extension FinanceTermsRepository {
    static let tradingTerms: [FinanceTerm] = [
        FinanceTerm(
            id: "emir",
            term: "Emir",
            fullName: "Order",
            definition: "Alım veya satım talimatı. Limit emir belirtilen fiyattan, piyasa emri anlık en iyi fiyattan işlem yapar.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Limit Emir", "Piyasa Emri", "Stop"],
            category: .trading
        ),
        FinanceTerm(
            id: "limitemir",
            term: "Limit Emir",
            fullName: nil,
            definition: "Belirtilen fiyattan veya daha iyi fiyattan gerçekleşecek alım/satım emri. Fiyat kontrolü sağlar ama gerçekleşme garantisi yok.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Piyasa Emri", "Emir", "Fiyat"],
            category: .trading
        ),
        FinanceTerm(
            id: "piyasaemri",
            term: "Piyasa Emri",
            fullName: "Market Order",
            definition: "Anlık en iyi fiyattan hemen gerçekleşen emir. Hızlı işlem garantisi ama fiyat kontrolü yok.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Limit Emir", "Emir", "Slippage"],
            category: .trading
        ),
        FinanceTerm(
            id: "stoploss",
            term: "Zarar Durdur",
            fullName: "Stop Loss",
            definition: "Belirli bir fiyata ulaşıldığında otomatik satış yapan emir. Kayıpları sınırlamak için kullanılır.",
            formula: nil,
            argusUsage: "Argus risk yönetimi modülü her pozisyon için zarar durdur seviyesi önerir.",
            relatedTerms: ["Risk Yönetimi", "Emir", "Trailing Stop"],
            category: .trading
        ),
        FinanceTerm(
            id: "takeprofit",
            term: "Kâr Al",
            fullName: "Take Profit",
            definition: "Belirli bir kâr seviyesine ulaşıldığında otomatik satış yapan emir. Kârı realize etmek için kullanılır.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Zarar Durdur", "Emir", "Risk/Ödül"],
            category: .trading
        ),
        FinanceTerm(
            id: "lot",
            term: "Lot",
            fullName: nil,
            definition: "Borsada işlem yapılabilen minimum hisse adedi. BIST'te 1 lot = 1 adet hisse.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["İşlem", "Miktar", "Emir"],
            category: .trading
        ),
        FinanceTerm(
            id: "pozisyon",
            term: "Pozisyon",
            fullName: nil,
            definition: "Yatırımcının sahip olduğu varlık durumu. Long pozisyon: alınmış hisse. Short pozisyon: açığa satılmış hisse.",
            formula: nil,
            argusUsage: "Argus portföy modülü tüm açık pozisyonları ve performanslarını takip eder.",
            relatedTerms: ["Long", "Short", "Portföy"],
            category: .trading
        ),
        FinanceTerm(
            id: "komisyon",
            term: "Komisyon",
            fullName: nil,
            definition: "Aracı kurumun işlem başına aldığı ücret. Genellikle işlem tutarının binde birkaçı kadar.",
            formula: nil,
            argusUsage: "Argus backtest modülü komisyon maliyetlerini simülasyona dahil eder.",
            relatedTerms: ["İşlem Maliyeti", "Slippage", "Aracı Kurum"],
            category: .trading
        ),
        FinanceTerm(
            id: "slippage",
            term: "Kayma",
            fullName: "Slippage",
            definition: "Beklenen fiyat ile gerçekleşen fiyat arasındaki fark. Düşük likidite ve yüksek volatilitede artar.",
            formula: "Kayma = Gerçekleşen Fiyat - Beklenen Fiyat",
            argusUsage: "Argus backtest modülü kayma maliyetlerini simülasyona dahil eder.",
            relatedTerms: ["Likidite", "Piyasa Emri", "İşlem Maliyeti"],
            category: .trading
        ),
        FinanceTerm(
            id: "kaldirac",
            term: "Kaldıraç",
            fullName: "Leverage",
            definition: "Sahip olunandan daha büyük pozisyon açmayı sağlayan mekanizma. Hem kârı hem zararı büyütür.",
            formula: "Kaldıraç = Toplam Pozisyon / Özkaynak",
            argusUsage: nil,
            relatedTerms: ["Marjin", "Risk", "Teminat"],
            category: .trading
        ),
        FinanceTerm(
            id: "marjin",
            term: "Teminat",
            fullName: "Margin",
            definition: "Kaldıraçlı işlem yapmak için yatırılması gereken minimum tutar.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Kaldıraç", "Marjin Call", "Risk"],
            category: .trading
        ),
        FinanceTerm(
            id: "portfoy",
            term: "Portföy",
            fullName: nil,
            definition: "Yatırımcının sahip olduğu tüm varlıkların bütünü. Çeşitlendirme riski azaltır.",
            formula: nil,
            argusUsage: "Argus portföy modülü pozisyon takibi, performans analizi ve risk yönetimi sağlar.",
            relatedTerms: ["Çeşitlendirme", "Varlık Dağılımı", "Risk"],
            category: .trading
        ),
        FinanceTerm(
            id: "cesitlendirme",
            term: "Çeşitlendirme",
            fullName: "Diversification",
            definition: "Riski azaltmak için yatırımları farklı varlıklar arasında dağıtma stratejisi. 'Tüm yumurtaları aynı sepete koyma.'",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Portföy", "Risk", "Korelasyon"],
            category: .trading
        ),
        FinanceTerm(
            id: "riskodul",
            term: "Risk/Ödül Oranı",
            fullName: nil,
            definition: "Potansiyel kârın potansiyel zarara oranı. 1:2 oranı, 1 birim risk için 2 birim kâr hedefi anlamına gelir.",
            formula: "R/Ö = (Hedef Fiyat - Giriş) / (Giriş - Stop Loss)",
            argusUsage: "Argus sinyal sisteminde her sinyal için risk/ödül oranı hesaplanır.",
            relatedTerms: ["Zarar Durdur", "Kâr Al", "Risk Yönetimi"],
            category: .trading
        ),
        FinanceTerm(
            id: "backtest",
            term: "Geriye Dönük Test",
            fullName: "Backtest",
            definition: "Bir stratejinin geçmiş veriler üzerinde test edilmesi. Stratejinin performansını değerlendirmede kullanılır.",
            formula: nil,
            argusUsage: "Argus Lab modülü stratejilerin geriye dönük testini yapma imkanı sunar.",
            relatedTerms: ["Strateji", "Simülasyon", "Performans"],
            category: .trading
        )
    ]
}
