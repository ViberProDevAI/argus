# Migration Guide: UnifiedDataStore to AppStateCoordinator

## Overview
UnifiedDataStore has been deprecated and will be removed in v2.0. All code should migrate to `AppStateCoordinator.shared` for proper Single Source of Truth (SSOT) architecture.

## Why This Change?
UnifiedDataStore duplicated data from child stores (PortfolioStore, MarketDataStore, WatchlistViewModel, etc.) instead of providing unified access. This led to:
- Inconsistent data states
- Difficult debugging when data diverged
- Unnecessary complexity in bindings

AppStateCoordinator solves this by:
- Acting as a facade to child stores
- Using computed properties instead of duplication
- Coordinating between domains without duplicating state

## Migration Steps

### Before (UnifiedDataStore)
```swift
import SwiftUI

struct PortfolioView: View {
    @StateObject var unified = UnifiedDataStore.shared

    var body: some View {
        List {
            ForEach(unified.portfolio) { trade in
                TradeRow(trade: trade)
            }
        }
        .onAppear {
            Task {
                await unified.refreshAllQuotes()
            }
        }
    }
}
```

### After (AppStateCoordinator)
```swift
import SwiftUI

struct PortfolioView: View {
    @StateObject var coordinator = AppStateCoordinator.shared

    var body: some View {
        List {
            ForEach(coordinator.portfolio.trades) { trade in
                TradeRow(trade: trade)
            }
        }
        .onAppear {
            Task {
                await coordinator.watchlist.refreshAllQuotes()
            }
        }
    }
}
```

## Common Property Mappings

### Watchlist Properties
| UnifiedDataStore | AppStateCoordinator |
|---|---|
| `unified.watchlist` | `coordinator.watchlist.watchlist` |
| `unified.watchlistQuotes` | `coordinator.watchlist.watchlistQuotes` |
| `unified.isWatchlistLoading` | `coordinator.watchlist.isWatchlistLoading` |
| `unified.addSymbol(_:)` | `coordinator.watchlist.addSymbol(_:)` |
| `unified.removeSymbol(_:)` | `coordinator.watchlist.removeSymbol(_:)` |
| `unified.loadQuote(for:)` | `coordinator.watchlist.loadQuote(for:)` |
| `unified.refreshAllQuotes()` | `coordinator.watchlist.refreshAllQuotes()` |

### Market Data Properties
| UnifiedDataStore | AppStateCoordinator |
|---|---|
| `unified.quotes` | Access via `MarketDataStore.shared.quotes` |
| `unified.candles` | Access via `MarketDataStore.shared.candles` |
| `unified.topGainers` | Calculate or fetch separately |

### Portfolio Properties
| UnifiedDataStore | AppStateCoordinator |
|---|---|
| `unified.portfolio` | `coordinator.portfolio.trades` |
| `unified.globalBalance` | `coordinator.portfolio.globalBalance` |
| `unified.bistBalance` | `coordinator.portfolio.bistBalance` |

### Signal Properties
| UnifiedDataStore | AppStateCoordinator |
|---|---|
| `unified.orionAnalysis` | `SignalStateViewModel.shared.orionAnalysis` |
| `unified.patterns` | `SignalStateViewModel.shared.patterns` |
| `unified.grandDecisions` | `SignalStateViewModel.shared.grandDecisions` |
| `unified.chimeraSignals` | `SignalStateViewModel.shared.chimeraSignals` |
| `unified.athenaResults` | `SignalStateViewModel.shared.athenaResults` |

### Execution Properties
| UnifiedDataStore | AppStateCoordinator |
|---|---|
| `unified.isAutoPilotEnabled` | `ExecutionStateViewModel.shared.isAutoPilotEnabled` |
| `unified.autoPilotLogs` | `ExecutionStateViewModel.shared.autoPilotLogs` |

### UI State Properties
| UnifiedDataStore | AppStateCoordinator |
|---|---|
| `unified.selectedSymbol` | `coordinator.selectedSymbol` |
| `unified.isLoading` | `coordinator.isGlobalLoading` |
| `unified.errorMessage` | `coordinator.errorMessage` |
| `unified.isBacktesting` | `coordinator.isBacktesting` |
| `unified.etfSummaries` | `coordinator.etfSummaries` |
| `unified.dailyReport` | `coordinator.dailyReport` |
| `unified.weeklyReport` | `coordinator.weeklyReport` |

## Testing Checklist

After migration, verify:
- [ ] All views compile without errors
- [ ] State changes propagate correctly to views
- [ ] No stale data appears in views
- [ ] Navigation and view updates work as expected
- [ ] Bindings between coordinator and child stores work properly

## Rollback Plan

If issues arise:
1. UnifiedDataStore is still available (just deprecated)
2. Check that data sources match between old and new implementations
3. Compare output of `coordinator.X` vs `unified.X` to identify divergence
4. File an issue with specific property mappings that differ

## See Also
- AppStateCoordinator: `argus/ViewModels/Core/AppStateCoordinator.swift`
- AppStateCoordinator+Data: `argus/ViewModels/Core/AppStateCoordinator+Data.swift`
- AppStateCoordinator+Bindings: `argus/ViewModels/Core/AppStateCoordinator+Bindings.swift`
