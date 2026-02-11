import Foundation
import UIKit

/// Exports the Debug Bundle
actor HeimdallDebugBundleExporter {
    static let shared = HeimdallDebugBundleExporter()
    
    // This initializer is guaranteed not to throw or fail.
    private init() {}
    
    func generateBundle() async -> String {
        // 1. Gather Data
        let telepresence = HeimdallTelepresence.shared
        
        // Actor calls must be awaited in Swift 6
        let traces = await telepresence.getTraces()
        let health = await telepresence.getEngineHealth()
        
        // 2. Build Header
        // MainActor properties accessed here require MainActor context or isolation
        let header = await MainActor.run {
            BundleHeader(
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                timestamp: Date(),
                deviceModel: UIDevice.current.model,
                systemVersion: UIDevice.current.systemVersion,
                sessionID: UUID().uuidString,
                timezone: TimeZone.current.identifier
            )
        }
        
        // 3. Format Traces
        // DebugMasker might be MainActor. Perform masking in MainActor block or make it non-isolated.
        // To be safe, let's map traces.
        // Also fix uuidString access if needed.
        let traceEntries = await MainActor.run {
            traces.prefix(300).map { t in
                TraceEntry(
                    id: t.id.uuidString,
                    timestamp: t.timestamp,
                    engine: t.engine.rawValue,
                    provider: t.provider.rawValue,
                    symbol: t.symbol,
                    assetType: t.canonicalAsset?.rawValue,
                    endpoint: DebugMasker.maskURL(t.endpoint),
                    latency: t.durationMs,
                    success: t.isSuccess,
                    status: t.httpStatusCode,
                    failureCategory: t.failureCategory.rawValue
                )
            }
        }
        
        // 4. Evidence
        let evidence = await telepresence.getFailureEvidence()
        
        // 5. Quota
        let quota = QuotaSnapshot(providers: await QuotaLedger.shared.getSnapshot())
        
        // 6. Keys (Masked)
        let keyDict = await APIKeyStore.shared.keys
        let keyList = keyDict.map { (provider, key) -> APIKeyMetadata in
            // Map APIProvider to ArgusProvider
            let argusProvider: ArgusProvider
            switch provider {
            case .twelveData: argusProvider = .twelveData
            case .alphaVantage: argusProvider = .alphaVantage
            case .eodhd: argusProvider = .eodhd
            case .fmp: argusProvider = .fmp
            case .tiingo: argusProvider = .tiingo
            case .marketstack: argusProvider = .marketStack
            case .gemini: argusProvider = .gemini
            case .glm: argusProvider = .gemini
            case .fred: argusProvider = .fred
            case .pinecone: argusProvider = .fred // Map to fred for now
            case .massive: argusProvider = .fred // Map to fred for now to avoid breaking ArgusProvider enum if it doesn't have massive yet
            case .groq: argusProvider = .gemini
            case .deepSeek: argusProvider = .gemini
            }
            
            return APIKeyMetadata(
                provider: argusProvider,
                key: key,
                isValid: !key.isEmpty && !key.contains("YOUR_") && !key.contains("PLACEHOLDER")
            )
        }.sorted { $0.provider.rawValue < $1.provider.rawValue }
        
        // 7. Registry
        let registry = await telepresence.getRegistrySnapshot()
        
        // 8. Assemble Bundle
        let bundle = DebugBundle(
            header: header,
            health: health,
            keys: keyList,
            registry: registry,
            traces: traceEntries,
            evidence: evidence,
            quota: quota
        )
        
        return renderAsText(bundle)
    }
    
    private func renderAsText(_ bundle: DebugBundle) -> String {
        var txt = ""
        let df = ISO8601DateFormatter()
        
        txt += "=== HEIMDALL DEBUG BUNDLE ===\n"
        txt += "Time: \(df.string(from: bundle.header.timestamp))\n"
        txt += "App: v\(bundle.header.appVersion) (\(bundle.header.buildNumber))\n"
        txt += "Device: \(bundle.header.deviceModel) iOS \(bundle.header.systemVersion)\n"
        txt += "Session: \(bundle.header.sessionID)\n"
        txt += "\n"
        
        txt += "--- KEY STORE (SSoT) ---\n"
        if bundle.keys.isEmpty {
            txt += "No keys registered in APIKeyStore.\n"
        } else {
            for k in bundle.keys {
                let validStr = k.isValid ? "VALID" : "INVALID"
                txt += "[\(k.provider.rawValue)] \(validStr) | Masked: \(k.maskedPreview) | LastUpd: \(df.string(from: k.lastUpdatedAt))\n"
                if let err = k.lastErrorCategory {
                     txt += "  -> Error: \(err)\n"
                }
            }
        }
        txt += "\n"
        
        txt += "--- REGISTRY SNAPSHOT ---\n"
        txt += "Authorized: \(bundle.registry.authorized.joined(separator: ", "))\n"
        if bundle.registry.states.isEmpty {
            txt += "States: All Healthy (No locks)\n"
        } else {
             for (k, v) in bundle.registry.states {
                 txt += "  \(k): \(v)\n"
             }
        }
        txt += "\n"
        
        txt += "--- HEALTH SNAPSHOT ---\n"
        for (tag, h) in bundle.health {
            let status = (h.consecutiveFailures == 0) ? "OPERATIONAL" : "FAILING (\(h.consecutiveFailures))"
            txt += "\(tag.rawValue): \(status)\n"
            if let lastFail = h.lastFailureAt {
                let cat = h.lastFailureCategory?.rawValue ?? "Unknown"
                txt += "  Last Fail: \(df.string(from: lastFail)) [\(cat)]\n"
            }
        }
        txt += "\n"
        
        txt += "--- QUOTA LEDGER ---\n"
        for (prov, q) in bundle.quota.providers {
            let status = q.isExhausted ? "EXHAUSTED" : "OK"
            txt += "\(prov): Used \(q.success)/\(q.limit) | Attempts: \(q.attempted) | Failures: \(q.failed) (\(status))\n"
        }
        txt += "\n"
        
        txt += "--- FAILURE EVIDENCE (Last Error per Provider) ---\n"
        if bundle.evidence.isEmpty {
            txt += "No failure evidence recorded.\n"
        } else {
            for (prov, ev) in bundle.evidence {
                txt += "[\(prov.rawValue)] \(ev.symbol) @ \(df.string(from: ev.timestamp))\n"
                txt += "  URL: \(ev.url)\n"
                txt += "  Status: \(ev.httpStatus)\n"
                txt += "  Error: \(ev.errorDetails)\n"
                let body = ev.bodyPrefix.replacingOccurrences(of: "\n", with: "\n  ")
                txt += "  Body Preview:\n  \(body)\n"
                txt += "\n"
            }
        }
        txt += "\n"
        
        txt += "--- TRACE LOG (Last \(bundle.traces.count)) ---\n"
        for t in bundle.traces {
            let ico = t.success ? "✅" : "❌"
            let lat = String(format: "%.0fms", t.latency)
            let asset = t.assetType ?? "N/A"
            txt += "\(ico) [\(df.string(from: t.timestamp))] \(t.engine) -> \(t.provider) (\(t.symbol)/\(asset))\n"
            txt += "    \(t.endpoint) | \(lat) | HTTP \(t.status ?? 0)\n"
            if !t.success {
                txt += "    Category: \(t.failureCategory ?? "N/A")\n"
            }
        }
        
        return txt
    }
}
