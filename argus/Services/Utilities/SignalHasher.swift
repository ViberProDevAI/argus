import Foundation
import CryptoKit

/// Utility for creating deterministic signal hashes for idempotency.
struct SignalHasher {
    
    /// Creates a SHA-256 hash for a trading signal.
    /// - Parameters:
    ///   - symbol: The instrument symbol (e.g., "AAPL").
    ///   - timeframe: The analysis timeframe (e.g., "1h").
    ///   - barCloseTime: The close time of the current bar (rounded to minute).
    ///   - action: The proposed action ("BUY", "SELL", "HOLD").
    ///   - inputsDigest: A digest of the module inputs (scores).
    /// - Returns: A hexadecimal SHA-256 hash string.
    static func hash(
        symbol: String,
        timeframe: String,
        barCloseTime: Date,
        action: String,
        inputsDigest: String
    ) -> String {
        // Round bar close time to the minute for consistency
        let roundedTime = barCloseTime.timeIntervalSince1970.rounded(.down)
        
        // Build the canonical string
        let canonical = "\(symbol)|\(timeframe)|\(Int(roundedTime))|\(action)|\(inputsDigest)"
        
        // Compute SHA-256
        let data = Data(canonical.utf8)
        let digest = SHA256.hash(data: data)
        
        // Convert to hex string
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Creates a simple inputs digest from module scores.
    static func inputsDigest(
        atlas: Double?,
        orion: Double?,
        aether: Double?,
        hermes: Double?,
        phoenix: Double?
    ) -> String {
        // Round to 2 decimal places for stability
        let parts = [
            atlas.map { String(format: "A%.0f", $0) } ?? "A-",
            orion.map { String(format: "O%.0f", $0) } ?? "O-",
            aether.map { String(format: "E%.0f", $0) } ?? "E-",
            hermes.map { String(format: "H%.0f", $0) } ?? "H-",
            phoenix.map { String(format: "P%.0f", $0) } ?? "P-"
        ]
        return parts.joined(separator: "_")
    }
}
