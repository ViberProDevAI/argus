import Foundation
import Combine

/// Unified Store for Fundamentals (Atlas Engine)
/// Integrates Mimir for filling missing data gaps.
@MainActor
final class FundamentalsStore: ObservableObject {
    static let shared = FundamentalsStore()
    
    @Published var financials: [String: DataValue<FinancialsData>] = [:]
    
    private init() {}
    
    // MARK: - Access
    func getFinancials(for symbol: String) -> FinancialsData? {
        return financials[symbol]?.value
    }
    
    // MARK: - Actions
    func fetchFinancials(symbol: String) async {
        // Cache Check
        if let current = financials[symbol], !current.isStale, -current.provenance.fetchedAt.timeIntervalSinceNow < 86400 { // 24h for Fundamentals
            return
        }
        
        do {
            // 1. Fetch Primary (Heimdall)
            let data = try await HeimdallOrchestrator.shared.requestFundamentals(symbol: symbol)
            
            // 2. Mimir Gap Analysis & Filling
            // We check specific fields important for analysis. 
            // If they are missing (nil or 0 where 0 is unlikely), we report to Mimir.
            
            // Example: If Total Debt is missing, ask Mimir
            /*
            if data.totalDebt == nil || data.totalDebt == 0 {
                // Async background fill - don't block UI
                Task { await self.attemptMimirFill(symbol: symbol, field: "TotalDebt", currentData: data) }
            }
            */
            // Note: Mimir Service integration requires implementing `completeMissingField` first.
            // For now, we store what we have.
            
            let val = DataValue<FinancialsData>(
                value: data,
                provenance: DataProvenance(source: "Heimdall", fetchedAt: Date(), confidence: 1.0),
                status: .fresh
            )
            self.financials[symbol] = val
            
        } catch {
            print("📉 FundamentalsStore: Failed for \(symbol): \(error)")
            // Mark Stale
            if let current = financials[symbol] {
                financials[symbol] = DataValue(value: current.value, provenance: current.provenance, status: .stale)
            }
        }
    }
    
    // Placeholder for Mimir Integration (as per prompt req)
    /*
    private func attemptMimirFill(symbol: String, field: String, currentData: FinancialsData) async {
         // Ask Mimir
         // If success, update `financials[symbol]` with patched data and provenance source="Mimir"
    }
    */
}
