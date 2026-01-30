import Foundation

// MARK: - TCMB EVDS Data Service
/// Turkiye Cumhuriyet Merkez Bankasi Elektronik Veri Dagitim Sistemi
/// Gercek zamanli makroekonomik veriler: Enflasyon, Faiz, Doviz, Petrol, Altin

actor TCMBDataService {
    static let shared = TCMBDataService()
    
    // MARK: - Configuration
    // API Key: https://evds2.tcmb.gov.tr adresinden ucretsiz alinir
    // Header olarak gonderilmeli: key: API_KEY
    private let baseURL = "https://evds2.tcmb.gov.tr/service/evds"
    
    // API Key - Settings'ten alinacak, simdilik bos
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "tcmb_evds_api_key") ?? ""
    }
    
    // MARK: - Serie Codes (TCMB Veri Kodlari)
    enum SerieCode: String, CaseIterable {
        // Doviz Kurlari
        case usdTry = "TP.DK.USD.A.YTL"      // USD/TRY Alis
        case eurTry = "TP.DK.EUR.A.YTL"      // EUR/TRY Alis
        
        // Faiz Oranlari
        case policyRate = "TP.TRB.PFO01"      // Politika Faizi
        case depositRate = "TP.TRB.MF05"      // Mevduat Faizi
        case loanRate = "TP.TRB.IKT02"        // Ticari Kredi Faizi
        
        // Enflasyon (TUFE)
        case cpiFull = "TP.FG.J0"             // TUFE Genel
        case cpiCore = "TP.FG.J01"            // Cekirdek Enflasyon
        
        // Buyume ve Uretim
        case gdpGrowth = "TP.GSGIH.G02"       // GSYIH Buyume Orani
        case industrialProd = "TP.N2SY01"     // Sanayi Uretim Endeksi
        
        // Istihdam
        case unemployment = "TP.TIG01"        // Issizlik Orani
        
        // Dis Ticaret ve Odemeler Dengesi
        case currentAccount = "TP.ODEMELER.CDG01"  // Cari Islemler Dengesi
        case exports = "TP.IHRTUT"            // Ihracat (Milyon USD)
        case imports = "TP.ITHTUT"            // Ithalat (Milyon USD)
        
        // MB Rezervleri
        case reserves = "TP.MBR.BRUT01"       // Brut Rezervler
        case netReserves = "TP.MBR.NET01"     // Net Rezervler
        
        // Kredi ve Mevduat
        case totalCredits = "TP.KRD.KRTOPLAM" // Toplam Krediler
        case tlDeposits = "TP.MEVDUAT.TL01"   // TL Mevduat
        
        // Emtia
        case brentOil = "TP.FTRPIT"           // Brent Petrol
        case goldOz = "TP.FGALT01"            // Altin (Ons/$)

        // Piyasa Gostergeleri
        case bist100 = "TP.BSTPAY.XKURY"      // BIST 100 Endeksi

        // Oracle için Ek Seriler
        case capacityUsage = "TP.KKO.MA"      // İmalat Sanayi Kapasite Kullanım Oranı (Mevsimsellikten Arındırılmış)
        case creditCardSpending = "TP.KKHARTUT.TOPLAM" // Kredi Kartı Harcama Tutarı (Toplam)
        
        /// Kullanıcı dostu isim
        var displayName: String {
            switch self {
            case .usdTry: return "USD/TRY"
            case .eurTry: return "EUR/TRY"
            case .policyRate: return "Politika Faizi"
            case .depositRate: return "Mevduat Faizi"
            case .loanRate: return "Kredi Faizi"
            case .cpiFull: return "TUFE"
            case .cpiCore: return "Cekirdek Enflasyon"
            case .gdpGrowth: return "GSYIH Buyume"
            case .industrialProd: return "Sanayi Uretimi"
            case .unemployment: return "Issizlik"
            case .currentAccount: return "Cari Denge"
            case .exports: return "Ihracat"
            case .imports: return "Ithalat"
            case .reserves: return "Brut Rezerv"
            case .netReserves: return "Net Rezerv"
            case .totalCredits: return "Toplam Kredi"
            case .tlDeposits: return "TL Mevduat"
            case .brentOil: return "Brent Petrol"
            case .goldOz: return "Altin"
            case .bist100: return "BIST 100"
            case .capacityUsage: return "Kapasite Kullanım"
            case .creditCardSpending: return "Kredi Kartı Harcama"
            }
        }
    }
    
    // MARK: - Data Models
    
    struct MacroDataPoint: Codable {
        let date: String
        let value: Double
        
        enum CodingKeys: String, CodingKey {
            case date = "Tarih"
            case value
        }
    }
    
    /// Genişletilmiş makro veri snapshot'ı
    struct TCMBMacroSnapshot: Sendable {
        // Doviz
        let usdTry: Double?
        let eurTry: Double?
        
        // Faiz
        let policyRate: Double?
        let depositRate: Double?
        let loanRate: Double?
        
        // Enflasyon
        let inflation: Double?
        let coreInflation: Double?
        
        // Buyume
        let gdpGrowth: Double?
        let industrialProduction: Double?
        
        // Istihdam
        let unemployment: Double?
        
        // Dis Denge
        let currentAccount: Double?
        let exports: Double?
        let imports: Double?
        
        // Rezervler
        let reserves: Double?
        let netReserves: Double?
        
        // Kredi/Mevduat
        let totalCredits: Double?
        let tlDeposits: Double?
        
        // Emtia
        let brentOil: Double?
        let goldPrice: Double?
        
        // Piyasa
        let bist100: Double?

        // Oracle için Ek Veriler
        let capacityUsage: Double?       // Kapasite Kullanım Oranı (%)
        let creditCardSpendingBillionTL: Double? // Kredi Kartı Harcama (Milyar TL)

        let timestamp: Date
        
        static let empty = TCMBMacroSnapshot(
            usdTry: nil, eurTry: nil,
            policyRate: nil, depositRate: nil, loanRate: nil,
            inflation: nil, coreInflation: nil,
            gdpGrowth: nil, industrialProduction: nil,
            unemployment: nil,
            currentAccount: nil, exports: nil, imports: nil,
            reserves: nil, netReserves: nil,
            totalCredits: nil, tlDeposits: nil,
            brentOil: nil, goldPrice: nil,
            bist100: nil,
            capacityUsage: nil, creditCardSpendingBillionTL: nil,
            timestamp: Date()
        )
        
        /// Ticaret dengesi (Ihracat - Ithalat)
        var tradeBalance: Double? {
            guard let exp = exports, let imp = imports else { return nil }
            return exp - imp
        }
        
        /// Reel faiz (Politika Faizi - Enflasyon)
        var realInterestRate: Double? {
            guard let policy = policyRate, let infl = inflation else { return nil }
            return policy - infl
        }
    }
    
    // MARK: - Cache
    private var cachedSnapshot: TCMBMacroSnapshot?
    private var lastFetchTime: Date?
    private let cacheValiditySeconds: TimeInterval = 3600 // 1 saat
    
    // MARK: - Public API
    
    /// Standard Alias for protocol conformity
    func getSnapshot() async -> TCMBMacroSnapshot {
        return await getMacroSnapshot()
    }
    
    /// Guncel makro snapshot'i dondur (cache varsa kullan)
    func getMacroSnapshot() async -> TCMBMacroSnapshot {
        // Cache gecerli mi?
        if let cached = cachedSnapshot,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheValiditySeconds {
            return cached
        }
        
        // API Key yoksa varsayilan degerler don
        // API Key yoksa varsayilan degerler don (Son Güncel Veriler - Ocak 2026)
        guard !apiKey.isEmpty else {
            print("⚠️ TCMB: API Key ayarlanmamis, GÜNCEL MANUAL FALLBACK verileri kullaniliyor (Ocak 2026)")
            // Fallback to real researched values (Jan 2026 / Dec 2025 Data)
            return TCMBMacroSnapshot(
                usdTry: 43.30,            // 21.01.2026 Piyasa Ortalaması
                eurTry: 45.15,            // Tahmini Pariteye göre (43.3 * 1.04)
                policyRate: 38.0,         // TCMB Aralık 2025 Kararı (%38)
                depositRate: 42.5,        // Tahmini Piyasa Faiz Oranı
                loanRate: 54.0,           // Ticari Kredi Faizleri (Tahmini)
                inflation: 30.89,         // TÜİK Aralık 2025 Yıllık TÜFE
                coreInflation: 29.5,      // Tahmini Çekirdek
                gdpGrowth: 3.5,           // Tahmini Büyüme
                industrialProduction: 1.2,// Sanayi Üretimi
                unemployment: 8.6,        // Kasım 2025 İşsizlik Oranı
                currentAccount: -3.99,    // Kasım 2025 Cari Açık (Milyar $)
                exports: 22.0,            // Tahmini
                imports: 28.0,            // Tahmini
                reserves: 205.0,          // TCMB Brü Rezerv (Tarihi Zirve - Ocak 2026)
                netReserves: 78.0,        // Net Rezerv
                totalCredits: nil,
                tlDeposits: nil,
                brentOil: 64.0,           // Brent Petrol (Ocak 2026)
                goldPrice: 2900.0,        // Ons Altın ($) - Safe Conservative Update
                bist100: 11500.0,         // Endeks Tahmini
                capacityUsage: 76.5,      // KKO (Ocak 2026 tahmini)
                creditCardSpendingBillionTL: 250.0, // Haftalık kredi kartı harcama (Milyar TL)
                timestamp: Date()
            )
        }
        
        // Yeni veri cek
        return await fetchFreshData()
    }
    
    /// API Key'i ayarla
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "tcmb_evds_api_key")
        cachedSnapshot = nil // Cache'i invalidate et
    }
    
    /// API baglantisini test et
    func testConnection() async -> Bool {
        guard !apiKey.isEmpty else { return false }
        
        do {
            let _ = try await fetchSerie(.usdTry, days: 1)
            return true
        } catch {
            print("❌ TCMB API baglanti hatasi: \(error)")
            return false
        }
    }
    
    /// Belirtilen seri icin gecmis veri ceker
    func getSeriesHistory(_ serie: SerieCode, days: Int = 30) async -> [MacroDataPoint] {
        guard !apiKey.isEmpty else { return [] }
        return (try? await fetchSerie(serie, days: days)) ?? []
    }
    
    // MARK: - Private Methods
    
    private func fetchFreshData() async -> TCMBMacroSnapshot {
        // Tüm serileri paralel olarak çek
        async let usd = fetchLatestValue(.usdTry)
        async let eur = fetchLatestValue(.eurTry)
        async let policy = fetchLatestValue(.policyRate)
        async let deposit = fetchLatestValue(.depositRate)
        async let loan = fetchLatestValue(.loanRate)
        async let cpi = fetchLatestValue(.cpiFull)
        async let core = fetchLatestValue(.cpiCore)
        async let gdp = fetchLatestValue(.gdpGrowth)
        async let industrial = fetchLatestValue(.industrialProd)
        async let unemp = fetchLatestValue(.unemployment)
        async let current = fetchLatestValue(.currentAccount)
        async let exp = fetchLatestValue(.exports)
        async let imp = fetchLatestValue(.imports)
        async let res = fetchLatestValue(.reserves)
        async let netRes = fetchLatestValue(.netReserves)
        async let credits = fetchLatestValue(.totalCredits)
        async let deposits = fetchLatestValue(.tlDeposits)
        async let oil = fetchLatestValue(.brentOil)
        async let gold = fetchLatestValue(.goldOz)
        async let bist = fetchLatestValue(.bist100)
        async let kko = fetchLatestValue(.capacityUsage)
        async let ccSpending = fetchLatestValue(.creditCardSpending)

        let snapshot = TCMBMacroSnapshot(
            usdTry: await usd,
            eurTry: await eur,
            policyRate: await policy,
            depositRate: await deposit,
            loanRate: await loan,
            inflation: await cpi,
            coreInflation: await core,
            gdpGrowth: await gdp,
            industrialProduction: await industrial,
            unemployment: await unemp,
            currentAccount: await current,
            exports: await exp,
            imports: await imp,
            reserves: await res,
            netReserves: await netRes,
            totalCredits: await credits,
            tlDeposits: await deposits,
            brentOil: await oil,
            goldPrice: await gold,
            bist100: await bist,
            capacityUsage: await kko,
            creditCardSpendingBillionTL: await ccSpending.map { $0 / 1_000_000 }, // Bin TL -> Milyar TL
            timestamp: Date()
        )

        cachedSnapshot = snapshot
        lastFetchTime = Date()
        
        print("✅ TCMB: Kapsamlı makro veriler güncellendi")
        print("   USD/TRY: \(snapshot.usdTry ?? 0), Faiz: %\(snapshot.policyRate ?? 0), Enflasyon: %\(snapshot.inflation ?? 0)")
        print("   Reel Faiz: %\(snapshot.realInterestRate ?? 0), Cari Denge: \(snapshot.currentAccount ?? 0)B$")
        
        return snapshot
    }
    
    private func fetchLatestValue(_ serie: SerieCode) async -> Double? {
        do {
            let data = try await fetchSerie(serie, days: 7)
            return data.last?.value
        } catch {
            print("⚠️ TCMB \(serie.rawValue) veri alinamadi: \(error)")
            return nil
        }
    }
    
    private func fetchSerie(_ serie: SerieCode, days: Int) async throws -> [MacroDataPoint] {
        // Tarih araligi
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"

        let startStr = dateFormatter.string(from: startDate)
        let endStr = dateFormatter.string(from: endDate)

        // URL olustur - EVDS API formatı: /series=CODE&startDate=...&endDate=...&type=json
        // NOT: Bazı seri kodlarında nokta (.) yerine alt çizgi (_) kullanılabilir
        let serieCode = serie.rawValue.replacingOccurrences(of: ".", with: "-")
        let urlString = "\(baseURL)/series=\(serieCode)&startDate=\(startStr)&endDate=\(endStr)&type=json"

        guard let url = URL(string: urlString) else {
            print("❌ TCMB: Geçersiz URL - \(urlString)")
            throw TCMBError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "key")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ TCMB: HTTP response alınamadı")
            throw TCMBError.apiError
        }

        // Debug: HTTP durumu
        if httpResponse.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? "Body okunamadı"
            print("❌ TCMB API Hata [\(serie.rawValue)]: HTTP \(httpResponse.statusCode)")
            print("   Response: \(responseBody.prefix(500))")
            throw TCMBError.apiError
        }

        // Parse JSON with JSONSerialization
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let responseBody = String(data: data, encoding: .utf8) ?? "Body okunamadı"
            print("❌ TCMB JSON Parse Hatası [\(serie.rawValue)]: \(responseBody.prefix(300))")
            throw TCMBError.parseError
        }

        // items array'i kontrol et
        guard let items = json["items"] as? [[String: Any]], !items.isEmpty else {
            print("⚠️ TCMB: Veri bulunamadı [\(serie.rawValue)] - items boş veya yok")
            print("   JSON Keys: \(json.keys.joined(separator: ", "))")
            return []
        }

        // Veri parse et - seri kodu key olarak kullanılıyor
        // EVDS bazen noktalı (TP.DK.USD.A.YTL), bazen tireli (TP-DK-USD-A-YTL) key döner
        let possibleKeys = [serie.rawValue, serieCode, serie.rawValue.replacingOccurrences(of: "-", with: ".")]

        return items.compactMap { item -> MacroDataPoint? in
            // Doğru key'i bul
            var valueStr: String?
            for key in possibleKeys {
                if let val = item[key] as? String {
                    valueStr = val
                    break
                }
            }

            guard let valStr = valueStr, let value = Double(valStr) else {
                return nil
            }
            return MacroDataPoint(date: item["Tarih"] as? String ?? "", value: value)
        }
    }
    
    enum TCMBError: Error {
        case invalidURL
        case apiError
        case parseError
    }
}

// MARK: - Sirkiye Engine Integration

extension TCMBDataService {
    /// SirkiyeEngine icin input olusturur. Kritik veri (USD/TRY) yoksa nil doner.
    func getSirkiyeInput() async -> SirkiyeEngine.SirkiyeInput? {
        let snapshot = await getMacroSnapshot()
        
        // Kritik veriler yoksa analiz yapma (Clean Rice Protocol)
        guard let usdTry = snapshot.usdTry, usdTry > 0 else { return nil }
        
        // Onceki gun tahmini (Veri varsa)
        let previousUsdTry = usdTry * 0.99
        
        return SirkiyeEngine.SirkiyeInput(
            usdTry: usdTry,
            usdTryPrevious: previousUsdTry,
            dxy: 104.0, // DXY icin ayri kaynak gerekli (Sabit deger - Bunu da temizlemek lazim ama TCMB disi)
            brentOil: snapshot.brentOil,
            globalVix: 15.0,
            newsSnapshot: nil,
            currentInflation: snapshot.inflation,
            policyRate: snapshot.policyRate,
            xu100Change: nil,
            goldPrice: snapshot.goldPrice
        )
    }
}

// MARK: - Oracle Engine Integration
extension TCMBDataService {
    /// OracleEngine icin genisletilmis veri seti
    /// EVDS'den çekilebilen veriler gerçek, diğerleri TÜİK/ODMD kaynaklarından manuel güncellenmeli
    func getOracleInput() async -> OracleDataInput {
        let snapshot = await getMacroSnapshot()

        // EVDS'den gelen gerçek veriler
        let kko = snapshot.capacityUsage ?? 76.5 // Kapasite Kullanım Oranı
        let ccSpending = snapshot.creditCardSpendingBillionTL ?? 250.0 // Kredi Kartı Harcama

        // Önceki dönem verileri (geçmiş veri çekilerek hesaplanmalı - şimdilik tahmini)
        let prevKko = kko - 0.3 // Aylık değişim tahmini

        // YoY değişim hesaplamaları (Gerçek hesaplama için 1 yıllık veri gerekli)
        // Şimdilik enflasyon üzerinden nominal/reel ayırma yapıyoruz
        let inflation = snapshot.inflation ?? 30.0
        let ccSpendingChangeYoY = 45.0 // Nominal artış (EVDS'den 1 yıllık veri çekilmeli)

        // TÜİK/ODMD verileri - EVDS'de YOK, manuel güncellenmeli veya ayrı servis eklenmeli
        // Bu değerler fallback olarak kullanılıyor
        let housingSalesTotal: Double = 125000      // TÜİK Konut Satış (Aylık)
        let housingSalesChangeYoY: Double = 12.5    // TÜİK YoY
        let housingSalesChangeMoM: Double = 2.1     // TÜİK MoM
        let touristArrivalsTotal: Double = 2.1      // TÜİK Turist Girişi (Milyon)
        let touristArrivalsChangeYoY: Double = 8.0  // TÜİK YoY
        let autoSalesTotal: Double = 85000          // ODD/ODMD Otomotiv Satış
        let autoSalesChangeYoY: Double = -5.0       // ODMD YoY

        return OracleDataInput(
            inflationYoY: inflation,
            housingSalesTotal: housingSalesTotal,
            housingSalesChangeYoY: housingSalesChangeYoY,
            housingSalesChangeMoM: housingSalesChangeMoM,
            creditCardSpendingTotal: ccSpending,
            creditCardSpendingChangeYoY: ccSpendingChangeYoY,
            capacityUsageRatio: kko,
            prevCapacityUsageRatio: prevKko,
            touristArrivalsTotal: touristArrivalsTotal,
            touristArrivalsChangeYoY: touristArrivalsChangeYoY,
            autoSalesTotal: autoSalesTotal,
            autoSalesChangeYoY: autoSalesChangeYoY
        )
    }

    /// KKO için YoY değişim hesapla (1 yıllık veri çekerek)
    func fetchKKOWithHistory() async -> (current: Double, prevYear: Double)? {
        guard !apiKey.isEmpty else { return nil }

        do {
            let data = try await fetchSerie(.capacityUsage, days: 400) // ~13 ay
            guard data.count >= 12 else { return nil }

            let current = data.last?.value ?? 0
            let prevYear = data[data.count - 12].value
            return (current, prevYear)
        } catch {
            print("⚠️ KKO geçmiş veri alınamadı: \(error)")
            return nil
        }
    }

    /// Kredi kartı harcaması için YoY değişim hesapla
    func fetchCCSpendingWithHistory() async -> (current: Double, changeYoY: Double)? {
        guard !apiKey.isEmpty else { return nil }

        do {
            let data = try await fetchSerie(.creditCardSpending, days: 400)
            guard data.count >= 52 else { return nil } // Haftalık veri, 52 hafta

            let current = data.last?.value ?? 0
            let prevYear = data[data.count - 52].value
            let changeYoY = ((current - prevYear) / prevYear) * 100
            return (current / 1_000_000, changeYoY) // Bin TL -> Milyar TL
        } catch {
            print("⚠️ Kredi kartı geçmiş veri alınamadı: \(error)")
            return nil
        }
    }
}
