import Foundation
import SwiftUI

protocol DependencyKey {
    associatedtype Value
    static var currentValue: Value { get set }
}

struct DependencyValues {
    private var storage: [ObjectIdentifier: Any] = [:]
    
    subscript<K: DependencyKey>(key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            return K.currentValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

private struct DependencyValuesKey: EnvironmentKey {
    static let defaultValue = DependencyValues()
}

extension EnvironmentValues {
    var dependencies: DependencyValues {
        get { self[DependencyValuesKey.self] }
        set { self[DependencyValuesKey.self] = newValue }
    }
}

extension DependencyValues {
    static var live: DependencyValues {
        var values = DependencyValues()
        return values
    }
    
    static var preview: DependencyValues {
        var values = DependencyValues()
        return values
    }
    
    static var test: DependencyValues {
        var values = DependencyValues()
        return values
    }
}

@propertyWrapper
struct Dependency<K: DependencyKey>: DynamicProperty {
    @Environment(\.dependencies) var dependencies
    
    var wrappedValue: K.Value {
        dependencies[K.self]
    }
}
