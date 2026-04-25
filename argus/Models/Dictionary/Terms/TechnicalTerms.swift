import Foundation

extension FinanceTermsRepository {
    static let technicalTerms: [FinanceTerm] = [
        FinanceTerm(
            id: "rsi",
            term: "RSI",
            fullName: "Göreceli Güç Endeksi",
            definition: "Fiyat hareketlerinin hızını ve değişimini ölçen momentum osilatörü. 0-100 arasında değer alır. 70 üzeri aşırı alım, 30 altı aşırı satım bölgesidir.",
            formula: "RSI = 100 - (100 / (1 + RS)), RS = Ortalama Kazanç / Ortalama Kayıp",
            argusUsage: "Orion motoru RSI'ı aşırı alım/satım tespitinde kullanır. 70 üzerinde dikkatli ol, 30 altında fırsat ara.",
            relatedTerms: ["TSI", "Momentum", "Osilatör"],
            category: .technical
        ),
        FinanceTerm(
            id: "tsi",
            term: "TSI",
            fullName: "Gerçek Güç Endeksi",
            definition: "Çift düzleştirilmiş momentum göstergesi. RSI'dan daha az gürültülü sinyal üretir. -100 ile +100 arasında değer alır.",
            formula: "TSI = 100 × (Düzleştirilmiş Momentum / Düzleştirilmiş Mutlak Momentum)",
            argusUsage: "Orion motorunun birincil momentum göstergesi. +25 üzeri yükseliş, -25 altı düşüş sinyali.",
            relatedTerms: ["RSI", "Momentum", "EMA"],
            category: .technical
        ),
        FinanceTerm(
            id: "macd",
            term: "MACD",
            fullName: "Hareketli Ortalama Yakınsama Iraksama",
            definition: "İki üstel hareketli ortalamanın farkını gösteren trend takip göstergesi. Sinyal çizgisi kesişimleri alım/satım sinyali üretir.",
            formula: "MACD = EMA(12) - EMA(26), Sinyal = EMA(9) of MACD",
            argusUsage: nil,
            relatedTerms: ["EMA", "SMA", "Trend"],
            category: .technical
        ),
        FinanceTerm(
            id: "sar",
            term: "SAR",
            fullName: "Parabolik SAR",
            definition: "Trend yönünü ve potansiyel dönüş noktalarını belirleyen gösterge. Fiyatın altındaysa yükseliş, üstündeyse düşüş trendi.",
            formula: "SAR = Önceki SAR + AF × (EP - Önceki SAR)",
            argusUsage: "Orion ve Phoenix motorlarının temel trend göstergesi. SAR kırılımları pozisyon kapama sinyali olarak değerlendirilir.",
            relatedTerms: ["Trend", "ADX", "Stop Loss"],
            category: .technical
        ),
        FinanceTerm(
            id: "adx",
            term: "ADX",
            fullName: "Ortalama Yön Endeksi",
            definition: "Trendin gücünü ölçer, yönünü değil. 25 üzeri güçlü trend, 20 altı zayıf/yatay piyasa anlamına gelir.",
            formula: "ADX = 100 × EMA(|+DI - -DI| / (+DI + -DI))",
            argusUsage: "Chiron motoru piyasa rejimini belirlerken ADX'i kullanır. ADX < 20 ise çapraz rejim, Orion devre dışı kalır.",
            relatedTerms: ["DMI", "Trend", "Volatilite"],
            category: .technical
        ),
        FinanceTerm(
            id: "ema",
            term: "EMA",
            fullName: "Üstel Hareketli Ortalama",
            definition: "Son fiyatlara daha fazla ağırlık veren hareketli ortalama. SMA'dan daha hızlı tepki verir.",
            formula: "EMA = Fiyat × k + EMA(dün) × (1-k), k = 2/(N+1)",
            argusUsage: nil,
            relatedTerms: ["SMA", "MACD", "Trend"],
            category: .technical
        ),
        FinanceTerm(
            id: "sma",
            term: "SMA",
            fullName: "Basit Hareketli Ortalama",
            definition: "Belirli bir dönemdeki kapanış fiyatlarının aritmetik ortalaması. Trend yönünü ve destek/direnç seviyelerini belirlemede kullanılır.",
            formula: "SMA = (P1 + P2 + ... + Pn) / n",
            argusUsage: nil,
            relatedTerms: ["EMA", "Trend", "Destek/Direnç"],
            category: .technical
        ),
        FinanceTerm(
            id: "bollinger",
            term: "Bollinger Bantları",
            fullName: nil,
            definition: "Fiyatın standart sapma bazlı üst ve alt bantlar içindeki hareketini gösteren volatilite göstergesi. Bantların daralması sıkışma, genişlemesi volatilite artışı anlamına gelir.",
            formula: "Üst Bant = SMA(20) + 2σ, Alt Bant = SMA(20) - 2σ",
            argusUsage: nil,
            relatedTerms: ["Volatilite", "SMA", "Standart Sapma"],
            category: .technical
        ),
        FinanceTerm(
            id: "fibonacci",
            term: "Fibonacci Düzeltme",
            fullName: nil,
            definition: "Fiyat düzeltmelerinin potansiyel destek/direnç seviyelerini belirlemek için kullanılan yatay çizgiler. Ana seviyeler: %23.6, %38.2, %50, %61.8.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Destek/Direnç", "Trend", "Geri Çekilme"],
            category: .technical
        ),
        FinanceTerm(
            id: "volume",
            term: "Hacim",
            fullName: "İşlem Hacmi",
            definition: "Belirli bir dönemde el değiştiren hisse senedi miktarı. Fiyat hareketlerinin gücünü doğrulamak için kullanılır. Yükselen fiyat + yükselen hacim = güçlü trend.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Likidite", "Trend Doğrulama"],
            category: .technical
        ),
        FinanceTerm(
            id: "divergence",
            term: "Uyumsuzluk",
            fullName: "Diverjans",
            definition: "Fiyat ve gösterge arasındaki zıt hareket. Pozitif uyumsuzluk: fiyat düşerken gösterge yükseliyor (potansiyel dönüş). Negatif uyumsuzluk bunun tersi.",
            formula: nil,
            argusUsage: "Orion motoru RSI ve TSI uyumsuzluklarını trend dönüş sinyali olarak değerlendirir.",
            relatedTerms: ["RSI", "TSI", "Trend Dönüşü"],
            category: .technical
        ),
        FinanceTerm(
            id: "supportresistance",
            term: "Destek/Direnç",
            fullName: nil,
            definition: "Destek: Fiyatın düşüşte durma eğilimi gösterdiği seviye. Direnç: Fiyatın yükselişte durma eğilimi gösterdiği seviye. Kırılımlar önemli sinyallerdir.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Breakout", "Trend", "Fibonacci"],
            category: .technical
        ),
        FinanceTerm(
            id: "breakout",
            term: "Kırılım",
            fullName: "Breakout",
            definition: "Fiyatın önemli bir destek veya direnç seviyesini geçmesi. Hacimle desteklenen kırılımlar daha güvenilirdir.",
            formula: nil,
            argusUsage: "Phoenix motoru kırılım stratejileri için optimize edilmiştir.",
            relatedTerms: ["Destek/Direnç", "Hacim", "Trend"],
            category: .technical
        ),
        FinanceTerm(
            id: "momentum",
            term: "Momentum",
            fullName: nil,
            definition: "Fiyat değişiminin hızı. Pozitif momentum yükseliş ivmesi, negatif momentum düşüş ivmesi gösterir.",
            formula: "Momentum = Güncel Fiyat - n Gün Önceki Fiyat",
            argusUsage: "Orion motoru momentum bazlı bir teknik analiz motorudur.",
            relatedTerms: ["RSI", "TSI", "MACD"],
            category: .technical
        ),
        FinanceTerm(
            id: "trendline",
            term: "Trend Çizgisi",
            fullName: nil,
            definition: "Ardışık dip veya tepe noktalarını birleştiren doğru. Yükselen trend çizgisi dipleri, düşen trend çizgisi tepeleri birleştirir.",
            formula: nil,
            argusUsage: nil,
            relatedTerms: ["Trend", "Destek/Direnç", "Kanal"],
            category: .technical
        )
    ]
}
