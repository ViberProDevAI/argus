import Foundation

/// Root Container for the Debug Export
struct DebugBundle: Codable {
    let header: BundleHeader
    let health: [EngineTag: EngineHealthSnapshot]
    let keys: [APIKeyMetadata] // New: Key Store State
    let registry: RegistryDebugInfo // New: Registry State
    let traces: [TraceEntry] // Simplified Trace
    let evidence: [ProviderTag: FailureEvidence]
    let quota: QuotaSnapshot
}

struct BundleHeader: Codable {
    let appVersion: String
    let buildNumber: String
    let timestamp: Date
    let deviceModel: String
    let systemVersion: String
    let sessionID: String
    let timezone: String
}

/// A simplified, export-safe view of a network trace
struct TraceEntry: Codable {
    let id: String
    let timestamp: Date
    let engine: String
    let provider: String
    let symbol: String
    let assetType: String?
    let endpoint: String // Masked URL
    let latency: Double
    let success: Bool
    let status: Int?
    let failureCategory: String?
}

/// Critical: Evidence of why a request failed
/// Stores the raw (masked) response body to debug "Decode Errors" and "Unknowns"
struct FailureEvidence: Codable, Sendable {
    let timestamp: Date
    let provider: String
    let symbol: String
    let url: String // Masked
    let httpStatus: Int
    let contentType: String?
    let bodyPrefix: String // First 300 chars, masked
    let errorDetails: String // "DecodingError: key not found 'data'..."
}

struct QuotaSnapshot: Codable {
    let providers: [String: ProviderQuotaStatus]
}

struct ProviderQuotaStatus: Codable {
    let attempted: Int
    let success: Int // equivalent to 'used'
    let failed: Int
    let limit: Int
    let remaining: Int
    let isExhausted: Bool
    
    // Backward compatibility helper (if needed by UI)
    var used: Int { success }
}

// MARK: - Masking Helpers
enum DebugMasker {
    static func maskURL(_ urlString: String) -> String {
        // Simple regex to mask apikey/token params
        // e.g. ?apikey=123 -> ?apikey=***
        // e.g. /token/123 -> /token/***
        
        var masked = urlString
        let patterns = [
            "apikey=([^&]+)",
            "token=([^&]+)",
            "key=([^&]+)",
            "auth=([^&]+)"
        ]
        
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: .caseInsensitive) {
                masked = regex.stringByReplacingMatches(
                    in: masked,
                    range: NSRange(masked.startIndex..., in: masked),
                    withTemplate: "$1=***"
                )
            }
        }
        return masked
    }
    
    static func scrubBody(_ body: String) -> String {
        // If content looks like HTML, return "HTML Payload (Len: X)"
        if body.lowercased().contains("<!doctype html") || body.lowercased().contains("<html") {
            return "[HTML Page Received - Likely Proxy/Error Page]"
        }
        if body.count > 500 {
            return String(body.prefix(500)) + "... (truncated)"
        }
        return body
    }
}

struct RegistryDebugInfo: Codable {
    let authorized: [String]
    let states: [String: String]
}
