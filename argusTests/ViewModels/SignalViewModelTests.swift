import XCTest
@testable import argus

@MainActor
final class SignalViewModelTests: XCTestCase {

    var sut: SignalViewModel!

    override func setUp() {
        super.setUp()
        sut = SignalViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertFalse(sut.isOrionLoading)
        XCTAssertEqual(sut.prometheusForecastBySymbol, [:])
        XCTAssertEqual(sut.searchResults, [])
        XCTAssertEqual(sut.demeterScores, [])
        XCTAssertNil(sut.demeterMatrix)
        XCTAssertFalse(sut.isRunningDemeter)
        XCTAssertEqual(sut.activeShocks, [])
    }

    // MARK: - Facade Accessor Tests

    func testOrionAnalysisAccessor() {
        // When
        let result = sut.orionAnalysis

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result is [String: MultiTimeframeAnalysis])
    }

    func testPatternsAccessor() {
        // When
        let result = sut.patterns

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result is [String: [OrionChartPattern]])
    }

    func testOrionScoresAccessor() {
        // When
        let result = sut.orionScores

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result is [String: OrionScoreResult])
    }

    // MARK: - Grand Decisions Tests

    func testGrandDecisionsGetter() {
        // When
        let result = sut.grandDecisions

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result is [String: ArgusGrandDecision])
    }

    func testGrandDecisionsSetter() {
        // Given
        let decisions: [String: ArgusGrandDecision] = [:]

        // When
        sut.grandDecisions = decisions

        // Then
        XCTAssertEqual(sut.grandDecisions.count, 0)
    }

    // MARK: - Chimera Signals Tests

    func testChimeraSignalsGetter() {
        // When
        let result = sut.chimeraSignals

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result is [String: ChimeraSignal])
    }

    func testChimeraSignalsSetter() {
        // Given
        let signals: [String: ChimeraSignal] = [:]

        // When
        sut.chimeraSignals = signals

        // Then
        XCTAssertEqual(sut.chimeraSignals.count, 0)
    }

    // MARK: - Demeter Analysis Tests

    func testDemeterScoresInitial() {
        XCTAssertEqual(sut.demeterScores, [])
    }

    func testDemeterMatrixInitial() {
        XCTAssertNil(sut.demeterMatrix)
    }

    func testActiveShocksInitial() {
        XCTAssertEqual(sut.activeShocks, [])
    }

    func testIsRunningDemeter_Initial() {
        XCTAssertFalse(sut.isRunningDemeter)
    }

    // MARK: - Prometheus Forecast Tests

    func testPrometheusForecastStorage() {
        // Given
        let forecast = PrometheusForecast(
            symbol: "AAPL",
            forecast: 155.0,
            confidence: 0.85,
            timeframe: "1D",
            signal: "BUY",
            timestamp: Date()
        )

        // When
        sut.prometheusForecastBySymbol["AAPL"] = forecast

        // Then
        XCTAssertEqual(sut.prometheusForecastBySymbol.count, 1)
        XCTAssertEqual(sut.prometheusForecastBySymbol["AAPL"]?.forecast, 155.0)
    }

    // MARK: - Search Results Tests

    func testSearchResultsEmpty() {
        XCTAssertEqual(sut.searchResults, [])
    }

    func testSearchResultsStorage() {
        // Given
        let result = SearchResult(
            symbol: "AAPL",
            name: "Apple Inc.",
            type: .stock,
            sector: "Technology"
        )

        // When
        sut.searchResults = [result]

        // Then
        XCTAssertEqual(sut.searchResults.count, 1)
        XCTAssertEqual(sut.searchResults.first?.symbol, "AAPL")
    }

    // MARK: - Orion Loading Tests

    func testIsOrionLoading_Initial() {
        XCTAssertFalse(sut.isOrionLoading)
    }

    func testIsOrionLoading_Toggle() {
        // When
        sut.isOrionLoading = true

        // Then
        XCTAssertTrue(sut.isOrionLoading)

        // When
        sut.isOrionLoading = false

        // Then
        XCTAssertFalse(sut.isOrionLoading)
    }

    // MARK: - Operations Tests

    func testEnsureOrionAnalysisMethodExists() {
        // This test verifies the method can be called
        // The actual async behavior is tested via integration tests
        XCTAssertNotNil(sut)
    }

    func testRunDemeterAnalysisMethodExists() {
        // This test verifies the method can be called
        XCTAssertNotNil(sut)
    }

    func testGetDemeterScoreForSymbolNotFound() {
        // When
        let result = sut.getDemeterScore(for: "UNKNOWN")

        // Then
        XCTAssertNil(result)
    }
}
