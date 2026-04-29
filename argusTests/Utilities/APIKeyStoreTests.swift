import XCTest
@testable import argus

/// `APIKeyStore` davranış testleri. Tüm doğrulama public API üzerinden
/// yapılır; private helper'lar (isUsableKey vb.) doğrudan değil, gözlenebilir
/// sonuçlarıyla test edilir.
///
/// Test izolasyonu:
/// - `.massive` provider'ı diğer test/üretim kodu tarafından kullanılmıyor
///   (Secrets fallback sabit `""`); bu yüzden çakışmasız sandbox.
/// - `customValue` testleri benzersiz prefix kullanır.
/// - Her test setUp/tearDown ile kendi yazdıklarını temizler.
///
/// Not: Tests gerçek Keychain'e yazar. iOS Simulator'da Keychain sandboxed
/// olduğu için CI runner'da kalıcı kirlilik bırakmaz.
final class APIKeyStoreTests: XCTestCase {

    private let testProvider: APIProvider = .massive
    private let customKeyPrefix = "argus.test.apikeystore."

    private var customStorageKey: String {
        "\(customKeyPrefix)\(name)"
    }

    override func setUp() {
        super.setUp()
        APIKeyStore.shared.deleteKey(provider: testProvider)
        APIKeyStore.shared.deleteCustomValue(for: customStorageKey)
    }

    override func tearDown() {
        APIKeyStore.shared.deleteKey(provider: testProvider)
        APIKeyStore.shared.deleteCustomValue(for: customStorageKey)
        super.tearDown()
    }

    // MARK: - Provider key round-trip

    func testSetKey_persistsAndGetKeyReturnsValue() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-abc123")
        XCTAssertEqual(APIKeyStore.shared.getKey(for: testProvider), "sk-live-abc123")
    }

    func testSetKey_trimsLeadingAndTrailingWhitespace() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "  sk-live-xyz  \n")
        XCTAssertEqual(APIKeyStore.shared.getKey(for: testProvider), "sk-live-xyz")
    }

    func testSetKey_emptyStringDeletesKey() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-existing")
        XCTAssertNotNil(APIKeyStore.shared.getKey(for: testProvider))

        APIKeyStore.shared.setKey(provider: testProvider, key: "")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testSetKey_whitespaceOnlyStringDeletesKey() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-existing")
        APIKeyStore.shared.setKey(provider: testProvider, key: "   \t\n")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testDeleteKey_removesValue() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-removeme")
        APIKeyStore.shared.deleteKey(provider: testProvider)
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    // MARK: - Placeholder rejection contract

    /// `Secrets.xcconfig.example` placeholder'ları üretimde key gibi
    /// görünmemeli. Filtre `isUsableKey` üzerinden gözlenir: bu değerler
    /// store'a yazılsa bile `getKey` `nil` döner.
    func testGetKey_returnsNilForYourKeyPlaceholder() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "YOUR_KEY_HERE")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testGetKey_returnsNilForLowercasePlaceholderVariant() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "your_api_key")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testGetKey_returnsNilForPlaceholderSubstring() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "INSERT_PLACEHOLDER_HERE")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testGetKey_returnsNilForChangeMeMarker() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "CHANGE_ME")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testGetKey_returnsNilForRedactedMarker() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "<REDACTED>")
        XCTAssertNil(APIKeyStore.shared.getKey(for: testProvider))
    }

    func testGetKey_acceptsRealisticTokenContainingNoPlaceholderMarkers() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "AIzaSyABC_real_token_999")
        XCTAssertEqual(APIKeyStore.shared.getKey(for: testProvider), "AIzaSyABC_real_token_999")
    }

    // MARK: - Custom value round-trip (non-enum storage)

    func testSetCustomValue_persistsAndGetCustomValueReturnsValue() {
        APIKeyStore.shared.setCustomValue("https://argus-test.example", for: customStorageKey)
        XCTAssertEqual(APIKeyStore.shared.getCustomValue(for: customStorageKey), "https://argus-test.example")
    }

    func testSetCustomValue_emptyStringDeletesValue() {
        APIKeyStore.shared.setCustomValue("https://argus-test.example", for: customStorageKey)
        APIKeyStore.shared.setCustomValue("", for: customStorageKey)
        XCTAssertNil(APIKeyStore.shared.getCustomValue(for: customStorageKey))
    }

    func testGetCustomValue_returnsNilForPlaceholder() {
        APIKeyStore.shared.setCustomValue("YOUR_CUSTOM_URL", for: customStorageKey)
        XCTAssertNil(APIKeyStore.shared.getCustomValue(for: customStorageKey))
    }

    func testDeleteCustomValue_removesValue() {
        APIKeyStore.shared.setCustomValue("payload", for: customStorageKey)
        APIKeyStore.shared.deleteCustomValue(for: customStorageKey)
        XCTAssertNil(APIKeyStore.shared.getCustomValue(for: customStorageKey))
    }

    // MARK: - NotificationCenter publish

    func testSetKey_postsArgusKeyStoreDidUpdateNotification() {
        let expectation = XCTNSNotificationExpectation(
            name: .argusKeyStoreDidUpdate,
            object: nil,
            notificationCenter: .default
        )
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-notif-test")
        wait(for: [expectation], timeout: 1.0)
    }

    func testDeleteKey_postsArgusKeyStoreDidUpdateNotification() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-existing")

        let expectation = XCTNSNotificationExpectation(
            name: .argusKeyStoreDidUpdate,
            object: nil,
            notificationCenter: .default
        )
        APIKeyStore.shared.deleteKey(provider: testProvider)
        wait(for: [expectation], timeout: 1.0)
    }

    func testSetCustomValue_postsArgusKeyStoreDidUpdateNotification() {
        let expectation = XCTNSNotificationExpectation(
            name: .argusKeyStoreDidUpdate,
            object: nil,
            notificationCenter: .default
        )
        APIKeyStore.shared.setCustomValue("payload", for: customStorageKey)
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Static accessor

    func testGetDirectKey_routesToSharedInstance() {
        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-direct")
        XCTAssertEqual(APIKeyStore.getDirectKey(for: testProvider), "sk-live-direct")
    }

    func testGetDirectKey_returnsNilWhenAbsent() {
        APIKeyStore.shared.deleteKey(provider: testProvider)
        XCTAssertNil(APIKeyStore.getDirectKey(for: testProvider))
    }

    // MARK: - Published `keys` dictionary state

    /// SwiftUI binding sözleşmesi: `@Published keys` setKey ile dolu, deleteKey
    /// ile boş kalır. Placeholder yazımı keys'e konur (raw storage) ama
    /// getKey filtresi nil döner; bu davranış değişirse UI logic kırılır.
    func testKeysDictionary_reflectsSetAndDelete() {
        XCTAssertNil(APIKeyStore.shared.keys[testProvider])

        APIKeyStore.shared.setKey(provider: testProvider, key: "sk-live-state")
        XCTAssertEqual(APIKeyStore.shared.keys[testProvider], "sk-live-state")

        APIKeyStore.shared.deleteKey(provider: testProvider)
        XCTAssertNil(APIKeyStore.shared.keys[testProvider])
    }
}
