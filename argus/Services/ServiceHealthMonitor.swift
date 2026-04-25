import Foundation
import Combine

enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case twelveData = "Twelve Data"
    case alphaVantage = "Alpha Vantage"
    case eodhd = "EODHD"
    case fmp = "FMP"
    case tiingo = "Tiingo"
    case marketstack = "MarketStack"
    case gemini = "Gemini AI"
    case glm = "GLM"
    case fred = "FRED"
    case pinecone = "Pinecone"
    case massive = "Massive" // New Options Provider
    case groq = "Groq (Llama)"
    case deepSeek = "DeepSeek"
    
    var id: String { rawValue }
}

enum ServiceStatus: String {
    case healthy = "Healthy" // Green
    case degraded = "Degraded" // Yellow
    case down = "Down / Limit Reached" // Red
    case unknown = "Unknown" // Gray
}

struct APIStatus: Identifiable {
    let id = UUID()
    let provider: APIProvider
    var status: ServiceStatus = .unknown
    var remainingQuota: Int? = nil // X-RateLimit-Remaining if available
    var totalQuota: Int? = nil
    var lastError: String? = nil
    var lastSuccess: Date? = nil
}

@MainActor
class ServiceHealthMonitor: ObservableObject {
    static let shared = ServiceHealthMonitor()
    
    @Published var providerStatuses: [APIProvider: APIStatus] = [:]
    @Published var requestLog: [String] = [] // Last 50 logs
    
    private init() {
        // Initialize default states
        for provider in APIProvider.allCases {
            providerStatuses[provider] = APIStatus(provider: provider)
        }
    }
    
    // MARK: - Updates
    
    nonisolated func reportSuccess(provider: APIProvider, headers: [AnyHashable: Any]? = nil) {
        // Capture specific headers we need as Sendable types (String/Int) or ignore the dictionary itself if it's causing Sendable issues
        // For simplicity, we just extract X-RateLimit headers here before dispatching if possible, but headers is [AnyHashable: Any]. 
        // Best approach: Don't pass the whole dictionary. Extract what we need first.
        
        // Just extract limits immediately (safe if dictionaries are copied, but Any isn't Sendable).
        // Let's create a Sendable Helper Struct
        var extractedRemaining: Int? = nil
        var extractedTotal: Int? = nil
             
        if let h = headers {
             func val(_ k: String) -> Int? {
                if let v = h[k] as? String { return Int(v) }
                if let v = h[k] as? Int { return v }
                return nil
             }
             extractedRemaining = val("x-ratelimit-remaining") ?? val("X-RateLimit-Remaining")
             extractedTotal = val("x-ratelimit-limit") ?? val("X-RateLimit-Limit")
        }
        
        // Capture specific values to avoid capturing var refs or the dictionary
        let remaining = extractedRemaining
        let total = extractedTotal
        
        Task { @MainActor in
            var current = providerStatuses[provider] ?? APIStatus(provider: provider)
            current.status = .healthy
            
            // Note: Date() inside Task might slightly differ from call time, but acceptable for monitoring
            current.lastSuccess = Date()
            current.lastError = nil
            
            if let r = remaining { current.remainingQuota = r }
            if let t = total { current.totalQuota = t }
            
            providerStatuses[provider] = current
            log("✅ \(provider.rawValue): Success")
        }
    }
    
    nonisolated func reportError(provider: APIProvider, error: Error, isQuotaRelated: Bool = false) {
        Task { @MainActor in
            var current = providerStatuses[provider] ?? APIStatus(provider: provider)
            current.status = isQuotaRelated ? .down : .degraded
            current.lastError = error.localizedDescription
            
            if isQuotaRelated {
                current.remainingQuota = 0
            }
            
            providerStatuses[provider] = current
            log("❌ \(provider.rawValue): \(isQuotaRelated ? "Quota Exceeded" : "Error") - \(error.localizedDescription)")
        }
    }
    
    private func parseHeaders(_ headers: [AnyHashable: Any], for provider: APIProvider, into status: inout APIStatus) {
        // Helper to find key case-insensitively
        func headerValue(_ key: String) -> Int? {
            let lowerKey = key.lowercased()
            for (k, v) in headers {
                if let kStr = k as? String, kStr.lowercased() == lowerKey,
                   let vStr = v as? String, let val = Int(vStr) {
                    return val
                } else if let kStr = k as? String, kStr.lowercased() == lowerKey,
                          let vInt = v as? Int {
                    return vInt
                }
            }
            return nil
        }
        
        if let remaining = headerValue("x-ratelimit-remaining") {
            status.remainingQuota = remaining
        }
        if let limit = headerValue("x-ratelimit-limit") {
            status.totalQuota = limit
        }
    }
    
    private func log(_ message: String) {
        // This is already on MainActor since it's called from inside Task { @MainActor }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        requestLog.append(logEntry)
        if requestLog.count > 50 {
            requestLog.removeFirst()
        }
    }
}
