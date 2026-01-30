import Foundation

extension FinanceTermsRepository {
    static let marketTerms: [FinanceTerm] = [
        FinanceTerm(
            id: "boga",
            term: "Boğa Piyasası",
            fullName: nil,
            definition: "Fiyatların genel olarak yükseldiği, iyimserliğin hakim olduğu piyasa dönemi. Genellikle %20 üzeri yükseliş boğa piyasası olarak kabul edilir.",
            formula: nil,
            argusUsage: "Chiron motoru boğa piyasasını TREND rejimi olarak sınıflandırır.",
            relatedTerms: ["Ayı Piyasası", "Ralli", "Trend"],
            category: .market
        ),
        FinanceTerm(
            id: "ayi",
            term: "Ayı Piyasası",
            fullName: nil,
            definition: "Fiyatların genel olarak düştüğü, karamsarlığın hakim olduğu piyasa dönemi. Genellikle %20 üzeri düşüş ayı piyasası olarak kabul edilir.",
            formula: nil,
            argusUsage: "Chiron motoru ayı piyasasını RISK_OFF rejimi olarak sınıflandırabilir.",
            relatedTerms: ["Boğa Piyasası", "Düzeltme", "Trend"],
            category: .market
        ),
        FinanceTerm(
            id: "ralli",
            term: "Ralli",
            fullName: nil,
            definition: "Fiyatlarda kısa sürede yaşanan hızlı ve güçlü yükseliş hareketi.",
            formula: nil,
            argusUsage: "Phoenix motoru ralli yakalama stratejileri için optimize edilmiştir.",
            relatedTerms: ["Boğa Piyasası", "Breakout", "Momentum"],
            category: .market
        ),
        FinanceTerm(
            id: "duzeltme",
            term: "Düzeltme",
            fullName: nil,
            definition: "Yükselen bir trendde geçici fiyat düşüşü. Genellikle %10-20 arası düşüşler düzeltme olarak adlandırılır.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Ayı Piyasası", "Geri Çekilme", "Trend"],
            category: .market
        ),
        FinanceTerm(
            id: "likidite",
            term: "Likidite",
            fullName: nil,
            definition: "Bir varlığın fiyatını önemli ölçüde etkilemeden hızla alınıp satılabilme özelliği. Yüksek işlem hacmi yüksek likidite anlamına gelir.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Hacim", "Spread", "Derinlik"],
            category: .market
        ),
        FinanceTerm(
            id: "volatilite",
            term: "Volatilite",
            fullName: "Oynaklık",
            definition: "Fiyat dalgalanmalarının büyüklüğü. Yüksek volatilite yüksek risk ve potansiyel getiri anlamına gelir.",
            formula: "Volatilite = Standart Sapma × √252 (yıllık)",
            argusUsage: "Chiron motoru volatiliteyi rejim tespitinde kullanır. Yüksek volatilite risk-off sinyali olabilir.",
            relatedTerms: ["VIX", "Risk", "Standart Sapma"],
            category: .market
        ),
        FinanceTerm(
            id: "spread",
            term: "Spread",
            fullName: "Alış-Satış Farkı",
            definition: "En iyi alış (bid) ve en iyi satış (ask) fiyatı arasındaki fark. Dar spread yüksek likidite göstergesi.",
            formula: "Spread = Satış Fiyatı - Alış Fiyatı",
            argusUsage: nil,
            relatedTerms: ["Likidite", "Bid/Ask", "İşlem Maliyeti"],
            category: .market
        ),
        FinanceTerm(
            id: "acigapozisyon",
            term: "Açığa Satış",
            fullName: "Short Pozisyon",
            definition: "Ödünç alınan hissenin satılıp daha düşük fiyattan geri alınması stratejisi. Düşen piyasalardan kâr elde etme yöntemi.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Long Pozisyon", "Kaldıraç", "Risk"],
            category: .market
        ),
        FinanceTerm(
            id: "piyasadegeri",
            term: "Piyasa Değeri",
            fullName: "Market Cap",
            definition: "Şirketin toplam hisse sayısının hisse fiyatıyla çarpılmasıyla hesaplanan değer.",
            formula: "Piyasa Değeri = Hisse Fiyatı × Toplam Hisse Sayısı",
            argusUsage: nil,
            relatedTerms: ["Firma Değeri", "Halka Açıklık", "PD/DD"],
            category: .market
        ),
        FinanceTerm(
            id: "halkaaciklik",
            term: "Halka Açıklık Oranı",
            fullName: nil,
            definition: "Şirketin borsada işlem gören hisse oranı. Düşük halka açıklık manipülasyon riskini artırabilir.",
            formula: "Halka Açıklık = Borsada İşlem Gören Hisse / Toplam Hisse",
            argusUsage: nil,
            relatedTerms: ["Likidite", "Piyasa Değeri"],
            category: .market
        ),
        FinanceTerm(
            id: "endeks",
            term: "Endeks",
            fullName: nil,
            definition: "Belirli kriterlere göre seçilmiş hisse senetlerinin performansını ölçen gösterge. BIST100, XU030 gibi.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["BIST100", "Benchmark", "Portföy"],
            category: .market
        ),
        FinanceTerm(
            id: "seans",
            term: "Seans",
            fullName: nil,
            definition: "Borsanın işlem yapılan zaman dilimi. BIST'te sürekli işlem seansı 10:00-18:00 arasında.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Açılış", "Kapanış", "İşlem Saatleri"],
            category: .market
        ),
        FinanceTerm(
            id: "tavan",
            term: "Tavan/Taban",
            fullName: nil,
            definition: "Borsanın belirlediği günlük maksimum fiyat değişim limitleri. BIST'te genellikle %10 tavan/taban limiti uygulanır.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Limit", "Volatilite", "Devre Kesici"],
            category: .market
        ),
        FinanceTerm(
            id: "devrekesici",
            term: "Devre Kesici",
            fullName: nil,
            definition: "Aşırı fiyat hareketlerinde işlemleri geçici olarak durduran mekanizma. Panik satışlarını önlemeyi amaçlar.",
            formula: nil,
            argusUsage: "Argus'un Heimdall modülü veri akışında kendi devre kesici mantığını kullanır.",
            relatedTerms: ["Tavan/Taban", "Volatilite", "Risk Yönetimi"],
            category: .market
        )
    ]
}
