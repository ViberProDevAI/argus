import Foundation
import Combine

// MARK: - SSoT Store Bindings (extracted from TradingViewModel)

extension TradingViewModel {

    func setupStoreBindings() {
        // MarketDataStore.$quotes subscription'ı MarketViewModel.setupBindings() içinde
        // kuruluyor (1s throttle ile + diff check). Burada tekrar 0.5s throttle ile
        // subscribe etmek aynı veriyi market.quotes'a 2 farklı zamanda yazıyordu —
        // setter yine market.quotes'a yazıp MarketViewModel.objectWillChange'i
        // gereksiz yere tetikliyordu. Bu yüzden kaldırıldı; tek kanal: MarketViewModel.

        // PortfolioStore subscription'ları setupPortfolioStoreBridge() içinde init()'te
        // kuruluyor. Burada tekrarlamak ikinci sink eklerdi ve her PortfolioStore
        // güncellemesinde 2x setter çağrısına yol açardı (setter yine risk.portfolio'ya
        // yazıyor — gereksiz ek iş). Bu yüzden kaldırıldı.

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
