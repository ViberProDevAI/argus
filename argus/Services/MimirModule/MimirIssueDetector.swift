import Foundation
import SwiftUI

// MARK: - Models

struct MimirIssue: Identifiable, Sendable {
    let id = UUID()
    let engine: EngineTag
    let asset: String
    let status: String // "STALE", "MISSING", "ERROR"
    let confidence: Double // 0-1 (Impact severity)
    let description: String
    let detectedAt: Date
}

struct DataInstruction: Codable, Sendable {
    let id: String
    let targetProvider: String
    let endpoint: String
    let method: String // GET/POST
    let validationRegex: String?
    let requiredFields: [String]
    
    // Hardened Validator
    func validate() -> Bool {
        // Allowlist for Security
        let allowedProviders = ["Yahoo", "FMP", "TwelveData", "FRED"]
        guard allowedProviders.contains(targetProvider) else { return false }
        
        // Prevent generic wildcards
        if endpoint.contains("*") { return false }
        
        return true
    }
}

// MARK: - Logic

actor MimirIssueDetector {
    static let shared = MimirIssueDetector()
    
    private init() {}
    
    func scan() async -> [MimirIssue] {
        var issues: [MimirIssue] = []
        
        // 1. Scan Aether (Macro)
        if let aether = await MacroRegimeService.shared.getCachedRating() {
            for (key, status) in aether.componentStatuses {
                if status == "STALE" || status == "MISSING" {
                    issues.append(MimirIssue(
                        engine: .aether,
                        asset: key.uppercased(),
                        status: status,
                        confidence: 0.8,
                        description: "\(key) verisi \(status) durumunda. (Aether 4.0)",
                        detectedAt: Date()
                    ))
                }
            }
        } else {
             issues.append(MimirIssue(
                engine: .aether,
                asset: "ALL",
                status: "MISSING",
                confidence: 1.0,
                description: "Aether henüz çalışmadı veya veri yok.",
                detectedAt: Date()
             ))
        }
        
        // 2. Scan Registry (Circuit Breaker)
        // Removed unused candidates check which had undefined 'field'
        let locks = await ProviderCapabilityRegistry.shared.getQuarantineStatus()
        for (key, reason) in locks {
            issues.append(MimirIssue(
                engine: .heimdall,
                asset: key,
                status: "LOCKED",
                confidence: 0.9,
                description: "Registry Kilidi: \(reason)",
                detectedAt: Date()
            ))
        }
        
        return issues
    }
    
    func resolve(issue: MimirIssue) async -> Bool {
        // Placeholder for "Auto-Fix" logic
        // In real impl, this would trigger orchestrator retries or "Gemini Instruction"
        
        if issue.engine == .heimdall && issue.status == "LOCKED" {
             // Example: Auto-unlock if purely rate limited? No, safety first.
             // But we can verify key.
             return false
        }
        return false // Requires Manual/AI Intervention
    }
}
