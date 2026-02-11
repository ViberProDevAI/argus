import Foundation

/// "The Diagnostician"
/// Deterministically examines errors to determine their root cause, category, and whether they are transient or permanent.
struct HeimdallErrorClassifier {
    
    struct Classification {
        let category: FailureCategory
        let code: Int?
        let reason: String
        let isTransient: Bool // Should we retry?
        let requiresCooldown: Bool // Should we back off?
        let isCapabilityLock: Bool // Is this a permanent feature breakage (e.g. 403 Legacy)?
    }
    
    nonisolated static func classify(_ error: Error, provider: ProviderTag, endpoint: String) -> Classification {
        let nsError = error as NSError
        let domain = nsError.domain
        let code = nsError.code
        
        // 1. Existing Heimdall Error (Trust it)
        if let hErr = error as? HeimdallCoreError {
            return Classification(
                category: hErr.category,
                code: hErr.code,
                reason: hErr.bodyPrefix,
                isTransient: isTransient(hErr.category),
                requiresCooldown: hErr.category == .rateLimited || hErr.category == .serverError,
                isCapabilityLock: hErr.category == .entitlementDenied
            )
        }
        
        // 2. Decode Errors
        if error is DecodingError {
            return Classification(category: .decodeError, code: -1, reason: "JSON Mismatch", isTransient: false, requiresCooldown: false, isCapabilityLock: false)
        }
        
        // 3. HTTP Codes (via URLError or other)
        
        if code == 429 {
            return Classification(category: .rateLimited, code: 429, reason: "Quota Exceeded", isTransient: true, requiresCooldown: true, isCapabilityLock: false)
        }
        
        if code == 1013 {
            return Classification(category: .rateLimited, code: 1013, reason: "Provider Rate Limited (1013)", isTransient: true, requiresCooldown: true, isCapabilityLock: false)
        }
        
        if code == 401 {
             return Classification(category: .authInvalid, code: 401, reason: "Invalid Key", isTransient: false, requiresCooldown: false, isCapabilityLock: true)
        }
        
        if code == 403 {
            // Text Analysis for "Entitlement" vs "Auth"
            let text = error.localizedDescription.lowercased()
            if text.contains("legacy") || text.contains("upgrade") || text.contains("plan") || text.contains("subscription") {
                 return Classification(category: .entitlementDenied, code: 403, reason: "Legacy/Plan Limit", isTransient: false, requiresCooldown: false, isCapabilityLock: true)
            }
            return Classification(category: .authInvalid, code: 403, reason: "Forbidden (Auth)", isTransient: false, requiresCooldown: false, isCapabilityLock: true)
        }
        
        if code >= 500 && code < 600 {
            return Classification(category: .serverError, code: code, reason: "Server Error", isTransient: true, requiresCooldown: true, isCapabilityLock: false)
        }
        
        if code == 404 {
            return Classification(category: .symbolNotFound, code: 404, reason: "Not Found", isTransient: false, requiresCooldown: false, isCapabilityLock: false)
        }
        
        // 4. Network
        if domain == NSURLErrorDomain {
            switch code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed, NSURLErrorTimedOut:
                 return Classification(category: .networkError, code: code, reason: "Network/Timeout", isTransient: true, requiresCooldown: true, isCapabilityLock: false)
            default:
                 return Classification(category: .networkError, code: code, reason: "Network Error", isTransient: true, requiresCooldown: false, isCapabilityLock: false)
            }
        }
        
        return Classification(category: .unknown, code: code, reason: error.localizedDescription, isTransient: true, requiresCooldown: false, isCapabilityLock: false)
    }
    
    private nonisolated static func isTransient(_ category: FailureCategory) -> Bool {
        switch category {
        case .rateLimited, .networkError, .serverError, .unknown, .emptyPayload:
            return true
        default:
            return false
        }
    }
}
