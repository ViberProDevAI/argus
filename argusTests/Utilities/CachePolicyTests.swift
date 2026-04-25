import XCTest
@testable import argus

final class CachePolicyTests: XCTestCase {

    // MARK: - CacheTTL

    func testIsExpired_nilTimestamp_returnsTrue() {
        XCTAssertTrue(CacheTTL.isExpired(timestamp: nil, ttl: 60))
    }

    func testIsExpired_recentTimestamp_returnsFalse() {
        let recent = Date()
        XCTAssertFalse(CacheTTL.isExpired(timestamp: recent, ttl: 60))
    }

    func testIsExpired_oldTimestamp_returnsTrue() {
        let old = Date().addingTimeInterval(-120)
        XCTAssertTrue(CacheTTL.isExpired(timestamp: old, ttl: 60))
    }

    func testToMilliseconds() {
        XCTAssertEqual(CacheTTL.toMilliseconds(1.5), 1500)
        XCTAssertEqual(CacheTTL.toMilliseconds(0), 0)
    }

    // MARK: - CacheEntry

    func testCacheEntry_freshEntry_isNotExpired() {
        let entry = CacheEntry(value: "test", ttl: 60)
        XCTAssertFalse(entry.isExpired)
        XCTAssertGreaterThan(entry.timeRemaining, 59)
    }

    // MARK: - MemoryCacheStore

    @MainActor
    func testMemoryCacheStore_setAndGet() {
        let store = MemoryCacheStore<String, Int>()
        store.set("key1", value: 42, ttl: 60)
        XCTAssertEqual(store.get("key1"), 42)
        XCTAssertEqual(store.count, 1)
    }

    @MainActor
    func testMemoryCacheStore_invalidate() {
        let store = MemoryCacheStore<String, Int>()
        store.set("key1", value: 42, ttl: 60)
        store.invalidate("key1")
        XCTAssertNil(store.get("key1"))
        XCTAssertEqual(store.count, 0)
    }

    @MainActor
    func testMemoryCacheStore_invalidateAll() {
        let store = MemoryCacheStore<String, Int>()
        store.set("a", value: 1, ttl: 60)
        store.set("b", value: 2, ttl: 60)
        store.invalidateAll()
        XCTAssertEqual(store.count, 0)
    }

    @MainActor
    func testMemoryCacheStore_expiredEntryReturnsNil() {
        let store = MemoryCacheStore<String, Int>()
        store.set("old", value: 99, ttl: 0) // TTL = 0 → immediately expired
        XCTAssertNil(store.get("old"))
    }
}
