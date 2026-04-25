import XCTest
@testable import argus

final class TradeValidatorTests: XCTestCase {

    func testValidateBuy_rejectsEmptySymbol() {
        let r = TradeValidator.validateBuy(
            symbol: "  ",
            quantity: 1,
            price: 10,
            availableBalance: 10_000,
            isBistMarketOpen: true,
            isGlobalMarketOpen: true
        )
        XCTAssertFalse(r.isValid)
        XCTAssertNotNil(r.error)
    }

    func testValidateBuy_rejectsNonPositiveQuantity() {
        let r = TradeValidator.validateBuy(
            symbol: "AAPL",
            quantity: 0,
            price: 10,
            availableBalance: 10_000,
            isBistMarketOpen: true,
            isGlobalMarketOpen: true
        )
        XCTAssertFalse(r.isValid)
    }

    func testValidateBuy_acceptsWhenMarketsOpenAndBalanceOk() {
        let r = TradeValidator.validateBuy(
            symbol: "AAPL",
            quantity: 1,
            price: 100,
            availableBalance: 10_000,
            isBistMarketOpen: true,
            isGlobalMarketOpen: true
        )
        XCTAssertTrue(r.isValid)
        XCTAssertNil(r.error)
    }
}
