import Foundation

/// "The Capability Sentry" v2
/// Uses HeimdallCapabilityMatrix for static capabilities,
/// and manages dynamic Quarantine states (Circuit Breaker).
actor ProviderCapabilityRegistry {
    static let shared = ProviderCapabilityRegistry()
    
    // Persistence
    private let cacheKey = "heimdall_registry_v2_quarantine"
    
    // Durable State
    private var quarantines: [String: QuarantineInfo] = [:]
    private var authorizedProviders: Set<String> = [] // Pushed from APIKeyStore
    private var providerModes: [String: String] = [:] // Configured by Probe (e.g. FMP -> DAILY_ONLY)
    
    // Config - Providers that don't require authorization check (always available)
    private let keylessProviders: Set<String> = ["Yahoo", "LocalScanner", "CoinGecko", "Yahoo Finance", "EODHD", "TwelveData"]
    
    // MARK: - Lifecycle
    
    private init() {
        // DEBUG: Verify keylessProviders contains TwelveData
        print("🔧 ProviderCapabilityRegistry: keylessProviders = \(keylessProviders)")
        Task { await load() }
    }
    
    // MARK: - Mode
    
    func setMode(_ provider: String, mode: String) {
        providerModes[provider] = mode
        print("🛡️ Registry: \(provider) set to mode \(mode)")
    }
    
    func getMode(_ provider: String) -> String? {
        return providerModes[provider]
    }
    
    // MARK: - Query
    
    func getCandidates(for field: HeimdallDataField, assetType: AssetType) async -> [String] {
        // 1. Get Static Candidates from Matrix
        // Accessing potentially MainActor isolated matrix
        let candidateTags = await MainActor.run { HeimdallCapabilityMatrix.shared.getCandidates(for: field, assetType: assetType) }
        
        var available: [String] = []
        
        for tag in candidateTags {
            let providerName = tag.rawValue
            
            // 2. Permanent Matrix Quarantine Check
            // Also requires MainActor if shared is isolated
            let isPerm = await MainActor.run { 
                HeimdallCapabilityMatrix.shared.getProfile(for: tag)?.isPermanentlyQuarantined ?? false 
            }
            
            if isPerm {
                // print("🚫 Registry: Skipped \(providerName) (Permanent Quarantine)")
                continue
            }
            
            // 3. Authorization Check
            if !keylessProviders.contains(providerName) && !authorizedProviders.contains(providerName) {
                // print("🚫 Registry: Skipped \(providerName) (Auth Missing)")
                continue
            }
            
            // 4. Dynamic Quarantine Check
            if isQuarantined(provider: providerName, field: field) {
                // print("🚫 Registry: Skipped \(providerName) (Circuit Breaker Active)")
                continue
            }
            
            available.append(providerName)
        }
        
        return available
    }
    
    func isQuarantined(provider: String, field: HeimdallDataField) -> Bool {
        let key = key(provider, field)
        
        if let q = quarantines[key] {
            if Date() < q.expiry {
                return true // Still quarantined
            } else {
                // Expired
                quarantines.removeValue(forKey: key)
                return false
            }
        }
        
        // Also check "Whole Provider" quarantine (key without field?)
        // For simplicity, we ban per endpoint-provider pair, or use a special "ALL" field key.
        let providerAllKey = "\(provider)_ALL"
        if let q = quarantines[providerAllKey] {
            if Date() < q.expiry { return true }
            else { quarantines.removeValue(forKey: providerAllKey) }
        }
        
        return false
    }
    
    // MARK: - Circuit Breaker Logic
    
    func reportCriticalFailure(provider: String, field: HeimdallDataField, error: Error) async {
        let key = self.key(provider, field)
        
        // Default: 5 min cooldown
        var duration: TimeInterval = 300
        var reason = "Unknown"
        var scope: QuarantineScope = .endpoint
        
        if let hErr = error as? HeimdallCoreError {
            switch hErr.category {
            case .entitlementDenied: // 403 Legacy/Plan
                duration = 900 // 15 Min (User Rule: Registry lock TTL = 900s)
                reason = "Entitlement Denied (Legacy/Plan)"
                scope = .endpoint // Only ban this specific endpoint (e.g. 1h candles)
                
            case .authInvalid: // 401
                duration = 24 * 3600 // 1 Day
                reason = "Authentication Failed (Invalid Key)"
                
                // EXCEPTION: Yahoo Auth is Cookie/Crumb based (Transient), not Global Key
                if provider == "Yahoo" || provider == "Yahoo Finance" {
                    scope = .endpoint
                    duration = 300 // 5 Min
                    reason = "Invalid Crumb (Transient)"
                } else {
                    scope = .provider // Ban entire provider
                }
                
            case .rateLimited: // 429
                // End of Day
                let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
                duration = tomorrow.timeIntervalSinceNow
                reason = "Rate Limit Exceeded"
                scope = .provider
                
            case .serverError: // 5xx
                duration = 3600 // 1 Hour
                reason = "Server Instability"
                scope = .endpoint
                
            case .decodeError, .emptyPayload, .circuitOpen, .unknown, .symbolNotFound, .none:
                duration = 60 // 1 Min
                reason = "Transient Error"
                scope = .endpoint
                
            case .networkError:
                // User Request: Do NOT Trip Circuit Breaker for NSURLError (Connection, Offline, etc)
                // Retry logic handles this in Network layer. If it reaches here, we just log failure.
                print("⚠️ Registry: Network Error reported but Circuit Breaker ignored (Transient).")
                return
            }
        } else {
            // Unclassified Error
            duration = 60
            reason = error.localizedDescription
        }
        
        let targetKey = scope == .provider ? "\(provider)_ALL" : key
        let expiry = Date().addingTimeInterval(duration)
        
        quarantines[targetKey] = QuarantineInfo(expiry: expiry, reason: reason, failureCount: (quarantines[targetKey]?.failureCount ?? 0) + 1)
        
        print("🚫 Registry: QUARANTINE \(provider) (\(scope == .provider ? "ALL" : field.rawValue)) -> \(Int(duration))s. Reason: \(reason)")
        
        // Save state if long ban
        if duration > 300 {
            save()
        }
    }
    
    func reportSuccess(provider: String, field: HeimdallDataField) {
        let key = self.key(provider, field)
        if quarantines[key] != nil {
            quarantines.removeValue(forKey: key)
            print("✅ Registry: RESTORED \(provider) (\(field.rawValue))")
        }
    }
    
    func resetBans() {
        self.quarantines.removeAll()
        print("✅ Registry: ALL bans manually reset.")
        save()
    }
    
    func resetLocks(for provider: String) {
        // Resets both specific endpoint bans (Provider_Field) AND "ALL" bans (Provider_ALL)
        let prefix = "\(provider)_"
        let allKey = "\(provider)_ALL"
        
        let keysToRemove = quarantines.keys.filter { 
            $0.hasPrefix(prefix) || $0 == allKey || $0 == provider // Handle strict matches too
        }
        
        for key in keysToRemove {
            quarantines.removeValue(forKey: key)
        }
        
        print("🔓 Registry: UNLOCKED \(provider). All circuit breakers reset.")
        save()
    }
    
    // MARK: - Helpers
    
    private func key(_ provider: String, _ field: HeimdallDataField) -> String {
        return "\(provider)_\(field.rawValue)"
    }
    
    enum QuarantineScope { case endpoint, provider }
    
    // MARK: - Authorization Sync
    func updateAuthorizedProviders(_ providers: Set<String>) {
        self.authorizedProviders = providers
    }
    
    func getAuthorizedProviders() -> Set<String> {
        return authorizedProviders
    }
    
    // MARK: - Introspection
    
    func getQuarantineStatus() -> [String: String] {
        var status: [String: String] = [:]
        for (k, v) in quarantines {
            let remaining = Int(v.expiry.timeIntervalSinceNow)
            if remaining > 0 {
                status[k] = "Locked (\(remaining)s): \(v.reason)"
            }
        }
        return status
    }
    
    // Compatibility for Debug Bundle
    func getEndpointStates() -> [String: String] {
        return getQuarantineStatus()
    }
    
    // MARK: - Persistence
    
    private func save() {
        let snapshot = RegistrySnapshotV2(quarantines: quarantines)
        Task { @MainActor in
            DiskCacheService.shared.save(key: self.cacheKey, data: snapshot, harvest: false)
        }
    }
    
    private func load() async {
        let snap: RegistrySnapshotV2? = await MainActor.run {
            DiskCacheService.shared.get(key: cacheKey, type: RegistrySnapshotV2.self, maxAge: 86400 * 30)
        }
        
        if let snap = snap {
            // Filter expired
            var valid = snap.quarantines.filter { $0.value.expiry > Date() }
            
            // EMERGENCY FIX: Auto-Unban FMP/Yahoo to allow retries
            valid.removeValue(forKey: "FMP_ALL")
            valid.removeValue(forKey: "Yahoo_ALL")
            
            self.quarantines = valid
            print("🛡️ Registry: Loaded \(valid.count) Active Quarantines (FMP Force-Unlocked)")
        }
    }
}

// Support Types

struct QuarantineInfo: Codable, Sendable {
    let expiry: Date
    let reason: String
    let failureCount: Int
}

struct RegistrySnapshotV2: Codable {
    let quarantines: [String: QuarantineInfo]
}
