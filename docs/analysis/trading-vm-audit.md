# TradingViewModel Audit Report

**Date:** 2026-02-03
**Status:** Complete

## Overview

Monolithic `TradingViewModel` (1,459 lines) requires decomposition into domain-specific ViewModels for testability and maintainability.

## Current Metrics

| Metric | Count |
|--------|-------|
| Total Lines | 1,459 |
| @Published Properties | 30 |
| Functions | 42 |
| Extension Files | 8 |
| Views Using This VM | 20+ |

## Property Inventory by Domain

### Portfolio Domain (8 properties)
- `portfolio: [Trade]` - Core position data
- `balance: Double` - USD cash balance
- `bistBalance: Double` - TRY cash balance
- `transactionHistory: [Transaction]` - Transaction log
- `generatedSmartPlan: PositionPlan?` - Generated plan
- `usdTryRate: Double` - Exchange rate
- `allTradesBySymbol: [String: [Trade]]` - Computed
- `bistPortfolio: [Trade]` - Computed

### Market Domain (9 properties)
- `quotes: [String: Quote]` - Price data
- `candles: [String: [Candle]]` - Candle data
- `topGainers: [Quote]` - Top gainers list
- `topLosers: [Quote]` - Top losers list
- `mostActive: [Quote]` - Most active list
- `watchlist: [String]` - Tracked symbols
- `searchResults: [SearchResult]` - Search results
- `tcmbData: TCMBDataService.TCMBMacroSnapshot?` - Macro data
- `foreignFlowData: [String: ForeignInvestorFlowService.ForeignFlowData]` - Flow data

### Signal Domain (8 properties)
- `orionAnalysis: [String: MultiTimeframeAnalysis]` - Technical analysis
- `patterns: [String: [OrionChartPattern]]` - Chart patterns
- `grandDecisions: [String: ArgusGrandDecision]` - Trading decisions
- `chimeraSignals: [String: ChimeraSignal]` - Signal outputs
- `demeterScores: [DemeterScore]` - Sector scores
- `demeterMatrix: CorrelationMatrix?` - Correlations
- `isOrionLoading: Bool` - Loading state
- `isRunningDemeter: Bool` - Running state

### News & Reports (6 properties)
- `newsBySymbol: [String: [NewsArticle]]`
- `newsInsightsBySymbol: [String: [NewsInsight]]`
- `hermesEventsBySymbol: [String: [HermesEvent]]`
- `watchlistNewsInsights: [NewsInsight]`
- `generalNewsInsights: [NewsInsight]`
- `isLoadingNews: Bool`

### Execution & UI (5 properties)
- `planAlerts: [TradeBrainAlert]`
- `selectedSymbolForDetail: String?` - Navigation state
- `isLoading: Bool` - Global loading
- `errorMessage: String?` - Error state
- `terminalItems: [TerminalItem]` - Terminal output

## Function Breakdown by Type

### Portfolio Operations (12 functions)
- `getTotalPortfolioValue()`
- `getEquity()`
- `getUnrealizedPnL()`
- `getBistPortfolioValue()`
- `getBistEquity()`
- `getBistUnrealizedPnL()`
- `getRealizedPnL()`
- `topPositions(count:)`
- `closeAllPositions(for:)`
- `resetBistPortfolio()`
- `isBistMarketOpen()`
- `exportTransactionHistoryJSON()`

### Trade Execution (6 functions)
- `buy(...)`
- `sell(...)`
- `createOrder(...)`
- Execution state management

### Market Data (8 functions)
- `addToWatchlist(symbol:)`
- `addSymbol(_:)`
- `deleteFromWatchlist(at:)`
- `search(query:)`
- `getTopPicks()`
- `refreshSymbol(_:)`
- Market data fetching

### Signal Analysis (6 functions)
- `ensureOrionAnalysis(for:)`
- `runDemeterAnalysis()`
- `getDemeterMultipliers(for:)`
- `getDemeterScore(for:)`
- Signal operations

### Utility & Setup (10 functions)
- Bootstrap functions
- State initialization
- Observation setup

## Recommended Decomposition

```
TradingViewModel (1,459 lines)
  ├── PortfolioViewModel (350 lines)
  │   ├── portfolio operations
  │   ├── balance tracking
  │   └── P&L calculations
  ├── MarketViewModel (200 lines, enhanced)
  │   ├── quotes/candles
  │   ├── watchlist operations
  │   └── discovery lists
  ├── SignalViewModel (250 lines)
  │   ├── Orion analysis
  │   ├── Trading signals
  │   └── Demeter scoring
  └── TradingViewModel (300 lines, facade)
      ├── Backward compatibility accessors
      ├── Domain VM delegation
      └── Cross-cutting concerns

Result: 5 focused ViewModels instead of 1 god object
```

## Views Requiring TradingViewModel

**Identified 20+ views using TradingViewModel:**
- AlkindusDashboardView
- ArgusCockpitView
- BistMarketView
- DiscoverView
- MarketView
- PortfolioView
- TradeBrainView
- ArgusSanctumView
- [+ 12 more]

## Next Steps

1. **Create domain ViewModels** (Tasks 2-4)
2. **Refactor TradingViewModel as facade** (Task 5)
3. **Implement domain ViewModel operations** (Tasks 6-8)
4. **Test & migrate views** (Tasks 9-12)

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Breaking changes | Use facade pattern with backward compat accessors |
| State sync issues | Proper Combine bindings between VMs |
| Missing dependencies | Audit all property access patterns first |
| Test coverage | Add 15+ unit tests per Task 10 |
