import Foundation
import Combine

// MARK: - Argus Lab ViewModel (Argus 3.0)
/// UI verilerini ForwardTestLedger'dan çeker ve UI'a sunar.

@MainActor
class ArgusLabViewModel: ObservableObject {
    @Published var openTrades: [TradeRecord] = []
    @Published var closedTrades: [TradeRecord] = []
    @Published var lessons: [LessonRecord] = []
    @Published var isLoading = false
    
    func refresh() {
        isLoading = true
        
        Task {
            // Fetch from ledger
            openTrades = await ArgusLedger.shared.getOpenTrades()
            closedTrades = await ArgusLedger.shared.getClosedTrades(limit: 50)
            lessons = await ArgusLedger.shared.getLessons(limit: 50)
            isLoading = false
        }
    }
}

// MARK: - Data Models

// MARK: - Data Models
// Moved to ForwardTestModels.swift (Phase 4 Refactoring)

