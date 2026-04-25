import Foundation

// MARK: - Heimdall 5.0 Core Models

/// Where did this data come from?
public struct DataProvenance: Codable, Sendable {
    public let source: String            // "Yahoo", "FRED", "Mimir", "Cache"
    public let fetchedAt: Date
    public let confidence: Double        // 0.0 - 1.0 (Low -> High)
    public let evidence: String?         // URL or Explanation
    public let isEstimate: Bool          // True if Mimir inferred it
    
    public init(source: String, fetchedAt: Date, confidence: Double, evidence: String? = nil, isEstimate: Bool = false) {
        self.source = source
        self.fetchedAt = fetchedAt
        self.confidence = confidence
        self.evidence = evidence
        self.isEstimate = isEstimate
    }
    
    public static var missing: DataProvenance {
        DataProvenance(source: "None", fetchedAt: Date(), confidence: 0.0)
    }
    
    // Helpers
    public var isFresh: Bool {
        return -fetchedAt.timeIntervalSinceNow < 15
    }
}

/// The Universal Data Envelope
/// Replaces raw T returns, allowing Partial Data and Metadata flow.
/// Conforms to Codable if T is Codable


/// Represents a specific missing data point for Mimir to hunt
public struct MissingField: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let symbol: String
    public let fieldKey: String         // e.g. "TotalDebt", "CEO"
    public let detectedAt: Date
    public let context: String?
    
    public init(symbol: String, fieldKey: String, context: String? = nil) {
        self.symbol = symbol
        self.fieldKey = fieldKey
        self.detectedAt = Date()
        self.context = context
    }
}
