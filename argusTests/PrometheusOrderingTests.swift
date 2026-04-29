import XCTest
@testable import argus

/// Sıralama / yön regresyon testleri.
///
/// Geçmişte `ArgusGrandCouncil`, `PrometheusEngine.forecast(...)` çağrısına seriyi
/// **ters** sırada (newest-first) iletiyordu; engine içeride bir kez daha
/// `reversed()` çağırarak veriyi oldest-first çeviriyordu — net etki: tahmin
/// gerçekte zamanın tersine işliyor, "afaki" ve trend yönüne aykırı sonuçlar
/// çıkıyordu. PR-1.1'de:
///   • Engine API'si açıkça **oldest-first** olarak yeniden tanımlandı.
///   • Engine'in iç `reversed()` çağrısı kaldırıldı.
///   • Tüm çağıran taraflar oldest-first verecek şekilde düzeltildi.
///
/// Bu test, doğru sıralamanın geriye dönmesini önler.
final class PrometheusOrderingTests: XCTestCase {

    /// Net yukarı seri (oldest-first) → tahmin son fiyatın üstünde, trend yeşil.
    func testForecast_ascendingSeries_yieldsBullishProjection() async {
        // 120 bar minimum eşiği — engine bunun altını insufficient sayar.
        let prices = (1...140).map { Double($0) }

        let result = await PrometheusEngine.shared.forecast(
            symbol: "TEST_ASC",
            historicalPrices: prices
        )

        XCTAssertTrue(result.isValid, "Forecast geçersiz; minimum bar eşiği değişmiş olabilir.")
        XCTAssertEqual(result.currentPrice, prices.last, "Current price oldest-first dizinin SON elemanı olmalı.")
        XCTAssertGreaterThan(result.predictedPrice, prices.last!,
                             "Yukarı trend serisi için tahmin son fiyatın üstünde olmalı.")
        XCTAssertEqual(result.trend.colorName, "green",
                       "Yukarı trendde renk yeşil ailesinde olmalı (bullish/strongBullish).")
    }

    /// Net aşağı seri (oldest-first) → tahmin son fiyatın altında, trend kırmızı.
    func testForecast_descendingSeries_yieldsBearishProjection() async {
        let prices = stride(from: 140.0, through: 1.0, by: -1.0).map { $0 }
        precondition(prices.count >= 120)

        let result = await PrometheusEngine.shared.forecast(
            symbol: "TEST_DESC",
            historicalPrices: prices
        )

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.currentPrice, prices.last,
                       "Current price oldest-first dizinin SON (en düşük) elemanı olmalı.")
        XCTAssertLessThan(result.predictedPrice, prices.last!,
                          "Aşağı trend serisi için tahmin son fiyatın altında olmalı.")
        XCTAssertEqual(result.trend.colorName, "red",
                       "Aşağı trendde renk kırmızı ailesinde olmalı (bearish/strongBearish).")
    }

    /// Minimum eşiğin altı → insufficient forecast (isValid == false).
    func testForecast_belowMinimumBars_returnsInsufficient() async {
        let prices = (1...100).map { Double($0) }  // 120'nin altı

        let result = await PrometheusEngine.shared.forecast(
            symbol: "TEST_INSUF",
            historicalPrices: prices
        )

        XCTAssertFalse(result.isValid, "120 barın altı insufficient olmalı.")
        XCTAssertEqual(result.confidence, 0,
                       "Insufficient forecast confidence 0 olmalı (eski 50 floor kaldırıldı).")
    }
}
