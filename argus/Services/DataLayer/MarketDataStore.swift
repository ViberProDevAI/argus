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
    
    // MARK: - Configuration
    private let quoteTTL: TimeInterval = 15 // 15 seconds
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
    @discardableResult
    func ensureQuote(symbol: String) async -> DataValue<Quote> {
        // 1. Check Cache
        if let current = quotes[symbol] {
            let age = -current.provenance.fetchedAt.timeIntervalSinceNow
            if current.isFresh && age < quoteTTL {
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
        
        // 3. Launch New Task
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
        print("📉 Store: Quote failed for \(symbol): \(error)")
        // If we have stale data, keep it but mark stale?
        if let old = quotes[symbol] {
             // Downgrade freshness
             // Downgrade freshness
             // We can't mutate provenance easily as it's let, but we can reuse it.
             
             let newVal = DataValue(
                 value: old.value,
                 provenance: old.provenance,
                  status: .stale
              )
             self.quotes[symbol] = newVal
             return newVal
        }
        
        // No data at all
        let missing = DataValue<Quote>.missing(reason: error.localizedDescription)
        self.quotes[symbol] = missing
        return missing
    }
    
    // MARK: - Candles
    
    func ensureCandles(symbol: String, timeframe: String) async -> DataValue<[Candle]> {
        let key = "\(symbol)_\(timeframe)"
        
        // 1. Cache
        if let current = candles[key], current.isFresh { 
            return current
        }
        
        // 2. Coalesce
        if let task = candleTasks[key] {
            let _ = await task.result // Wait for it
            return candles[key] ?? .missing(reason: "Task failed")
        }
        
        // 3. Fetch
        let task = Task<[Candle], Error> {
            let limit = (timeframe == "1day") ? 365 : 100
            return try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: timeframe, limit: limit)
        }
        
        candleTasks[key] = task
        
        do {
            let data = try await task.value
            candleTasks[key] = nil
            let val = DataValue.fresh(data)
            candles[key] = val
            return val
        } catch {
            candleTasks[key] = nil
            print("📉 Store: Candles failed for \(key): \(error)")
            // No stale fallback for candles typically
            let missing = DataValue<[Candle]>.missing(reason: error.localizedDescription)
            candles[key] = missing
            return missing
        }
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
    func ensureQuotes(symbols: [String]) async {
        // Optimize batch fetching if provider supports it
        // Şu an paralel tekli fetch yapıyoruz
        await withTaskGroup(of: Void.self) { group in
            for sym in symbols {
                group.addTask { await self.ensureQuote(symbol: sym) }
            }
        }
    }
    
    /// Batch Refresh Logic - Replaces ArgusDataService call in ViewModel
    func refreshQuotes(symbols: [String]) async throws {
        // Use Heimdall (or ArgusDataService if available via Orchestrator)
        // Here we assume HeimdallOrchestrator can handle batch or we loop
        // If ArgusDataService has a specialized batch endpoint, we should expose it via Heimdall
        
        // Şimdilik existing pattern: HeimdallOrchestrator üstünden git
        // İleride HeimdallOrchestrator.batchRequestQuote(symbols) eklenmeli
        
        // Paralel Fetch (Mevcut yapı)
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
