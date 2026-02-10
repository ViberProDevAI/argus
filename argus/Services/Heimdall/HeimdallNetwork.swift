import Foundation

/// Centralized Networking Layer for Heimdall Providers
/// Enforces observability, error categorization, and body logging for all API traffic.
enum HeimdallNetwork {
    
    /// Performs a network request with full Heimdall Telepresence tracing.
    static func request(
        url: URL,
        engine: EngineTag,
        provider: ProviderTag,
        symbol: String,
        explicitRequest: URLRequest? = nil, // Added for Yahoo Auth injections
        timeout: TimeInterval = 25.0
    ) async throws -> Data {
        
        // 1. Trace Start
        // We use 'trace' extension but since we want to capture body/status specifically, 
        // we might do manual recording inside or rely on the extension catching errors.
        // Let's use the extension but enhance it by throwing rich errors.
        
        return try await HeimdallTelepresence.shared.trace(
            engine: engine,
            provider: provider,
            symbol: symbol,
            canonicalAsset: nil,
            endpoint: url.path
        ) {
            
            var request: URLRequest
            if let explicit = explicitRequest {
                request = explicit
                // Ensure timeout matches (override explicit or keep it? explicit wins usually, but let's respect param)
                request.timeoutInterval = timeout
            } else {
                request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
            }
            
            // Common Headers (Merge if needed, specific headers should already be in explicitRequest)
            if request.value(forHTTPHeaderField: "User-Agent") == nil {
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            }
            
            // RETRY LOGIC (Max 3 attempts for transient errors)
            var attempt = 0
            let maxAttempts = 3
            var lastError: Error?
            
            while attempt < maxAttempts {
                attempt += 1
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResp = response as? HTTPURLResponse else {
                         throw URLError(.badServerResponse)
                    }
                    
                    // Capture Body Prefix for Analysis
                    let bodyPrefix = String(data: data.prefix(300), encoding: .utf8)?.replacingOccurrences(of: "\n", with: " ") ?? "Bin/Empty"
                    let bodyLower = bodyPrefix.lowercased()
                    
                    // Status Code Analysis
                    switch httpResp.statusCode {
                    case 200...299:
                        // Success (Technically). Check for Soft Errors
                        if data.isEmpty {
                            throw HeimdallCoreError(category: .emptyPayload, code: httpResp.statusCode, message: "Empty Body", bodyPrefix: bodyPrefix)
                        }
                        if bodyPrefix.contains("Error Message") || bodyPrefix.contains("\"code\": 429") || bodyPrefix.contains("exceeded your daily API") {
                             throw HeimdallCoreError(category: .rateLimited, code: 429, message: "API Error in 200 OK", bodyPrefix: bodyPrefix)
                        }
                        if bodyLower.contains("1013") && (bodyLower.contains("rate") || bodyLower.contains("try again later")) {
                            throw HeimdallCoreError(category: .rateLimited, code: 1013, message: "Provider Rate Limited (1013)", bodyPrefix: bodyPrefix)
                        }
                        return data
                        
                    case 401:
                        throw HeimdallCoreError(category: .authInvalid, code: httpResp.statusCode, message: "Unauthorized", bodyPrefix: bodyPrefix)
                    case 403:
                         let lower = bodyPrefix.lowercased()
                         if lower.contains("legacy") || lower.contains("upgrade") || lower.contains("plan") {
                             throw HeimdallCoreError(category: .entitlementDenied, code: 403, message: "Entitlement Denied", bodyPrefix: bodyPrefix)
                         }
                         throw HeimdallCoreError(category: .authInvalid, code: 403, message: "Forbidden", bodyPrefix: bodyPrefix)
                    case 404:
                        throw HeimdallCoreError(category: .symbolNotFound, code: 404, message: "Not Found", bodyPrefix: bodyPrefix)
                    case 429:
                        throw HeimdallCoreError(category: .rateLimited, code: 429, message: "Rate Limit Exceeded", bodyPrefix: bodyPrefix)
                    case 500...599:
                        if bodyLower.contains("1013") && (bodyLower.contains("rate") || bodyLower.contains("try again later")) {
                            throw HeimdallCoreError(category: .rateLimited, code: 1013, message: "Provider Rate Limited (1013)", bodyPrefix: bodyPrefix)
                        }
                        throw HeimdallCoreError(category: .serverError, code: httpResp.statusCode, message: "Server Error", bodyPrefix: bodyPrefix)
                    default:
                        throw HeimdallCoreError(category: .unknown, code: httpResp.statusCode, message: "HTTP \(httpResp.statusCode)", bodyPrefix: bodyPrefix)
                    }
                    
                } catch {
                    lastError = error
                    
                    // Retry Decision Logic
                    let isTransient: Bool
                    
                    if let urlError = error as? URLError {
                        // -1008 (resourceUnavailable), -1009 (notConnected), -1001 (timeout), -1011 (badServerResponse sometimes if connection dropped)
                        // User specifically mentioned -1008, -1009, -1011, -1017
                        switch urlError.code {
                        case .resourceUnavailable, .notConnectedToInternet, .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                            isTransient = true
                        default:
                            isTransient = false
                        }
                    } else if let heimdallError = error as? HeimdallCoreError {
                        switch heimdallError.category {
                        case .rateLimited, .serverError, .networkError:
                            isTransient = true
                        default:
                            isTransient = false
                        }
                    } else {
                        // HeimdallCoreError is NOT transient usually (4xx, 5xx)
                        // Unless we decide 5xx is transient?
                        isTransient = false
                    }
                    
                    if isTransient && attempt < maxAttempts {
                        let delay: Double
                        if let heimdallError = error as? HeimdallCoreError, heimdallError.category == .rateLimited {
                            delay = Double(attempt) * 1.0 // 1s, 2s, 3s
                        } else {
                            delay = Double(attempt) * 0.5 // 0.5s, 1.0s, 1.5s
                        }
                        print("⏳ Network Retry (\(attempt)/\(maxAttempts)) for \(url.lastPathComponent): \(error.localizedDescription)")
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    
                    // If not retryable or max attempts, throw
                    throw error
                }
            }
            throw lastError ?? URLError(.unknown)
        }
    }
}

/// Rich Error type for Heimdall
