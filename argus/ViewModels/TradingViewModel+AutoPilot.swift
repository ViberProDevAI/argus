
import Foundation
import SwiftUI
import Combine

// MARK: - AutoPilot & Trading Logic (Refactored to Store)
extension TradingViewModel {

    // MARK: - Auto-Pilot Logic (Delegated)
    
    func startAutoPilotLoop() {
        // Delegate to Store
        AutoPilotStore.shared.startAutoPilotLoop()
    }
    
    func runAutoPilot() async {
        await AutoPilotStore.shared.runAutoPilot()
    }
    
    // MARK: - Passive Scanner
    
    func processHighConvictionCandidate(symbol: String, score: Double) async {
        await AutoPilotStore.shared.processHighConvictionCandidate(symbol: symbol, score: score)
    }
    
    func scanHighConvictionCandidates() async {
        // Logic moved to Store
        // Keeping empty implementation if referenced by other legacy headers, or remove entirely if safe.
        // Assuming implementation simply delegates or is no-op.
    }
    
    func analyzeDiscoveryCandidates(_ tickers: [String], source: NewsInsight) async {
        await AutoPilotStore.shared.analyzeDiscoveryCandidates(tickers, source: source)
    }
    
    @objc func handleAutoPilotIntent(_ notification: Notification) {
        AutoPilotStore.shared.handleAutoPilotIntent(notification)
    }
    
    // MARK: - Removed Duplicate Logics
    // checkStopLoss / checkTakeProfit removed (handled by PortfolioStore)
    // executeProtectedTrade removed (handled by Store/Executor)
}
