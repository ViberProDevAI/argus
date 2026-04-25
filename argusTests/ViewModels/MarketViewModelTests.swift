import XCTest
@testable import argus

@MainActor
final class MarketViewModelTests: XCTestCase {

    var sut: MarketViewModel!

    override func setUp() {
        super.setUp()
        sut = MarketViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertEqual(sut.quotes, [:])
        XCTAssertEqual(sut.candles, [:])
        XCTAssertEqual(sut.topGainers, [])
        XCTAssertEqual(sut.topLosers, [])
        XCTAssertEqual(sut.mostActive, [])
        XCTAssertEqual(sut.tcmbData, nil)
        XCTAssertEqual(sut.foreignFlowData, [:])
        XCTAssertEqual(sut.marketRegime, .neutral)
        XCTAssertFalse(sut.isLiveMode)
    }

    // MARK: - Quote Management Tests

    func testQuotesStorage_SingleQuote() {
        // Given
        let quote = Quote(
            symbol: "AAPL",
            price: 150.0,
            percentChange: 2.5,
            absoluteChange: 3.75,
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

        // When
        sut.quotes["AAPL"] = quote

        // Then
        XCTAssertEqual(sut.quotes.count, 1)
        XCTAssertEqual(sut.quotes["AAPL"]?.symbol, "AAPL")
        XCTAssertEqual(sut.quotes["AAPL"]?.price, 150.0)
    }

    func testQuotesStorage_MultipleQuotes() {
        // Given
        let quotes = [
            Quote(symbol: "AAPL", price: 150.0, percentChange: 2.5, absoluteChange: 3.75, volume: 1000000, dayHigh: 151.0, dayLow: 149.0, fiftyTwoWeekHigh: 200.0, fiftyTwoWeekLow: 100.0, marketCap: nil, pe: 28.5, dividend: 0.92, sector: "Technology"),
            Quote(symbol: "GOOGL", price: 2900.0, percentChange: 1.5, absoluteChange: 43.5, volume: 500000, dayHigh: 2910.0, dayLow: 2890.0, fiftyTwoWeekHigh: 3500.0, fiftyTwoWeekLow: 2000.0, marketCap: nil, pe: 25.0, dividend: nil, sector: "Technology"),
            Quote(symbol: "SPY", price: 600.0, percentChange: 0.8, absoluteChange: 4.8, volume: 100000000, dayHigh: 601.0, dayLow: 599.0, fiftyTwoWeekHigh: 650.0, fiftyTwoWeekLow: 450.0, marketCap: nil, pe: nil, dividend: nil, sector: "ETF")
        ]

        // When
        for quote in quotes {
            sut.quotes[quote.symbol!] = quote
        }

        // Then
        XCTAssertEqual(sut.quotes.count, 3)
        XCTAssertNotNil(sut.quotes["AAPL"])
        XCTAssertNotNil(sut.quotes["GOOGL"])
        XCTAssertNotNil(sut.quotes["SPY"])
    }

    // MARK: - Discovery Lists Tests

    func testTopGainers_Empty() {
        XCTAssertEqual(sut.topGainers, [])
    }

    func testTopGainers_WithData() {
        // Given
        sut.topGainers = [
            Quote(symbol: "STOCK1", price: 100.0, percentChange: 5.0, absoluteChange: 5.0, volume: 1000000, dayHigh: 105.0, dayLow: 95.0, fiftyTwoWeekHigh: 110.0, fiftyTwoWeekLow: 90.0, marketCap: nil, pe: nil, dividend: nil, sector: "Tech"),
            Quote(symbol: "STOCK2", price: 50.0, percentChange: 3.0, absoluteChange: 1.5, volume: 500000, dayHigh: 51.0, dayLow: 49.0, fiftyTwoWeekHigh: 60.0, fiftyTwoWeekLow: 40.0, marketCap: nil, pe: nil, dividend: nil, sector: "Finance")
        ]

        // When
        let result = sut.topGainers

        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertGreater(result[0].percentChange ?? 0, result[1].percentChange ?? 0)
    }

    func testTopLosers_Empty() {
        XCTAssertEqual(sut.topLosers, [])
    }

    func testMostActive_Empty() {
        XCTAssertEqual(sut.mostActive, [])
    }

    // MARK: - Candles Storage Tests

    func testCandlesStorage_SymbolWithTimeframe() {
        // Given
        let candle = Candle(
            timestamp: Date(),
            open: 150.0,
            high: 155.0,
            low: 149.0,
            close: 152.0,
            volume: 1000000
        )

        // When
        sut.candles["AAPL_1D"] = [candle]

        // Then
        XCTAssertEqual(sut.candles.count, 1)
        XCTAssertEqual(sut.candles["AAPL_1D"]?.count, 1)
        XCTAssertEqual(sut.candles["AAPL_1D"]?.first?.close, 152.0)
    }

    func testCandlesStorage_MultipleTimeframes() {
        // Given
        let dailyCandle = Candle(timestamp: Date(), open: 150.0, high: 155.0, low: 149.0, close: 152.0, volume: 1000000)
        let hourlyCandle = Candle(timestamp: Date(), open: 151.0, high: 153.0, low: 150.5, close: 151.5, volume: 100000)

        // When
        sut.candles["AAPL_1D"] = [dailyCandle]
        sut.candles["AAPL_1H"] = [hourlyCandle]

        // Then
        XCTAssertEqual(sut.candles.count, 2)
        XCTAssertEqual(sut.candles["AAPL_1D"]?.first?.close, 152.0)
        XCTAssertEqual(sut.candles["AAPL_1H"]?.first?.close, 151.5)
    }

    // MARK: - Market Regime Tests

    func testMarketRegime_Initial() {
        XCTAssertEqual(sut.marketRegime, .neutral)
    }

    func testMarketRegime_Changes() {
        // When
        sut.marketRegime = .bull
        XCTAssertEqual(sut.marketRegime, .bull)

        sut.marketRegime = .bear
        XCTAssertEqual(sut.marketRegime, .bear)
    }

    // MARK: - Live Mode Tests

    func testLiveMode_Initial() {
        XCTAssertFalse(sut.isLiveMode)
    }

    func testLiveMode_Toggle() {
        // When
        sut.isLiveMode = true

        // Then
        XCTAssertTrue(sut.isLiveMode)

        // When
        sut.isLiveMode = false

        // Then
        XCTAssertFalse(sut.isLiveMode)
    }

    // MARK: - Macro Data Tests

    func testMacroData_Initial() {
        XCTAssertNil(sut.tcmbData)
        XCTAssertEqual(sut.foreignFlowData, [:])
    }

    func testMacroData_Assignment() {
        // Given
        let macroData = TCMBDataService.TCMBMacroSnapshot(
            interestRate: 24.5,
            inflationRate: 44.2,
            unemploymentRate: 5.5,
            gdpGrowth: -0.5,
            currencyReserves: 85000000000,
            timestamp: Date()
        )

        // When
        sut.tcmbData = macroData

        // Then
        XCTAssertNotNil(sut.tcmbData)
        XCTAssertEqual(sut.tcmbData?.interestRate, 24.5)
        XCTAssertEqual(sut.tcmbData?.inflationRate, 44.2)
    }
}
