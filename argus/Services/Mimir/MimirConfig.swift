import Foundation

public struct MimirConfig: Codable, Sendable {
    public var enabled: Bool
    public var modelPrimary: String         // e.g. "gemini-1.5-flash"
    public var modelFallback: String?       // smaller/cheaper
    
    // Limits
    public var maxRequestsPerMinute: Int
    public var maxTokensPerMinute: Int
    public var maxTokensPerDay: Int
    public var burstLimit: Int
    
    // Safety
    public var cooldownOn429Seconds: Int
    public var circuitBreakerThreshold: Int
    public var circuitBreakerOpenSeconds: Int
    public var defaultTTLSeconds: Int
    
    // Defaults
    public nonisolated static var standard: MimirConfig {
        return MimirConfig(
            enabled: true,
            modelPrimary: "gemini-1.5-flash",
            modelFallback: "gemini-1.5-nano",
            maxRequestsPerMinute: 15,
            maxTokensPerMinute: 32_000,
            maxTokensPerDay: 1_000_000,
            burstLimit: 5,
            cooldownOn429Seconds: 60,
            circuitBreakerThreshold: 3,
            circuitBreakerOpenSeconds: 300,
            defaultTTLSeconds: 3600
        )
    }
}
