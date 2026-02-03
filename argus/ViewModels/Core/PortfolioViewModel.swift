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

    func getEquity() -> Double {
        let portfolioValue = portfolio.reduce(0) { result, trade in
            result + (trade.quantity * trade.entryPrice)
        }
        return balance + portfolioValue
    }

    func clearAll() {
        portfolio.removeAll()
        balance = 100000.0
        bistBalance = 1000000.0
        usdTryRate = 35.0
        errorMessage = nil
    }
}
