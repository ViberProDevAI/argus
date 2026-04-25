import Foundation
import Combine
import SwiftUI

/// FAZ 2: AppStateCoordinator - Single Source of Truth (SSOT)
/// Tüm alt ViewModel'leri koordine eden merkezi orchestrator.
/// TradingViewModel'den ayrılmış modüler yapı için köprü görevi görür.
///
/// SSOT Pattern: AppStateCoordinator acts as a facade to child stores/ViewModels:
/// - Does NOT duplicate data
/// - Uses computed properties to access child store data
/// - Binds only its own @Published UI state properties
/// - Coordinates between different domains (Watchlist, Market, Portfolio, Signals, Execution, Diagnostics)
///
/// Data Flow:
/// 1. Child Stores (PortfolioStore, MarketDataStore, WatchlistViewModel, etc.) are the true sources
/// 2. AppStateCoordinator provides unified access via computed properties
/// 3. AppStateCoordinator+Data.swift: All @Published properties organized by domain
/// 4. AppStateCoordinator+Bindings.swift: setupDataBindings() for coordination
///
/// Testing Strategy:
/// - Test that coordinator accesses child stores, not duplicates
/// - Test that data binding works without duplication
/// - Test that loading state aggregation works correctly
/// - Verify no objectWillChange.send() calls exist (let @Published handle it)
@MainActor
final class AppStateCoordinator: ObservableObject {
    
    // MARK: - Singleton (Geçiş döneminde backward compatibility için)
    static let shared = AppStateCoordinator()
    
    // MARK: - Sub ViewModels
    let watchlist: WatchlistViewModel
    
    // MARK: - Legacy Accessor for Views (Backward Compatibility)
    // Views that access `coordinator.portfolio` will now get the Store directly.
    var portfolio: PortfolioStore {
        PortfolioStore.shared
    }
    
    // MARK: - Shared State (Alt ViewModel'ler arası paylaşım)
    // UI State Properties (owned by coordinator, not duplicated from child stores)
    @Published var selectedSymbol: String?
    @Published var isGlobalLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isBacktesting: Bool = false
    @Published var isUnlimitedPositions: Bool = false {
        didSet {
            PortfolioRiskManager.shared.isUnlimitedPositionsEnabled = isUnlimitedPositions
        }
    }
    @Published var etfSummaries: [String: ArgusEtfSummary] = [:]
    @Published var isLoadingEtf: Bool = false
    @Published var activeBacktestResult: BacktestResult?
    @Published var sarTsiBacktestResult: OrionSarTsiBacktestResult?
    @Published var isLoadingSarTsiBacktest: Bool = false
    @Published var sarTsiErrorMessage: String?
    @Published var overreactionResult: OverreactionResult?
    @Published var demeterScores: [DemeterScore] = []
    @Published var demeterMatrix: CorrelationMatrix?
    @Published var isRunningDemeter: Bool = false
    @Published var activeShocks: [ShockFlag] = []
    @Published var hermesSummaries: [String: [HermesSummary]] = [:]
    @Published var hermesMode: HermesMode = .full
    @Published var terminalItems: [TerminalItem] = []
    @Published var dailyReport: String?
    @Published var weeklyReport: String?
    @Published var bistDailyReport: String?
    @Published var bistWeeklyReport: String?
    @Published var lastAction: String = ""
    @Published var planAlerts: [TradeBrainAlert] = []
    @Published var agoraSnapshots: [DecisionSnapshot] = []
    @Published var lastTradeTimes: [String: Date] = [:]
    @Published var universeCache: [String: UniverseItem] = [:]
    @Published var kapDisclosures: [String: [KAPDataService.KAPNews]] = [:]
    @Published var bistAtmosphere: AetherDecision?
    @Published var bistAtmosphereLastUpdated: Date?

    // MARK: - Combine
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    private init() {
        // Alt ViewModel'leri oluştur
        self.watchlist = WatchlistViewModel()

        // Koordinasyon: Watchlist ve MarketData değişikliklerini dinle
        setupDataBindings()
    }
    
    // MARK: - Convenience Methods

    /// Sembol detay görünümüne geçiş
    func selectSymbol(_ symbol: String) {
        selectedSymbol = symbol
    }
}
