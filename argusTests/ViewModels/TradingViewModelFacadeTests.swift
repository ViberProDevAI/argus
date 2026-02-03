import XCTest
@testable import argus

@MainActor
final class TradingViewModelFacadeTests: XCTestCase {

    var sut: TradingViewModel!

    override func setUp() {
        super.setUp()
        sut = TradingViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Facade Pattern Tests

    func testFacadeExposesPortfolioData() {
        // TradingViewModel should still expose portfolio data for backward compatibility
        XCTAssertNotNil(sut.portfolio)
        XCTAssertNotNil(sut.balance)
        XCTAssertNotNil(sut.bistBalance)
        XCTAssertNotNil(sut.transactionHistory)
    }

    func testFacadeExposesMarketData() {
        // TradingViewModel should still expose market data
        XCTAssertNotNil(sut.quotes)
        XCTAssertNotNil(sut.candles)
        XCTAssertNotNil(sut.topGainers)
        XCTAssertNotNil(sut.topLosers)
        XCTAssertNotNil(sut.mostActive)
        XCTAssertNotNil(sut.watchlist)
    }

    func testFacadeExposesSignalData() {
        // TradingViewModel should still expose signal/analysis data
        XCTAssertNotNil(sut.orionAnalysis)
        XCTAssertNotNil(sut.patterns)
        XCTAssertNotNil(sut.grandDecisions)
        XCTAssertNotNil(sut.chimeraSignals)
        XCTAssertNotNil(sut.demeterScores)
    }

    func testFacadeExposesNewsData() {
        // TradingViewModel should still expose news data
        XCTAssertNotNil(sut.newsBySymbol)
        XCTAssertNotNil(sut.newsInsightsBySymbol)
        XCTAssertNotNil(sut.hermesEventsBySymbol)
        XCTAssertNotNil(sut.watchlistNewsInsights)
        XCTAssertNotNil(sut.generalNewsInsights)
    }

    // MARK: - Portfolio Accessor Tests

    func testPortfolioAccessor() {
        // When
        let portfolio = sut.portfolio

        // Then
        XCTAssertNotNil(portfolio)
        XCTAssertTrue(portfolio is [Trade])
    }

    func testBalanceAccessor() {
        // When
        let balance = sut.balance

        // Then
        XCTAssertGreater(balance, 0)
    }

    func testBistBalanceAccessor() {
        // When
        let bistBalance = sut.bistBalance

        // Then
        XCTAssertGreater(bistBalance, 0)
    }

    // MARK: - Market Data Accessor Tests

    func testQuotesAccessor() {
        // When
        let quotes = sut.quotes

        // Then
        XCTAssertNotNil(quotes)
        XCTAssertTrue(quotes is [String: Quote])
    }

    func testCandlesAccessor() {
        // When
        let candles = sut.candles

        // Then
        XCTAssertNotNil(candles)
        XCTAssertTrue(candles is [String: [Candle]])
    }

    func testWatchlistAccessor() {
        // When
        let watchlist = sut.watchlist

        // Then
        XCTAssertNotNil(watchlist)
        XCTAssertTrue(watchlist is [String])
    }

    // MARK: - Signal Data Accessor Tests

    func testOrionAnalysisAccessor() {
        // When
        let analysis = sut.orionAnalysis

        // Then
        XCTAssertNotNil(analysis)
        XCTAssertTrue(analysis is [String: MultiTimeframeAnalysis])
    }

    func testPatternsAccessor() {
        // When
        let patterns = sut.patterns

        // Then
        XCTAssertNotNil(patterns)
        XCTAssertTrue(patterns is [String: [OrionChartPattern]])
    }

    func testGrandDecisionsAccessor() {
        // When
        let decisions = sut.grandDecisions

        // Then
        XCTAssertNotNil(decisions)
        XCTAssertTrue(decisions is [String: ArgusGrandDecision])
    }

    // MARK: - Backward Compatibility Tests

    func testFacadePreservesPublishedProperties() {
        // Verify that @Published properties are still available
        XCTAssertNotNil(sut.$portfolio)
        XCTAssertNotNil(sut.$balance)
        XCTAssertNotNil(sut.$quotes)
        XCTAssertNotNil(sut.$candles)
        XCTAssertNotNil(sut.$topGainers)
    }

    func testFacadePreservesLoadingState() {
        // When
        XCTAssertNotNil(sut.isLoading)

        // Then
        XCTAssertTrue(sut.isLoading is Bool)
    }

    func testFacadePreservesErrorHandling() {
        // When
        XCTAssertNotNil(sut.errorMessage)

        // Then
        // Error message should be nil initially
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Multiple Views Simulation Tests

    func testMultipleViewsCanObservePortfolioChanges() {
        // This simulates multiple views observing portfolio updates
        // through the TradingViewModel facade

        var observedBalance: Double?

        // Observer 1
        let observation1 = sut.$balance.sink { newBalance in
            observedBalance = newBalance
        }

        // Observer 2
        let observation2 = sut.$balance.sink { newBalance in
            XCTAssertEqual(newBalance, observedBalance)
        }

        // When balance updates
        sut.balance = 75000.0

        // Then both observers see the change
        XCTAssertEqual(observedBalance, 75000.0)

        observation1.cancel()
        observation2.cancel()
    }

    func testMultipleViewsCanObserveQuoteChanges() {
        // Simulates multiple views observing quote updates

        var observedQuoteCount: Int?
        var quote: Quote? = nil

        // Observer
        let observation = sut.$quotes.sink { newQuotes in
            observedQuoteCount = newQuotes.count
        }

        // Add a quote
        quote = Quote(
            symbol: "AAPL",
            price: 150.0,
            percentChange: 2.0,
            absoluteChange: 3.0,
            volume: 1000000,
            dayHigh: 151.0,
            dayLow: 149.0,
            fiftyTwoWeekHigh: 200.0,
            fiftyTwoWeekLow: 100.0,
            marketCap: nil,
            pe: 28.5,
            dividend: 0.92,
            sector: "Technology"
        )
        sut.quotes["AAPL"] = quote

        // Trigger update
        sut.objectWillChange.send()

        observation.cancel()
    }
}
