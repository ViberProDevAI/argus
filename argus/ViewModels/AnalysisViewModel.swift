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
    
    /// Cached daily scores - SignalStateViewModel'deki @Published cache'ten okur.
    /// Önceden her erişimde mapValues çalışıyordu; artık tek seviyeli forward.
    var orionScores: [String: OrionScoreResult] {
        return SignalStateViewModel.shared.orionScores
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
    
    init() {
        // Manuel objectWillChange relay'i kaldırıldı (2026-04-30).
        //
        // Önceki kod SignalStateViewModel'in objectWillChange yayınını sink'leyip
        // AVM'in kendi objectWillChange'ini fire ediyordu. Bu, SignalState'teki
        // HER property değişimini AVM'e yansıtıyordu — bu da AVM'i observe eden
        // SignalViewModel.shared'a kademeli olarak relay ediliyordu.
        //
        // Sorun: ne AVM ne SignalViewModel'i doğrudan observe eden view yok.
        // Tüm view'lar TradingViewModel üzerinden gidiyor ve TVM bu chain'in
        // çıktısını dinlemiyor. Yani bu relay tamamen ölü iş — her
        // SignalState güncellemesinde 2 ekstra sink çalışıyordu, sıfır görünür
        // etkisi olan re-render tetikliyordu.
        //
        // Bir gün view AVM'i doğrudan observe ederse, dar (per-property)
        // binding kullan: `SignalStateViewModel.shared.$orionAnalysis
        //   .sink { ... }`. Tek property için tek emit, tüm chain için değil.
    }
}
