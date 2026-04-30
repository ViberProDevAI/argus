import Foundation
import Combine

// MARK: - PortfolioStore
/// Tek Gerçek Kaynak (Single Source of Truth) portföy yönetim sistemi.
/// Tüm portföy işlemleri bu class üzerinden yapılır.
/// BIST ve Global piyasalar ayrı bakiyeler, tek portföy listesi.

@MainActor
final class PortfolioStore: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PortfolioStore()
    
    // MARK: - Published State
    @Published private(set) var trades: [Trade] = [] {
        didSet {
            // CACHE PERFORMANCE: trades değiştiğinde filtered alt küme cache'lerini
            // bir kez hesapla. Önceden computed property'di ve PortfolioView,
            // DailyAgendaView, PortfolioPlanBoard, TradeBrainStatusBand gibi 6+
            // yerde body içinde her render'da .filter çalışıyordu. Artık tek
            // mutasyonla 4 cache güncellenir, view body'leri O(1) okuma yapar.
            recomputeFilteredCaches()
        }
    }
    @Published private(set) var globalBalance: Double = -1.0 // -1 denotes "Not Loaded"
    @Published private(set) var bistBalance: Double = -1.0   // -1 denotes "Not Loaded"
    @Published private(set) var transactions: [Transaction] = []

    // MARK: - Cached Filtered Subsets (Performance)
    @Published private(set) var openTradesCache: [Trade] = []
    @Published private(set) var closedTradesCache: [Trade] = []
    @Published private(set) var globalOpenTradesCache: [Trade] = []
    @Published private(set) var bistOpenTradesCache: [Trade] = []

    private func recomputeFilteredCaches() {
        var open: [Trade] = []
        var closed: [Trade] = []
        var globalOpen: [Trade] = []
        var bistOpen: [Trade] = []
        open.reserveCapacity(trades.count)
        for trade in trades {
            if trade.isOpen {
                open.append(trade)
                if trade.currency == .USD { globalOpen.append(trade) }
                else if trade.currency == .TRY { bistOpen.append(trade) }
            } else {
                closed.append(trade)
            }
        }
        openTradesCache = open
        closedTradesCache = closed
        globalOpenTradesCache = globalOpen
        bistOpenTradesCache = bistOpen
    }
    
    // MARK: - Persistence Keys (V6 - FileManager)
    private let portfolioFileName = "argus_portfolio_v6.json"
    private let transactionsFileName = "argus_transactions_v6.json"
    private let balanceFileName = "argus_balance_v6.json"
    
    // Legacy Keys for Migration
    private let legacyPortfolioKey = "argus_portfolio_v5" 
    private let legacyGlobalBalanceKey = "argus_balance_usd_v5"
    private let legacyBistBalanceKey = "argus_balance_try_v5"
    private let legacyTransactionsKey = "argus_transactions_v5"

    // MARK: - Debounced Save Mechanism
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 1.0 // 1 saniye

    /// Debounced disk yazma - çok sık yazma işlemlerini birleştirir
    private func scheduleDebouncedSave() {
        // Prevent saving if not loaded yet!
        if globalBalance < 0 || bistBalance < 0 {
             return
        }

        saveWorkItem?.cancel()
        saveWorkItem = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        if let workItem = saveWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
        }
    }

    /// O1: Uygulama background'a geçerken veya sonlanırken çağrılır.
    /// Bekleyen 1 sn'lik debounced save'i iptal eder ve diski anında yazar.
    ///
    /// **Neden:** `updateStops()` gibi mutasyonlar debounce kullanıyor; kullanıcı
    /// işlem yapar yapmaz uygulamayı background'a atarsa 1 sn'lik pencere içinde
    /// DispatchWorkItem henüz fire etmeden app suspend olabilir — sessiz veri
    /// kaybı. `flushNow()` bu pencereyi sıfıra indirir.
    ///
    /// **Garanti:** `@MainActor` class olduğu için main thread üzerinden çağrılmalı.
    /// scenePhase onChange ve willTerminateNotification handler'ları zaten main
    /// actor bağlamındadır.
    func flushNow() {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveToDisk()
    }

    // MARK: - Public Methods
    
    func addTransaction(_ transaction: Transaction) {
        transactions.insert(transaction, at: 0)
        saveToDisk() // Will verify balance > 0 inside
        print("📝 PortfolioStore: Transaction logged: \(transaction.type.rawValue) \(transaction.symbol)")
    }

    func addTrade(_ trade: Trade) {
        trades.append(trade)
        scheduleDebouncedSave()
    }
    
    // MARK: - Initialization
    private init() {
        print("🚀 PortfolioStore: Initializing (V6 FileManager)...")
        loadFromDisk()
    }
    
    // ... (Computed Properties omitted, they are unchanged)
    
    // MARK: - Persistence (FileManager)
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveToDisk() {
        // SAFETY CHECK: Never overwrite disk with uninitialized (-1) state
        if globalBalance < 0 || bistBalance < 0 {
            print("⚠️ PortfolioStore: Skipping Save (Balances not loaded yet)")
            return
        }
    
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let docs = getDocumentsDirectory()
        
        // 1. Save Trades
        do {
            let data = try encoder.encode(trades)
            try data.write(to: docs.appendingPathComponent(portfolioFileName))
        } catch {
            print("❌ PortfolioStore: Portfolio save failed: \(error)")
        }
        
        // 2. Save Transactions
        do {
            let data = try encoder.encode(transactions)
            try data.write(to: docs.appendingPathComponent(transactionsFileName))
            // Also backup to UserDefaults for Widget access?
            // ArgusStorage handles AppGroup sync separately.
        } catch {
            print("❌ PortfolioStore: Transactions save failed: \(error)")
        }
        
        // 3. Save Balances
        let balances = ["usd": globalBalance, "try": bistBalance]
        do {
            let data = try encoder.encode(balances)
            try data.write(to: docs.appendingPathComponent(balanceFileName))
        } catch {
             print("❌ PortfolioStore: Balance save failed: \(error)")
        }
        
        print("💾 PortfolioStore: Saved to Disk (V6) - USD: \(globalBalance)")
        
        // Sync with ArgusStorage (for Widget/AppGroup)
        ArgusStorage.shared.savePortfolio(trades)
    }
    
    private func loadFromDisk() {
        let decoder = JSONDecoder()
        let docs = getDocumentsDirectory()
        
        let balanceFile = docs.appendingPathComponent(balanceFileName)
        let portfolioFile = docs.appendingPathComponent(portfolioFileName)
        let txFile = docs.appendingPathComponent(transactionsFileName)
        
        let balanceExists = FileManager.default.fileExists(atPath: balanceFile.path)
        let portfolioExists = FileManager.default.fileExists(atPath: portfolioFile.path)
        let txExists = FileManager.default.fileExists(atPath: txFile.path)

        // 1. Check for legacy migration ONLY if no V6 files exist at all
        if !balanceExists && !portfolioExists && !txExists {
            print("📂 PortfolioStore: No V6 files found. Attempting migration from V5...")
            migrateFromV5()
            return
        }
        
        print("🚀 PortfolioStore: Loading V6 Data (Granular Load)...")
        
        // 2. Load Balances
        if balanceExists {
            do {
                let data = try Data(contentsOf: balanceFile)
                let balances = try decoder.decode([String: Double].self, from: data)
                if let usd = balances["usd"], let tl = balances["try"] {
                    globalBalance = usd
                    bistBalance = tl
                    print("✅ PortfolioStore: Balances loaded: $\(usd) / ₺\(tl)")
                }
            } catch {
                print("❌ PortfolioStore: Balance Load FAILED: \(error)")
                // Do NOT reset to default. Keep -1 to prevent 'saveToDisk' from overwriting broken file with defaults.
            }
        } else {
             print("⚠️ PortfolioStore: Balance file missing, but other V6 files exist.")
             // If we found trades but no balance, maybe it was deleted?
             // Initialize defaults to allow usage, but this is a rare edge case.
             globalBalance = 100_000.0
             bistBalance = 1_000_000.0
        }
        
        // 3. Load Trades
        if portfolioExists {
            do {
                let data = try Data(contentsOf: portfolioFile)
                trades = try decoder.decode([Trade].self, from: data)
                print("✅ PortfolioStore: \(trades.count) trades loaded")
            } catch {
                print("❌ PortfolioStore: Trades Load FAILED: \(error)")
                // Keep trades empty [] but don't delete file
            }
        }
        
        // 4. Load Transactions
        if txExists {
             do {
                let data = try Data(contentsOf: txFile)
                transactions = try decoder.decode([Transaction].self, from: data)
                print("✅ PortfolioStore: \(transactions.count) transactions loaded")
            } catch {
                print("❌ PortfolioStore: Transactions Load FAILED: \(error)")
            }
        }
        
        print("🏁 PortfolioStore: Load Complete - Trades: \(trades.count), USD: $\(globalBalance), TRY: ₺\(bistBalance)")

        // ── Tek seferlik GLOBAL RESET (2026-04-21) ────────────────────────
        // Kullanıcı isteği: "Global portföyü sıfırla, $100k yatır, baştan
        // başla." Bu flag UserDefaults'ta sadece bu build'de tetiklenir,
        // çalıştıktan sonra kendini devre dışı bırakır. BIST'e dokunmaz.
        let resetFlagKey = "Argus_PendingGlobalReset_2026_04_21"
        let alreadyDone = UserDefaults.standard.bool(forKey: resetFlagKey)
        if !alreadyDone {
            print("🚨 PortfolioStore: Pending Global Reset algılandı — yürütülüyor...")
            resetGlobalPortfolio()
            UserDefaults.standard.set(true, forKey: resetFlagKey)
            print("✅ PortfolioStore: Global reset tamamlandı, flag kapatıldı. Bu build'de bir daha çalışmaz.")
        }

        // Tek seferlik migration: `.IS` suffix'li ama USD etiketli eski trade'leri TRY'ye çek.
        //
        // BUG: SymbolResolver.isBistSymbol eskiden sadece whitelist'e bakıyordu; AYGAZ.IS,
        // AGHOL.IS gibi liste dışı BIST sembolleri USD kaydediliyordu. Fix sonrası
        // yeni alımlar doğru etiketleniyor, ama daha önce alınmış hisseler hâlâ USD.
        // Bu migration persisted kayıtları düzeltir. Flag UserDefaults'ta saklanır —
        // bir kez çalışıp kapanır.
        let bistCurrencyFixKey = "Argus_BistCurrencyFix_2026_04_23"
        let bistFixDone = UserDefaults.standard.bool(forKey: bistCurrencyFixKey)
        if !bistFixDone {
            var relabeled = 0
            for idx in trades.indices where trades[idx].symbol.uppercased().hasSuffix(".IS") && trades[idx].currency != .TRY {
                trades[idx].currency = .TRY
                relabeled += 1
            }
            if relabeled > 0 {
                print("🔧 PortfolioStore: \(relabeled) BIST trade USD→TRY'ye taşındı.")
                saveToDisk()
            }
            UserDefaults.standard.set(true, forKey: bistCurrencyFixKey)
        }
    }
    
    private func migrateFromV5() {
        let decoder = JSONDecoder()
        var migrationSuccess = false
        
        // Migrate Balances
        if let usd = UserDefaults.standard.object(forKey: legacyGlobalBalanceKey) as? Double {
            globalBalance = usd
            migrationSuccess = true
        }
        if let tl = UserDefaults.standard.object(forKey: legacyBistBalanceKey) as? Double {
            bistBalance = tl
            migrationSuccess = true
        }
        
        // Migrate Trades
        if let data = UserDefaults.standard.data(forKey: legacyPortfolioKey),
           let v5Trades = try? decoder.decode([Trade].self, from: data) {
            trades = v5Trades
            print("📦 PortfolioStore: Migrated \(trades.count) trades from V5")
            migrationSuccess = true
        }
        
        // Migrate Transactions
        if let data = UserDefaults.standard.data(forKey: legacyTransactionsKey),
           let v5Tx = try? decoder.decode([Transaction].self, from: data) {
            transactions = v5Tx
        }
        
        if migrationSuccess {
            // Validate Logic: Defaults if still negative (though migrationSuccess implies we found something)
            if globalBalance < 0 { globalBalance = 100_000.0 }
            if bistBalance < 0 { bistBalance = 1_000_000.0 }
            saveToDisk() // Create V6 files
            print("✅ PortfolioStore: V5 -> V6 Migration Successful")
        } else {
            // FRESH INSTALL
            print("🆕 PortfolioStore: No V5 data found. Fresh Install Defaults.")
            globalBalance = 100_000.0
            bistBalance = 1_000_000.0
            saveToDisk()
        }
    }
    
    /// Cache'lenmiş alt kümeler — geriye dönük uyumluluk için aynı isimle korunur.
    /// Doğrudan @Published cache'e forward eder; geri kalan kod değişiklik gerektirmez.
    var openTrades: [Trade] { openTradesCache }
    var closedTrades: [Trade] { closedTradesCache }
    var globalOpenTrades: [Trade] { globalOpenTradesCache }
    var bistOpenTrades: [Trade] { bistOpenTradesCache }
    
    // MARK: - Balance Helpers
    
    func availableBalance(for symbol: String) -> Double {
        isBistSymbol(symbol) ? bistBalance : globalBalance
    }
    
    func availableBalance(currency: Currency) -> Double {
        currency == .TRY ? bistBalance : globalBalance
    }
    
    // MARK: - Buy Operation
    
    @discardableResult
    func buy(
        symbol: String,
        quantity: Double,
        price: Double,
        source: TradeSource = .user,
        engine: AutoPilotEngine? = nil,
        stopLoss: Double? = nil,
        takeProfit: Double? = nil,
        rationale: String? = nil,
        orionSnapshot: OrionComponentSnapshot? = nil
    ) -> Trade? {
        guard quantity > 0, price > 0 else { return nil }
        
        let isBist = isBistSymbol(symbol)
        let currency: Currency = isBist ? .TRY : .USD
        let cost = quantity * price
        let commission = FeeModel.forSymbol(symbol).calculate(amount: cost)
        let totalCost = cost + commission
        
        // Balance Check
        if isBist {
            guard bistBalance >= totalCost else {
                print("❌ PortfolioEngine: Yetersiz BIST bakiyesi (₺\(bistBalance) < ₺\(totalCost))")
                return nil
            }
            bistBalance -= totalCost
        } else {
            guard globalBalance >= totalCost else {
                print("❌ PortfolioEngine: Yetersiz USD bakiyesi ($\(globalBalance) < $\(totalCost))")
                return nil
            }
            globalBalance -= totalCost
        }
        
        // Create Trade
        var trade = Trade(
            symbol: symbol,
            entryPrice: price,
            quantity: quantity,
            entryDate: Date(),
            isOpen: true,
            source: source,
            engine: engine,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            rationale: rationale,
            currency: currency
        )
        trade.entryOrionSnapshot = orionSnapshot
        // Y4: Giriş komisyonunun adet bazında payı. Kısmi satışta prorate edilir.
        // quantity > 0 `guard` üstte sağlandığı için bölme güvenli.
        trade.entryCommissionPerShare = commission / quantity

        trades.append(trade)
        
        // Log Transaction
        let transaction = Transaction(
            id: UUID(),
            type: .buy,
            symbol: symbol,
            amount: cost,
            price: price,
            date: Date(),
            fee: commission
        )
        transactions.insert(transaction, at: 0)
        
        saveToDisk()
        
        let currencySymbol = isBist ? "₺" : "$"
        print("✅ PortfolioEngine: BUY \(symbol) x\(quantity) @ \(currencySymbol)\(price)")
        return trade
    }
    
    // MARK: - Market Data Updates (Stop Loss / Take Profit)

    /// O2: Fonksiyon-seviyesi reentrancy guard. Per-trade `isPendingSale` zaten
    /// aynı trade'in iki kez satılmasını önlüyor; bu flag ise iç `sell()` →
    /// @Published mutation → subscriber → yeniden `handleQuoteUpdates` zincirini
    /// kırıyor. Nested döngü hem `trades.indices` iterasyonunu bozar hem de
    /// Combine run-loop'unda patlayan emission'a yol açar.
    private var isHandlingQuoteUpdate: Bool = false

    func handleQuoteUpdates(_ quotes: [String: DataValue<Quote>]) {
        // O2: Zaten içerideyiz → dış çağrı iterasyonunu tamamlasın, yeni çağrıyı
        // düşür. Bir sonraki quote tick'i yine bizi çağıracak; bekleyen güncelleme
        // sırasında kaybolmuş fiyat yok (quote'lar stateless tick'ler, gap önemsiz).
        if isHandlingQuoteUpdate {
            return
        }
        isHandlingQuoteUpdate = true
        defer { isHandlingQuoteUpdate = false }

        // Sadece açık pozisyonlar için quote'ları güncelle ve kontrol et
        let openSymbols = Set(trades.filter { $0.isOpen }.map { $0.symbol })

        for symbol in openSymbols {
            if let dataValue = quotes[symbol], let quote = dataValue.value {
                let currentPrice = quote.currentPrice

                // Stop Loss / Take Profit / HWM kontrolü
                for index in trades.indices where trades[index].symbol == symbol && trades[index].isOpen {
                    let trade = trades[index]

                    // High Water Mark Update (Trailing Stop için)
                    if currentPrice > (trade.highWaterMark ?? 0) {
                        var mutableTrade = trades[index]
                        mutableTrade.highWaterMark = currentPrice
                        trades[index] = mutableTrade
                        scheduleDebouncedSave() // Debounced - çok sık yazma önlenir
                    }

                    checkStopLoss(for: trade, at: index, currentPrice: currentPrice)
                    checkTakeProfit(for: trade, at: index, currentPrice: currentPrice)
                }
            }
        }
    }
    
    private func checkStopLoss(for trade: Trade, at index: Int, currentPrice: Double) {
        guard let stopLoss = trade.stopLoss,
              currentPrice <= stopLoss,
              !trade.isPendingSale else { return } // Duplicate trigger koruması

        // İşaretle ve sat - race condition önleme
        trades[index].isPendingSale = true
        scheduleDebouncedSave()

        // Retroaktif gap tespiti: Uygulama kapalıyken fiyat stop'u geçtiyse,
        // satış her zaman stop fiyatından yapılır (mevcut gap fiyatından değil).
        let isRetroactiveGap = currentPrice < stopLoss * 0.99 // %1'den fazla gap = retroaktif
        let sellPrice = stopLoss // Her zaman stop fiyatından sat
        let reason = isRetroactiveGap ? "STOP_LOSS_RETROACTIVE" : "STOP_LOSS"

        if isRetroactiveGap {
            print("🛑⏮️ PortfolioStore: STOP LOSS (RETROAKTİF) tetiklendi for \(trade.symbol) — Stop: \(sellPrice), Mevcut: \(currentPrice)")
        } else {
            print("🛑 PortfolioStore: STOP LOSS tetiklendi for \(trade.symbol) @ \(sellPrice) (SL: \(stopLoss))")
        }
        sell(tradeId: trade.id, currentPrice: sellPrice, reason: reason)
    }

    private func checkTakeProfit(for trade: Trade, at index: Int, currentPrice: Double) {
        guard let takeProfit = trade.takeProfit,
              currentPrice >= takeProfit,
              !trade.isPendingSale else { return } // Duplicate trigger koruması

        // İşaretle ve sat - race condition önleme
        trades[index].isPendingSale = true
        scheduleDebouncedSave()

        // Retroaktif gap tespiti: Uygulama kapalıyken fiyat take-profit'i geçtiyse,
        // satış her zaman take-profit fiyatından yapılır (mevcut gap fiyatından değil).
        let isRetroactiveGap = currentPrice > takeProfit * 1.01 // %1'den fazla gap = retroaktif
        let sellPrice = takeProfit // Her zaman take-profit fiyatından sat
        let reason = isRetroactiveGap ? "TAKE_PROFIT_RETROACTIVE" : "TAKE_PROFIT"

        if isRetroactiveGap {
            print("💰⏮️ PortfolioStore: TAKE PROFIT (RETROAKTİF) tetiklendi for \(trade.symbol) — TP: \(sellPrice), Mevcut: \(currentPrice)")
        } else {
            print("💰 PortfolioStore: TAKE PROFIT tetiklendi for \(trade.symbol) @ \(sellPrice) (TP: \(takeProfit))")
        }
        sell(tradeId: trade.id, currentPrice: sellPrice, reason: reason)
    }
    
    // MARK: - Sell Operation
    
    @discardableResult
    func sell(tradeId: UUID, currentPrice: Double, reason: String? = nil) -> Double? {
        guard let index = trades.firstIndex(where: { $0.id == tradeId && $0.isOpen }) else {
            print("❌ PortfolioEngine: Trade bulunamadı: \(tradeId)")
            return nil
        }
        
        var trade = trades[index]
        let isBist = trade.currency == .TRY
        let revenue = trade.quantity * currentPrice
        let commission = FeeModel.forSymbol(trade.symbol).calculate(amount: revenue)
        let netRevenue = revenue - commission
        // Y4: Giriş komisyonunun bu satışa düşen payı PnL'den düşülür.
        // Legacy trade'lerde entryCommissionPerShare=0 → eski davranış korunur.
        let entryCommissionShare = trade.entryCommissionPerShare * trade.quantity
        let pnl = (currentPrice - trade.entryPrice) * trade.quantity - commission - entryCommissionShare

        // Add to balance
        if isBist {
            bistBalance += netRevenue
        } else {
            globalBalance += netRevenue
        }

        // Close trade
        trade.isOpen = false
        trade.exitPrice = currentPrice
        trade.exitDate = Date()
        trades[index] = trade
        
        // Log for Chiron Learning
        let tradeLog = TradeLog(
            date: Date(),
            symbol: trade.symbol,
            entryPrice: trade.entryPrice,
            exitPrice: currentPrice,
            pnlPercent: trade.profitPercentage,
            pnlAbsolute: pnl,
            entryRegime: ChironRegimeEngine.shared.globalResult.regime,
            entryOrionScore: trade.entryOrionSnapshot?.momentumScore ?? 0,
            entryAtlasScore: 0,
            entryAetherScore: 0,
            engine: trade.engine?.rawValue ?? "MANUAL",
            entryOrionSnapshot: trade.entryOrionSnapshot,
            exitOrionSnapshot: nil
        )
        TradeLogStore.shared.append(tradeLog)

        // Öğrenme sistemlerine geri besleme — trade kapanınca hepsini tetikle
        let _symbol       = trade.symbol
        let _pnlAbsolute  = pnl
        let _pnlPercent   = trade.profitPercentage
        let _entryPrice   = trade.entryPrice
        let _exitPrice    = currentPrice
        let _entryDate    = trade.entryDate
        let _holdingDays  = Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0

        Task.detached(priority: .background) {
            // 1a. Chiron öğrenmesi — ağırlık optimizasyonu (mevcut)
            let outcome: ChironLearningSystem.TradeExperience.TradeOutcome
            if _pnlAbsolute > 0      { outcome = .winner }
            else if _pnlAbsolute < 0 { outcome = .loser }
            else                     { outcome = .scratch }

            let weights = await ChironLearningSystem.shared.getCurrentState().weights
            await ChironLearningSystem.shared.recordTrade(
                symbol:        _symbol,
                weights:       weights,
                outcome:       outcome,
                duration:      Date().timeIntervalSince(_entryDate),
                profitPercent: _pnlPercent
            )

            // 1b. ChironCouncilLearningService — feedback loop'un KAPANIŞ adımı.
            // Eski sürümde bu çağrı yoktu; pending CouncilVotingRecord'lar sonsuza dek
            // kuyrukta kalıp completedRecords hiç büyümüyordu. Şimdi her trade
            // kapanışında sembol bazlı en son pending kaydı outcome ile eşleniyor.
            let councilOutcome: ChironTradeOutcome = _pnlAbsolute >= 0 ? .win : .loss
            await ChironCouncilLearningService.shared.updateOutcome(
                symbol:     _symbol,
                outcome:    councilOutcome,
                pnlPercent: _pnlPercent
            )

            // 2. TradeBrain öğrenmesi
            await AutoPilotStore.shared.triggerLearningForClosedTrade(
                symbol:      _symbol,
                entryPrice:  _entryPrice,
                exitPrice:   _exitPrice,
                holdingDays: _holdingDays
            )

            // 3. Alkindus olgunlaşma — yeni veri geldi, bekleyen kararları değerlendir
            await AlkindusCalibrationEngine.shared.periodicMatureCheck()

            // 4. RAG — tamamlanan trade'i vektör hafızasına kaydet
            // Gelecekte benzer sembol/koşul sorgulanırsa bu trade örnek olarak çekilir
            await AlkindusRAGEngine.shared.syncChironTrade(
                id: UUID().uuidString,
                symbol: _symbol,
                engine: "PORTFOLIO",
                entryPrice: _entryPrice,
                exitPrice: _exitPrice,
                pnlPercent: _pnlPercent,
                holdingDays: _holdingDays,
                orionScore: nil,
                atlasScore: nil,
                regime: ChironRegimeEngine.shared.globalResult.regime.rawValue
            )
        }

        // Log Transaction
        var transaction = Transaction(
            id: UUID(),
            type: .sell,
            symbol: trade.symbol,
            amount: revenue,
            price: currentPrice,
            date: Date(),
            fee: commission,
            pnl: pnl,
            pnlPercent: trade.profitPercentage
        )
        transaction.reasonCode = reason
        transactions.insert(transaction, at: 0)
        
        saveToDisk()
        
        let currencySymbol = isBist ? "₺" : "$"
        print("✅ PortfolioEngine: SELL \(trade.symbol) @ \(currencySymbol)\(currentPrice), PnL: \(currencySymbol)\(String(format: "%.2f", pnl))")
        return pnl
    }

    // MARK: - Update Stops (SL / TP)

    /// Açık bir pozisyonun stop-loss ve/veya take-profit değerlerini SSoT üzerinde günceller.
    /// ViewModel'lerin kendi `portfolio[index].stopLoss = ...` ataması yapması YASAK —
    /// o atama Combine tick'inde bu store'un yayımladığı değerle ezilir ve koruma
    /// eski seviyede kalır. Trailing stop ve plan sıkılaştırma çağrıları buraya gelmeli.
    @discardableResult
    func updateStops(tradeId: UUID, newStop: Double? = nil, newTakeProfit: Double? = nil) -> Bool {
        guard newStop != nil || newTakeProfit != nil else { return false }
        guard let index = trades.firstIndex(where: { $0.id == tradeId && $0.isOpen }) else {
            return false
        }
        var trade = trades[index]
        if let s = newStop { trade.stopLoss = s }
        if let tp = newTakeProfit { trade.takeProfit = tp }
        trades[index] = trade
        scheduleDebouncedSave()
        return true
    }

    /// Trade'e Argus Voice raporunu ekler ve persist eder.
    /// ViewModel'lerin `portfolio[index].voiceReport = …` ataması aynı ghost-mutation
    /// desenine yakalanır — bu API SSoT üzerinden yazar.
    @discardableResult
    func attachVoiceReport(tradeId: UUID, report: String) -> Bool {
        guard let index = trades.firstIndex(where: { $0.id == tradeId }) else {
            return false
        }
        var trade = trades[index]
        trade.voiceReport = report
        trades[index] = trade
        scheduleDebouncedSave()
        return true
    }

    // MARK: - Partial Sell (Trim)
    
    @discardableResult
    func trim(tradeId: UUID, percentage: Double, currentPrice: Double, reason: String? = nil) -> Double? {
        guard percentage > 0, percentage < 100 else { return nil }
        guard let index = trades.firstIndex(where: { $0.id == tradeId && $0.isOpen }) else { return nil }
        
        var trade = trades[index]
        let sellQuantity = trade.quantity * (percentage / 100.0)
        let remainingQuantity = trade.quantity - sellQuantity

        let isBist = trade.currency == .TRY
        let revenue = sellQuantity * currentPrice
        let commission = FeeModel.forSymbol(trade.symbol).calculate(amount: revenue)
        let netRevenue = revenue - commission
        // Y4: Giriş komisyonunu bu parça kadar prorate et.
        let entryCommissionShare = trade.entryCommissionPerShare * sellQuantity
        let pnl = (currentPrice - trade.entryPrice) * sellQuantity - commission - entryCommissionShare
        
        // Add to balance
        if isBist {
            bistBalance += netRevenue
        } else {
            globalBalance += netRevenue
        }
        
        // Update trade quantity
        trade.quantity = remainingQuantity
        trades[index] = trade
        
        // Log Transaction
        var transaction = Transaction(
            id: UUID(),
            type: .sell,
            symbol: trade.symbol,
            amount: revenue,
            price: currentPrice,
            date: Date(),
            fee: commission,
            pnl: pnl,
            pnlPercent: ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
        )
        transaction.reasonCode = "TRIM_\(Int(percentage))%"
        transactions.insert(transaction, at: 0)

        saveToDisk()

        print("✅ PortfolioEngine: TRIM \(trade.symbol) \(Int(percentage))% @ \(currentPrice)")
        return pnl
    }

    /// Quantity tabanlı kısmi satış. Plan execution'daki `sellPartial` bu rota üzerinden geçer.
    /// - Parameters:
    ///   - tradeId: Kapatılacak trade.
    ///   - quantity: Satılacak adet. Açık quantity'yi geçerse `nil` döner.
    ///   - currentPrice: Mevcut piyasa fiyatı.
    ///   - reason: Log/Transaction reasonCode.
    /// - Returns: Realize PnL (commission sonrası). Trade kapanırsa `isOpen=false` set edilir.
    @discardableResult
    func trimByQuantity(tradeId: UUID, quantity: Double, currentPrice: Double, reason: String? = nil) -> Double? {
        guard quantity > 0 else { return nil }
        guard let index = trades.firstIndex(where: { $0.id == tradeId && $0.isOpen }) else { return nil }

        var trade = trades[index]
        // Floating point toleransı: 0.0001 adet altında "tam kapatma" sayılır.
        guard quantity <= trade.quantity + 0.0001 else { return nil }

        let isBist = trade.currency == .TRY
        let revenue = quantity * currentPrice
        let commission = FeeModel.forSymbol(trade.symbol).calculate(amount: revenue)
        let netRevenue = revenue - commission
        // Y4: Giriş komisyonunun bu adede düşen payı.
        let entryCommissionShare = trade.entryCommissionPerShare * quantity
        let pnl = (currentPrice - trade.entryPrice) * quantity - commission - entryCommissionShare
        let pnlPct = trade.entryPrice > 0
            ? ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
            : 0.0

        // Bakiye güncelle
        if isBist {
            bistBalance += netRevenue
        } else {
            globalBalance += netRevenue
        }

        // Trade quantity düş; kalan ≤ 0.0001 ise trade'i kapat
        trade.quantity -= quantity
        if trade.quantity <= 0.0001 {
            trade.quantity = 0
            trade.isOpen = false
            trade.exitPrice = currentPrice
            trade.exitDate = Date()
        }
        trades[index] = trade

        // Transaction log
        var transaction = Transaction(
            id: UUID(),
            type: .sell,
            symbol: trade.symbol,
            amount: revenue,
            price: currentPrice,
            date: Date(),
            fee: commission,
            pnl: pnl,
            pnlPercent: pnlPct
        )
        transaction.reasonCode = reason ?? "TRIM_QTY"
        transactions.insert(transaction, at: 0)

        saveToDisk()

        let currencySymbol = isBist ? "₺" : "$"
        print("✅ PortfolioEngine: TRIM-QTY \(trade.symbol) \(String(format: "%.4f", quantity))@ \(currencySymbol)\(currentPrice), PnL: \(currencySymbol)\(String(format: "%.2f", pnl))")
        return pnl
    }


    // MARK: - Portfolio Value Calculations
    
    func getGlobalEquity(quotes: [String: Quote]) -> Double {
        let positionValue = globalOpenTrades.reduce(0.0) { sum, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (trade.quantity * currentPrice)
        }
        return globalBalance + positionValue
    }
    
    func getBistEquity(quotes: [String: Quote]) -> Double {
        let positionValue = bistOpenTrades.reduce(0.0) { sum, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + (trade.quantity * currentPrice)
        }
        return bistBalance + positionValue
    }
    
    func getGlobalUnrealizedPnL(quotes: [String: Quote]) -> Double {
        globalOpenTrades.reduce(0.0) { sum, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + ((currentPrice - trade.entryPrice) * trade.quantity)
        }
    }
    
    func getBistUnrealizedPnL(quotes: [String: Quote]) -> Double {
        bistOpenTrades.reduce(0.0) { sum, trade in
            let currentPrice = quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return sum + ((currentPrice - trade.entryPrice) * trade.quantity)
        }
    }
    
    func getRealizedPnL(currency: Currency? = nil) -> Double {
        let relevantTransactions: [Transaction]
        if let currency = currency {
            relevantTransactions = transactions.filter { tx in
                guard tx.type == .sell, let pnl = tx.pnl else { return false }
                let isBist = isBistSymbol(tx.symbol)
                return currency == .TRY ? isBist : !isBist
            }
        } else {
            relevantTransactions = transactions.filter { $0.type == .sell }
        }
        return relevantTransactions.compactMap { $0.pnl }.reduce(0.0, +)
    }
    
    // MARK: - Position Helpers
    
    func getPosition(for symbol: String) -> [Trade] {
        openTrades.filter { $0.symbol == symbol }
    }
    
    func getTotalQuantity(for symbol: String) -> Double {
        getPosition(for: symbol).reduce(0) { $0 + $1.quantity }
    }
    
    func hasPosition(for symbol: String) -> Bool {
        openTrades.contains { $0.symbol == symbol }
    }
    
    // MARK: - Helpers
    
    private func isBistSymbol(_ symbol: String) -> Bool {
        SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    // MARK: - Persistence
    

    

    
    func resetPortfolio() {
        trades = []
        transactions = []
        globalBalance = 100_000.0
        bistBalance = 1_000_000.0
        
        // Force sync removal of V5 keys first? No, just overwrite.
        saveToDisk()
        print("🔄 PortfolioEngine: Reset complete (V6 FileManager)")
    }
    
    /// Sadece GLOBAL (USD) portföyü sıfırla — BIST'e dokunma.
    /// Tüm USD trade'leri ve USD cinsi transaction'ları sil, bakiyeyi $100k yap.
    /// Kullanıcı gözlemi: "Baştan deneyelim, sıfır temiz kullanıcı."
    func resetGlobalPortfolio() {
        print("🚨 PortfolioStore: GLOBAL PORTFÖY SIFIRLANIYOR...")
        let beforeTradeCount = trades.filter { $0.currency == .USD }.count
        let beforeTxCount = transactions.filter { !isBistSymbol($0.symbol) }.count
        trades.removeAll { $0.currency == .USD }
        transactions.removeAll { !isBistSymbol($0.symbol) }
        globalBalance = 100_000.0
        saveToDisk()
        print("🔄 PortfolioStore: Global reset — \(beforeTradeCount) trade + \(beforeTxCount) tx silindi, bakiye $100k")
        ArgusLogger.warn("🔄 Global portföy sıfırlandı — \(beforeTradeCount) pozisyon kapatıldı, bakiye $100k", category: "PORTFOLIO")
    }

    func resetBistPortfolio() {
        print("🚨 PortfolioStore: BIST PORTFÖYÜ SIFIRLANIYOR...")
        trades.removeAll { $0.currency == .TRY }
        transactions.removeAll { isBistSymbol($0.symbol) }
        bistBalance = 1_000_000.0
        saveToDisk()
    }

    /// Y5: VM facade bağımsız mutation yapmasın; snapshot import bu tek kanaldan geçer.
    /// Dışarıdan alınan parçalar nil olabilir (kısmi import); sadece sağlanan alanlar
    /// uygulanır. Side-effect: `@Published` yayınları tetikler ve sink üzerinden VM
    /// otomatik güncellenir. Disk'e yazma garanti.
    func importSnapshot(
        trades: [Trade]?,
        transactions: [Transaction]?,
        globalBalance: Double?,
        bistBalance: Double?
    ) {
        if let trades = trades { self.trades = trades }
        if let transactions = transactions { self.transactions = transactions }
        if let globalBalance = globalBalance { self.globalBalance = globalBalance }
        if let bistBalance = bistBalance { self.bistBalance = bistBalance }
        saveToDisk()
        print("📥 PortfolioStore: Snapshot import tamamlandı — trades:\(self.trades.count) tx:\(self.transactions.count)")
    }
}
