import Foundation
import Combine

// MARK: - SSoT Store Bindings (extracted from TradingViewModel)

extension TradingViewModel {

    func setupStoreBindings() {
        MarketDataStore.shared.$quotes
            .throttle(for: .seconds(0.5), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] storeQuotes in
                var cleanQuotes: [String: Quote] = [:]
                for (sym, dv) in storeQuotes {
                    if let val = dv.value {
                        cleanQuotes[sym] = val
                    }
                }
                self?.quotes = cleanQuotes
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$trades
            .receive(on: RunLoop.main)
            .sink { [weak self] trades in
                self?.portfolio = trades
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$globalBalance
            .receive(on: RunLoop.main)
            .sink { [weak self] newBalance in
                self?.balance = newBalance
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$bistBalance
            .receive(on: RunLoop.main)
            .sink { [weak self] newBalance in
                self?.bistBalance = newBalance
            }
            .store(in: &cancellables)

        PortfolioStore.shared.$transactions
            .receive(on: RunLoop.main)
            .sink { [weak self] transactions in
                self?.transactionHistory = transactions
            }
            .store(in: &cancellables)

        ExecutionStateViewModel.shared.$planAlerts
            .receive(on: RunLoop.main)
            .sink { [weak self] alerts in
                self?.planAlerts = alerts
            }
            .store(in: &cancellables)

        ExecutionStateViewModel.shared.$agoraSnapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] snaps in
                self?.agoraSnapshots = snaps
            }
            .store(in: &cancellables)

        ExecutionStateViewModel.shared.$lastTradeTimes
            .receive(on: RunLoop.main)
            .sink { [weak self] times in
                self?.lastTradeTimes = times
            }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$newsBySymbol
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.newsBySymbol = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$newsInsightsBySymbol
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.newsInsightsBySymbol = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$hermesEventsBySymbol
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.hermesEventsBySymbol = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$kulisEventsBySymbol
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.kulisEventsBySymbol = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$watchlistNewsInsights
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.watchlistNewsInsights = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$generalNewsInsights
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.generalNewsInsights = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$isLoadingNews
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.isLoadingNews = v }
            .store(in: &cancellables)

        HermesStateViewModel.shared.$newsErrorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] v in self?.newsErrorMessage = v }
            .store(in: &cancellables)
    }
}
