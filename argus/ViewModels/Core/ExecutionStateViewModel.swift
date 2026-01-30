import Foundation
import Combine
import SwiftUI

// MARK: - Execution State ViewModel
/// Extracted from TradingViewModel (God Object Decomposition - Phase 2)
/// Responsibilities: AutoPilot state, execution monitoring, trade cooldowns

@MainActor
final class ExecutionStateViewModel: ObservableObject {
    static let shared = ExecutionStateViewModel()
    
    // MARK: - Published Properties
    
    /// AutoPilot enabled state
    @Published var isAutoPilotEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isAutoPilotEnabled, forKey: "autopilot_enabled_v2")
            if isAutoPilotEnabled {
                startAutoPilot()
            } else {
                stopAutoPilot()
            }
        }
    }
    
    /// Selected AutoPilot engine
    @Published var selectedEngine: AutoPilotEngine = .corse {
        didSet {
            UserDefaults.standard.set(selectedEngine.rawValue, forKey: "autopilot_engine_v2")
        }
    }
    
    /// Is currently scanning
    @Published var isScanning: Bool = false
    
    /// Last scan time
    @Published var lastScanTime: Date?
    
    /// Active scan symbols
    @Published var activeScanSymbols: [String] = []
    
    /// AutoPilot Execution Logs
    @Published var autoPilotLogs: [String] = []

    /// Last Trade Times (Shared for Agora Checks)
    @Published var lastTradeTimes: [String: Date] = [:]


    
    /// Trade Brain alerts
    @Published var planAlerts: [TradeBrainAlert] = []
    
    /// AGORA decision snapshots
    @Published var agoraSnapshots: [DecisionSnapshot] = []
    
    /// Cooldown tracking - Symbol → Next allowed trade time
    @Published var tradeCooldowns: [String: Date] = [:]
    
    /// AGORA V2 TRACE STORE (Decision Traces)
    @Published var agoraTraces: [String: AgoraTrace] = [:]
    
    // MARK: - Internal State
    private var autoPilotTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadPersistedState()
        setupTradeBrainObservers()
    }
    
    // MARK: - Persistence
    private func loadPersistedState() {
        isAutoPilotEnabled = UserDefaults.standard.bool(forKey: "autopilot_enabled_v2")
        if let engineRaw = UserDefaults.standard.string(forKey: "autopilot_engine_v2"),
           let engine = AutoPilotEngine(rawValue: engineRaw) {
            selectedEngine = engine
        }
    }
    
    // MARK: - AutoPilot Control
    
    private func startAutoPilot() {
        print("🚀 AutoPilot Started: \(selectedEngine.rawValue)")
        NotificationCenter.default.post(name: .autoPilotStateChanged, object: nil, userInfo: ["enabled": true])
    }
    
    private func stopAutoPilot() {
        print("⏹️ AutoPilot Stopped")
        autoPilotTask?.cancel()
        autoPilotTask = nil
        isScanning = false
        NotificationCenter.default.post(name: .autoPilotStateChanged, object: nil, userInfo: ["enabled": false])
    }
    
    /// Toggle AutoPilot
    func toggleAutoPilot() {
        isAutoPilotEnabled.toggle()
    }
    
    /// Set scanning state
    func setScanning(_ scanning: Bool, symbols: [String] = []) {
        isScanning = scanning
        activeScanSymbols = symbols
        if scanning {
            lastScanTime = Date()
        }
    }
    
    // MARK: - Cooldown Management
    
    /// Check if symbol is in cooldown
    func isInCooldown(symbol: String) -> Bool {
        guard let cooldownEnd = tradeCooldowns[symbol] else { return false }
        return Date() < cooldownEnd
    }
    
    /// Set cooldown for a symbol
    func setCooldown(symbol: String, duration: TimeInterval) {
        tradeCooldowns[symbol] = Date().addingTimeInterval(duration)
    }
    
    /// Clear cooldown for a symbol
    func clearCooldown(symbol: String) {
        tradeCooldowns.removeValue(forKey: symbol)
    }
    
    /// Get remaining cooldown time
    func remainingCooldown(symbol: String) -> TimeInterval? {
        guard let cooldownEnd = tradeCooldowns[symbol] else { return nil }
        let remaining = cooldownEnd.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
    
    // MARK: - Trade Brain Observers
    private func setupTradeBrainObservers() {
        // Alert Observer
        NotificationCenter.default.publisher(for: .tradeBrainAlert)
            .receive(on: DispatchQueue.main)
            .compactMap { $0.userInfo?["alert"] as? TradeBrainAlert }
            .sink { [weak self] alert in
                self?.planAlerts.append(alert)
                if self?.planAlerts.count ?? 0 > 50 {
                    self?.planAlerts.removeFirst()
                }
            }
            .store(in: &cancellables)
            
        // Execution Observers
        NotificationCenter.default.addObserver(self, selector: #selector(handleTradeBrainBuy(_:)), name: .tradeBrainBuyOrder, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTradeBrainSell(_:)), name: .tradeBrainSellOrder, object: nil)
    }
    
    // MARK: - Trade Brain Handlers
    
    @objc private func handleTradeBrainBuy(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let symbol = userInfo["symbol"] as? String,
              let quantity = userInfo["quantity"] as? Double,
              let price = userInfo["price"] as? Double else { return }
        
        Task { @MainActor in
            self.buy(
                symbol: symbol,
                quantity: quantity,
                source: .autoPilot,
                engine: .pulse,
                stopLoss: nil,
                takeProfit: nil,
                rationale: "Trade Brain Execution"
            )
            print("✅ TRADE BRAIN ALIM: \(symbol) - \(Int(quantity)) adet @ \(String(format: "%.2f", price))")
        }
    }
    
    @objc private func handleTradeBrainSell(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let _ = userInfo["price"] as? Double,
              let reason = userInfo["reason"] as? String else { return }
        
        // Trade ID check via PortfolioStore
        if let tradeIdStr = userInfo["tradeId"] as? String,
           let tradeId = UUID(uuidString: tradeIdStr),
           let trade = PortfolioStore.shared.trades.first(where: { $0.id == tradeId }) {
            
            Task { @MainActor in
                self.sell(
                    symbol: trade.symbol,
                    quantity: trade.quantity, // Sell full for now
                    source: .autoPilot,
                    reason: reason
                )
                print("🚨 TRADE BRAIN SATIŞ: \(trade.symbol) - \(reason)")
            }
        }
    }

    // MARK: - Execution Logic (Core)
    
    @MainActor
    @discardableResult
    func buy(symbol: String, quantity: Double, source: TradeSource = .user, engine: AutoPilotEngine? = nil, stopLoss: Double? = nil, takeProfit: Double? = nil, rationale: String? = nil, decisionTrace: DecisionTraceSnapshot? = nil, marketSnapshot: MarketSnapshot? = nil) -> Trade? {
        
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        
        // Use MarketDataStore for price
        guard let quote = MarketDataStore.shared.getQuote(for: symbol) else {
            ArgusLogger.error(.portfoy, "Fiyat verisi bulunamadı: \(symbol)")
            return nil
        }
        let price = quote.currentPrice
        
        // Validate
        let availableBalance = (isBist ? PortfolioStore.shared.bistBalance : PortfolioStore.shared.globalBalance)
        
        let validation = TradeValidator.validateBuy(
            symbol: symbol,
            quantity: quantity,
            price: price,
            availableBalance: availableBalance,
            isBistMarketOpen: isBist, 
            isGlobalMarketOpen: MarketStatusService.shared.canTrade()
        )
        
        guard validation.isValid else {
            let error = validation.error?.localizedDescription ?? "Bilinmeyen hata"
            ArgusLogger.error(.portfoy, "İŞLEM REDDEDİLDİ: \(error)")
            return nil
        }
        
        // AGORA Control
        if let decision = SignalStateViewModel.shared.argusDecisions[symbol] {
             let snapshot = AgoraExecutionGovernor.shared.audit(
                decision: decision,
                currentPrice: price,
                portfolio: PortfolioStore.shared.trades,
                lastTradeTime: lastTradeTimes[symbol],
                lastActionPrice: nil
            )
            
            if snapshot.locks.isLocked {
                ArgusLogger.warning(.autopilot, "AGORA BLOCKED BUY: \(snapshot.reasonOneLiner)")
                addAgoraSnapshot(snapshot)
                return nil
            }
        }
        
        // Execute via PortfolioStore SSoT
        // Returns Trade object now (V6 Update)
        if let trade = PortfolioStore.shared.buy(
            symbol: symbol,
            quantity: quantity,
            price: price,
            source: source,
            engine: engine,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            rationale: rationale
        ) {
            // Update Last Trade Time
            self.lastTradeTimes[symbol] = Date()
            
            // Voice Report Trigger
             if !self.agoraSnapshots.isEmpty, let snapshot = self.agoraSnapshots.first {
                 Task {
                     let _ = await ArgusVoiceService.shared.generateReport(from: snapshot)
                 }
             }
             
             return trade
        }
        
        return nil
    }
    
    @MainActor
    func sell(symbol: String, quantity: Double, source: TradeSource = .user, engine: AutoPilotEngine? = nil, reason: String? = nil) {
        
        // Use MarketDataStore for price
        guard let quote = MarketDataStore.shared.getQuote(for: symbol) else { 
            ArgusLogger.error(.portfoy, "Fiyat verisi bulunamadı: \(symbol)")
            return 
        }
        let price = quote.currentPrice
        
        let openTrades = PortfolioStore.shared.trades.filter { $0.symbol == symbol && $0.isOpen }
        let totalOwned = openTrades.reduce(0.0) { $0 + $1.quantity }
        
        // Simplified check
        let isBist = symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
        
        let validation = TradeValidator.validateSell(
            symbol: symbol,
            quantity: quantity,
            ownedQuantity: totalOwned,
            isBistMarketOpen: isBist, 
            isGlobalMarketOpen: MarketStatusService.shared.canTrade()
        )
        
        guard validation.isValid else {
            ArgusLogger.error(.portfoy, "SATIŞ REDDEDİLDİ: \(validation.error?.localizedDescription ?? "")")
            return
        }
        
        // AGORA Control
        if let decision = SignalStateViewModel.shared.argusDecisions[symbol] {
             let snapshot = AgoraExecutionGovernor.shared.audit(
                decision: decision,
                currentPrice: price,
                portfolio: PortfolioStore.shared.trades,
                lastTradeTime: lastTradeTimes[symbol],
                lastActionPrice: nil
            )
            
            if snapshot.locks.isLocked {
                 ArgusLogger.warning(.autopilot, "AGORA BLOCKED SELL: \(snapshot.reasonOneLiner)")
                 addAgoraSnapshot(snapshot)
                 return
            }
        }
        
        // FIFO Close Logic
        var remainingToSell = quantity
        var didSellAny = false
        
        // Sort by Date Ascending (FIFO)
        let sortedTrades = openTrades.sorted { $0.entryDate < $1.entryDate }
        
        for trade in sortedTrades {
            if remainingToSell <= 0.000001 { break }
            
            let tradeQty = trade.quantity
            let closeQty = min(tradeQty, remainingToSell)
            
            if closeQty >= tradeQty {
                // Full Close
                let pnl = PortfolioStore.shared.sell(tradeId: trade.id, currentPrice: price, reason: reason)
                if pnl != nil {
                    didSellAny = true
                    remainingToSell -= tradeQty
                }
            } else {
                // Partial Close
                let percentage = (closeQty / tradeQty) * 100.0
                let pnl = PortfolioStore.shared.trim(tradeId: trade.id, percentage: percentage, currentPrice: price, reason: reason)
                if pnl != nil {
                    didSellAny = true
                    remainingToSell -= closeQty
                }
            }
        }
        
        if didSellAny {
             self.lastTradeTimes[symbol] = Date()
             ArgusLogger.info(.portfoy, "Satıldı: \(quantity)x \(symbol) @ \(price)")
        }
    }

    // Helpers
    private func makeDecisionContext(fromTrace trace: DecisionTraceSnapshot) -> DecisionContext {
        return DecisionContext(decisionId: UUID().uuidString, overallAction: "BUY", dominantSignals: [], conflicts: [], moduleVotes: ModuleVotes(atlas: nil, orion: nil, aether: nil, hermes: nil, chiron: nil)) // Simplified for now
    }
    
    private func makeDecisionContext(from snapshot: DecisionSnapshot) -> DecisionContext {
         return DecisionContext(decisionId: snapshot.id.uuidString, overallAction: snapshot.action.rawValue, dominantSignals: snapshot.dominantSignals, conflicts: [], moduleVotes: ModuleVotes(atlas: nil, orion: nil, aether: nil, hermes: nil, chiron: nil)) // Simplified
    }
    

    
    /// Add decision snapshot
    func addAgoraSnapshot(_ snapshot: DecisionSnapshot) {
        agoraSnapshots.insert(snapshot, at: 0)
        // Keep last 100
        if agoraSnapshots.count > 100 {
            agoraSnapshots.removeLast()
        }
    }
    
    /// Get recent snapshots for a symbol
    func getRecentSnapshots(for symbol: String, limit: Int = 10) -> [DecisionSnapshot] {
        return agoraSnapshots
            .filter { $0.symbol == symbol }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let autoPilotStateChanged = Notification.Name("autoPilotStateChanged")
    static let tradeBrainAlert = Notification.Name("tradeBrainAlert")
}
