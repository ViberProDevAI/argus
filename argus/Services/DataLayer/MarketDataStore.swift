import Foundation
import Combine

/// Unified Data Store - The Single Source of Truth
/// Owns all data caches, handles request coalescing (deduplication), and enforces TTLs.
@MainActor
final class MarketDataStore: ObservableObject {
    static let shared = MarketDataStore()
    
    // MARK: - State (The Truth)
    // We use DataValue wrapper to include Provenance and Freshness
    @Published var quotes: [String: DataValue<Quote>] = [:]
    @Published var candles: [String: DataValue<[Candle]>] = [:]
    @Published var fundamentals: [String: DataValue<FinancialsData>] = [:]
    @Published var macro: [String: DataValue<MacroData>] = [:]
    
    // MARK: - Coalescing (Flight Control)
    private var quoteTasks: [String: Task<Quote, Error>] = [:]
    private var candleTasks: [String: Task<[Candle], Error>] = [:]
    private var macroTasks: [String: Task<MacroData, Error>] = [:]
    private var fundamentalTasks: [String: Task<FinancialsData, Error>] = [:]

    // MARK: - User Focus (Phase 6 PR-C.2)
    /// Detay sayfası açıldığında bu sembol set edilir. AutoPilot taraması
    /// kullanıcı bir sembolde odaklıyken çalışmamalı — onun yerine **odaklanılan
    /// sembolün** istekleri full bant genişliğine erişsin. Detay sayfası
    /// `.onAppear { setUserFocus(symbol) }` / `.onDisappear { clearUserFocus() }`
    /// pattern'iyle yönetir. AutoPilot.scanMarket başında bu değer kontrol edilir.
    @Published var userFocusedSymbol: String?

    func setUserFocus(_ symbol: String) {
        userFocusedSymbol = symbol
    }

    func clearUserFocus() {
        userFocusedSymbol = nil
    }
    
    // MARK: - Configuration
    // Phase 5 (2026-04-29): Quote TTL 15s → 60s. Yahoo rate baskısı altında 15sn'lik
    // refresh agresifti — UI 5sn auto-refresh'i ile çakışıyor, fan-out hacmini şişiriyordu.
    // Intra-day fiyat hareketi için 60s yeterli; Engine'in kendi event-driven
    // invalidation'ı (yeni bar geldiğinde) zaten cache'i güncelliyor.
    private let quoteTTL: TimeInterval = 60 // 60 seconds (was 15)
    private let macroTTL: TimeInterval = 3600 // 1 hour (Macro changes slowly)
    private let fundamentalsTTL: TimeInterval = 86400 // 24 hours
    
    private init() {}
    
    // MARK: - Public API (Accessors)
    
    func getQuote(for symbol: String) -> Quote? {
        return quotes[symbol]?.value
    }
    
    // Provenance Access
    func getQuoteProvenance(for symbol: String) -> DataProvenance? {
        return quotes[symbol]?.provenance
    }
    
    /// Live Quotes Dictionary - TradingViewModel uyumlu format
    /// DataValue wrapper'ı unwrap ederek [String: Quote] döndürür
    var liveQuotes: [String: Quote] {
        var result: [String: Quote] = [:]
        for (symbol, dataValue) in quotes {
            if let quote = dataValue.value {
                result[symbol] = quote
            }
        }
        return result
    }

    /// Injection for Streaming Engine (MarketDataProvider)
    func injectLiveQuote(_ quote: Quote, source: String) {
        guard let sym = quote.symbol else { return }
        
        var finalQuote = quote
        
        // MERGE LOGIC: Preserve rich data (Previous Close, Name, etc.) from existing Cache
        if let existing = quotes[sym]?.value {
            if finalQuote.previousClose == nil {
                finalQuote.previousClose = existing.previousClose
            }
            if finalQuote.shortName == nil {
                finalQuote.shortName = existing.shortName
            }
            if finalQuote.marketCap == nil {
                finalQuote.marketCap = existing.marketCap
            }
            if finalQuote.peRatio == nil {
                finalQuote.peRatio = existing.peRatio
            }
        }
        
        // SESSION BASELINE LOGIC (Sychronized with ViewModel)
        // If no previousClose exists (even after merge), assume current price is the start.
        if finalQuote.previousClose == nil || finalQuote.previousClose == 0 {
            finalQuote.previousClose = finalQuote.currentPrice
        }
        
        // Manual Recalculation (Session based change)
        if (finalQuote.d == nil || finalQuote.d == 0) && (finalQuote.previousClose != nil && finalQuote.previousClose! > 0) {
            finalQuote.d = finalQuote.currentPrice - finalQuote.previousClose!
            finalQuote.dp = (finalQuote.d! / finalQuote.previousClose!) * 100.0
        }
            // If the stream sends 0 change, and we have previousClose, let the computed property handle it.
            // But we must ensure d/dp are nil if strictly 0 so the computed property kicks in? 
            // Actually Quote.change logic is: if d != 0 return d. 
            // TwelveDataService sends 0. So we should probably reset d/dp to nil if they are 0 in the stream, 
            // so the specific logic `if let val = d, val != 0` skips and goes to `previousClose`.
            
        // MANUAL DERIVATION (Senior Architect Fix)
        // If the Stream/Provider sends 0.00% (or nil), we MUST attempt to derive it from Cached Candles.
        // This is the "Safety Net" for the 0.00% bug.
        if (finalQuote.dp == nil || finalQuote.dp == 0) {
            // Check Cached Candles for this symbol
            // We need a synchronous check or assume "injectLiveQuote" might be called often.
            // Since this is MainActor, we can access 'candles' directly.
            
            // Try 1-Day Candles first (Best for Day Change)
            if let dailyData = candles["\(sym)_1d"]?.value ?? candles["\(sym)_1day"]?.value {
                 if dailyData.count >= 2 {
                     // Last candle is "today" (incomplete), previous is "yesterday"
                     let prevClose = dailyData[dailyData.count - 2].close
                     if prevClose > 0 {
                         finalQuote.previousClose = prevClose // Correct the baseline
                         finalQuote.d = finalQuote.currentPrice - prevClose
                         finalQuote.dp = (finalQuote.d! / prevClose) * 100.0
                     }
                 }
            }
        }

        // Final Cleanup: If still 0, ensure it's nil so UI shows "—" instead of "0.00%"
        // This enforces the "No Fake Data" rule.
        if finalQuote.dp == 0.0 && finalQuote.d == 0.0 {
             // Only if price is also 0? No, if price hasn't moved it IS 0.00.
             // But usually it's unlikely to be EXACTLY 0.000000 unless market is closed and no data.
             // We'll leave it 0.0 if we successfully calculated it, but if it was 0 from start and we failed to calculate,
             // we might want to mark it?
             // For now, let's trust the logic above. If we found a prevClose, 0 is valid.
             // If we didn't fine prevClose, we set d/dp to nil.
             if finalQuote.previousClose == nil || finalQuote.previousClose == 0 {
                 finalQuote.d = nil
                 finalQuote.dp = nil
             }
        }
        
        self.quotes[sym] = DataValue.fresh(finalQuote, source: source)
    }
    
    func getDataValueQuote(for symbol: String) -> DataValue<Quote>? {
        return quotes[symbol]
    }
    
    // MARK: - Generic Fetch Orchestration
    
    /// Ensures we have fresh Quote data. Returns the data (cached or fetched).
    ///
    /// Phase 6 PR-D (2026-04-29) — Stale-While-Revalidate.
    /// Cache stale ama mevcut bir değer varsa eski veri **anında** döner ve arka
    /// planda fresh fetch tetiklenir. Kullanıcı asla "Hazırlanıyor" boş ekran
    /// görmez (cache'inde değer varsa). Yalnızca cache hiç yok ya da çok eski
    /// (4× TTL) ise blocking fetch yapılır.
    @discardableResult
    func ensureQuote(symbol: String) async -> DataValue<Quote> {
        // 1. Check Cache
        if let current = quotes[symbol] {
            let age = -current.provenance.fetchedAt.timeIntervalSinceNow

            // 1a. Fresh: hemen dön.
            if current.isFresh && age < quoteTTL {
                return current
            }

            // 1b. Stale-while-revalidate: değer var, makul yaşta (<4× TTL),
            //     in-flight task yok → eski veriyi anında dön + arka planda yenile.
            if current.value != nil,
               age < quoteTTL * 4,
               quoteTasks[symbol] == nil {
                Task { [weak self] in
                    _ = await self?.fetchAndStoreQuote(symbol: symbol)
                }
                return current
            }
        }

        // 2. Check In-Flight (Dedup)
        if let existingTask = quoteTasks[symbol] {
            do {
                let result = try await existingTask.value
                return processQuoteSuccess(symbol: symbol, quote: result, source: "Coalesced")
            } catch {
                return processQuoteFailure(symbol: symbol, error: error)
            }
        }

        // 3. Phase 7 PR-Q+: Daily candle cache'inden türet.
        //    Cache hiç yok ama daily candle var → ek istek atmadan quote ürer.
        //    Detay panelinden ya da daha önce çekilmiş bir candles var ise
        //    quote için ayrıca network gitmeye gerek yok. Arka planda yine
        //    fresh quote fetch tetiklenir (UI'a sonra gelir).
        if let derived = quoteFromDailyCache(symbol: symbol) {
            let val = processQuoteSuccess(symbol: symbol, quote: derived, source: "Derived-Candle")
            Task { [weak self] in
                _ = await self?.fetchAndStoreQuote(symbol: symbol)
            }
            return val
        }

        // 4. Blocking fetch — hiçbir kaynak yok.
        return await fetchAndStoreQuote(symbol: symbol)
    }

    /// Phase 7 PR-Q+: Daily candle cache'inden quote türetir.
    /// 1d/1day master cache'inde en az 2 bar varsa son kapanış = current,
    /// önceki bar = previous close → quote inşa edilir. Currency sembol
    /// pattern'ından infer edilir (`.IS` → TRY, `-USD` → USD, default USD).
    /// Yetersiz veri / kötü prev → nil.
    private func quoteFromDailyCache(symbol: String) -> Quote? {
        let candidates = ["\(symbol)_1day"]
        for key in candidates {
            guard let candleList = candles[key]?.value, candleList.count >= 2 else { continue }
            guard let last = candleList.last else { continue }
            let prev = candleList[candleList.count - 2]
            guard prev.close > 0 else { continue }

            let change = last.close - prev.close
            let pct = (change / prev.close) * 100

            let upper = symbol.uppercased()
            let inferredCurrency: String = {
                if upper.hasSuffix(".IS") { return "TRY" }
                if upper.contains("-USD") { return "USD" }
                if upper.hasSuffix("=X") { return "USD" }
                if upper.hasSuffix("=F") { return "USD" }
                return "USD"
            }()

            var q = Quote(
                c: last.close,
                d: change,
                dp: pct,
                currency: inferredCurrency,
                shortName: nil,
                symbol: symbol
            )
            q.previousClose = prev.close
            q.timestamp = Date()
            return q
        }
        return nil
    }

    /// Yeni bir quote fetch task'i başlatır, sonucu cache'e yazar ve döndürür.
    /// `ensureQuote` (foreground) ve stale-while-revalidate (background) yolları
    /// tarafından paylaşılır — fetch logic tek source-of-truth.
    @discardableResult
    private func fetchAndStoreQuote(symbol: String) async -> DataValue<Quote> {
        let task = Task<Quote, Error> {
            return try await HeimdallOrchestrator.shared.requestQuote(symbol: symbol)
        }
        quoteTasks[symbol] = task

        do {
            let result = try await task.value
            quoteTasks[symbol] = nil
            return processQuoteSuccess(symbol: symbol, quote: result, source: "Heimdall")
        } catch {
            quoteTasks[symbol] = nil
            return processQuoteFailure(symbol: symbol, error: error)
        }
    }
    
    private func processQuoteSuccess(symbol: String, quote: Quote, source: String) -> DataValue<Quote> {
        let val = DataValue.fresh(quote, source: source)
        self.quotes[symbol] = val
        return val
    }
    
    private func processQuoteFailure(symbol: String, error: Error) -> DataValue<Quote> {
        // print yerine kategori bazlı log — DataPipeline bölümünden filtrelenir.
        // Eski veri varsa stale olarak korunur ki UI "boş" yerine "eski" gösterebilsin.
        let msg = error.localizedDescription
        if let old = quotes[symbol], old.value != nil {
            ArgusLogger.info("\(symbol) quote fetch başarısız (\(msg)) — stale fallback", category: "DataPipeline")
            let newVal = DataValue(
                value: old.value,
                provenance: old.provenance,
                status: .stale
            )
            self.quotes[symbol] = newVal
            return newVal
        }

        ArgusLogger.warn("\(symbol) quote fetch başarısız + cache yok: \(msg)", category: "DataPipeline")
        let missing = DataValue<Quote>.missing(reason: msg)
        self.quotes[symbol] = missing
        return missing
    }
    
    // MARK: - Candles
    
    func ensureCandles(symbol: String, timeframe: String) async -> DataValue<[Candle]> {
        // Phase 5 (2026-04-29): Cache key normalizasyonu.
        let canonicalTimeframe = Self.normalizeTimeframe(timeframe)
        let key = "\(symbol)_\(canonicalTimeframe)"

        // Phase 7+ (2026-04-29): Candle TTL + SWR.
        // `DataValue.isFresh` 15 saniye sonra stale sayıyordu — günlük mum 15 sn'de
        // değişmez, ama eskiden ensureCandles 15 sn sonra tekrar fetch'e gidiyordu.
        // Prometheus + Orion peş peşe açılınca aynı candle 2-3 kez fetch ediliyor →
        // ikincisi rate-limit / cancel yiyince Orion fail → "Analiz Başarısız" hatası.
        //
        // Yeni: timeframe-bazlı TTL + stale-while-revalidate. Cache'te değer varsa
        // anında dön; eski ise arkada yenile.
        if let current = candles[key], let value = current.value, !value.isEmpty {
            let age = -current.provenance.fetchedAt.timeIntervalSinceNow
            let ttl = Self.candleTTL(for: canonicalTimeframe)

            // Fresh: hemen dön.
            if age < ttl { return current }

            // Stale: eski değeri DÖNDÜR + arka planda yenile (SWR).
            // In-flight task varsa yeni başlatma — coalescing.
            if candleTasks[key] == nil && age < ttl * 4 {
                Task { [weak self] in
                    _ = await self?.fetchAndStoreCandles(symbol: symbol, timeframe: timeframe, canonicalKey: key)
                }
                return current
            }
        }

        // 2. Coalesce — in-flight task varsa onu bekle.
        if let task = candleTasks[key] {
            let _ = await task.result
            return candles[key] ?? .missing(reason: "Task failed")
        }

        // 3. Phase 6 PR-B: Daily ailesi için master daily seriyi kullan.
        //
        // 1d/1wk/1mo/3mo aynı kaynaktan (1d, range=max) gelen daily seriden
        // lokalde aggregate edilebilir. 1d zaten master; 1wk/1mo/3mo master'ı
        // alıp `MultiTimeframeCandleService.aggregate` ile türetir. Tek hisse
        // için 4 daily-aile timeframe'i 4 yerine **1 Yahoo isteği** ister.
        if MultiTimeframeCandleService.isDailyFamily(canonicalTimeframe),
           canonicalTimeframe != "1day" {
            // Türev timeframe — master daily'yi al, aggregate et.
            let masterValue = await ensureCandles(symbol: symbol, timeframe: "1day")
            guard let dailyList = masterValue.value, !dailyList.isEmpty else {
                let missing = DataValue<[Candle]>.missing(
                    reason: masterValue.provenance.evidence ?? "Master daily yok"
                )
                candles[key] = missing
                return missing
            }
            let aggregated = MultiTimeframeCandleService.aggregate(daily: dailyList, to: canonicalTimeframe)
            let val = DataValue.fresh(aggregated, source: "Daily-Aggregate")
            candles[key] = val
            return val
        }

        // 4. Blocking fetch — cache hiç yok ya da çok eski.
        return await fetchAndStoreCandles(symbol: symbol, timeframe: timeframe, canonicalKey: key)
    }

    /// Yeni bir candles fetch task'i başlatır, sonucu cache'e yazar ve döndürür.
    /// `ensureCandles` (foreground) ve stale-while-revalidate (background) yolları
    /// tarafından paylaşılır — fetch logic tek source-of-truth.
    @discardableResult
    private func fetchAndStoreCandles(symbol: String, timeframe: String, canonicalKey: String) async -> DataValue<[Candle]> {
        let task = Task<[Candle], Error> {
            let limit = candleLimit(for: timeframe)
            return try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: timeframe, limit: limit)
        }
        candleTasks[canonicalKey] = task

        do {
            let data = try await task.value
            candleTasks[canonicalKey] = nil
            let val = DataValue.fresh(data)
            candles[canonicalKey] = val
            return val
        } catch {
            candleTasks[canonicalKey] = nil
            print("📉 Store: Candles failed for \(canonicalKey): \(error)")
            // SWR: cache'te eski değer varsa stale olarak koru.
            // Ki üst seviye ensureCandles "no value" yerine eski candle'ı dönsün.
            if let old = candles[canonicalKey], let value = old.value, !value.isEmpty {
                let staleVal = DataValue(value: value, provenance: old.provenance, status: .stale)
                candles[canonicalKey] = staleVal
                return staleVal
            }
            let missing = DataValue<[Candle]>.missing(reason: error.localizedDescription)
            candles[canonicalKey] = missing
            return missing
        }
    }

    /// Phase 7+ (2026-04-29): Timeframe-bazlı cache TTL.
    /// Daha önce DataValue.isFresh 15 saniye sabitti — daily candle 15 sn'de
    /// değişmez ama 15 sn sonra cache stale sayılıp tekrar fetch'e gidiyordu.
    /// Bu da "ABBV detayı açıldığında Orion analiz başarısız" semptomunun ana
    /// sebebiydi (Prometheus daily fetch + Orion daily fetch arasındaki 15 sn'de
    /// ikinci fetch rate-limit yiyince tüm 6 timeframe fail).
    private static func candleTTL(for canonicalTimeframe: String) -> TimeInterval {
        switch canonicalTimeframe {
        case "5m":               return 60          // 1 dk — intraday hızlı bayatlar
        case "15m":              return 180         // 3 dk
        case "1h":               return 600         // 10 dk
        case "4h":               return 1800        // 30 dk
        case "1day":             return 1800        // 30 dk — gün ortasında son bar değişir
        case "1week", "1month",
             "3month":           return 3600        // 1 saat — uzun vade nadiren değişir
        default:                 return 300         // 5 dk default
        }
    }

    /// Cache key için kanonik timeframe adı.
    /// "1day", "1d", "1G", "1D", "daily" → "1day"; "1h", "1H", "60m" → "1h"; vs.
    /// Provider çağrılarında orijinal string geçirilir — Yahoo adapter'ı kendi
    /// mapping'ini yapıyor. Bu sadece coalescing/cache için.
    private static func normalizeTimeframe(_ tf: String) -> String {
        let trimmed = tf.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "1day", "1d", "1g", "daily", "d":         return "1day"
        case "1h", "1hour", "60m", "60min", "1s":      return "1h"
        case "4h", "4hour", "240m", "240min", "4s":    return "4h"
        case "15m", "15min", "15d":                    return "15m"
        case "5m", "5min", "5d":                       return "5m"
        case "1week", "1wk", "1w", "weekly":           return "1week"
        case "1month", "1mo", "1mon", "monthly":       return "1month"
        default:                                       return trimmed
        }
    }

    private func candleLimit(for timeframe: String) -> Int {
        let trimmed = timeframe.trimmingCharacters(in: .whitespacesAndNewlines)

        // UI kısa kodları (case-sensitive)
        switch trimmed {
        case "1H": return 260 // Haftalık
        case "1G": return 365
        case "1S": return 240
        case "4S": return 240
        case "15D", "5D": return 300
        default: break
        }

        let normalized = trimmed.lowercased()
        if ["1week", "1wk", "1w"].contains(normalized) { return 260 }
        if ["1day", "1d", "1g"].contains(normalized) { return 365 }
        if ["4h", "4hour", "240m", "240min"].contains(normalized) { return 240 }
        if ["1h", "1hour", "60min"].contains(normalized) { return 240 }
        if ["15m", "15min", "5m", "5min"].contains(normalized) { return 300 }
        return 200
    }
    
    // MARK: - Fundamentals (Atlas)
    
    func ensureFundamentals(symbol: String) async -> DataValue<FinancialsData> {
        // Cache
        if let current = fundamentals[symbol], !current.isMissing {
            return current
        }
        
        if let task = fundamentalTasks[symbol] {
             let _ = await task.result
             return fundamentals[symbol] ?? .missing(reason: "Task already in progress")
        }
        
        let task = Task<FinancialsData, Error> {
            try await HeimdallOrchestrator.shared.requestFundamentals(symbol: symbol)
        }
        fundamentalTasks[symbol] = task
        
        do {
            let data = try await task.value
            fundamentalTasks[symbol] = nil
            let val = DataValue.fresh(data)
            fundamentals[symbol] = val
            return val
        } catch {
             fundamentalTasks[symbol] = nil
             return .missing(reason: "Fetch failed")
        }
    }
    
    // MARK: - Bulk Operations

    /// Tek seferde ne kadar paralel ensureQuote çalıştırılacağı. Yahoo cap
    /// ~5 req/s; chunk=10 + 600ms ara → bir önceki chunk'ın ilk 5'i pencerede,
    /// sonraki 5 backoff'ta zaten beklerken yeni chunk geliyor. Eskiden 304
    /// sembolün hepsi aynı anda paralel gönderiliyordu → acquireSlot kuyruğu
    /// patlayıp 200+ istek 30s'de timeout oluyordu ("kimisi boş" semptomu).
    // Phase 6 PR-A ROLLBACK (2026-04-29):
    //
    // Yahoo `v7/finance/quote?symbols=A,B,C` batch endpoint'ini engelledi
    // (HTTP 401 "User is unable to access this feature" — bit.ly/yahoo-finance-api-feedback).
    // Production loglarında onlarca 401 alındı. PR-A iyi niyetli ama fiilen
    // ÇALIŞMAYAN bir yola gitti. `requestQuotesBatch` artık çağrılmıyor (deprecated).
    //
    // Yeni yaklaşım: Phase 5'in chunked yaklaşımına dön — N sembol için
    // 8'lik chunk × inflight semaphore (Yahoo cap=4) ile akar şekilde dağılan
    // single quote istekleri. Tek-sembol endpoint hâlâ çalışıyor.
    //
    // Phase 5'ten farklılıklar:
    //  • Chunk 4 → 8 (PR-D SWR çoğu çağrıyı zaten kesiyor; daha büyük chunk OK)
    //  • Delay 2sn → 800ms (inflight semaphore + SWR yastığı yeterli; uzun delay
    //    artık gereksiz)
    private static let chunkSize = 8
    private static let chunkDelayNs: UInt64 = 800_000_000 // 800 ms

    /// Watchlist gibi N>1 senaryolarda sembolleri chunked paralel olarak çeker.
    /// SWR ve in-flight coalescing `ensureQuote` içinde devrede; aynı sembol için
    /// duplikate fetch yok. Cache fresh olanlar zaten orada filtreleniyor.
    func ensureQuotes(symbols: [String]) async {
        let needsFetch = symbols.filter { sym in
            if let current = quotes[sym] {
                let age = -current.provenance.fetchedAt.timeIntervalSinceNow
                if current.isFresh && age < quoteTTL { return false }
            }
            return true
        }
        guard !needsFetch.isEmpty else { return }

        let chunks = stride(from: 0, to: needsFetch.count, by: MarketDataStore.chunkSize).map {
            Array(needsFetch[$0..<min($0 + MarketDataStore.chunkSize, needsFetch.count)])
        }

        for (index, batch) in chunks.enumerated() {
            await withTaskGroup(of: Void.self) { group in
                for sym in batch {
                    group.addTask { [weak self] in
                        _ = await self?.ensureQuote(symbol: sym)
                    }
                }
            }
            if index < chunks.count - 1 {
                try? await Task.sleep(nanoseconds: MarketDataStore.chunkDelayNs)
            }
        }
    }

    /// Phase 6 öncesi `ensureQuotesParallel` (sınırsız paralel `ensureQuote`)
    /// silindi — N sembollük tüm senaryolar artık `ensureQuotes` üzerinden
    /// tek Yahoo batch isteğine indirgeniyor.
    ///
    /// Tek-sembol için `ensureQuote(symbol:)` korunuyor (detay sayfası gibi
    /// tekil/anında senaryolar batch latency'sini bekleyemez).

    /// Batch Refresh Logic - ViewModel'lerden çağrılan public API.
    /// Yahoo `v7/finance/quote?symbols=...` üzerinden tek batch istekle akar.
    func refreshQuotes(symbols: [String]) async throws {
        await ensureQuotes(symbols: symbols)
    }
    // MARK: - Historical Data Access (Validator)
    
    /// Belirli bir tarihteki kapanış fiyatını getirir.
    /// Validator (Doğrulayıcı) modülü için kritik önem taşır.
    /// Önce cache'deki mumlara bakar, yoksa API'ye gider (henüz API geçmiş veri çekme implemente edilmediği için mum cache'i esastır).
    func fetchHistoricalClose(symbol: String, targetDate: Date) async -> Double? {
        // En yakın mumu bulmak için 1 günlük mumları kullanırız
        let candlesResult = await ensureCandles(symbol: symbol, timeframe: "1day")
        
        guard let candles = candlesResult.value, !candles.isEmpty else {
            return nil
        }
        
        // Hedef tarihe en yakın mumu bul
        // Mum tarihleri genellikle gün başlangıcıdır (00:00).
        let calendar = Calendar.current
        
        // Basit arama (Veri seti küçük olduğu için yeterli, ileride Binary Search yapılabilir)
        // Tarih sırasına göre olduğu varsayımıyla (Heimdall sort eder)
        
        let targetDay = calendar.startOfDay(for: targetDate)
        
        // Tam eşleşme ara
        if let match = candles.first(where: { calendar.isDate($0.date, inSameDayAs: targetDay) }) {
            return match.close
        }
        
        // Tam eşleşme yoksa (haftasonu vb.), hedef tarihten ÖNCEKİ en son kapanışı bul (Latest Known Value)
        // Veya hedef tarih bir "vade" ise ve o gün veri yoksa, o günü takip eden ilk işlem günü mü yoksa önceki mi?
        // Finansal standart: O gün tatilse, bir önceki işlem gününün kapanışı o günün değeri kabul edilir.
        
        let validCandles = candles.filter { $0.date <= targetDate }
        return validCandles.last?.close
    }
}
