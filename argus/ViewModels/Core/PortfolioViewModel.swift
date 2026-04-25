import Foundation
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    static let shared = PortfolioViewModel()

    // Y5: Read-through facade. `portfolio/balance/bistBalance/transactionHistory`
    // artık yalnızca PortfolioStore'dan gelen Combine sink tarafından güncellenir;
    // dış yazım engellenir (`private(set)`). Böylece VM ve Store state'i arasındaki
    // sessiz drift (dual SSoT) ortadan kalkar. clearAll / resetAllData / import
    // operasyonları store rota'sından geçer, sonuç sink ile geri yansır.
    @Published private(set) var portfolio: [Trade] = []
    @Published private(set) var balance: Double = 100000.0
    @Published private(set) var bistBalance: Double = 1000000.0
    @Published var usdTryRate: Double = 35.0
    @Published private(set) var transactionHistory: [Transaction] = []
    @Published var isLoadingPortfolio = false
    @Published var errorMessage: String?
    @Published var activePlans: [UUID: PositionPlan] = [:]
    @Published var isCheckingPlanTriggers: Bool = false

    private let portfolioStore = PortfolioStore.shared
    private var cancellables = Set<AnyCancellable>()

    // Updated for DI compatibility
    init(portfolioManager: Any? = nil, riskManager: Any? = nil) {
        setupPortfolioSubscription()
    }

    private func setupPortfolioSubscription() {
        portfolioStore.$trades
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trades in
                self?.portfolio = trades
            }
            .store(in: &cancellables)

        portfolioStore.$transactions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.transactionHistory = transactions
            }
            .store(in: &cancellables)

        portfolioStore.$globalBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.balance = balance
            }
            .store(in: &cancellables)

        portfolioStore.$bistBalance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] balance in
                self?.bistBalance = balance
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties

    var allTradesBySymbol: [String: [Trade]] {
        Dictionary(grouping: portfolio, by: { $0.symbol })
    }

    var bistPortfolio: [Trade] {
        portfolio.filter { $0.currency == .TRY }
    }

    var bistOpenPortfolio: [Trade] {
        portfolio.filter { $0.currency == .TRY && $0.isOpen }
    }

    var globalPortfolio: [Trade] {
        portfolio.filter { $0.currency == .USD }
    }

    var globalOpenPortfolio: [Trade] {
        portfolio.filter { $0.currency == .USD && $0.isOpen }
    }

    // MARK: - Portfolio Calculations

    func getTotalPortfolioValue() -> Double {
        return getEquity() - balance
    }

    func getEquity() -> Double {
        return PortfolioStore.shared.getGlobalEquity(quotes: [:])
    }

    func getUnrealizedPnL() -> Double {
        return PortfolioStore.shared.getGlobalUnrealizedPnL(quotes: [:])
    }

    func getBistPortfolioValue() -> Double {
        return getBistEquity() - bistBalance
    }

    func getBistEquity() -> Double {
        return PortfolioStore.shared.getBistEquity(quotes: [:])
    }

    func getBistUnrealizedPnL() -> Double {
        return PortfolioStore.shared.getBistUnrealizedPnL(quotes: [:])
    }

    func getRealizedPnL(market: TradeMarket? = nil) -> Double {
        let currency: Currency?
        if let m = market {
            currency = (m == .bist) ? .TRY : .USD
        } else {
            currency = nil
        }
        return PortfolioStore.shared.getRealizedPnL(currency: currency)
    }

    var portfolioAllocation: [String: Any] {
        return [:]
    }

    var concentrationWarnings: [String] {
        return []
    }

    func topPositions(count: Int = 5) -> [Any] {
        return []
    }

    // MARK: - Portfolio Operations

    func triggerSmartPlan(for trade: Trade) {
        Task {
            // Retrieve decision from SignalViewModel if available
            if let decision = SignalViewModel.shared.grandDecisions[trade.symbol] {
                _ = PositionPlanStore.shared.createPlan(for: trade, decision: decision)
            }
            await MainActor.run {
                print("✅ Smart Plan oluşturuldu: \(trade.symbol)")
            }
        }
    }

    func closeAllPositions(for symbol: String) {
        let openTrades = portfolio.filter { $0.symbol == symbol && $0.isOpen }
        let totalQty = openTrades.reduce(0.0) { $0 + $1.quantity }

        if totalQty > 0 {
            // Will delegate to ExecutionStateViewModel through TradingViewModel
        }
    }

    func resetBistPortfolio() {
        PortfolioStore.shared.resetBistPortfolio()
    }

    /// BIST Piyasa Açıklık Kontrolü — Istanbul TZ + resmi tatil listesi.
    ///
    /// O3: MarketStatusService tek otorite. Eskiden cihaz saat dilimiyle
    /// kontrol ediliyordu (yurt dışı kullanıcısı için yanlış), tatil bilgisi
    /// yoktu. Artık hafta içi + saat + sabit tarihli resmi tatiller merkezi
    /// kontrol ediliyor.
    func isBistMarketOpen() -> Bool {
        MarketStatusService.shared.isBistOpen()
    }

    func exportTransactionHistoryJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(transactionHistory)
            return String(data: data, encoding: .utf8) ?? "Error: Could not encode"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    func updateDataHealth(for symbol: String, update: (inout DataHealth) -> Void) {
        var health = DiagnosticsViewModel.shared.dataHealthBySymbol[symbol] ?? DataHealth(symbol: symbol)
        update(&health)
        DiagnosticsViewModel.shared.dataHealthBySymbol[symbol] = health
    }

    func clearAll() {
        // Y5: Store üzerinden git; trade/transaction/bakiye değişiklikleri sink ile
        // VM'e geri yansıyacak. Önceki versiyonda VM kendi cache'ini siliyor ama store
        // eski state'te kalıyordu — bir sonraki emission'da VM yeniden dolup "reset"
        // etkisi saniyeler içinde kayboluyordu.
        portfolioStore.resetPortfolio()
        usdTryRate = 35.0
        errorMessage = nil
    }

    // MARK: - Portfolio Reset & Persistence

    func resetAllData() {
        print("🔄 Resetting all portfolio data...")

        // Y5: Hem global hem BIST'i tek noktadan sıfırla. Önceki versiyon sadece
        // BIST'i sıfırlıyor, globalBalance değişmiyordu; VM'de ise local portfolio'yu
        // siliyordu — sonuç tutarsız (USD trade'leri store'da sağlam, VM cache'i boş).
        portfolioStore.resetPortfolio()
        usdTryRate = 35.0
        isLoadingPortfolio = false
        errorMessage = nil

        print("✅ Portfolio data reset complete")
    }

    func exportPortfolioSnapshot() -> [String: Any] {
        return [
            "timestamp": Date(),
            "portfolio": portfolio,
            "balance": balance,
            "bistBalance": bistBalance,
            "usdTryRate": usdTryRate,
            "transactionHistory": transactionHistory
        ]
    }

    func importPortfolioSnapshot(_ snapshot: [String: Any]) async {
        print("📥 Importing portfolio snapshot...")

        // Y5: VM artık yazmıyor; import operasyonu store üzerinden geçer.
        // usdTryRate VM'e özgü (Store'da persist edilmiyor), sadece o lokal.
        let trades = snapshot["portfolio"] as? [Trade]
        let transactions = snapshot["transactionHistory"] as? [Transaction]
        let bal = snapshot["balance"] as? Double
        let bistBal = snapshot["bistBalance"] as? Double

        portfolioStore.importSnapshot(
            trades: trades,
            transactions: transactions,
            globalBalance: bal,
            bistBalance: bistBal
        )

        if let rate = snapshot["usdTryRate"] as? Double {
            usdTryRate = rate
        }

        print("✅ Portfolio snapshot imported")
    }

    // MARK: - Plan Execution

    func addActivePlan(_ plan: PositionPlan) {
        activePlans[plan.id] = plan
        print("📋 Active plan added: \(plan.symbol)")
    }

    func removeActivePlan(id: UUID) {
        activePlans.removeValue(forKey: id)
        print("✖️ Plan removed")
    }

    func checkPlanTriggers() async {
        isCheckingPlanTriggers = true
        defer { isCheckingPlanTriggers = false }
        // Check active plans
    }
}
