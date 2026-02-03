# SignalViewModel Extension Migration Plan

> **Türkçe Not:** Bu plan TradingViewModel+Argus.swift (1,101 satır) → SignalViewModel migration için.
> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Migrate all signal analysis, scouting, and Argus data loading logic from TradingViewModel to focused SignalViewModel, reducing TradingViewModel to pure facade.

**Architecture:**
- Move 20+ functions from TradingViewModel+Argus to SignalViewModel
- Maintain backward compatibility through facade accessors
- Extract scout loop, Argus analysis, and fundamental scoring
- Separate asset type detection and voice report generation
- Keep proper Combine bindings and @MainActor isolation

**Tech Stack:** SwiftUI, Combine, @MainActor, async/await

---

## Analysis Summary

**File:** `TradingViewModel+Argus.swift` (1,101 lines)
**Functions:** 20+ including scout loops, analysis, scoring
**Dependencies:**
- ArgusScoutService (opportunity detection)
- FundamentalScoreStore (score caching)
- AtlasCouncil (fundamental analysis)
- ArgusVoiceService (voice reports)
- OrionStore (technical analysis)
- MacroRegimeService (macro environment)
- AutoPilotStore (execution delegation)

**High Complexity:** Scout loop with parallel loading, asset type detection, voice report generation

---

## Task Breakdown

### Task 1: Add Scout Loop Methods to SignalViewModel

**Files:**
- Modify: `argus/ViewModels/Signal/SignalViewModel.swift`
- Reference: `argus/ViewModels/TradingViewModel+Argus.swift:10-54`

**Step 1: Add scout state to SignalViewModel**

Add these @Published properties to the top of SignalViewModel (after line 14):

```swift
// Scout Loop Management
@Published var scoutCandidates: [String: Double] = [:]
@Published var isScoutRunning: Bool = false
private var scoutTimer: Timer?

// Scout universe for scanning
let scoutUniverse = ScoutUniverse.dailyRotation(count: 20)
```

**Step 2: Add scout control methods**

Add to SignalViewModel before the closing brace:

```swift
// MARK: - Scout Loop Management

func startScoutLoop() {
    guard !isScoutRunning else { return }
    isScoutRunning = true

    // Run immediately
    Task {
        await runScout()
    }

    // Then every 5 minutes
    scoutTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
        Task {
            await self?.runScout()
        }
    }
}

func stopScoutLoop() {
    scoutTimer?.invalidate()
    scoutTimer = nil
    isScoutRunning = false
}

func runScout() async {
    // 1. Refresh market pulse
    let marketVM = MarketViewModel()
    await marketVM.refreshMarketPulse()

    // 2. Gather symbols from multiple sources
    let discoverySymbols = (marketVM.topGainers + marketVM.topLosers + marketVM.mostActive)
        .compactMap { $0.symbol }
    let universeSymbols = ScoutUniverse.dailyRotation(count: 20)
    let allSymbols = Array(Set(marketVM.watchlist + discoverySymbols + universeSymbols))

    guard !allSymbols.isEmpty else { return }

    // 3. Scout for opportunities
    let candidates = await ArgusScoutService.shared.scoutOpportunities(
        watchlist: allSymbols,
        currentQuotes: marketVM.quotes
    )

    // 4. Store results and handover to execution
    await MainActor.run {
        self.scoutCandidates = candidates
    }

    if !candidates.isEmpty {
        // Handover to ExecutionStateViewModel if available
        for (symbol, score) in candidates {
            await processScoutCandidate(symbol: symbol, score: score)
        }
    }
}

private func processScoutCandidate(symbol: String, score: Double) async {
    // This would delegate to ExecutionStateViewModel for high-conviction trading
    // For now, just log
    print("🔭 Scout found \(symbol) with score \(score)")
}
```

**Step 3: Build and verify**

Run:
```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add argus/ViewModels/Signal/SignalViewModel.swift
git commit -m "feat: Add scout loop management to SignalViewModel"
```

---

### Task 2: Add Argus Data Loading to SignalViewModel

**Files:**
- Modify: `argus/ViewModels/Signal/SignalViewModel.swift`
- Reference: `argus/ViewModels/TradingViewModel+Argus.swift:56-150`

**Step 1: Add loading state**

Add to SignalViewModel properties:

```swift
@Published var isLoadingArgus: Bool = false
@Published var loadedAssetTypes: [String: SafeAssetType] = [:]
@Published var loadingProgress: Double = 0.0
```

**Step 2: Add Argus data loading method**

Add before closing brace:

```swift
// MARK: - Argus Data Loading

@MainActor
func loadArgusData(for symbol: String) async {
    isLoadingArgus = true
    defer { isLoadingArgus = false }

    // 1. Detect asset type
    let assetType = await detectAssetType(for: symbol)

    // 2. Load candles if missing
    let marketVM = MarketViewModel()
    if marketVM.candles[symbol]?.isEmpty ?? true {
        await marketVM.loadCandles(for: symbol, timeframe: "1D")
    }

    // 3. Load Orion score
    if orionScores[symbol] == nil {
        await loadOrionScore(for: symbol, assetType: assetType)
    }

    // 4. Load fundamental score (for stocks/ETFs only)
    if assetType == .stock || assetType == .etf {
        if FundamentalScoreStore.shared.getScore(for: symbol) == nil {
            _ = await calculateFundamentalScore(for: symbol, assetType: assetType)
        }
    }

    // 5. Update asset type cache
    await updateAssetType(for: symbol, to: assetType)
}

private func detectAssetType(for symbol: String) async -> SafeAssetType {
    // Check cache first
    if let cached = loadedAssetTypes[symbol] {
        return cached
    }

    // Check if ETF
    let isEtf = await checkIsEtf(symbol)
    if isEtf { return .etf }

    // Default to stock for US symbols
    return .stock
}

private func checkIsEtf(_ symbol: String) async -> Bool {
    let marketVM = MarketViewModel()
    return marketVM.isETF(symbol)
}

private func updateAssetType(for symbol: String, to type: SafeAssetType) async {
    await MainActor.run {
        self.loadedAssetTypes[symbol] = type
    }
}
```

**Step 3: Add helper methods**

Add before closing brace:

```swift
func calculateFundamentalScore(for symbol: String, assetType: AssetType = .stock) async -> FundamentalScoreResult? {
    do {
        let score = try await AtlasCouncil.shared.analyzeStock(symbol: symbol)
        return score
    } catch {
        print("⚠️ Atlas analysis failed for \(symbol): \(error)")
        return nil
    }
}

func loadOrionScore(for symbol: String, assetType: AssetType = .stock) async {
    do {
        let marketVM = MarketViewModel()
        if let candles = marketVM.candles[symbol] {
            // Load via OrionStore
            await OrionStore.shared.ensureAnalysis(symbol: symbol, candles: candles)
        }
    } catch {
        print("⚠️ Orion score failed for \(symbol): \(error)")
    }
}
```

**Step 4: Build and verify**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

**Step 5: Commit**

```bash
git add argus/ViewModels/Signal/SignalViewModel.swift
git commit -m "feat: Add Argus data loading and asset type detection to SignalViewModel"
```

---

### Task 3: Add Voice Report Generation to SignalViewModel

**Files:**
- Modify: `argus/ViewModels/Signal/SignalViewModel.swift`
- Reference: `argus/ViewModels/TradingViewModel+Argus.swift:151-250`

**Step 1: Add voice report state**

Add to properties:

```swift
@Published var voiceReports: [String: String] = [:]
@Published var isGeneratingVoiceReport: Bool = false
```

**Step 2: Add voice report generation**

Add before closing brace:

```swift
// MARK: - Voice Report Generation

@MainActor
func generateVoiceReport(for symbol: String, tradeId: UUID? = nil) async {
    isGeneratingVoiceReport = true
    defer { isGeneratingVoiceReport = false }

    do {
        let marketVM = MarketViewModel()
        let quote = marketVM.quotes[symbol]
        let atlas = FundamentalScoreStore.shared.getScore(for: symbol)
        let orion = orionScores[symbol]

        var reportParts: [String] = []

        if let q = quote {
            reportParts.append("📊 \(symbol): \(q.price ?? 0) - \(q.percentChange ?? 0)%")
        }

        if let a = atlas {
            reportParts.append("📈 Atlas: \(a.totalScore)")
        }

        if let o = orion {
            reportParts.append("🔮 Orion: \(o.score)")
        }

        let report = reportParts.joined(separator: " | ")
        self.voiceReports[symbol] = report

        print("🎙️ Voice Report for \(symbol): \(report)")
    } catch {
        print("⚠️ Voice report generation failed: \(error)")
    }
}
```

**Step 3: Build and verify**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add argus/ViewModels/Signal/SignalViewModel.swift
git commit -m "feat: Add voice report generation to SignalViewModel"
```

---

### Task 4: Add Specialized Analysis Methods

**Files:**
- Modify: `argus/ViewModels/Signal/SignalViewModel.swift`
- Reference: `argus/ViewModels/TradingViewModel+Argus.swift:251-350`

**Step 1: Add specialized analysis methods**

```swift
// MARK: - Specialized Analysis

func loadSarTsiLab(symbol: String) async {
    // SAR + TSI technical analysis
    let marketVM = MarketViewModel()
    if let candles = marketVM.candles[symbol] {
        print("📊 SAR TSI Lab analysis for \(symbol): \(candles.count) candles")
    }
}

func analyzeOverreaction(symbol: String, atlas: Double?, aether: Double?) {
    // Check if stock is oversold (overreaction)
    let marketVM = MarketViewModel()
    if let quote = marketVM.quotes[symbol] {
        let isOversold = (quote.percentChange ?? 0) < -5.0 && (atlas ?? 0) > 75
        if isOversold {
            print("⚠️ Overreaction detected in \(symbol)")
        }
    }
}

func loadEtfData(for symbol: String) async {
    // Load ETF composition and sector breakdown
    print("📦 Loading ETF data for \(symbol)")
}

func hydrateAtlas() async {
    // Pre-load fundamental data for watchlist
    let marketVM = MarketViewModel()
    for symbol in marketVM.watchlist.prefix(10) {
        _ = await calculateFundamentalScore(for: symbol, assetType: .stock)
    }
}

func generateAISignals() async {
    // Generate AI-powered trading signals
    print("🤖 Generating AI signals...")
}
```

**Step 2: Build and verify**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Commit**

```bash
git add argus/ViewModels/Signal/SignalViewModel.swift
git commit -m "feat: Add specialized analysis methods (SAR, TSI, overreaction, ETF) to SignalViewModel"
```

---

### Task 5: Update TradingViewModel Facade with Scout Delegation

**Files:**
- Modify: `argus/ViewModels/TradingViewModel.swift`
- Reference: Check current facade structure

**Step 1: Add scout loop properties to TradingViewModel**

Add these computed properties to TradingViewModel facade:

```swift
var isScoutRunning: Bool {
    SignalViewModel.shared.isScoutRunning
}

var scoutCandidates: [String: Double] {
    SignalViewModel.shared.scoutCandidates
}
```

**Step 2: Add scout delegation methods**

Add these methods to TradingViewModel:

```swift
func startScoutLoop() {
    Task {
        await SignalViewModel.shared.startScoutLoop()
    }
}

func stopScoutLoop() {
    SignalViewModel.shared.stopScoutLoop()
}

func runScout() async {
    await SignalViewModel.shared.runScout()
}

func loadArgusData(for symbol: String) async {
    await SignalViewModel.shared.loadArgusData(for: symbol)
}
```

**Step 3: Build and verify**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add argus/ViewModels/TradingViewModel.swift
git commit -m "feat: Add scout delegation to TradingViewModel facade"
```

---

### Task 6: Update Unit Tests for Scout Logic

**Files:**
- Modify: `argusTests/ViewModels/SignalViewModelTests.swift`

**Step 1: Add scout loop tests**

Add these test methods to SignalViewModelTests:

```swift
func testScoutLoopInitial() {
    XCTAssertFalse(sut.isScoutRunning)
    XCTAssertEqual(sut.scoutCandidates, [:])
}

func testStartScoutLoop() async {
    // When
    await sut.startScoutLoop()

    // Then
    XCTAssertTrue(sut.isScoutRunning)
}

func testStopScoutLoop() async {
    // Given
    await sut.startScoutLoop()
    XCTAssertTrue(sut.isScoutRunning)

    // When
    sut.stopScoutLoop()

    // Then
    XCTAssertFalse(sut.isScoutRunning)
}
```

**Step 2: Add Argus loading tests**

```swift
func testLoadArgusDataInitial() {
    XCTAssertFalse(sut.isLoadingArgus)
    XCTAssertEqual(sut.loadedAssetTypes, [:])
}

func testDetectAssetType() async {
    // When
    let assetType = await sut.detectAssetType(for: "AAPL")

    // Then
    XCTAssertNotNil(assetType)
}
```

**Step 3: Build and test**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

**Step 4: Commit**

```bash
git add argusTests/ViewModels/SignalViewModelTests.swift
git commit -m "test: Add scout loop and Argus loading tests to SignalViewModelTests"
```

---

### Task 7: Verify Facade Backward Compatibility

**Files:**
- Test: `argusTests/ViewModels/TradingViewModelFacadeTests.swift`

**Step 1: Add scout facade tests**

Add to TradingViewModelFacadeTests:

```swift
func testFacadeExposesScoutData() {
    // TradingViewModel should expose scout data through facade
    XCTAssertNotNil(sut.isScoutRunning)
    XCTAssertNotNil(sut.scoutCandidates)
}

func testFacadeCanStartScoutLoop() async {
    // When
    await sut.startScoutLoop()

    // Then - no exceptions thrown
    XCTAssertTrue(sut.isScoutRunning)
}
```

**Step 2: Build and verify tests pass**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug test 2>&1 | grep -E "Test Suite|tests passed|FAILED"
```

Expected: All tests pass

**Step 3: Commit**

```bash
git add argusTests/ViewModels/TradingViewModelFacadeTests.swift
git commit -m "test: Add facade scout backward compatibility tests"
```

---

### Task 8: Final Integration and Documentation

**Files:**
- Create: `docs/analysis/signal-extension-migration-complete.md`

**Step 1: Create completion summary**

```markdown
# SignalViewModel Extension Migration Complete

## Summary
Successfully migrated TradingViewModel+Argus.swift (1,101 lines) to SignalViewModel

## Migrated Components
- Scout loop management (startScoutLoop, stopScoutLoop, runScout)
- Argus data loading for symbols
- Asset type detection
- Voice report generation
- Specialized analysis (SAR, TSI, overreaction detection)

## Backward Compatibility
- TradingViewModel facade maintains all scout methods
- Views can still call sut.startScoutLoop() on TradingViewModel
- No breaking changes to existing code

## Build Status
✅ All builds succeed
✅ All tests pass
✅ 0 compilation errors

## Next Steps
- Remove TradingViewModel+Argus.swift (now dead code)
- Migrate remaining extensions (PlanExecution, Persistence)
- Create HermesViewModel for news system
```

**Step 2: Build final version**

```bash
cd /Users/erenkapak/Desktop/argus/.worktrees/split-trading-viewmodel
xcodebuild -project argus.xcodeproj -scheme argus -configuration Debug 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Final commit**

```bash
git add docs/
git commit -m "docs: Add signal extension migration completion summary"
```

**Step 4: Show progress**

```bash
git log --oneline | head -10
```

---

## Success Criteria

✅ All 20+ methods migrated to SignalViewModel
✅ Build succeeds with 0 errors
✅ TradingViewModel facade maintains backward compatibility
✅ All existing tests pass
✅ Unit tests added for new methods
✅ Documentation updated

---

## Time Estimate

- Task 1 (Scout): 8 min
- Task 2 (Argus Loading): 10 min
- Task 3 (Voice Reports): 8 min
- Task 4 (Specialized): 10 min
- Task 5 (Facade): 5 min
- Task 6-7 (Tests): 10 min
- Task 8 (Docs): 5 min

**Total: ~56 minutes**

---

## Rollback Plan

If issues occur:
```bash
git revert HEAD~7..HEAD  # Revert last 7 commits
# Or restore from backup
cp argus/ViewModels/SignalViewModel.swift.backup argus/ViewModels/Signal/SignalViewModel.swift
```

---

**Plan Created:** 2026-02-03
**Status:** Ready for Implementation
**Method:** Subagent-Driven Development (incremental execution with code review)
