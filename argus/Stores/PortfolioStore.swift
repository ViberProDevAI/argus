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
    @Published private(set) var trades: [Trade] = []
    @Published private(set) var globalBalance: Double = -1.0 // -1 denotes "Not Loaded"
    @Published private(set) var bistBalance: Double = -1.0   // -1 denotes "Not Loaded"
    @Published private(set) var transactions: [Transaction] = []
    
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
        
        // 1. Try Loading V6 Files
        var v6Loaded = false
        
        if FileManager.default.fileExists(atPath: balanceFile.path) {
            do {
                let data = try Data(contentsOf: balanceFile)
                let balances = try decoder.decode([String: Double].self, from: data)
                if let usd = balances["usd"], let tl = balances["try"] {
                    globalBalance = usd
                    bistBalance = tl
                    v6Loaded = true
                    print("✅ PortfolioStore: Balances loaded from V6 File")
                }
            } catch {
                print("❌ PortfolioStore: V6 Balance load failed: \(error)")
            }
        }
        
        if v6Loaded {
            // Load Trades
            if let data = try? Data(contentsOf: portfolioFile) {
                if let savedTrades = try? decoder.decode([Trade].self, from: data) {
                    trades = savedTrades
                    print("✅ PortfolioStore: \(trades.count) trades loaded from V6 File")
                }
            }
            
            // Load Transactions
            if let data = try? Data(contentsOf: txFile) {
                if let savedTx = try? decoder.decode([Transaction].self, from: data) {
                    transactions = savedTx
                }
            }
        } else {
            // V6 Missing -> Migrate from V5 (UserDefaults)
            print("📂 PortfolioStore: V6 not found. Attempting migration from V5...")
            migrateFromV5()
        }

        print("🏁 PortfolioStore: Load Complete - Trades: \(trades.count), USD: $\(globalBalance), TRY: ₺\(bistBalance)")
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
    
    var openTrades: [Trade] {
        trades.filter { $0.isOpen }
    }
    
    var closedTrades: [Trade] {
        trades.filter { !$0.isOpen }
    }
    
    var globalOpenTrades: [Trade] {
        openTrades.filter { $0.currency == .USD }
    }
    
    var bistOpenTrades: [Trade] {
        openTrades.filter { $0.currency == .TRY }
    }
    
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
        let commission = FeeModel.shared.calculate(amount: cost)
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
    
    func handleQuoteUpdates(_ quotes: [String: DataValue<Quote>]) {
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

        // Stop Loss tetiklendi
        print("🛑 PortfolioStore: STOP LOSS tetiklendi for \(trade.symbol) @ \(currentPrice) (SL: \(stopLoss))")
        sell(tradeId: trade.id, currentPrice: currentPrice, reason: "STOP_LOSS")
    }

    private func checkTakeProfit(for trade: Trade, at index: Int, currentPrice: Double) {
        guard let takeProfit = trade.takeProfit,
              currentPrice >= takeProfit,
              !trade.isPendingSale else { return } // Duplicate trigger koruması

        // İşaretle ve sat - race condition önleme
        trades[index].isPendingSale = true
        scheduleDebouncedSave()

        // Take Profit tetiklendi
        print("💰 PortfolioStore: TAKE PROFIT tetiklendi for \(trade.symbol) @ \(currentPrice) (TP: \(takeProfit))")
        sell(tradeId: trade.id, currentPrice: currentPrice, reason: "TAKE_PROFIT")
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
        let commission = FeeModel.shared.calculate(amount: revenue)
        let netRevenue = revenue - commission
        let pnl = (currentPrice - trade.entryPrice) * trade.quantity - commission
        
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
        let commission = FeeModel.shared.calculate(amount: revenue)
        let netRevenue = revenue - commission
        let pnl = (currentPrice - trade.entryPrice) * sellQuantity - commission
        
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
        symbol.uppercased().hasSuffix(".IS")
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
    
    func resetBistPortfolio() {
        print("🚨 PortfolioStore: BIST PORTFÖYÜ SIFIRLANIYOR...")
        trades.removeAll { $0.currency == .TRY }
        transactions.removeAll { isBistSymbol($0.symbol) }
        bistBalance = 1_000_000.0
        saveToDisk()
    }
}
