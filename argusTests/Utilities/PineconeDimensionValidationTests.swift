import XCTest
@testable import argus

/// `PineconeService.validateIndexDimension()` davranışı, network call gerektirdiği
/// için bu suite gerçek doğrulama akışını mock URL session olmadan test edemez.
/// Network'siz olarak doğrulanan yüzeyler:
///
/// - `PineconeError.dimensionMismatch` ve `.dimensionUnknown` description çıktısı
///   (kullanıcıya gösterilen aksiyon: index'i yeniden oluştur, README Adım 5)
/// - `PineconeError` Equatable conformance (Result cache'inin doğru davranması için)
/// - `PineconeService.expectedDimension` sabiti `GeminiEmbeddingService` modelinin
///   ürettiği boyutla uyumlu (text-embedding-004 → 768). Embedding modeli değişirse
///   bu test kırılır ve geliştiriciyi expectedDimension'ı güncellemeye yönlendirir.
final class PineconeDimensionValidationTests: XCTestCase {

    // MARK: - Expected dimension contract

    func testExpectedDimension_matchesTextEmbedding004OutputSize() {
        XCTAssertEqual(
            PineconeService.expectedDimension,
            768,
            "text-embedding-004 768-dim üretir; embedding modeli değiştiyse expectedDimension güncellenmeli."
        )
    }

    // MARK: - dimensionMismatch description

    func testDimensionMismatch_descriptionMentionsBothNumbers() {
        let error = PineconeError.dimensionMismatch(expected: 768, actual: 1024)
        let description = error.errorDescription ?? ""

        XCTAssertTrue(description.contains("768"), "Expected dimension mesajda olmalı")
        XCTAssertTrue(description.contains("1024"), "Actual dimension mesajda olmalı")
    }

    func testDimensionMismatch_descriptionPointsToReadmeStep() {
        let error = PineconeError.dimensionMismatch(expected: 768, actual: 1536)
        let description = error.errorDescription ?? ""

        XCTAssertTrue(
            description.localizedCaseInsensitiveContains("Adım 5") ||
            description.localizedCaseInsensitiveContains("README"),
            "Kullanıcıya 'nereye bakacağını' söylemeli (README Adım 5)"
        )
    }

    func testDimensionMismatch_descriptionMentionsEmbeddingModelName() {
        let error = PineconeError.dimensionMismatch(expected: 768, actual: 384)
        let description = error.errorDescription ?? ""

        XCTAssertTrue(
            description.contains("text-embedding-004"),
            "Hangi modelin bu boyutu beklediği açık olmalı"
        )
    }

    // MARK: - dimensionUnknown description

    func testDimensionUnknown_descriptionMentionsResponseGap() {
        let error = PineconeError.dimensionUnknown
        let description = error.errorDescription ?? ""

        XCTAssertFalse(description.isEmpty, "dimensionUnknown'un kullanıcıya gösterilen mesajı olmalı")
        XCTAssertTrue(
            description.localizedCaseInsensitiveContains("describe_index_stats") ||
            description.localizedCaseInsensitiveContains("yanıt"),
            "Hangi endpoint'in eksik döndüğü/yanıtın eksikliği belirtilmeli"
        )
    }

    // MARK: - Equatable conformance

    /// `validateIndexDimension()` cache'i `Result<Int, PineconeError>` saklar;
    /// hata cache'inin doğru karşılaştırılabilmesi için Equatable olmalı.
    func testPineconeError_equatable_dimensionMismatchSameValuesAreEqual() {
        let a = PineconeError.dimensionMismatch(expected: 768, actual: 1024)
        let b = PineconeError.dimensionMismatch(expected: 768, actual: 1024)
        XCTAssertEqual(a, b)
    }

    func testPineconeError_equatable_dimensionMismatchDifferentActualNotEqual() {
        let a = PineconeError.dimensionMismatch(expected: 768, actual: 1024)
        let b = PineconeError.dimensionMismatch(expected: 768, actual: 1536)
        XCTAssertNotEqual(a, b)
    }

    func testPineconeError_equatable_dimensionUnknownEqualsItself() {
        XCTAssertEqual(PineconeError.dimensionUnknown, PineconeError.dimensionUnknown)
    }

    func testPineconeError_equatable_differentCasesNotEqual() {
        XCTAssertNotEqual(PineconeError.dimensionUnknown, PineconeError.missingAPIKey)
        XCTAssertNotEqual(
            PineconeError.dimensionMismatch(expected: 768, actual: 1024),
            PineconeError.dimensionUnknown
        )
    }

    func testPineconeError_equatable_apiErrorPreservesAssociatedValues() {
        XCTAssertEqual(
            PineconeError.apiError(400, "vector dimension mismatch"),
            PineconeError.apiError(400, "vector dimension mismatch")
        )
        XCTAssertNotEqual(
            PineconeError.apiError(400, "x"),
            PineconeError.apiError(401, "x")
        )
    }

    // MARK: - Cache reset

    /// `resetDimensionValidationCache()` mevcut cache durumundan bağımsız
    /// olarak çağrılabilir olmalı (idempotent). Network-bağımsız smoke test.
    @MainActor
    func testResetDimensionValidationCache_isIdempotent() {
        PineconeService.shared.resetDimensionValidationCache()
        PineconeService.shared.resetDimensionValidationCache()
    }
}
