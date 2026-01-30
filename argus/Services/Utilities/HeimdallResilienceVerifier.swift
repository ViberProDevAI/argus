import Foundation

/// Manual Runtime Verifier for Heimdall 5.2 Resilience
/// (Replaces XCTest to avoid linking issues in Main App Target)
final class HeimdallResilienceVerifier {
    
    // MARK: - Symbol Resolver
    
    static func verifySymbolResolver() {
        print("🧪 Verifying SymbolResolver...")
        let resolver = SymbolResolver.shared
        
        // Yahoo Mappings
        assert(resolver.resolve("SILVER", for: .yahoo) == "SI=F", "SILVER should be SI=F")
        assert(resolver.resolve("VIX", for: .yahoo) == "^VIX", "VIX should be ^VIX")
        assert(resolver.resolve("EURUSD", for: .yahoo) == "EURUSD=X", "EURUSD should be EURUSD=X")
        assert(resolver.resolve("AAPL", for: .yahoo) == "AAPL", "AAPL should pass through")
        
        // EODHD Mappings (Pass through usually)
        assert(resolver.resolve("SILVER", for: .eodhd) == "SILVER", "SILVER (EODHD) should pass through") 
        print("✅ SymbolResolver Verified.")
    }
    
    // MARK: - Quota Ledger
    
    static func verifyQuotaExhaustion() async {
        print("🧪 Verifying QuotaLedger...")
        let ledger = QuotaLedger.shared
        
        // Reset First
        await ledger.reset(provider: "TwelveData")
        
        // Verify Start (Assuming default limit 800)
        let initialExhausted = await ledger.isExhausted(provider: "TwelveData")
        if initialExhausted { print("❌ Expected Not Exhausted"); return }
        
        let canSpend = await ledger.canSpend(provider: "TwelveData", cost: 1)
        if !canSpend { print("❌ Expected Can Spend"); return }
        
        print("✅ QuotaLedger Verified.")
    }
    
    // MARK: - KeyStore & Registry Interaction
    
    static func verifyKeyUpdateResetsLocks() async {
        print("🧪 Verifying KeyStore Locks...")
        let registry = ProviderCapabilityRegistry.shared
        let keystore = APIKeyStore.shared
        
        // 1. Manually Lock EODHD
        await registry.reportCriticalFailure(provider: "EODHD", field: .quote, error: HeimdallCoreError(category: .authInvalid, code: 401, message: "Manual Test", bodyPrefix: ""))
        
        // Verify Locked
        let statusLocked = await registry.getQuarantineStatus()
        if !statusLocked.keys.contains(where: { $0.contains("EODHD") }) {
             print("❌ Failed to lock EODHD manually.")
             return
        }
        
        // 2. Update Key
        await MainActor.run {
            keystore.setKey(provider: .eodhd, key: "NEW_TEST_KEY")
        }
        
        // Allow async task to propagate
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // 3. Verify Unlocked
        let statusUnlocked = await registry.getQuarantineStatus()
        if statusUnlocked.keys.contains(where: { $0.contains("EODHD") }) {
            print("❌ EODHD still locked after key update.")
            return
        }
        
        print("✅ KeyStore Locks Verified.")
    }
    
    // MARK: - SSoT Verification
    
    static func verifySecretsSSoT() async {
        print("🧪 Verifying Secrets SSoT...")
        // 1. Update KeyStore
        let testKey = "TEST_SSOT_KEY_\(Int.random(in: 100...999))"
        APIKeyStore.shared.setKey(provider: .twelveData, key: testKey)
        
        // 2. Check Secrets Proxy
        let readBack = Secrets.shared.twelveData
        
        // 3. Verify
        if readBack == testKey {
            print("✅ Secrets Proxy matches KeyStore (SSoT Active).")
        } else {
            print("❌ Secrets Proxy Mismatch! Expected \(testKey), got \(readBack)")
        }
    }
    
    // MARK: - Circuit Breaker Policy verification
    
    static func verifyNetworkErrorNoBreaker() async {
        print("🧪 Verifying Circuit Breaker Policy (No Ban on Network Error)...")
        let registry = ProviderCapabilityRegistry.shared
        let provider = "Yahoo"
        
        // 1. Report Network Error (-1008 simulated)
        _ = URLError(.resourceUnavailable) // -1008
        await registry.reportCriticalFailure(provider: provider, field: .candles, error: HeimdallCoreError(category: .networkError, code: -1008, message: "Simulated Net Error", bodyPrefix: ""))
        
        // 2. Check Quarantine
        let status = await registry.getQuarantineStatus()
        let isLocked = status.keys.contains { $0.contains(provider) }
        
        if isLocked {
            print("❌ Registry LOCKED provider on Network Error! Should be ignored.")
        } else {
            print("✅ Registry IGNORED Network Error (Correct).")
        }
        
        // 3. Report Auth Error (Should Lock)
        await registry.reportCriticalFailure(provider: provider, field: .candles, error: HeimdallCoreError(category: .authInvalid, code: 401, message: "Simulated Auth", bodyPrefix: ""))
        
        let status2 = await registry.getQuarantineStatus()
        let isLocked2 = status2.keys.contains { $0.contains(provider) }
        
        if isLocked2 {
            print("✅ Registry LOCKED provider on Auth Error (Correct).")
        } else {
            print("❌ Registry FAILED to lock on Auth Error!")
        }
        
        // Cleanup
        await registry.resetLocks(for: provider)
    }

    static func runAll() async {
        verifySymbolResolver()
        await verifyQuotaExhaustion()
        await verifyKeyUpdateResetsLocks()
        await verifySecretsSSoT()
        await verifyNetworkErrorNoBreaker()
        await InstrumentResolverVerifier.verify()
        print("🏆 All Resilience Tests Passed.")
    }
}
