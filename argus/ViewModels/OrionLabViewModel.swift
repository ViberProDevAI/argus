import Foundation
import Combine
import SwiftUI

class OrionLabViewModel: ObservableObject {
    @Published var gradeStats: [OrionGradeStats] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let engine = OrionStatsEngine()
    
    func loadStats() {
        isLoading = true
        errorMessage = nil
        
        Task {
            let snapshots = OrionStatsStore.shared.loadAll()
            
            if snapshots.isEmpty {
                await MainActor.run {
                    self.gradeStats = []
                    self.isLoading = false
                }
                return
            }
            
            // Compute stats (heavy lifting)
            let stats = await engine.computeStats(snapshots: snapshots)
            
            await MainActor.run {
                self.gradeStats = stats
                self.isLoading = false
            }
        }
    }
}
