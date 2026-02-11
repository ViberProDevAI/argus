import Foundation

enum BISTBilancoError: LocalizedError {
    case veriCekilemedi(sembol: String, hata: String)
    case eksikVeri(sembol: String, detay: String)
    
    var errorDescription: String? {
        switch self {
        case .veriCekilemedi(let sembol, let hata):
            return "Bilanço verisi çekilemedi (\(sembol)): \(hata)"
        case .eksikVeri(let sembol, let detay):
            return "Eksik veri (\(sembol)): \(detay)"
        }
    }
}

// MARK: - BIST Bilanço Analiz Motoru
// Atlas V2 yapısının BIST'e uyarlanmış hali

actor BISTBilancoEngine {
    static let shared = BISTBilancoEngine()
    
    private let benchmarks = BISTSektorBenchmarks.shared
    
    // Cache
    private var cache: [String: BISTBilancoSonuc] = [:]
    private let cacheTTL: TimeInterval = 3600 // 1 saat
    
    private init() {}
    
    // MARK: - Ana Analiz Fonksiyonu
    
    func analiz(sembol: String, yenidenYukle: Bool = false) async throws -> BISTBilancoSonuc {
        // Cache kontrolü
        if !yenidenYukle, let cached = cache[sembol] {
            if Date().timeIntervalSince(cached.tarih) < cacheTTL {
                return cached
            }
        }
        
        // 1. Veri çek (BorsaPy - İş Yatırım)
        print("📊 BIST Bilanço: \(sembol) için veri çekiliyor (BorsaPy)...")
        
        let finansallar: FinancialsData
        var quote: Quote?
        
        do {
            async let bistFinTask = BorsaPyProvider.shared.getFinancialStatements(symbol: sembol)
            async let quoteTask = HeimdallOrchestrator.shared.requestQuote(symbol: sembol)
            
            let bistFin = try await bistFinTask
            quote = try? await quoteTask
            
            finansallar = convertBistToFinancials(bist: bistFin, quote: quote)
            
            print("✅ BIST Bilanço: \(sembol) veri alındı (BorsaPy). F/K: \(finansallar.peRatio ?? -1)")
        } catch {
            print("⚠️ BIST Bilanço: İş Yatırım API hatası: \(error)")
            print("📡 BIST Bilanço: Yahoo/FMP fallback deneniyor...")
            
            // FALLBACK: HeimdallOrchestrator üzerinden Yahoo/FMP'den veri çek
            do {
                quote = try? await HeimdallOrchestrator.shared.requestQuote(symbol: sembol)
                finansallar = try await HeimdallOrchestrator.shared.requestFundamentals(symbol: sembol)
                print("✅ BIST Bilanço: \(sembol) Yahoo/FMP fallback başarılı. F/K: \(finansallar.peRatio ?? -1)")
            } catch let fallbackError {
                print("❌ BIST Bilanço: Fallback da başarısız: \(fallbackError)")
                throw BISTBilancoError.veriCekilemedi(
                    sembol: sembol, 
                    hata: "İş Yatırım API bakımda ve alternatif kaynaklar da yanıt vermiyor. Lütfen daha sonra tekrar deneyin."
                )
            }
        }
        
        // 3. Sektör benchmark'ını al
        let sektorBenchmark = benchmarks.getBenchmark(sektor: nil) // TODO: Sektör bilgisi ekle
        
        // 4. Her bölümü analiz et ve skorla
        let degerlemeVerisi = analizDegerleme(finansallar: finansallar, quote: quote, benchmark: sektorBenchmark)
        let karlilikVerisi = analizKarlilik(finansallar: finansallar, benchmark: sektorBenchmark)
        let buyumeVerisi = analizBuyume(finansallar: finansallar)
        let saglikVerisi = analizSaglik(finansallar: finansallar)
        let nakitVerisi = analizNakit(finansallar: finansallar)
        let temettuVerisi = analizTemettu(finansallar: finansallar)
        let riskVerisi = analizRisk(finansallar: finansallar, quote: quote)
        
        // 5. Bölüm skorlarını hesapla (SADECE VERİ MEVCUT OLANLAR)
        // 5. Bölüm skorlarını hesapla (SADECE VERİ MEVCUT OLANLAR)
        let degerleme = hesaplaBolumSkoru(degerlemeVerisi.tumMetrikler)
        let karlilik = hesaplaBolumSkoru(karlilikVerisi.tumMetrikler)
        let buyume = 50.0   // Veri yok - default  
        let saglik = hesaplaBolumSkoru(saglikVerisi.tumMetrikler)
        let nakit = 50.0    // Veri yok - default
        let temettu = hesaplaBolumSkoru(temettuVerisi.tumMetrikler)
        
        // 6. Toplam skor (Ağırlıklı Ortalama)
        // Veri kalitesine göre dinamik ağırlıklandırma yapılabilir
        // Şimdilik Değerleme ve Karlılık en güvenilir veriler
        var toplamPuan = 0.0
        var toplamAgirlik = 0.0
        
        // Değerleme (%40)
        if degerleme > 0 {
            toplamPuan += degerleme * 0.4
            toplamAgirlik += 0.4
        }
        
        // Karlılık (%40)
        if karlilik > 0 {
            toplamPuan += karlilik * 0.4
            toplamAgirlik += 0.4
        }
        
        // Sağlık (%20)
        if saglik > 0 && saglik != 50 { // 50 default ise alma
            toplamPuan += saglik * 0.2
            toplamAgirlik += 0.2
        }
        
        let toplamSkor = toplamAgirlik > 0 ? (toplamPuan / toplamAgirlik) : 50.0
        
        // 7. Şirket profili
        let profil = BISTSirketProfili(
            sembol: sembol,
            isim: quote?.shortName ?? sembol.replacingOccurrences(of: ".IS", with: ""),
            sektor: nil,
            altSektor: nil,
            piyasaDegeri: finansallar.marketCap,
            formatliPiyasaDegeri: BISTMetrik.formatla(finansallar.marketCap),
            halkaAciklikOrani: nil,
            paraBirimi: "TRY"
        )
        
        // 8. Öne çıkanlar ve uyarılar
        let (oneCikanlar, uyarilar) = olusturOneCikanlar(
            degerleme: degerlemeVerisi,
            karlilik: karlilikVerisi,
            buyume: buyumeVerisi,
            saglik: saglikVerisi,
            nakit: nakitVerisi
        )
        
        // 9. Özet yorum
        let ozet = olusturOzet(
            sembol: sembol,
            toplamSkor: toplamSkor,
            karlilik: karlilik,
            degerleme: degerleme,
            buyume: buyume,
            saglik: saglik
        )
        
        // 10. Sonuç oluştur
        let sonuc = BISTBilancoSonuc(
            sembol: sembol,
            profil: profil,
            toplamSkor: toplamSkor,
            degerleme: degerleme,
            karlilik: karlilik,
            buyume: buyume,
            saglik: saglik,
            nakit: nakit,
            temettu: temettu,
            degerlemeVerisi: degerlemeVerisi,
            karlilikVerisi: karlilikVerisi,
            buyumeVerisi: buyumeVerisi,
            saglikVerisi: saglikVerisi,
            nakitVerisi: nakitVerisi,
            temettuVerisi: temettuVerisi,
            riskVerisi: riskVerisi,
            ozet: ozet,
            oneCikanlar: oneCikanlar,
            uyarilar: uyarilar
        )
        
        // Cache'e kaydet
        cache[sembol] = sonuc
        
        return sonuc
    }
    
    // MARK: - Değerleme Analizi
    
    private func analizDegerleme(finansallar: FinancialsData, quote: Quote?, benchmark: BISTSektorBenchmark) -> BISTDegerlemeVerisi {
        let fk = olusturMetrik(
            id: "fk",
            isim: "F/K (Fiyat/Kazanç)",
            deger: finansallar.peRatio,
            sektorOrt: benchmark.ortalamaFK,
            formul: "Hisse Fiyatı / Hisse Başına Kar",
            egitim: "F/K oranı, yatırımcıların şirketin 1 TL kazancı için kaç TL ödediğini gösterir. Düşük F/K değerli bir hisse ucuz olabilir ama nedenini araştırmak önemlidir."
        ) { deger, ort in
            if deger < 0 { return (.kotu, 20, "Şirket zarar ediyor.") }
            if deger < ort * 0.7 { return (.mukemmel, 90, "Sektör ortalamasının çok altında, ucuz!") }
            if deger < ort { return (.iyi, 75, "Sektöre göre uygun fiyatlı.") }
            if deger < ort * 1.5 { return (.notr, 50, "Sektör ortalamasına yakın.") }
            return (.dikkat, 30, "Sektör ortalamasının üstünde, pahalı sayılabilir.")
        }
        
        let pddd = olusturMetrik(
            id: "pddd",
            isim: "PD/DD (Piyasa Değeri/Defter Değeri)",
            deger: finansallar.priceToBook, // priceToBook kullan
            sektorOrt: benchmark.ortalamaPDDD,
            formul: "Piyasa Değeri / Özsermaye",
            egitim: "PD/DD 1'in altındaysa, şirket defterlerindeki değerinin altında fiyatlanıyor demektir. Ancak bu bazen finansal sıkıntıya işaret edebilir."
        ) { deger, ort in
            if deger < 0.5 { return (.dikkat, 40, "Çok düşük - finansal sıkıntı işareti olabilir.") }
            if deger < 1.0 { return (.iyi, 80, "Defter değerinin altında, potansiyel fırsat.") }
            if deger < ort { return (.iyi, 70, "Sektör ortalamasının altında.") }
            if deger < ort * 1.5 { return (.notr, 50, "Makul değerleme.") }
            return (.dikkat, 30, "Yüksek PD/DD - büyüme beklentisi yüksek veya aşırı değerli.")
        }
        
        let fdFavok = olusturMetrik(
            id: "fdFavok",
            isim: "FD/FAVÖK",
            deger: finansallar.evToEbitda,
            sektorOrt: 8.0, // Genel ortalama
            formul: "Firma Değeri / FAVÖK",
            egitim: "FD/FAVÖK, şirketin operasyonel kârlılığına göre ne kadar pahalı olduğunu gösterir. Borç dahil değerlemedir, F/K'den daha kapsamlıdır."
        ) { deger, ort in
            if deger < 0 { return (.kotu, 20, "Negatif FAVÖK - şirket operasyonel zarar ediyor.") }
            if deger < 5 { return (.mukemmel, 90, "Çok ucuz değerleme!") }
            if deger < 8 { return (.iyi, 75, "Uygun fiyatlı.") }
            if deger < 12 { return (.notr, 50, "Ortalama değerleme.") }
            return (.dikkat, 30, "Yüksek değerleme.")
        }
        
        // PEG için büyüme verisi gerekiyor - basitleştirilmiş
        let fkBuyume = BISTMetrik(
            id: "fkBuyume",
            isim: "F/K / Büyüme (PEG)",
            deger: nil, // Büyüme verisi geldiğinde hesaplanacak
            durum: .veriYok,
            skor: 0,
            aciklama: "Büyüme verisi gerekli.",
            egitimNotu: "PEG oranı, F/K'yı şirketin büyüme oranına böler. 1'in altı ucuz, 1'in üstü pahalı kabul edilir."
        )
        
        let eps = olusturMetrik(
            id: "eps",
            isim: "Hisse Başına Kar (EPS)",
            deger: finansallar.earningsPerShare,
            sektorOrt: nil,
            formul: "Net Kar / Ödenmiş Sermaye",
            egitim: "Hisse başına kar, şirketin her bir hisse senedi için ne kadar kar ürettiğini gösterir. Temettü ödeme potansiyelinin ana kaynağıdır."
        ) { deger, _ in
            if deger < 0 { return (.kotu, 20, "Zarar: Hisse başı eksi yazıyor.") }
            if deger > 0 { return (.iyi, 80, "Pozitif kar üretimi.") }
            return (.notr, 50, "Nötr")
        }
        
        return BISTDegerlemeVerisi(fk: fk, pddd: pddd, fdFavok: fdFavok, fkBuyume: fkBuyume, eps: eps)
    }
    
    // MARK: - Karlılık Analizi
    
    private func analizKarlilik(finansallar: FinancialsData, benchmark: BISTSektorBenchmark) -> BISTKarlilikVerisi {
        let roe = olusturMetrik(
            id: "roe",
            isim: "Özsermaye Kârlılığı (ROE)",
            deger: finansallar.returnOnEquity, // Zaten yüzde cinsinden geliyor
            sektorOrt: benchmark.ortalamaROE,
            formul: "Net Kâr / Özsermaye × 100",
            egitim: "ROE, şirketin hissedarların parasıyla ne kadar verimli kâr ürettiğini gösterir. Yüksek ROE genellikle iyidir, ancak yüksek borçla şişirilebilir."
        ) { deger, ort in
            if deger < 0 { return (.kotu, 15, "Negatif ROE - şirket zarar ediyor.") }
            if deger < 5 { return (.dikkat, 30, "Düşük karlılık.") }
            if deger < ort * 0.8 { return (.notr, 50, "Sektör ortalamasının altında.") }
            if deger < ort * 1.2 { return (.iyi, 70, "Sektör ortalamasına yakın.") }
            if deger < 30 { return (.mukemmel, 85, "Güçlü karlılık!") }
            return (.mukemmel, 95, "Olağanüstü karlılık!")
        }
        
        let roa = olusturMetrik(
            id: "roa",
            isim: "Aktif Kârlılığı (ROA)",
            deger: finansallar.returnOnAssets, // Zaten yüzde cinsinden geliyor
            sektorOrt: 5.0, // Genel ortalama
            formul: "Net Kâr / Toplam Aktifler × 100",
            egitim: "ROA, şirketin tüm varlıklarından ne kadar verim aldığını ölçer. Borç etkisinden arındırılmıştır."
        ) { deger, ort in
            if deger < 0 { return (.kotu, 15, "Negatif - zarar ediliyor.") }
            if deger < 2 { return (.dikkat, 35, "Düşük aktif verimliliği.") }
            if deger < ort { return (.notr, 50, "Ortalama aktif verimliliği.") }
            if deger < 10 { return (.iyi, 75, "İyi aktif verimliliği.") }
            return (.mukemmel, 90, "Mükemmel aktif verimliliği!")
        }
        
        let netMarj = olusturMetrik(
            id: "netMarj",
            isim: "Net Kâr Marjı",
            deger: finansallar.profitMargin, // Zaten yüzde cinsinden geliyor
            sektorOrt: benchmark.ortalamaNetKarMarji,
            formul: "Net Kâr / Toplam Gelir × 100",
            egitim: "Net kâr marjı, şirketin her 100 TL gelirden kaç TL net kâr elde ettiğini gösterir."
        ) { deger, ort in
            if deger < 0 { return (.kotu, 15, "Zarar ediliyor.") }
            if deger < 5 { return (.dikkat, 40, "Düşük marj - fiyatlandırma gücü zayıf.") }
            if deger < ort { return (.notr, 55, "Sektör ortalamasının altında.") }
            if deger < ort * 1.5 { return (.iyi, 75, "İyi kâr marjı.") }
            return (.mukemmel, 90, "Güçlü fiyatlandırma gücü!")
        }
        
        let brutMarj = BISTMetrik(
            id: "brutMarj",
            isim: "Brüt Kâr Marjı",
            deger: finansallar.grossMargin, // Zaten yüzde cinsinden geliyor
            durum: finansallar.grossMargin != nil ? .notr : .veriYok,
            skor: finansallar.grossMargin != nil ? 50 : 0,
            aciklama: finansallar.grossMargin != nil ? "Hesaplandı." : "Veri yok.",
            egitimNotu: "Brüt kâr marjı = (Gelir - Satış Maliyeti) / Gelir. Üretim verimliliğini gösterir."
        )
        
        return BISTKarlilikVerisi(ozsermayeKarliligi: roe, aktifKarliligi: roa, netKarMarji: netMarj, brutKarMarji: brutMarj)
    }
    
    // MARK: - Büyüme Analizi
    
    private func analizBuyume(finansallar: FinancialsData) -> BISTBuyumeVerisi {
        let gelirB = olusturMetrik(
            id: "gelirBuyume",
            isim: "Gelir Büyümesi (YoY)",
            deger: finansallar.revenueGrowth, // Zaten yüzde cinsinden geliyor
            sektorOrt: nil,
            formul: "(Bu Yıl Gelir - Geçen Yıl Gelir) / Geçen Yıl Gelir × 100",
            egitim: "Yıllık gelir büyümesi, şirketin satışlarını ne kadar artırdığını gösterir. Enflasyonun üstünde büyüme önemlidir."
        ) { deger, _ in
            if deger < -10 { return (.kotu, 20, "Ciddi gelir düşüşü!") }
            if deger < 0 { return (.dikkat, 40, "Gelir azalıyor.") }
            if deger < 10 { return (.notr, 55, "Düşük büyüme.") }
            if deger < 30 { return (.iyi, 75, "Sağlıklı büyüme.") }
            return (.mukemmel, 90, "Güçlü büyüme!")
        }
        
        let karB = olusturMetrik(
            id: "karBuyume",
            isim: "Net Kâr Büyümesi",
            deger: finansallar.earningsGrowth, // Zaten yüzde cinsinden geliyor
            sektorOrt: nil,
            formul: "(Bu Yıl Net Kâr - Geçen Yıl Net Kâr) / Geçen Yıl Net Kâr × 100",
            egitim: "Net kâr büyümesi, şirketin kârlılığını ne kadar artırdığını gösterir. Gelirden bile önemlidir."
        ) { deger, _ in
            if deger < -20 { return (.kotu, 15, "Ciddi kâr düşüşü!") }
            if deger < 0 { return (.dikkat, 35, "Kârlar azalıyor.") }
            if deger < 15 { return (.notr, 55, "Düşük kâr büyümesi.") }
            if deger < 40 { return (.iyi, 75, "İyi kâr büyümesi.") }
            return (.mukemmel, 90, "Mükemmel kâr büyümesi!")
        }
        
        // FAVÖK büyümesi için veri gerekiyor
        let favokB: BISTMetrik? = nil
        
        return BISTBuyumeVerisi(gelirBuyumesi: gelirB, karBuyumesi: karB, favokBuyumesi: favokB)
    }
    
    // MARK: - Sağlık Analizi
    
    private func analizSaglik(finansallar: FinancialsData) -> BISTSaglikVerisi {
        let borcOz = olusturMetrik(
            id: "borcOz",
            isim: "Borç/Özsermaye",
            deger: finansallar.debtToEquity.map { $0 / 100 }, // Genellikle % olarak gelir
            sektorOrt: 1.0,
            formul: "Toplam Borç / Özsermaye",
            egitim: "Borç/Özsermaye oranı, şirketin finansman yapısını gösterir. 1'in altı sağlıklı kabul edilir, 2'nin üstü riskli olabilir."
        ) { deger, _ in
            if deger < 0 { return (.veriYok, 0, "Hesaplanamadı.") }
            if deger < 0.3 { return (.mukemmel, 95, "Çok düşük borç - güçlü bilanço!") }
            if deger < 0.7 { return (.iyi, 80, "Düşük borç seviyesi.") }
            if deger < 1.5 { return (.notr, 55, "Orta düzey borç.") }
            if deger < 2.5 { return (.dikkat, 35, "Yüksek borç - dikkatli olun.") }
            return (.kotu, 15, "Çok yüksek borç - riskli!")
        }
        
        let cariOran = olusturMetrik(
            id: "cariOran",
            isim: "Cari Oran",
            deger: finansallar.currentRatio,
            sektorOrt: 1.5,
            formul: "Dönen Varlıklar / Kısa Vadeli Borçlar",
            egitim: "Cari oran, şirketin kısa vadeli borçlarını ödeme kapasitesini gösterir. 1.5'in üstü güvenli kabul edilir."
        ) { deger, _ in
            if deger < 0.5 { return (.kritik, 10, "Ciddi likidite sorunu!") }
            if deger < 1.0 { return (.kotu, 30, "Kısa vade borçlarını ödemekte zorlanabilir.") }
            if deger < 1.5 { return (.notr, 55, "Kabul edilebilir seviye.") }
            if deger < 2.5 { return (.iyi, 80, "Sağlam likidite.") }
            return (.mukemmel, 90, "Güçlü nakit pozisyonu.")
        }
        
        let likidite: BISTMetrik? = nil // Asit test için ek veri gerekli
        
        return BISTSaglikVerisi(borcOzsermaye: borcOz, cariOran: cariOran, likiditeOrani: likidite)
    }
    
    // MARK: - Nakit Analizi
    
    private func analizNakit(finansallar: FinancialsData) -> BISTNakitVerisi {
        let fcf = olusturMetrik(
            id: "fcf",
            isim: "Serbest Nakit Akışı",
            deger: finansallar.freeCashFlow,
            sektorOrt: nil,
            formul: "Operasyonlardan Nakit Akışı - Yatırım Harcamaları",
            egitim: "Serbest nakit akışı, şirketin gerçekte cebine giren parayı gösterir. Pozitif FCF, temettü ve büyüme için kaynak sağlar."
        ) { deger, _ in
            if deger < 0 { return (.dikkat, 30, "Negatif FCF - nakit yakmakta.") }
            return (.iyi, 75, "Pozitif nakit üretimi.")
        }
        
        let nakitPoz: BISTMetrik? = nil // Ek veri gerekli
        let nakitKar: BISTMetrik? = nil
        
        return BISTNakitVerisi(serbestNakitAkisi: fcf, nakitPozisyonu: nakitPoz, nakitKarOrani: nakitKar)
    }
    
    // MARK: - Temettü Analizi
    
    private func analizTemettu(finansallar: FinancialsData) -> BISTTemettuVerisi {
        let verim = olusturMetrik(
            id: "temettuVerim",
            isim: "Temettü Verimi",
            deger: finansallar.dividendYield, // Zaten yüzde cinsinden geliyor
            sektorOrt: 2.5,
            formul: "Yıllık Temettü / Hisse Fiyatı × 100",
            egitim: "Temettü verimi, yatırımınızdan elde edeceğiniz düzenli geliri gösterir. BIST'te %5 üstü cazip kabul edilir."
        ) { deger, _ in
            if deger == 0 { return (.notr, 40, "Temettü dağıtmıyor.") }
            if deger < 2 { return (.notr, 50, "Düşük temettü verimi.") }
            if deger < 5 { return (.iyi, 70, "Makul temettü verimi.") }
            if deger < 10 { return (.mukemmel, 85, "Yüksek temettü verimi!") }
            return (.dikkat, 60, "Çok yüksek verim - sürdürülebilirliği kontrol edin.")
        }
        
        let dagitim: BISTMetrik? = nil // Veri gerekli
        let buyume: BISTMetrik? = nil
        
        return BISTTemettuVerisi(temettuVerimi: verim, dagitimOrani: dagitim, temettuBuyumesi: buyume)
    }
    
    // MARK: - Risk Analizi
    
    private func analizRisk(finansallar: FinancialsData, quote: Quote?) -> BISTRiskVerisi {
        // NOT: FinancialsData'da beta yok, varsayılan değer kullanılıyor
        let betaDeger: Double? = nil // Yahoo'dan ayrıca çekilebilir
        
        let beta = olusturMetrik(
            id: "beta",
            isim: "Beta",
            deger: betaDeger,
            sektorOrt: 1.0,
            formul: "Hisse Volatilitesi / Piyasa Volatilitesi",
            egitim: "Beta, hissenin piyasaya göre ne kadar hareketli olduğunu gösterir. 1'den büyükse piyasadan daha volatil, küçükse daha stabil."
        ) { deger, _ in
            if deger < 0.5 { return (.mukemmel, 90, "Çok düşük volatilite - defansif hisse.") }
            if deger < 0.8 { return (.iyi, 75, "Düşük volatilite.") }
            if deger < 1.2 { return (.notr, 55, "Piyasa ile benzer hareketler.") }
            if deger < 1.5 { return (.dikkat, 40, "Yüksek volatilite.") }
            return (.kotu, 25, "Çok yüksek volatilite - agresif yatırımcılar için.")
        }
        
        let korelasyon: BISTMetrik? = nil
        let volatilite: BISTMetrik? = nil
        
        return BISTRiskVerisi(beta: beta, xu100Korelasyon: korelasyon, volatilite: volatilite)
    }
    
    // MARK: - Yardımcı Fonksiyonlar
    
    private func olusturMetrik(
        id: String,
        isim: String,
        deger: Double?,
        sektorOrt: Double?,
        formul: String,
        egitim: String,
        degerlendirme: (Double, Double) -> (BISTMetrikDurum, Double, String)
    ) -> BISTMetrik {
        guard let d = deger else {
            return BISTMetrik(
                id: id,
                isim: isim,
                deger: nil,
                sektorOrtalamasi: sektorOrt,
                durum: .veriYok,
                skor: 0,
                aciklama: "Veri bulunamadı.",
                egitimNotu: egitim,
                formul: formul
            )
        }
        
        let ort = sektorOrt ?? 0
        let (durum, skor, aciklama) = degerlendirme(d, ort)
        
        return BISTMetrik(
            id: id,
            isim: isim,
            deger: d,
            sektorOrtalamasi: sektorOrt,
            durum: durum,
            skor: skor,
            aciklama: aciklama,
            egitimNotu: egitim,
            formul: formul
        )
    }
    
    private func hesaplaBolumSkoru(_ metrikler: [BISTMetrik]) -> Double {
        let gecerliMetrikler = metrikler.filter { $0.durum != .veriYok && $0.skor > 0 }
        guard !gecerliMetrikler.isEmpty else { return 50 } // Varsayılan
        return gecerliMetrikler.map { $0.skor }.reduce(0, +) / Double(gecerliMetrikler.count)
    }
    
    private func olusturOneCikanlar(
        degerleme: BISTDegerlemeVerisi,
        karlilik: BISTKarlilikVerisi,
        buyume: BISTBuyumeVerisi,
        saglik: BISTSaglikVerisi,
        nakit: BISTNakitVerisi
    ) -> ([String], [String]) {
        var oneCikanlar: [String] = []
        var uyarilar: [String] = []
        
        // Öne çıkanlar
        if karlilik.ozsermayeKarliligi.skor >= 80 {
            oneCikanlar.append("Yüksek özsermaye kârlılığı (%\(Int(karlilik.ozsermayeKarliligi.deger ?? 0)))")
        }
        if degerleme.fk.skor >= 75 {
            oneCikanlar.append("Uygun F/K değerlemesi (\(BISTMetrik.formatla(degerleme.fk.deger))x)")
        }
        if saglik.borcOzsermaye.skor >= 80 {
            oneCikanlar.append("Güçlü bilanço - düşük borç")
        }
        
        // Uyarılar
        if saglik.borcOzsermaye.skor < 40 {
            uyarilar.append("Yüksek borç yükü dikkat gerektirir")
        }
        if karlilik.netKarMarji.skor < 30 {
            uyarilar.append("Düşük kâr marjı")
        }
        if buyume.gelirBuyumesi.durum == .kotu {
            uyarilar.append("Gelirler düşüşte")
        }
        
        return (oneCikanlar, uyarilar)
    }
    
    private func olusturOzet(
        sembol: String,
        toplamSkor: Double,
        karlilik: Double,
        degerleme: Double,
        buyume: Double,
        saglik: Double
    ) -> String {
        let bant = BISTKaliteBandi.hesapla(skor: toplamSkor)
        
        switch bant {
        case .aArti, .a:
            return "\(sembol) yüksek kaliteli bir BIST hissesi görünüyor. Karlılık ve bilanço sağlığı öne çıkıyor."
        case .b:
            return "\(sembol) ortalama üstü bir profil sergiliyor. Bazı güçlü yönleri var."
        case .c:
            return "\(sembol) ortalama bir profil çiziyor. Dikkatli analiz önerilir."
        case .d, .f:
            return "\(sembol) bazı zayıf noktalar taşıyor. Detaylı inceleme şart."
        }
    }

    
    // MARK: - BorsaPy Dönüşüm Helper
    
    private func convertBistToFinancials(bist: BistFinancials, quote: Quote?) -> FinancialsData {
        // IsYatirim API'si verileri genellikle tam sayı olarak döner.
        // Ancak ilan edilen oranlar (ROE, ROA vb) % olarak gelir (örn 15.4)
        
        // Enterprise Value hesabı (Piyasa Değeri + Toplam Borç - Nakit)
        let marketCap = bist.marketCap ?? quote?.marketCap ?? 0
        let totalDebt = bist.totalDebt ?? 0
        let cash = bist.cash ?? 0
        let enterpriseValue = marketCap + totalDebt - cash
        
        return FinancialsData(
            symbol: bist.symbol,
            currency: "TRY",
            lastUpdated: Date(),
            totalRevenue: bist.revenue,
            netIncome: bist.netProfit,
            totalShareholderEquity: bist.totalEquity,
            marketCap: bist.marketCap ?? quote?.marketCap,
            revenueHistory: [],
            netIncomeHistory: [],
            ebitda: bist.ebitda,
            shortTermDebt: bist.shortTermDebt,
            longTermDebt: bist.longTermDebt,
            operatingCashflow: nil,
            capitalExpenditures: nil,
            cashAndCashEquivalents: bist.cash,
            peRatio: bist.pe,
            forwardPERatio: nil,
            priceToBook: bist.pb,
            evToEbitda: (bist.ebitda != nil && bist.ebitda! > 0) ? enterpriseValue / bist.ebitda! : nil,
            dividendYield: nil,
            earningsPerShare: bist.eps, // MOVED HERE
            forwardGrowthEstimate: nil,
            isETF: false,
            grossMargin: bist.grossMargin,
            operatingMargin: bist.operatingMargin,
            profitMargin: bist.netMargin,
            returnOnEquity: bist.roe,
            returnOnAssets: bist.roa,

            debtToEquity: bist.debtToEquity,
            currentRatio: bist.currentRatio,
            freeCashFlow: nil,
            enterpriseValue: enterpriseValue,
            pegRatio: nil,
            priceToSales: nil,
            revenueGrowth: nil,
            earningsGrowth: nil,
            targetMeanPrice: nil,
            targetHighPrice: nil,
            targetLowPrice: nil,
            recommendationMean: nil,
            numberOfAnalystOpinions: nil
        )
    }
}
