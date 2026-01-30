import Foundation
import Combine
import SwiftUI

/// Analysis & Signals Manager
/// Extracted from TradingViewModel (Phase 2)
/// Handles: Orion, Council, Chimera, Reports, Demeter
@MainActor
final class AnalysisViewModel: ObservableObject {
    
    // MARK: - Signal Facade (Delegated to SignalStateViewModel)
    
    var orionAnalysis: [String: MultiTimeframeAnalysis] { SignalStateViewModel.shared.orionAnalysis }
    var isOrionLoading: Bool { SignalStateViewModel.shared.isOrionLoading }
    var patterns: [String: [OrionChartPattern]] { SignalStateViewModel.shared.patterns }
    
    var grandDecisions: [String: ArgusGrandDecision] {
        get { SignalStateViewModel.shared.grandDecisions }
        set { SignalStateViewModel.shared.grandDecisions = newValue }
    }
    
    var chimeraSignals: [String: ChimeraSignal] {
        get { SignalStateViewModel.shared.chimeraSignals }
        set { SignalStateViewModel.shared.chimeraSignals = newValue }
    }
    
    var orionScores: [String: OrionScoreResult] {
        return orionAnalysis.mapValues { $0.daily }
    }
    
    // MARK: - Financial Data
    @Published var snapshots: [String: FinancialSnapshot] = [:]

    // MARK: - Other AI Signals
    @Published var aiSignals: [AISignal] = []
    @Published var macroRating: MacroEnvironmentRating?
    
    // Reported & Content
    @Published var dailyReport: String?
    @Published var weeklyReport: String?
    @Published var bistDailyReport: String?
    @Published var bistWeeklyReport: String?
    
    // KAP
    @Published var kapDisclosures: [String: [KAPDataService.KAPNews]] = [:]
    
    // Sirkiye (BIST Atmosphere)
    @Published var bistAtmosphere: AetherDecision?
    @Published var bistAtmosphereLastUpdated: Date?
    
    // Overreaction Hunter
    @Published var overreactionResult: OverreactionResult?
    
    // DEMETER (Sector Engine)
    @Published var demeterScores: [DemeterScore] = []
    @Published var demeterMatrix: CorrelationMatrix?
    @Published var isRunningDemeter: Bool = false
    @Published var activeShocks: [ShockFlag] = []
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Init logic
        setupBindings()
    }
    
    private func setupBindings() {
        // In a full refactor, we would bind to SignalStateViewModel updates here
        // to manually trigger objectWillChange if needed, or rely on View's observing SignalStateViewModel directly.
        // For now, since we return computed props from Shared, Views might not update unless we publish change.
        
        SignalStateViewModel.shared.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
