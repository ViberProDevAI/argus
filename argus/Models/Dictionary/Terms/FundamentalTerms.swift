import Foundation

extension FinanceTermsRepository {
    static let fundamentalTerms: [FinanceTerm] = [
        FinanceTerm(
            id: "fk",
            term: "F/K",
            fullName: "Fiyat/Kazanç Oranı",
            definition: "Şirketin piyasa değerinin yıllık net kârına oranı. Yatırımcının her 1 TL kâr için kaç TL ödediğini gösterir. Sektör ortalamasıyla karşılaştırılmalı.",
            formula: "F/K = Hisse Fiyatı / Hisse Başına Kâr",
            argusUsage: "Atlas motoru F/K'yı %30 ağırlıkla değerlendirmeye alır. Sektör ortalamasının altındaki F/K ucuzluk işareti.",
            relatedTerms: ["PD/DD", "HBK", "Değerleme"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "pddd",
            term: "PD/DD",
            fullName: "Piyasa Değeri / Defter Değeri",
            definition: "Şirketin piyasa değerinin özkaynaklarına oranı. 1'in altı değerler şirketin defter değerinin altında işlem gördüğünü gösterir.",
            formula: "PD/DD = Piyasa Değeri / Özkaynaklar",
            argusUsage: "Atlas motorunun en ağırlıklı metriği (%40). PD/DD < 1 genellikle ucuzluk, > 2 pahalılık işareti.",
            relatedTerms: ["F/K", "Defter Değeri", "Özkaynaklar"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "favok",
            term: "FAVÖK",
            fullName: "Faiz Amortisman Vergi Öncesi Kâr",
            definition: "Şirketin operasyonel performansını ölçen metrik. Finansman ve muhasebe etkilerinden arındırılmış kârlılık gösterir.",
            formula: "FAVÖK = Net Kâr + Faiz + Vergi + Amortisman",
            argusUsage: nil,
            relatedTerms: ["EBITDA", "Net Kâr", "Operasyonel Kâr"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "fdfavok",
            term: "FD/FAVÖK",
            fullName: "Firma Değeri / FAVÖK",
            definition: "Şirketin toplam değerinin operasyonel kârlılığına oranı. Borçlu şirketleri karşılaştırmak için F/K'dan daha uygun.",
            formula: "FD/FAVÖK = (Piyasa Değeri + Net Borç) / FAVÖK",
            argusUsage: nil,
            relatedTerms: ["FAVÖK", "F/K", "Firma Değeri"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "hbk",
            term: "HBK",
            fullName: "Hisse Başına Kâr",
            definition: "Şirketin net kârının toplam hisse sayısına bölünmesiyle elde edilen değer. Kârlılık karşılaştırması için temel metrik.",
            formula: "HBK = Net Kâr / Toplam Hisse Sayısı",
            argusUsage: nil,
            relatedTerms: ["F/K", "Net Kâr", "Temettü"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "roe",
            term: "ROE",
            fullName: "Özkaynak Kârlılığı",
            definition: "Şirketin özkaynaklarını ne kadar verimli kullandığını gösteren oran. Yüksek ROE iyi yönetim ve rekabet avantajı işareti olabilir.",
            formula: "ROE = Net Kâr / Özkaynaklar × 100",
            argusUsage: nil,
            relatedTerms: ["ROA", "Özkaynaklar", "Kârlılık"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "roa",
            term: "ROA",
            fullName: "Aktif Kârlılığı",
            definition: "Şirketin toplam varlıklarını ne kadar verimli kullandığını gösteren oran.",
            formula: "ROA = Net Kâr / Toplam Varlıklar × 100",
            argusUsage: nil,
            relatedTerms: ["ROE", "Varlıklar", "Kârlılık"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "cagr",
            term: "CAGR",
            fullName: "Bileşik Yıllık Büyüme Oranı",
            definition: "Bir yatırımın veya metriğin belirli dönemdeki ortalama yıllık büyüme oranı. Düzensiz büyümeyi düzleştirerek karşılaştırma sağlar.",
            formula: "CAGR = (Son Değer / İlk Değer)^(1/n) - 1",
            argusUsage: "Atlas motoru gelir ve kâr CAGR'ını büyüme değerlendirmesinde kullanır.",
            relatedTerms: ["Büyüme", "Getiri", "Performans"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "temettu",
            term: "Temettü Verimi",
            fullName: nil,
            definition: "Hisse başına temettünün hisse fiyatına oranı. Yüksek temettü verimi gelir odaklı yatırımcılar için önemli.",
            formula: "Temettü Verimi = Hisse Başına Temettü / Hisse Fiyatı × 100",
            argusUsage: nil,
            relatedTerms: ["Temettü", "Getiri", "Pasif Gelir"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "netborc",
            term: "Net Borç",
            fullName: nil,
            definition: "Toplam finansal borçlardan nakit ve nakit benzerlerinin çıkarılmasıyla bulunan değer. Şirketin gerçek borçluluk durumunu gösterir.",
            formula: "Net Borç = Toplam Borç - Nakit ve Nakit Benzerleri",
            argusUsage: "Atlas motoru borçluluk analizinde net borç/özkaynak oranını kullanır.",
            relatedTerms: ["Borç/Özkaynak", "Likidite", "Mali Yapı"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "defterdeğeri",
            term: "Defter Değeri",
            fullName: nil,
            definition: "Şirketin bilançosundaki özkaynaklar toplamı. Varlıklardan borçların çıkarılmasıyla hesaplanır.",
            formula: "Defter Değeri = Toplam Varlıklar - Toplam Borçlar",
            argusUsage: nil,
            relatedTerms: ["PD/DD", "Özkaynaklar", "Bilanço"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "ciroorani",
            term: "Brüt Kâr Marjı",
            fullName: nil,
            definition: "Satış gelirlerinden satılan malın maliyetinin çıkarılmasıyla elde edilen brüt kârın satışlara oranı.",
            formula: "Brüt Kâr Marjı = (Satışlar - SMM) / Satışlar × 100",
            argusUsage: nil,
            relatedTerms: ["Net Kâr Marjı", "FAVÖK Marjı", "Kârlılık"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "carioran",
            term: "Cari Oran",
            fullName: nil,
            definition: "Dönen varlıkların kısa vadeli borçlara oranı. Şirketin kısa vadeli borçlarını ödeme kapasitesini gösterir. 1.5-2 arası ideal.",
            formula: "Cari Oran = Dönen Varlıklar / Kısa Vadeli Borçlar",
            argusUsage: nil,
            relatedTerms: ["Likidite", "Asit Test Oranı", "Mali Yapı"],
            category: .fundamental
        ),
        FinanceTerm(
            id: "peg",
            term: "PEG",
            fullName: "F/K Büyüme Oranı",
            definition: "F/K oranının beklenen kâr büyümesine bölünmesiyle hesaplanır. 1'in altı ucuz, 1'in üstü pahalı olarak yorumlanabilir.",
            formula: "PEG = F/K / Yıllık Kâr Büyümesi",
            argusUsage: nil,
            relatedTerms: ["F/K", "Büyüme", "Değerleme"],
            category: .fundamental
        )
    ]
}
