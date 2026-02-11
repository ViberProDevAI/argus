import Foundation

extension ArgusAutoPilotEngine {
    
    /// Safety Guard: Checks if the asset is safe to trade based on fundamental events (Earnings).
    /// Uses Smart Atlas (Disk Cache) to check without burning API limits.
    func checkSafety(symbol: String) async -> Bool {
        // FMP Removed. Earnings Guard temporarily disabled.
        print("⚠️ AutoPilot: Safety check disabled (FMP Removed).")
        return true
    }
}
