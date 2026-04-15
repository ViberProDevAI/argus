import XCTest
@testable import argus

final class SymbolMapperTests: XCTestCase {

    func testNormalize_eodhd_appendsUS() {
        let result = SymbolMapper.normalize(symbol: "aapl", for: .eodhd)
        XCTAssertEqual(result, "AAPL.US")
    }

    func testNormalize_eodhd_doesNotDoubleAppend() {
        let result = SymbolMapper.normalize(symbol: "AAPL.US", for: .eodhd)
        XCTAssertEqual(result, "AAPL.US")
    }

    func testNormalize_twelveData_uppercases() {
        let result = SymbolMapper.normalize(symbol: "  msft  ", for: .twelveData)
        XCTAssertEqual(result, "MSFT")
    }

    func testNormalize_yahoo_uppercases() {
        let result = SymbolMapper.normalize(symbol: "goog", for: .yahoo)
        XCTAssertEqual(result, "GOOG")
    }

    func testNormalize_finnhub_uppercases() {
        let result = SymbolMapper.normalize(symbol: "tsla", for: .finnhub)
        XCTAssertEqual(result, "TSLA")
    }

    func testNormalize_coinApi_preservesUppercase() {
        let result = SymbolMapper.normalize(symbol: "btc-usd", for: .coinApi)
        XCTAssertEqual(result, "BTC-USD")
    }
}
