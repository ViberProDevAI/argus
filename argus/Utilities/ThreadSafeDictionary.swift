import Foundation

/// Thread-safe dictionary wrapper for concurrent access
/// Kullanım: Race condition'ları önlemek için @Published dictionary'ler yerine kullanılır
@propertyWrapper
final class ThreadSafe<T> {
    private var value: T
    private let lock = NSLock()
    
    init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    var wrappedValue: T {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
    
    /// Atomic update with closure
    func update(_ transform: (inout T) -> Void) {
        lock.withLock {
            transform(&value)
        }
    }
}

/// Thread-safe dictionary with convenient subscript access
final class ThreadSafeDictionary<Key: Hashable, Value>: @unchecked Sendable {
    private var dictionary: [Key: Value] = [:]
    private let lock = NSLock()
    
    init(_ initial: [Key: Value] = [:]) {
        self.dictionary = initial
    }
    
    subscript(key: Key) -> Value? {
        get { lock.withLock { dictionary[key] } }
        set { lock.withLock { dictionary[key] = newValue } }
    }
    
    var keys: [Key] {
        lock.withLock { Array(dictionary.keys) }
    }
    
    var values: [Value] {
        lock.withLock { Array(dictionary.values) }
    }
    
    var count: Int {
        lock.withLock { dictionary.count }
    }
    
    func removeAll() {
        lock.withLock { dictionary.removeAll() }
    }
    
    func update(_ transform: (inout [Key: Value]) -> Void) {
        lock.withLock { transform(&dictionary) }
    }
    
    /// Snapshot for iteration (avoids holding lock during iteration)
    func snapshot() -> [Key: Value] {
        lock.withLock { dictionary }
    }
}
