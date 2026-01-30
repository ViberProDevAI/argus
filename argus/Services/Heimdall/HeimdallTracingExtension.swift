import Foundation

extension HeimdallTelepresence {
    
    /// Traces an asynchronous operation block automatically.
    /// - Parameters:
    ///   - engine: The Heimdall engine (Context)
    ///   - provider: The provider attempted
    ///   - symbol: The target symbol
    ///   - operation: The async throwing closure to execute
    /// - Returns: The result of the operation
    /// - Throws: The error thrown by operation, wrapped with trace logging.
    func trace<T>(
        engine: EngineTag,
        provider: ProviderTag,
        symbol: String,
        canonicalAsset: CanonicalInstrument? = nil,
        endpoint: String = "",
        operation: () async throws -> T
    ) async throws -> T {
        
        let start = Date()
        var trace = RequestTraceEvent.start(engine: engine, provider: provider, endpoint: endpoint, symbol: symbol, canonicalAsset: canonicalAsset)
        
        // 0. Quota Check (Attempt Record)
        await QuotaLedger.shared.recordAttempt(provider: provider.rawValue)
        
        do {
            let result = try await operation()
            
            // Ledger Success
            await QuotaLedger.shared.recordSuccess(provider: provider.rawValue)
            
            let duration = Date().timeIntervalSince(start)
            let bytes = (result as? Data)?.count ?? 0
            
            trace = trace.completed(success: true, duration: duration, code: 200, bytes: bytes)
            self.record(trace: trace) // Sync call within actor
            
            return result
        } catch {
            // Ledger Failure
            await QuotaLedger.shared.recordFailure(provider: provider.rawValue)
            
            let duration = Date().timeIntervalSince(start)
            
            let nsError = error as NSError
            let domain = nsError.domain
            let code = nsError.code
            let failingURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL)?.absoluteString ?? (nsError.userInfo["NSURLErrorFailingURLStringErrorKey"] as? String)
            
            let classification = HeimdallErrorClassifier.classify(error, provider: provider, endpoint: endpoint)
            
            // Extract Body if available (specifically from HeimdallError)
            let body = (error as? HeimdallCoreError)?.bodyPrefix
            
            trace = trace.completed(
                success: false,
                duration: duration,
                code: classification.code ?? code,
                bytes: 0,
                error: classification.reason,
                category: classification.category,
                body: body,
                failingURL: failingURL,
                errorDomain: domain,
                errorCode: code
            )
            
            // Check for Capability Verification (Circuit Breaker Trigger)
            if classification.isCapabilityLock {
                print("🔒 Heimdall: Capability Lock Detected for \(provider.rawValue) on endpoint \(endpoint)")
                // Trace only; The Orchestrator is responsible for triggering the registry lock via reportCriticalFailure.
            }
            
            // Create Evidence if available
            var evidence: FailureEvidence? = nil
            if let body = body {
                let maskedUrl = await MainActor.run { DebugMasker.maskURL(endpoint) }
                let scrubbedBody = await MainActor.run { DebugMasker.scrubBody(body) }
                
                evidence = FailureEvidence(
                    timestamp: Date(),
                    provider: provider.rawValue,
                    symbol: symbol,
                    url: maskedUrl,
                    httpStatus: classification.code ?? 0,
                    contentType: nil,
                    bodyPrefix: scrubbedBody,
                    errorDetails: classification.reason
                )
            }
            
            self.record(trace: trace, evidence: evidence)
            
            throw error
        }
    }
}
