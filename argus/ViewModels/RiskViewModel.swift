import Foundation
import Combine
import SwiftUI

/// Risk & Portfolio Manager
/// Extracted from TradingViewModel (Phase 2)
/// Handles: Portfolio, Balance, Backtesting, Whales, ETFs
@MainActor
final class RiskViewModel: ObservableObject {
    
    // MARK: - Portfolio State
    @Published var portfolio: [Trade] = []
    @Published var balance: Double = 100000.0 // USD Balance
    @Published var bistBalance: Double = 1000000.0 // 1M TL BIST demo balance
    @Published var usdTryRate: Double = 35.0
    @Published var transactionHistory: [Transaction] = []
    
    // MARK: - Risk & Analysis Data
    @Published var activeBacktestResult: BacktestResult?
    
    // Orion SAR+TSI Lab
    @Published var sarTsiBacktestResult: OrionSarTsiBacktestResult?
    @Published var isLoadingSarTsiBacktest: Bool = false
    @Published var sarTsiErrorMessage: String?
    
    // Poseidon (Whale)
    @Published var poseidonWhaleScores: [String: WhaleScore] = [:]
    
    // ETF Summaries
    @Published var etfSummaries: [String: ArgusEtfSummary] = [:]
    @Published var isLoadingEtf = false
    
    // Services
    // In a real refactor, we might inject stores here.
    // For now, we assume this VM owns this state or syncs with a Store driven by TradingVM originally.
    // Since TradingVM was the source of truth, we are moving that truth here.
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Future: Bind to Persistence Stores if applicable
    }
    
    // MARK: - Public Actions
    
    func updatePortfolio(_ newPortfolio: [Trade]) {
        self.portfolio = newPortfolio
    }
    
    func updateBalance(usd: Double, tryBalance: Double) {
        self.balance = usd
        self.bistBalance = tryBalance
    }
    
    func addTransaction(_ transaction: Transaction) {
        self.transactionHistory.append(transaction)
    }
    
    // Logic for loading ETFs or Whales could move here in future steps.
}
