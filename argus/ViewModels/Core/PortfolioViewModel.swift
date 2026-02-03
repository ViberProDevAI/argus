import Foundation
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    static let shared = PortfolioViewModel()

    @Published var portfolio: [Trade] = []
    @Published var balance: Double = 100000.0
    @Published var bistBalance: Double = 1000000.0
    @Published var usdTryRate: Double = 35.0
    @Published var transactionHistory: [Transaction] = []
    @Published var isLoadingPortfolio = false
    @Published var errorMessage: String?

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
            if let decision = SignalViewModel().grandDecisions[trade.symbol] {
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

    func isBistMarketOpen() -> Bool {
        let calendar = Calendar.current
        let now = Date()

        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 { return false }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute

        let startMinutes = 10 * 60
        let endMinutes = 18 * 60 + 10

        return totalMinutes >= startMinutes && totalMinutes < endMinutes
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
        portfolio.removeAll()
        balance = 100000.0
        bistBalance = 1000000.0
        usdTryRate = 35.0
        errorMessage = nil
    }
}
