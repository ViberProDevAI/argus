import Foundation

/// Rich Error type for Heimdall
public struct HeimdallCoreError: LocalizedError, Sendable {
    public let category: FailureCategory
    public let code: Int
    public let message: String
    public let bodyPrefix: String
    
    public init(category: FailureCategory, code: Int, message: String, bodyPrefix: String) {
        self.category = category
        self.code = code
        self.message = message
        self.bodyPrefix = bodyPrefix
    }
    
    public var errorDescription: String? {
        return "\(category.rawValue): \(message) [HTTP \(code)] Body: \(bodyPrefix)"
    }
}
