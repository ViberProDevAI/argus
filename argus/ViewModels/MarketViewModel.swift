import Foundation
import Combine
import SwiftUI

/// Market Data Manager
/// Extracted from TradingViewModel to reduce complexity.
/// Handles: Quotes, Candles, Discovery Lists, Macro Data (TCMB/Flow)
@MainActor
final class MarketViewModel: ObservableObject {
    // MARK: - Market Data State
    @Published var quotes: [String: Quote] = [:]
    @Published var candles: [String: [Candle]] = [:]
    
    // Discovery Lists
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var mostActive: [Quote] = []
    
    // BIST Macro & Flow Data
    @Published var tcmbData: TCMBDataService.TCMBMacroSnapshot?
    @Published var foreignFlowData: [String: ForeignInvestorFlowService.ForeignFlowData] = [:]
    
    // Market Regime
    @Published var marketRegime: MarketRegime = .neutral
    @Published var isLiveMode: Bool = false {
        didSet {
            handleLiveModeChange()
        }
    }
    
    // Services
    private let marketDataProvider = MarketDataProvider.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // 1. Bind Quotes
        MarketDataStore.shared.$quotes
            .throttle(for: .seconds(1.0), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] storeQuotes in
                guard let self = self else { return }
                var newQuotes: [String: Quote] = [:]
                for (key, val) in storeQuotes {
                    if let q = val.value {
                        newQuotes[key] = q
                    }
                }
                if self.quotes != newQuotes {
                    self.quotes = newQuotes
                    self.updateDiscoveryLists()
                }
            }
            .store(in: &cancellables)
            
        // 2. Bind Candles
        MarketDataStore.shared.$candles
            .throttle(for: .seconds(1.0), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] storeCandles in
                guard let self = self else { return }
                var newCandles: [String: [Candle]] = [:]
                for (key, val) in storeCandles {
                    if let c = val.value {
                        // Store with original key (e.g. "ABT_1G")
                        newCandles[key] = c

                        // Also store with symbol-only key for UI compatibility
                        let symbol = key.components(separatedBy: "_").first ?? key
                        if newCandles[symbol] == nil || key.contains("1day") || key.contains("1G") {
                            newCandles[symbol] = c
                        }
                    }
                }
                if self.candles != newCandles {
                    self.candles = newCandles
                }
            }
            .store(in: &cancellables)
            
        // 3. Bind Regime
        // Assuming Chiron has a publisher or we pull it? 
        // For now, let's just expose the property or bind if available.
        // ChironRegimeEngine.shared is a singleton.
    }
    
    private func updateDiscoveryLists() {
        let allQuotes = Array(quotes.values)
        guard !allQuotes.isEmpty else { return }
        
        self.topGainers = allQuotes
            .sorted { ($0.percentChange ?? 0) > ($1.percentChange ?? 0) }
            .prefix(10)
            .map { $0 }
            
        self.topLosers = allQuotes
            .sorted { ($0.percentChange ?? 0) < ($1.percentChange ?? 0) }
            .prefix(10)
            .map { $0 }
            
        // Volume logic if available?
    }
    
    // MARK: - Live Mode Logic
    private func handleLiveModeChange() {
        if isLiveMode {
            MarketSessionManager.shared.startSession()
        } else {
            MarketSessionManager.shared.stopSession()
        }
    }
    
    // MARK: - Public Methods
    
    func refreshMarketRegime() {
        self.marketRegime = ChironRegimeEngine.shared.globalResult.regime
    }
    
    func fetchTCMBData() {
        Task {
            self.tcmbData = await TCMBDataService.shared.getSnapshot()
        }
    }
}
