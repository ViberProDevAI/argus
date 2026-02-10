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
    
    // API Key - Settings ekranindaki guvenli depodan okunur
    private func currentAPIKey() async -> String {
        await APIKeyStore.shared.getCustomValue(for: "tcmb_evds_api_key") ?? ""
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
    private var seriesHistoryCache: [String: (data: [MacroDataPoint], fetchedAt: Date)] = [:]
    private let seriesHistoryCacheValidity: TimeInterval = 10 * 60 // 10 dakika
    
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
        
        let apiKey = await currentAPIKey()

        // API Key yoksa, resmi keyless kaynaklardan (tcmb.gov.tr + yahoo) canli fallback dene
        guard !apiKey.isEmpty else {
            if let publicSnapshot = await fetchPublicKeylessSnapshot() {
                cachedSnapshot = publicSnapshot
                lastFetchTime = Date()
                print("✅ TCMB: Keyless resmi fallback verileri guncellendi")
                return publicSnapshot
            }

            print("⚠️ TCMB: API Key yok ve keyless fallback de alinmadi, bos snapshot donuluyor")
            let emptySnapshot = TCMBMacroSnapshot.empty
            cachedSnapshot = emptySnapshot
            lastFetchTime = Date()
            return emptySnapshot
        }
        
        // Yeni veri cek
        return await fetchFreshData()
    }
    
    /// API Key'i ayarla
    func setAPIKey(_ key: String) async {
        await APIKeyStore.shared.setCustomValue(key, for: "tcmb_evds_api_key")
        cachedSnapshot = nil // Cache'i invalidate et
    }
    
    /// API baglantisini test et
    func testConnection() async -> Bool {
        let apiKey = await currentAPIKey()
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
        let apiKey = await currentAPIKey()
        guard !apiKey.isEmpty else { return [] }

        let cacheKey = "\(serie.rawValue)_\(days)"
        if let cached = seriesHistoryCache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < seriesHistoryCacheValidity {
            return cached.data
        }

        let fetched = (try? await fetchSerie(serie, days: days)) ?? []
        seriesHistoryCache[cacheKey] = (fetched, Date())
        return fetched
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
        let apiKey = await currentAPIKey()
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

    // MARK: - Public Keyless Fallback Sources

    /// Resmi ve ucretsiz endpoint'lerden (API key'siz) temel snapshot olusturur.
    private func fetchPublicKeylessSnapshot() async -> TCMBMacroSnapshot? {
        async let fx = fetchPublicFXFromTCMB()
        async let rates = fetchPublicRatesFromTCMB()
        async let inflation = fetchPublicInflationFromTCMBHomepage()
        async let oil = fetchYahooPublicPrice(symbol: "CL=F")
        async let gold = fetchYahooPublicPrice(symbol: "GC=F")
        async let bist = fetchYahooPublicPrice(symbol: "XU100.IS")

        let fxValues = await fx
        let rateValues = await rates
        let inflationValue = await inflation
        let oilValue = await oil
        let goldValue = await gold
        let bistValue = await bist

        let hasAnyValue =
            fxValues.usdTry != nil ||
            fxValues.eurTry != nil ||
            rateValues.policyRate != nil ||
            inflationValue != nil ||
            oilValue != nil ||
            goldValue != nil ||
            bistValue != nil

        guard hasAnyValue else { return nil }

        return TCMBMacroSnapshot(
            usdTry: fxValues.usdTry,
            eurTry: fxValues.eurTry,
            policyRate: rateValues.policyRate,
            depositRate: rateValues.depositRate,
            loanRate: rateValues.loanRate,
            inflation: inflationValue,
            coreInflation: nil,
            gdpGrowth: nil,
            industrialProduction: nil,
            unemployment: nil,
            currentAccount: nil,
            exports: nil,
            imports: nil,
            reserves: nil,
            netReserves: nil,
            totalCredits: nil,
            tlDeposits: nil,
            brentOil: oilValue,
            goldPrice: goldValue,
            bist100: bistValue,
            capacityUsage: nil,
            creditCardSpendingBillionTL: nil,
            timestamp: Date()
        )
    }

    /// tcmb.gov.tr/kurlar/today.xml
    private func fetchPublicFXFromTCMB() async -> (usdTry: Double?, eurTry: Double?) {
        guard let url = URL(string: "https://www.tcmb.gov.tr/kurlar/today.xml") else {
            return (nil, nil)
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let xml = String(data: data, encoding: .utf8) else {
                return (nil, nil)
            }

            let usd = extractForexBuying(xml: xml, currencyCode: "USD")
            let eur = extractForexBuying(xml: xml, currencyCode: "EUR")
            return (usd, eur)
        } catch {
            print("⚠️ TCMB keyless FX alınamadı: \(error)")
            return (nil, nil)
        }
    }

    /// tcmb.gov.tr/.../anasayfa_faizorani.json
    private func fetchPublicRatesFromTCMB() async -> (policyRate: Double?, depositRate: Double?, loanRate: Double?) {
        guard let url = URL(string: "https://www.tcmb.gov.tr/wps/wcm/connect/tr/tcmb+tr/main+page+site+area/anasayfa_faizorani.json") else {
            return (nil, nil, nil)
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return (nil, nil, nil)
            }

            let responseBody = try JSONDecoder().decode(TCMBHomepageRatesResponse.self, from: data)
            let byName = Dictionary(uniqueKeysWithValues: responseBody.rates.map { ($0.name, $0.value) })

            let policy = parseLocalizedDouble(byName["hr-bv"])
            let deposit = parseLocalizedDouble(byName["gon-ba"])
            let loan = parseLocalizedDouble(byName["gon-bv"])
            return (policy, deposit, loan)
        } catch {
            print("⚠️ TCMB keyless faiz oranları alınamadı: \(error)")
            return (nil, nil, nil)
        }
    }

    /// tcmb.gov.tr anasayfa Highcharts serisinden son enflasyon degeri.
    private func fetchPublicInflationFromTCMBHomepage() async -> Double? {
        guard let url = URL(string: "https://www.tcmb.gov.tr/") else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return extractLatestInflationFromHomepage(html: html)
        } catch {
            print("⚠️ TCMB keyless enflasyon alınamadı: \(error)")
            return nil
        }
    }

    /// Yahoo public endpoint uzerinden destekleyici emtia/endeks fiyatı.
    private func fetchYahooPublicPrice(symbol: String) async -> Double? {
        await fetchYahooPublicQuote(symbol: symbol)?.c
    }

    /// Yahoo public endpoint'ten quote ceker (price + previous close + degisim).
    private func fetchYahooPublicQuote(symbol: String) async -> Quote? {
        do {
            return try await YahooFinanceProvider.shared.fetchQuote(symbol: symbol)
        } catch {
            return nil
        }
    }

    private func extractForexBuying(xml: String, currencyCode: String) -> Double? {
        let escapedCode = NSRegularExpression.escapedPattern(for: currencyCode)
        let pattern = "<Currency[^>]*Kod=\\\"\(escapedCode)\\\"[\\s\\S]*?<ForexBuying>([^<]+)</ForexBuying>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let nsRange = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let match = regex.firstMatch(in: xml, options: [], range: nsRange),
              let range = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        return parseLocalizedDouble(String(xml[range]))
    }

    private func extractLatestInflationFromHomepage(html: String) -> Double? {
        guard let chartStart = html.range(of: "Highcharts.chart('container'") else { return nil }
        let suffix = String(html[chartStart.lowerBound...])
        let chartSection: String
        if let colorsStart = suffix.range(of: "colors:[") {
            chartSection = String(suffix[..<colorsStart.lowerBound])
        } else {
            chartSection = suffix
        }

        guard let regex = try? NSRegularExpression(pattern: "y:\\s*([0-9]+(?:[\\.,][0-9]+)?)", options: []) else {
            return nil
        }

        let nsRange = NSRange(chartSection.startIndex..<chartSection.endIndex, in: chartSection)
        let matches = regex.matches(in: chartSection, options: [], range: nsRange)
        guard let lastMatch = matches.last,
              let range = Range(lastMatch.range(at: 1), in: chartSection) else {
            return nil
        }

        return parseLocalizedDouble(String(chartSection[range]))
    }

    private func parseLocalizedDouble(_ value: String?) -> Double? {
        guard let raw = value else { return nil }
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !normalized.isEmpty, normalized != "-", normalized != "null" else {
            return nil
        }
        return Double(normalized)
    }

    private struct TCMBHomepageRatesResponse: Codable {
        struct Item: Codable {
            let name: String
            let value: String
        }
        let rates: [Item]
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

        async let usdTryQuote = fetchYahooPublicQuote(symbol: "TRY=X")
        async let dxyValue = fetchYahooPublicPrice(symbol: "DX-Y.NYB")
        async let vixValue = fetchYahooPublicPrice(symbol: "^VIX")
        async let xu100Value = fetchYahooPublicPrice(symbol: "XU100.IS")
        async let oilValue = fetchYahooPublicPrice(symbol: "CL=F")
        async let goldValue = fetchYahooPublicPrice(symbol: "GC=F")

        let usdQuote = await usdTryQuote
        let dxy = await dxyValue
        let vix = await vixValue
        let xu100 = await xu100Value
        let oil = await oilValue
        let gold = await goldValue
        let usdTry = snapshot.usdTry ?? usdQuote?.c

        // Kritik veriler yoksa analiz yapma (Clean Rice Protocol)
        guard let usdTry, usdTry > 0 else { return nil }

        // Onceki gun kapanisi: gercek quote'tan geliyorsa onu, yoksa mevcut degeri kullan.
        let previousUsdTry = (usdQuote?.previousClose ?? snapshot.usdTry ?? usdTry)

        return SirkiyeEngine.SirkiyeInput(
            usdTry: usdTry,
            usdTryPrevious: previousUsdTry,
            dxy: dxy,
            brentOil: snapshot.brentOil ?? oil,
            globalVix: vix,
            newsSnapshot: nil,
            currentInflation: snapshot.inflation,
            policyRate: snapshot.policyRate,
            xu100Change: nil,
            xu100Value: snapshot.bist100 ?? xu100,
            goldPrice: snapshot.goldPrice ?? gold
        )
    }
}

// MARK: - Oracle Engine Integration
extension TCMBDataService {
    /// OracleEngine icin genisletilmis veri seti
    /// Veri yoksa alanlar nil kalir; sahte/fallback rakam uretilmez.
    func getOracleInput() async -> OracleDataInput {
        let snapshot = await getMacroSnapshot()
        async let kkoHistory = fetchKKOWithHistory()
        async let ccHistory = fetchCCSpendingWithHistory()
        let kko = await kkoHistory
        let cc = await ccHistory

        return OracleDataInput(
            inflationYoY: snapshot.inflation,
            housingSalesTotal: nil,
            housingSalesChangeYoY: nil,
            housingSalesChangeMoM: nil,
            creditCardSpendingTotal: cc?.current ?? snapshot.creditCardSpendingBillionTL,
            creditCardSpendingChangeYoY: cc?.changeYoY,
            capacityUsageRatio: kko?.current ?? snapshot.capacityUsage,
            prevCapacityUsageRatio: kko?.prevYear,
            touristArrivalsTotal: nil,
            touristArrivalsChangeYoY: nil,
            autoSalesTotal: nil,
            autoSalesChangeYoY: nil
        )
    }

    /// KKO için YoY değişim hesapla (1 yıllık veri çekerek)
    func fetchKKOWithHistory() async -> (current: Double, prevYear: Double)? {
        let apiKey = await currentAPIKey()
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
        let apiKey = await currentAPIKey()
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
