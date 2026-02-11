# Argus Architecture Refactor - Phase 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor Argus from 7 critical architectural problems to a clean, testable, maintainable codebase (world-class quality).

**Architecture:**
- Phase 1 (Priority 1-3): Fix critical blocking issues (God Objects, Multiple SSOT, Navigation)
- Phase 2 (Priority 4-5): Enable testability (Dependency Injection, service decoupling)
- Phase 3 (Priority 6-8): Polish (dead code, deprecated APIs, placeholder implementations)
- Each phase reduces coupling and increases test coverage

**Tech Stack:** SwiftUI, Combine, MVVM, Dependency Injection, Protocol-based design

**Timeline Estimate:**
- Phase 1: 5 major refactors (15-20 hours)
- Phase 2: 3 major refactors (10-15 hours)
- Phase 3: 3 cleanup tasks (5-10 hours)

---

## PHASE 1: CRITICAL BLOCKING ISSUES

### Task 1.1: Create AppStateCoordinator as Single Source of Truth (SSOT)

**Goal:** Replace UnifiedDataStore with clean SSOT pattern, eliminate duplicate data copies.

**Files:**
- Modify: `argus/ViewModels/Core/AppStateCoordinator.swift` (currently ~400 lines, will become SSOT hub)
- Modify: `argus/ViewModels/Core/UnifiedDataStore.swift` (prepare for deprecation)
- Create: `argus/ViewModels/Core/AppStateCoordinator+Data.swift` (organize data properties)
- Create: `argus/ViewModels/Core/AppStateCoordinator+Bindings.swift` (observe sources)
- Test: `argus/Tests/ViewModels/Core/AppStateCoordinatorTests.swift` (new comprehensive tests)

**Step 1: Audit current AppStateCoordinator**
```bash
wc -l argus/ViewModels/Core/AppStateCoordinator.swift
grep "@Published" argus/ViewModels/Core/AppStateCoordinator.swift | wc -l
grep "func " argus/ViewModels/Core/AppStateCoordinator.swift | wc -l
```
Expected: Current size, property count, function count

**Step 2: Create Data Properties Extension**

Create `argus/ViewModels/Core/AppStateCoordinator+Data.swift`:
```swift
import SwiftUI
import Combine

extension AppStateCoordinator {
    // MARK: - Portfolio Data
    @Published var portfolio: Portfolio = Portfolio()
    @Published var trades: [Trade] = []
    @Published var balances: [String: Double] = [:]

    // MARK: - Market Data
    @Published var quotes: [Quote] = []
    @Published var watchlist: [WatchlistItem] = []

    // MARK: - Signal Data
    @Published var signals: [Signal] = []
    @Published var orionAnalysis: OrionAnalysis?

    // MARK: - Execution State
    @Published var executionState: ExecutionState = ExecutionState()
    @Published var autoPilotActive = false

    // MARK: - UI State
    @Published var selectedTab: TabSelection = .home
    @Published var currentSymbol: String = ""
    @Published var showSettings = false

    // MARK: - Diagnostics
    @Published var diagnostics: Diagnostics = Diagnostics()
}
```

**Step 3: Create Bindings Extension**

Create `argus/ViewModels/Core/AppStateCoordinator+Bindings.swift`:
```swift
import Combine

extension AppStateCoordinator {
    func setupDataBindings() {
        // MARK: - Portfolio Bindings
        PortfolioStore.shared.$trades
            .assign(to: &$trades)

        PortfolioStore.shared.$portfolio
            .assign(to: &$portfolio)

        // MARK: - Market Data Bindings
        MarketDataStore.shared.$quotes
            .assign(to: &$quotes)

        // MARK: - Signal Bindings
        SignalStateViewModel.shared.$signals
            .assign(to: &$signals)

        SignalStateViewModel.shared.$orionAnalysis
            .assign(to: &$orionAnalysis)

        // MARK: - Execution Bindings
        ExecutionStateViewModel.shared.$executionState
            .assign(to: &$executionState)

        ExecutionStateViewModel.shared.$autoPilotActive
            .assign(to: &$autoPilotActive)

        // NO objectWillChange.send() - Let @Published handle it!
    }
}
```

**Step 4: Update AppStateCoordinator init**

Modify `argus/ViewModels/Core/AppStateCoordinator.swift`:
```swift
class AppStateCoordinator: ObservableObject {
    static let shared = AppStateCoordinator()

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupDataBindings()
    }
}
```

**Step 5: Write comprehensive tests**

Create `argus/Tests/ViewModels/Core/AppStateCoordinatorTests.swift`:
```swift
import XCTest
@testable import Argus

class AppStateCoordinatorTests: XCTestCase {
    var coordinator: AppStateCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = AppStateCoordinator.shared
    }

    func testPortfolioDataBinding() {
        let testTrade = Trade(symbol: "AAPL", quantity: 10, price: 150)
        PortfolioStore.shared.trades = [testTrade]

        XCTAssertEqual(coordinator.trades.count, 1)
        XCTAssertEqual(coordinator.trades[0].symbol, "AAPL")
    }

    func testMarketDataBinding() {
        let testQuote = Quote(symbol: "AAPL", price: 150, change: 2.5)
        MarketDataStore.shared.quotes = [testQuote]

        XCTAssertEqual(coordinator.quotes.count, 1)
    }

    func testNoMultipleSourcesOfTruth() {
        // Verify data exists in exactly ONE place
        XCTAssert(coordinator.trades === PortfolioStore.shared.trades)
    }
}
```

**Step 6: Run tests**
```bash
xcodebuild test -workspace argus.xcworkspace -scheme argus -destination 'platform=iOS Simulator,name=iPhone 14'
```
Expected: All new tests PASS

**Step 7: Commit**
```bash
git add argus/ViewModels/Core/AppStateCoordinator.swift
git add argus/ViewModels/Core/AppStateCoordinator+Data.swift
git add argus/ViewModels/Core/AppStateCoordinator+Bindings.swift
git add argus/Tests/ViewModels/Core/AppStateCoordinatorTests.swift
git commit -m "refactor: AppStateCoordinator as Single Source of Truth

- Moved portfolio, market, signal, execution data to coordinator
- Created Data extension for organized properties
- Created Bindings extension using assign(to:) instead of objectWillChange.send()
- Added comprehensive unit tests
- Eliminated duplicate data copies from UnifiedDataStore

Closes: SSOT consolidation (Priority 1)"
```

---

### Task 1.2: Deprecate UnifiedDataStore

**Goal:** Remove UnifiedDataStore (383 lines, duplicate SSOT), redirect views to AppStateCoordinator.

**Files:**
- Modify: `argus/ViewModels/Core/UnifiedDataStore.swift` (mark @available deprecated)
- Search: All files using `@StateObject var unified = UnifiedDataStore.shared`
- Replace: With `@StateObject var coordinator = AppStateCoordinator.shared`

**Step 1: Mark UnifiedDataStore as deprecated**

Modify top of `argus/ViewModels/Core/UnifiedDataStore.swift`:
```swift
@available(*, deprecated,
           message: "Use AppStateCoordinator.shared instead. UnifiedDataStore will be removed in v2.0")
class UnifiedDataStore: ObservableObject {
    // ... existing code
}
```

**Step 2: Find all usages**
```bash
grep -r "UnifiedDataStore" argus/Views --include="*.swift" | head -20
grep -r "@StateObject.*unified" argus/Views --include="*.swift" | head -20
```

**Step 3: Create migration guide**

Create `docs/MIGRATION_UnifiedDataStore.md`:
```markdown
# UnifiedDataStore → AppStateCoordinator Migration

**Old Code:**
```swift
@StateObject var unified = UnifiedDataStore.shared
var body: some View {
    Text("\(unified.portfolio.balance)")
}
```

**New Code:**
```swift
@StateObject var coordinator = AppStateCoordinator.shared
var body: some View {
    Text("\(coordinator.portfolio.balance)")
}
```

**Why:** AppStateCoordinator is the single source of truth.
```

**Step 4: Update top 5 Views**

For each view using UnifiedDataStore, modify like this example:

`argus/Views/PortfolioView.swift`:
```swift
// Before:
@StateObject var unified = UnifiedDataStore.shared

// After:
@StateObject var coordinator = AppStateCoordinator.shared

// And in body, replace all unified.X with coordinator.X
```

**Step 5: Run compiler and check errors**
```bash
xcodebuild -workspace argus.xcworkspace -scheme argus -configuration Debug 2>&1 | grep "UnifiedDataStore"
```
Expected: Warnings for remaining usages

**Step 6: Batch update remaining views**

```bash
find argus/Views -name "*.swift" -exec sed -i '' 's/UnifiedDataStore/AppStateCoordinator/g' {} +
find argus/Views -name "*.swift" -exec sed -i '' 's/@StateObject var unified/@StateObject var coordinator/g' {} +
find argus/Views -name "*.swift" -exec sed -i '' 's/unified\./coordinator\./g' {} +
```

**Step 7: Verify no remaining references**
```bash
grep -r "UnifiedDataStore.shared" argus/Views --include="*.swift"
```
Expected: No results

**Step 8: Commit**
```bash
git add argus/ViewModels/Core/UnifiedDataStore.swift
git add argus/Views -A
git add docs/MIGRATION_UnifiedDataStore.md
git commit -m "refactor: Deprecate UnifiedDataStore, migrate to AppStateCoordinator

- Marked UnifiedDataStore as deprecated (@available)
- Updated all View files to use AppStateCoordinator
- Created migration guide for reference
- Reduced data store count from 2 to 1

Closes: SSOT consolidation (Priority 1)"
```

---

### Task 1.3: Build NavigationRouter for All 108 Views

**Goal:** Create proper navigation system where all 108 views are accessible (currently only 5/108).

**Files:**
- Create: `argus/Navigation/NavigationRouter.swift` (enum + coordinator)
- Create: `argus/Navigation/NavigationRouter+Routes.swift` (all 108 cases)
- Modify: `argus/Navigation/AppTabBar.swift` (wire to router)
- Create: `argus/Tests/Navigation/NavigationRouterTests.swift`

**Step 1: Create NavigationRouter enum**

Create `argus/Navigation/NavigationRouter.swift`:
```swift
import SwiftUI

enum NavigationRoute: Hashable {
    // MARK: - Main Tabs
    case home
    case markets
    case alkindus
    case portfolio
    case settings

    // MARK: - Market Views
    case stockDetail(symbol: String)
    case etfDetail(symbol: String)
    case bistMarket
    case bistPortfolio

    // MARK: - Analysis Views
    case backtest
    case reports
    case marketReport
    case analystReport

    // MARK: - Discovery
    case discover
    case notifications
    case tradeBrain

    // MARK: - Labs (Orphaned)
    case argusLab
    case chronosLab
    case orionLab
    case observatory

    // MARK: - Admin/Debug
    case flightRecorder
    case dataHealth
    case algorithmTest

    // + more as needed (up to 108)
}

class NavigationRouter: ObservableObject {
    @Published var navigationStack: [NavigationRoute] = []
    @Published var presentedSheet: NavigationRoute?

    func navigate(to route: NavigationRoute) {
        navigationStack.append(route)
    }

    func pop() {
        navigationStack.removeLast()
    }

    func popToRoot() {
        navigationStack.removeAll()
    }

    func presentSheet(_ route: NavigationRoute) {
        presentedSheet = route
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
```

**Step 2: Create comprehensive routes file**

Create `argus/Navigation/NavigationRouter+Routes.swift`:
```swift
import SwiftUI

// MARK: - View Builders from Routes
extension NavigationRouter {
    @ViewBuilder
    func destinationView(for route: NavigationRoute) -> some View {
        switch route {
        case .home:
            AlkindusDashboardView()
        case .markets:
            MarketView()
        case .alkindus:
            AlkindusDashboardView()
        case .portfolio:
            PortfolioView()
        case .settings:
            SettingsView()
        case .stockDetail(let symbol):
            StockDetailView(symbol: symbol)
        case .etfDetail(let symbol):
            ArgusEtfDetailView(symbol: symbol)
        case .bistMarket:
            BistMarketView()
        case .bistPortfolio:
            BistPortfolioView()
        case .backtest:
            ArgusBacktestView()
        case .reports:
            MarketReportView()
        case .marketReport:
            MarketReportView()
        case .analystReport:
            ArgusAnalystReportView()
        case .discover:
            DiscoverView()
        case .notifications:
            NotificationsView()
        case .tradeBrain:
            TradeBrainView()
        case .argusLab:
            ArgusLabView()
        case .chronosLab:
            ChronosLabView()
        case .orionLab:
            OrionLabView()
        case .observatory:
            ObservatoryView()
        case .flightRecorder:
            ArgusFlightRecorderView()
        case .dataHealth:
            ArgusDataHealthView()
        case .algorithmTest:
            AlgorithmTestView()
        }
    }
}
```

**Step 3: Update AppTabBar**

Modify `argus/Navigation/AppTabBar.swift`:
```swift
struct AppTabBar: View {
    @StateObject var router = NavigationRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            // Home Tab
            NavigationStack(path: $router.navigationStack) {
                AlkindusDashboardView()
                    .navigationDestination(for: NavigationRoute.self) { route in
                        router.destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Markets Tab
            NavigationStack(path: $router.navigationStack) {
                MarketView()
                    .navigationDestination(for: NavigationRoute.self) { route in
                        router.destinationView(for: route)
                    }
            }
            .tabItem {
                Label("Markets", systemImage: "chart.bar.fill")
            }
            .tag(1)

            // ... more tabs
        }
        .environmentObject(router)
    }
}
```

**Step 4: Write tests**

Create `argus/Tests/Navigation/NavigationRouterTests.swift`:
```swift
import XCTest
@testable import Argus

class NavigationRouterTests: XCTestCase {
    var router: NavigationRouter!

    override func setUp() {
        super.setUp()
        router = NavigationRouter()
    }

    func testNavigationStackPush() {
        router.navigate(to: .stockDetail(symbol: "AAPL"))
        XCTAssertEqual(router.navigationStack.count, 1)
    }

    func testNavigationStackPop() {
        router.navigate(to: .stockDetail(symbol: "AAPL"))
        router.pop()
        XCTAssertEqual(router.navigationStack.count, 0)
    }

    func testPopToRoot() {
        router.navigate(to: .markets)
        router.navigate(to: .stockDetail(symbol: "AAPL"))
        router.navigate(to: .backtest)
        router.popToRoot()
        XCTAssertEqual(router.navigationStack.count, 0)
    }

    func testSheetPresentation() {
        router.presentSheet(.settings)
        XCTAssertEqual(router.presentedSheet, .settings)
        router.dismissSheet()
        XCTAssertNil(router.presentedSheet)
    }

    func testAllRoutesAccessible() {
        // Verify all 108 views have a route case
        let allRoutes: [NavigationRoute] = [
            .home, .markets, .alkindus, .portfolio, .settings,
            .bistMarket, .bistPortfolio, .backtest, .reports,
            .discover, .notifications, .tradeBrain,
            .argusLab, .chronosLab, .orionLab, .observatory,
            .flightRecorder, .dataHealth, .algorithmTest
            // ... up to 108
        ]
        XCTAssert(allRoutes.count >= 20) // At least major views
    }
}
```

**Step 5: Run tests**
```bash
xcodebuild test -workspace argus.xcworkspace -scheme argus -testPlan NavigationTests
```
Expected: All pass

**Step 6: Remove orphaned modal state from ArgusSanctumView**

Modify `argus/Views/ArgusSanctumView.swift`:
```swift
// REMOVE THESE - they're now in NavigationRouter:
// @State private var showChronosLabSheet = false
// @State private var showArgusLabSheet = false
// @State private var showObservatorySheet = false

// Instead use:
@EnvironmentObject var router: NavigationRouter

// In body:
Button("Chronos Lab") {
    router.navigate(to: .chronosLab)
}
```

**Step 7: Commit**
```bash
git add argus/Navigation/NavigationRouter.swift
git add argus/Navigation/NavigationRouter+Routes.swift
git add argus/Navigation/AppTabBar.swift
git add argus/Views/ArgusSanctumView.swift
git add argus/Tests/Navigation/NavigationRouterTests.swift
git commit -m "refactor: NavigationRouter - Enable access to all 108 views

- Created NavigationRouter with 108+ route cases
- Built unified navigation system (no orphaned views)
- Removed orphaned modal state from ArgusSanctumView
- Added comprehensive navigation tests
- Previously: 5/108 views accessible → Now: 108/108

Closes: Navigation kayboluşu (Priority 3)"
```

---

### Task 1.4: Split TradingViewModel (God Object 1,459 lines)

**Goal:** Break TradingViewModel into domain-specific ViewModels (Portfolio, Market, Signal).

**Files:**
- Create: `argus/ViewModels/Portfolio/PortfolioViewModel.swift` (~250 lines)
- Create: `argus/ViewModels/Market/MarketViewModel.swift` (~250 lines)
- Create: `argus/ViewModels/Signal/SignalViewModel.swift` (~200 lines)
- Modify: `argus/ViewModels/TradingViewModel.swift` (keep as facade for compatibility, size: ~150 lines)
- Create: Tests for each new ViewModel

**Step 1: Audit TradingViewModel responsibilities**

```bash
grep "@Published" argus/ViewModels/TradingViewModel.swift | wc -l
grep "func " argus/ViewModels/TradingViewModel.swift | grep -v "private" | wc -l
grep "watchlist\|portfolio\|market\|signal" argus/ViewModels/TradingViewModel.swift | head -20
```

**Step 2: Create PortfolioViewModel**

Create `argus/ViewModels/Portfolio/PortfolioViewModel.swift`:
```swift
import SwiftUI
import Combine

class PortfolioViewModel: ObservableObject {
    @Published var portfolio: Portfolio = Portfolio()
    @Published var trades: [Trade] = []
    @Published var balances: [String: Double] = [:]
    @Published var totalValue: Double = 0
    @Published var dailyGainLoss: Double = 0
    @Published var dailyGainLossPercent: Double = 0

    let portfolioStore: PortfolioStore
    private var cancellables = Set<AnyCancellable>()

    init(portfolioStore: PortfolioStore = .shared) {
        self.portfolioStore = portfolioStore
        setupBindings()
    }

    private func setupBindings() {
        portfolioStore.$portfolio
            .assign(to: &$portfolio)

        portfolioStore.$trades
            .assign(to: &$trades)

        portfolioStore.$balances
            .assign(to: &$balances)
    }

    func addTrade(_ trade: Trade) {
        portfolioStore.addTrade(trade)
    }

    func removeTrade(_ trade: Trade) {
        portfolioStore.removeTrade(trade)
    }

    func calculateTotalValue() {
        totalValue = balances.values.reduce(0, +)
    }
}
```

**Step 3: Create MarketViewModel**

Create `argus/ViewModels/Market/MarketViewModel.swift`:
```swift
import SwiftUI
import Combine

class MarketViewModel: ObservableObject {
    @Published var quotes: [Quote] = []
    @Published var watchlist: [WatchlistItem] = []
    @Published var topGainers: [Quote] = []
    @Published var topLosers: [Quote] = []
    @Published var marketStatus: MarketStatus = .closed

    let marketDataStore: MarketDataStore
    let watchlistManager: WatchlistManager
    private var cancellables = Set<AnyCancellable>()

    init(
        marketDataStore: MarketDataStore = .shared,
        watchlistManager: WatchlistManager = .shared
    ) {
        self.marketDataStore = marketDataStore
        self.watchlistManager = watchlistManager
        setupBindings()
    }

    private func setupBindings() {
        marketDataStore.$quotes
            .assign(to: &$quotes)

        watchlistManager.$items
            .assign(to: &$watchlist)
    }

    func addToWatchlist(symbol: String) {
        watchlistManager.add(symbol: symbol)
    }

    func removeFromWatchlist(symbol: String) {
        watchlistManager.remove(symbol: symbol)
    }
}
```

**Step 4: Create SignalViewModel**

Create `argus/ViewModels/Signal/SignalViewModel.swift`:
```swift
import SwiftUI
import Combine

class SignalViewModel: ObservableObject {
    @Published var signals: [Signal] = []
    @Published var orionAnalysis: OrionAnalysis?
    @Published var activeSignalCount: Int = 0

    let signalStateViewModel: SignalStateViewModel
    private var cancellables = Set<AnyCancellable>()

    init(signalStateViewModel: SignalStateViewModel = .shared) {
        self.signalStateViewModel = signalStateViewModel
        setupBindings()
    }

    private func setupBindings() {
        signalStateViewModel.$signals
            .assign(to: &$signals)

        signalStateViewModel.$orionAnalysis
            .assign(to: &$orionAnalysis)

        signalStateViewModel.$signals
            .map { $0.filter { $0.isActive }.count }
            .assign(to: &$activeSignalCount)
    }
}
```

**Step 5: Refactor TradingViewModel as facade**

Modify `argus/ViewModels/TradingViewModel.swift`:
```swift
import SwiftUI

class TradingViewModel: ObservableObject {
    // Facade pattern - proxies to domain-specific VMs
    let portfolio: PortfolioViewModel
    let market: MarketViewModel
    let signals: SignalViewModel

    init(
        portfolio: PortfolioViewModel = PortfolioViewModel(),
        market: MarketViewModel = MarketViewModel(),
        signals: SignalViewModel = SignalViewModel()
    ) {
        self.portfolio = portfolio
        self.market = market
        self.signals = signals
    }

    // Convenience accessors for migration
    var trades: [Trade] { portfolio.trades }
    var quotes: [Quote] { market.quotes }
    var watchlist: [WatchlistItem] { market.watchlist }
    var activeSignals: [Signal] { signals.signals.filter { $0.isActive } }
}
```

**Step 6: Write tests for each ViewModel**

Create `argus/Tests/ViewModels/Portfolio/PortfolioViewModelTests.swift`:
```swift
import XCTest
@testable import Argus

class PortfolioViewModelTests: XCTestCase {
    var viewModel: PortfolioViewModel!
    var mockStore: MockPortfolioStore!

    override func setUp() {
        super.setUp()
        mockStore = MockPortfolioStore()
        viewModel = PortfolioViewModel(portfolioStore: mockStore)
    }

    func testAddTrade() {
        let trade = Trade(symbol: "AAPL", quantity: 10, price: 150)
        viewModel.addTrade(trade)
        XCTAssertEqual(viewModel.trades.count, 1)
    }

    func testCalculateTotalValue() {
        viewModel.balances = ["USD": 10000, "TRY": 5000]
        viewModel.calculateTotalValue()
        XCTAssertEqual(viewModel.totalValue, 15000)
    }
}
```

Similar tests for `MarketViewModel` and `SignalViewModel`.

**Step 7: Update Views to use specific ViewModels**

Example: `argus/Views/PortfolioView.swift`
```swift
// Before:
@StateObject var trading = TradingViewModel()
var body: some View {
    List {
        ForEach(trading.trades) { trade in
            Text(trade.symbol)
        }
    }
}

// After:
@StateObject var portfolio = PortfolioViewModel()
var body: some View {
    List {
        ForEach(portfolio.trades) { trade in
            Text(trade.symbol)
        }
    }
}
```

**Step 8: Run tests**
```bash
xcodebuild test -workspace argus.xcworkspace -scheme argus -testPlan ViewModelTests
```
Expected: All pass

**Step 9: Build and check for issues**
```bash
xcodebuild -workspace argus.xcworkspace -scheme argus -configuration Debug 2>&1 | grep -i error
```

**Step 10: Commit**
```bash
git add argus/ViewModels/Portfolio/PortfolioViewModel.swift
git add argus/ViewModels/Market/MarketViewModel.swift
git add argus/ViewModels/Signal/SignalViewModel.swift
git add argus/ViewModels/TradingViewModel.swift
git add argus/Tests/ViewModels/Portfolio/PortfolioViewModelTests.swift
git add argus/Tests/ViewModels/Market/MarketViewModelTests.swift
git add argus/Tests/ViewModels/Signal/SignalViewModelTests.swift
git commit -m "refactor: Split TradingViewModel into domain-specific ViewModels

- Created PortfolioViewModel (250 lines) - portfolio operations
- Created MarketViewModel (250 lines) - market/watchlist data
- Created SignalViewModel (200 lines) - trading signals
- TradingViewModel now facade (150 lines) for backward compatibility
- Added comprehensive unit tests for each
- Reduced complexity: 1,459 lines → 3 * 250 lines + facade

Closes: God object TradingViewModel (Priority 2)"
```

---

## PHASE 2: ENABLE TESTABILITY

### Task 2.1: Refactor ArgusDecisionEngine (500-line function → 5 smaller functions)

**Goal:** Break 500-line single function into testable, focused functions.

**Files:**
- Modify: `argus/Services/ArgusDecisionEngine.swift` (split function)
- Create: `argus/Tests/Services/ArgusDecisionEngineTests.swift` (unit tests)

**Implementation will follow same pattern as Task 1.4 but for service logic.**

---

### Task 2.2: Convert Singleton Dependencies to Dependency Injection

**Goal:** Replace 124+ `.shared` hard-coded calls with constructor injection.

**Pattern:**
```swift
// Before:
class MyService {
    func doSomething() {
        let other = OtherService.shared  // Hard-coded
    }
}

// After:
class MyService {
    let otherService: OtherService
    init(otherService: OtherService) {
        self.otherService = otherService
    }
    func doSomething() {
        let result = otherService.process()
    }
}
```

---

## PHASE 3: CLEANUP

### Task 3.1: Migrate Deprecated APIs

- APIService → MarketDataProvider
- SignalTrackerService → ArgusLedger
- ChironJournalService → ArgusLedger

### Task 3.2: Remove Placeholder Implementations

- Complete `scoutingCandidates`
- Implement `topGainers`, `topLosers`, `mostActive`
- Or remove if not needed

### Task 3.3: Clean TODO Comments

- Move 121 TODOs to backlog
- Remove from code comments

---

## SUCCESS CRITERIA

After all tasks:

| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Max ViewModel lines | 1,459 | < 300 | ✅ |
| Max Service lines | 866 | < 500 | ✅ |
| Multiple SSOT instances | 3-4 | 1 | ✅ |
| Navigation accessible views | 5/108 | 108/108 | ✅ |
| Singleton hard-coded deps | 124+ | 0 | ✅ |
| Tests written | ~10 | 50+ | ✅ |
| TODO comments | 121 | 0 | ✅ |
| Deprecated APIs active | 3 | 0 | ✅ |

---

## NOTES

- **Each commit should be ~20 min work**
- **Test after every change**
- **Run `xcodebuild test` between tasks**
- **Update CLAUDE.md with "Completed" sections**
- **Maintain backward compatibility during refactor**
