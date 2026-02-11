import Foundation

// MARK: - BIST Bilanço V2 Modelleri
// Atlas yapısının BIST'e uyarlanmış hali

// MARK: - Kalite Bandı
enum BISTKaliteBandi: String, Codable {
    case aArti = "A+"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
    
    var aciklama: String {
        switch self {
        case .aArti: return "Mükemmel"
        case .a: return "Çok İyi"
        case .b: return "İyi"
        case .c: return "Orta"
        case .d: return "Zayıf"
        case .f: return "Kötü"
        }
    }
    
    static func hesapla(skor: Double) -> BISTKaliteBandi {
        switch skor {
        case 85...: return .aArti
        case 70..<85: return .a
        case 55..<70: return .b
        case 40..<55: return .c
        case 25..<40: return .d
        default: return .f
        }
    }
}

// MARK: - Metrik Durumu
enum BISTMetrikDurum: String, Codable {
    case mukemmel = "mukemmel"
    case iyi = "iyi"
    case notr = "notr"
    case dikkat = "dikkat"
    case kotu = "kotu"
    case kritik = "kritik"
    case veriYok = "veriYok"
    
    var emoji: String {
        switch self {
        case .mukemmel: return ""
        case .iyi: return ""
        case .notr: return ""
        case .dikkat: return ""
        case .kotu: return ""
        case .kritik: return "⛔"
        case .veriYok: return "⚪"
        }
    }
    
    var etiket: String {
        switch self {
        case .mukemmel: return "Mükemmel"
        case .iyi: return "İyi"
        case .notr: return "Orta"
        case .dikkat: return "Dikkat"
        case .kotu: return "Kötü"
        case .kritik: return "Tehlikeli"
        case .veriYok: return "Veri Yok"
        }
    }
}

// MARK: - Tek Metrik
struct BISTMetrik: Identifiable, Codable {
    let id: String
    let isim: String                     // "F/K (P/E)"
    let deger: Double?                   // 28.5
    let formatliDeger: String            // "28.5"
    let sektorOrtalamasi: Double?        // 32.0
    let durum: BISTMetrikDurum           // .iyi
    let skor: Double                     // 0-100
    let aciklama: String                 // "Sektöre göre %11 ucuz"
    let egitimNotu: String               // "F/K, şirketin karına göre fiyatını ölçer..."
    let formul: String?                  // "Fiyat / Hisse Başına Kar"
    
    init(
        id: String,
        isim: String,
        deger: Double?,
        sektorOrtalamasi: Double? = nil,
        durum: BISTMetrikDurum,
        skor: Double,
        aciklama: String,
        egitimNotu: String,
        formul: String? = nil
    ) {
        self.id = id
        self.isim = isim
        self.deger = deger
        self.formatliDeger = BISTMetrik.formatla(deger)
        self.sektorOrtalamasi = sektorOrtalamasi
        self.durum = durum
        self.skor = skor
        self.aciklama = aciklama
        self.egitimNotu = egitimNotu
        self.formul = formul
    }
    
    static func formatla(_ deger: Double?) -> String {
        guard let v = deger else { return "—" }
        if abs(v) >= 1_000_000_000_000 { return String(format: "%.1fT ₺", v / 1_000_000_000_000) }
        if abs(v) >= 1_000_000_000 { return String(format: "%.1f Milyar ₺", v / 1_000_000_000) }
        if abs(v) >= 1_000_000 { return String(format: "%.1f Milyon ₺", v / 1_000_000) }
        if abs(v) >= 1000 { return String(format: "%.0f", v) }
        if abs(v) < 0.01 { return String(format: "%.4f", v) }
        return String(format: "%.2f", v)
    }
    
    static func yuzdeFormatla(_ deger: Double?) -> String {
        guard let v = deger else { return "—" }
        return String(format: "%%%.1f", v)
    }
}

// MARK: - Bölüm Verileri

struct BISTDegerlemeVerisi: Codable {
    let fk: BISTMetrik           // F/K (P/E)
    let pddd: BISTMetrik         // PD/DD (P/B)
    let fdFavok: BISTMetrik      // FD/FAVÖK (EV/EBITDA)
    let fkBuyume: BISTMetrik?    // F/K / Büyüme (PEG)
    let eps: BISTMetrik?         // NEW: Hisse Başına Kar (EPS)
    
    var tumMetrikler: [BISTMetrik] {
        [fk, pddd, fdFavok, fkBuyume, eps].compactMap { $0 }
    }
}

struct BISTKarlilikVerisi: Codable {
    let ozsermayeKarliligi: BISTMetrik   // ROE
    let aktifKarliligi: BISTMetrik       // ROA
    let netKarMarji: BISTMetrik          
    let brutKarMarji: BISTMetrik?        
    
    var tumMetrikler: [BISTMetrik] {
        [ozsermayeKarliligi, aktifKarliligi, netKarMarji, brutKarMarji].compactMap { $0 }
    }
}

struct BISTBuyumeVerisi: Codable {
    let gelirBuyumesi: BISTMetrik        // Yıllık Gelir Büyümesi
    let karBuyumesi: BISTMetrik          // Yıllık Net Kar Büyümesi
    let favokBuyumesi: BISTMetrik?       // FAVÖK Büyümesi
    
    var tumMetrikler: [BISTMetrik] {
        [gelirBuyumesi, karBuyumesi, favokBuyumesi].compactMap { $0 }
    }
}

struct BISTSaglikVerisi: Codable {
    let borcOzsermaye: BISTMetrik        // Borç/Özsermaye
    let cariOran: BISTMetrik             // Cari Oran
    let likiditeOrani: BISTMetrik?       // Asit Test Oranı
    
    var tumMetrikler: [BISTMetrik] {
        [borcOzsermaye, cariOran, likiditeOrani].compactMap { $0 }
    }
}

struct BISTNakitVerisi: Codable {
    let serbestNakitAkisi: BISTMetrik    // Serbest Nakit Akışı
    let nakitPozisyonu: BISTMetrik?      // Nakit ve Benzerleri
    let nakitKarOrani: BISTMetrik?       // Nakit / Net Kar
    
    var tumMetrikler: [BISTMetrik] {
        [serbestNakitAkisi, nakitPozisyonu, nakitKarOrani].compactMap { $0 }
    }
}

struct BISTTemettuVerisi: Codable {
    let temettuVerimi: BISTMetrik        // Temettü Verimi
    let dagitimOrani: BISTMetrik?        // Dağıtım Oranı (Payout Ratio)
    let temettuBuyumesi: BISTMetrik?     // 3 Yıllık Temettü Büyümesi
    
    var tumMetrikler: [BISTMetrik] {
        [temettuVerimi, dagitimOrani, temettuBuyumesi].compactMap { $0 }
    }
}

struct BISTRiskVerisi: Codable {
    let beta: BISTMetrik
    let xu100Korelasyon: BISTMetrik?     // XU100 ile korelasyon
    let volatilite: BISTMetrik?          // 52 hafta volatilite
    
    var tumMetrikler: [BISTMetrik] {
        [beta, xu100Korelasyon, volatilite].compactMap { $0 }
    }
}

// MARK: - Şirket Profili
struct BISTSirketProfili: Codable {
    let sembol: String
    let isim: String
    let sektor: String?
    let altSektor: String?
    let piyasaDegeri: Double?
    let formatliPiyasaDegeri: String
    let halkaAciklikOrani: Double?
    let paraBirimi: String
    
    var piyasaDegeriSinifi: String {
        guard let pd = piyasaDegeri else { return "Bilinmiyor" }
        switch pd {
        case 100_000_000_000...: return "BIST 30"
        case 20_000_000_000..<100_000_000_000: return "BIST 50"
        case 5_000_000_000..<20_000_000_000: return "BIST 100"
        default: return "BIST Tüm"
        }
    }
}

// MARK: - Ana Sonuç
struct BISTBilancoSonuc: Identifiable, Codable {
    let id: String
    let sembol: String
    let tarih: Date
    
    // Şirket Profili
    let profil: BISTSirketProfili
    
    // Skorlar (0-100)
    let toplamSkor: Double
    let degerleme: Double
    let karlilik: Double
    let buyume: Double
    let saglik: Double
    let nakit: Double
    let temettu: Double
    
    // Kalite Bandı
    let kaliteBandi: BISTKaliteBandi
    
    // Detay Veriler
    let degerlemeVerisi: BISTDegerlemeVerisi
    let karlilikVerisi: BISTKarlilikVerisi
    let buyumeVerisi: BISTBuyumeVerisi
    let saglikVerisi: BISTSaglikVerisi
    let nakitVerisi: BISTNakitVerisi
    let temettuVerisi: BISTTemettuVerisi
    let riskVerisi: BISTRiskVerisi
    
    // Yorumlar
    let ozet: String
    let oneCikanlar: [String]
    let uyarilar: [String]
    
    init(
        sembol: String,
        profil: BISTSirketProfili,
        toplamSkor: Double,
        degerleme: Double,
        karlilik: Double,
        buyume: Double,
        saglik: Double,
        nakit: Double,
        temettu: Double,
        degerlemeVerisi: BISTDegerlemeVerisi,
        karlilikVerisi: BISTKarlilikVerisi,
        buyumeVerisi: BISTBuyumeVerisi,
        saglikVerisi: BISTSaglikVerisi,
        nakitVerisi: BISTNakitVerisi,
        temettuVerisi: BISTTemettuVerisi,
        riskVerisi: BISTRiskVerisi,
        ozet: String,
        oneCikanlar: [String],
        uyarilar: [String]
    ) {
        self.id = "\(sembol)_\(Date().timeIntervalSince1970)"
        self.sembol = sembol
        self.tarih = Date()
        self.profil = profil
        self.toplamSkor = toplamSkor
        self.degerleme = degerleme
        self.karlilik = karlilik
        self.buyume = buyume
        self.saglik = saglik
        self.nakit = nakit
        self.temettu = temettu
        self.kaliteBandi = BISTKaliteBandi.hesapla(skor: toplamSkor)
        self.degerlemeVerisi = degerlemeVerisi
        self.karlilikVerisi = karlilikVerisi
        self.buyumeVerisi = buyumeVerisi
        self.saglikVerisi = saglikVerisi
        self.nakitVerisi = nakitVerisi
        self.temettuVerisi = temettuVerisi
        self.riskVerisi = riskVerisi
        self.ozet = ozet
        self.oneCikanlar = oneCikanlar
        self.uyarilar = uyarilar
    }
}

// MARK: - Sektör Benchmark Verileri (BIST)
struct BISTSektorBenchmark: Codable {
    let sektor: String
    let ortalamaFK: Double
    let ortalamaPDDD: Double
    let ortalamaROE: Double
    let ortalamaNetKarMarji: Double
    let ortalamaBorcOzsermaye: Double
    let ortalamaTemettuVerimi: Double
}

// MARK: - Varsayılan BIST Sektör Benchmark'ları
struct BISTSektorBenchmarks {
    static let shared = BISTSektorBenchmarks()
    
    private let benchmarks: [String: BISTSektorBenchmark] = [
        "Bankacılık": BISTSektorBenchmark(
            sektor: "Bankacılık",
            ortalamaFK: 5.0,
            ortalamaPDDD: 0.7,
            ortalamaROE: 15.0,
            ortalamaNetKarMarji: 25.0,
            ortalamaBorcOzsermaye: 8.0, // Bankalar için yüksek normal
            ortalamaTemettuVerimi: 5.0
        ),
        "Holding": BISTSektorBenchmark(
            sektor: "Holding",
            ortalamaFK: 10.0,
            ortalamaPDDD: 1.0,
            ortalamaROE: 12.0,
            ortalamaNetKarMarji: 15.0,
            ortalamaBorcOzsermaye: 0.8,
            ortalamaTemettuVerimi: 3.0
        ),
        "Sanayi": BISTSektorBenchmark(
            sektor: "Sanayi",
            ortalamaFK: 12.0,
            ortalamaPDDD: 2.0,
            ortalamaROE: 18.0,
            ortalamaNetKarMarji: 10.0,
            ortalamaBorcOzsermaye: 1.2,
            ortalamaTemettuVerimi: 2.0
        ),
        "Perakende": BISTSektorBenchmark(
            sektor: "Perakende",
            ortalamaFK: 15.0,
            ortalamaPDDD: 3.0,
            ortalamaROE: 20.0,
            ortalamaNetKarMarji: 5.0,
            ortalamaBorcOzsermaye: 1.5,
            ortalamaTemettuVerimi: 1.5
        ),
        "Teknoloji": BISTSektorBenchmark(
            sektor: "Teknoloji",
            ortalamaFK: 20.0,
            ortalamaPDDD: 4.0,
            ortalamaROE: 25.0,
            ortalamaNetKarMarji: 15.0,
            ortalamaBorcOzsermaye: 0.5,
            ortalamaTemettuVerimi: 0.5
        )
    ]
    
    func getBenchmark(sektor: String?) -> BISTSektorBenchmark {
        guard let s = sektor, let benchmark = benchmarks[s] else {
            // Varsayılan (Genel BIST Ortalaması)
            return BISTSektorBenchmark(
                sektor: "Genel",
                ortalamaFK: 10.0,
                ortalamaPDDD: 1.5,
                ortalamaROE: 15.0,
                ortalamaNetKarMarji: 10.0,
                ortalamaBorcOzsermaye: 1.0,
                ortalamaTemettuVerimi: 2.5
            )
        }
        return benchmark
    }
}
