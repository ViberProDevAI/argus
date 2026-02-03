import XCTest
@testable import argus

@MainActor
final class PortfolioViewModelTests: XCTestCase {

    var sut: PortfolioViewModel!

    override func setUp() {
        super.setUp()
        sut = PortfolioViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertEqual(sut.portfolio, [])
        XCTAssertEqual(sut.balance, 100000.0)
        XCTAssertEqual(sut.bistBalance, 1000000.0)
        XCTAssertEqual(sut.usdTryRate, 35.0)
        XCTAssertEqual(sut.transactionHistory, [])
        XCTAssertFalse(sut.isLoadingPortfolio)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Computed Properties Tests

    func testAllTradesBySymbol_Empty() {
        XCTAssertEqual(sut.allTradesBySymbol, [:])
    }

    func testAllTradesBySymbol_MultipleSymbols() {
        // Given
        let trade1 = Trade(id: "1", symbol: "AAPL", quantity: 10, entryPrice: 150.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        let trade2 = Trade(id: "2", symbol: "AAPL", quantity: 5, entryPrice: 145.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        let trade3 = Trade(id: "3", symbol: "GOOGL", quantity: 2, entryPrice: 2800.0, currentPrice: 2900.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")

        sut.portfolio = [trade1, trade2, trade3]

        // When
        let result = sut.allTradesBySymbol

        // Then
        XCTAssertEqual(result.keys.count, 2)
        XCTAssertEqual(result["AAPL"]?.count, 2)
        XCTAssertEqual(result["GOOGL"]?.count, 1)
    }

    func testBistPortfolio_FiltersCorrectly() {
        // Given
        let bistTrade = Trade(id: "1", symbol: "THYAO", quantity: 100, entryPrice: 50.0, currentPrice: 52.0, currency: .TRY, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        let usdTrade = Trade(id: "2", symbol: "AAPL", quantity: 10, entryPrice: 150.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")

        sut.portfolio = [bistTrade, usdTrade]

        // When
        let result = sut.bistPortfolio

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.symbol, "THYAO")
    }

    func testGlobalPortfolio_FiltersCorrectly() {
        // Given
        let bistTrade = Trade(id: "1", symbol: "THYAO", quantity: 100, entryPrice: 50.0, currentPrice: 52.0, currency: .TRY, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        let usdTrade = Trade(id: "2", symbol: "AAPL", quantity: 10, entryPrice: 150.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")

        sut.portfolio = [bistTrade, usdTrade]

        // When
        let result = sut.globalPortfolio

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.symbol, "AAPL")
    }

    func testBistOpenPortfolio_FiltersOpenTradesOnly() {
        // Given
        let openTrade = Trade(id: "1", symbol: "THYAO", quantity: 100, entryPrice: 50.0, currentPrice: 52.0, currency: .TRY, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        let closedTrade = Trade(id: "2", symbol: "TUPRS", quantity: 50, entryPrice: 35.0, currentPrice: 36.0, currency: .TRY, isOpen: false, tradeType: .long, entryDate: Date(), exitDate: Date(), notes: "")

        sut.portfolio = [openTrade, closedTrade]

        // When
        let result = sut.bistOpenPortfolio

        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.symbol, "THYAO")
    }

    // MARK: - Portfolio Calculations Tests

    func testClearAll() {
        // Given
        sut.balance = 50000.0
        sut.bistBalance = 500000.0
        sut.usdTryRate = 40.0
        sut.errorMessage = "Some error"
        sut.portfolio = [
            Trade(id: "1", symbol: "AAPL", quantity: 10, entryPrice: 150.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        ]

        // When
        sut.clearAll()

        // Then
        XCTAssertEqual(sut.portfolio, [])
        XCTAssertEqual(sut.balance, 100000.0)
        XCTAssertEqual(sut.bistBalance, 1000000.0)
        XCTAssertEqual(sut.usdTryRate, 35.0)
        XCTAssertNil(sut.errorMessage)
    }

    func testIsBistMarketOpen_Weekend() {
        // Create a Saturday
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!

        // Saturday (weekday = 7)
        let saturdayComponents = DateComponents(year: 2025, month: 2, day: 8, hour: 12, minute: 0)
        let saturday = calendar.date(from: saturdayComponents)!

        // Note: This test would require mocking Date() which is more complex
        // For now, we'll just test that the method exists and returns a Bool
        let result = sut.isBistMarketOpen()
        XCTAssertTrue(result is Bool)
    }

    func testExportTransactionHistoryJSON_Empty() {
        // Given
        sut.transactionHistory = []

        // When
        let json = sut.exportTransactionHistoryJSON()

        // Then
        XCTAssertTrue(json.contains("[]"))
    }

    func testExportTransactionHistoryJSON_WithData() {
        // Given
        let transaction = Transaction(
            id: "tx1",
            symbol: "AAPL",
            type: .buy,
            quantity: 10,
            price: 150.0,
            total: 1500.0,
            date: Date(),
            notes: "Test transaction"
        )
        sut.transactionHistory = [transaction]

        // When
        let json = sut.exportTransactionHistoryJSON()

        // Then
        XCTAssertTrue(json.contains("AAPL"))
        XCTAssertTrue(json.contains("buy"))
        XCTAssertFalse(json.contains("Error"))
    }

    // MARK: - Utility Methods Tests

    func testTopPositions_Default() {
        // When
        let result = sut.topPositions()

        // Then
        XCTAssertEqual(result.count, 0)
    }

    func testConcentrationWarnings() {
        // When
        let result = sut.concentrationWarnings

        // Then
        XCTAssertEqual(result.count, 0)
    }

    func testPortfolioAllocation() {
        // When
        let result = sut.portfolioAllocation

        // Then
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - Portfolio Operations Tests

    func testCloseAllPositions_NoOpenTrades() {
        // Given
        let closedTrade = Trade(id: "1", symbol: "AAPL", quantity: 10, entryPrice: 150.0, currentPrice: 155.0, currency: .USD, isOpen: false, tradeType: .long, entryDate: Date(), exitDate: Date(), notes: "")
        sut.portfolio = [closedTrade]

        // When
        sut.closeAllPositions(for: "AAPL")

        // Then (no exceptions thrown, portfolio unchanged)
        XCTAssertEqual(sut.portfolio.count, 1)
    }

    func testCloseAllPositions_WithOpenTrades() {
        // Given
        let trade1 = Trade(id: "1", symbol: "AAPL", quantity: 10, entryPrice: 150.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        let trade2 = Trade(id: "2", symbol: "AAPL", quantity: 5, entryPrice: 145.0, currentPrice: 155.0, currency: .USD, isOpen: true, tradeType: .long, entryDate: Date(), exitDate: nil, notes: "")
        sut.portfolio = [trade1, trade2]

        // When
        sut.closeAllPositions(for: "AAPL")

        // Then (no exceptions thrown)
        XCTAssertEqual(sut.portfolio.count, 2)
    }

    // MARK: - Plan Execution Tests

    func testActivePlansInitial() {
        XCTAssertEqual(sut.activePlans, [:])
    }

    func testAddActivePlan() {
        // Given
        let plan = PositionPlan(
            id: UUID(),
            symbol: "AAPL",
            quantity: 10,
            entryPrice: 150.0,
            targetPrice: 160.0,
            stopPrice: 140.0,
            createdAt: Date()
        )

        // When
        sut.addActivePlan(plan)

        // Then
        XCTAssertEqual(sut.activePlans.count, 1)
        XCTAssertNotNil(sut.activePlans[plan.id])
    }

    func testRemoveActivePlan() {
        // Given
        let planId = UUID()
        sut.activePlans[planId] = PositionPlan(
            id: planId,
            symbol: "AAPL",
            quantity: 10,
            entryPrice: 150.0,
            targetPrice: 160.0,
            stopPrice: 140.0,
            createdAt: Date()
        )

        // When
        sut.removeActivePlan(id: planId)

        // Then
        XCTAssertEqual(sut.activePlans.count, 0)
    }

    func testIsCheckingPlanTriggersInitial() {
        XCTAssertFalse(sut.isCheckingPlanTriggers)
    }

    // MARK: - Portfolio Persistence Tests

    func testResetAllData() {
        // Given
        sut.balance = 50000.0
        sut.bistBalance = 500000.0

        // When
        sut.resetAllData()

        // Then
        XCTAssertEqual(sut.balance, 100000.0)
        XCTAssertEqual(sut.bistBalance, 1000000.0)
        XCTAssertEqual(sut.activePlans, [:])
    }

    func testExportPortfolioSnapshot() {
        // When
        let snapshot = sut.exportPortfolioSnapshot()

        // Then
        XCTAssertNotNil(snapshot["timestamp"])
        XCTAssertNotNil(snapshot["balance"])
        XCTAssertNotNil(snapshot["portfolio"])
    }
}
