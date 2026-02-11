
import Foundation

// MARK: - Heimdall V5 Data Envelope

/// Standard Data Value wrapper that includes Provenance.
/// Replaces raw T return types to provide context (Source, Timestamp, Confidence).
public struct DataValue<T: Sendable>: Sendable {
    public let value: T?
    public let provenance: DataProvenance
    public let status: DataStatus
    
    public enum DataStatus: String, Sendable, Codable {
        case fresh = "Fresh"
        case stale = "Stale"
        case missing = "Missing"
        case estimated = "Estimated"
    }

    public init(value: T?, provenance: DataProvenance, status: DataStatus) {
        self.value = value
        self.provenance = provenance
        self.status = status
    }
    
    // Helpers
    public var isValid: Bool { return value != nil && status != .missing }
    public var isStale: Bool { status == .stale }
    public var isFresh: Bool { status == .fresh }
    public var isMissing: Bool { status == .missing }
    
    public static func fresh(_ val: T, source: String = "Heimdall") -> DataValue<T> {
        return DataValue(
            value: val,
            provenance: DataProvenance(source: source, fetchedAt: Date(), confidence: 1.0),
            status: .fresh
        )
    }
    
    public static func missing(reason: String) -> DataValue<T> {
        return DataValue(
            value: nil,
            provenance: .missing,
            status: .missing
        )
    }
}

extension DataValue: Codable where T: Codable {}
