import SwiftUI
import Combine

/// Signal Analysis & Trading Signals ViewModel
/// Manages: Orion Analysis, Trading Signals, Technical Patterns, Demeter Scores
@MainActor
final class SignalViewModel: ObservableObject {

    // MARK: - Orion Analysis State
    @Published var isOrionLoading = false
    @Published var prometheusForecastBySymbol: [String: PrometheusForecast] = [:]

    // MARK: - Decision & Signal State
    @Published var searchResults: [SearchResult] = []

    // MARK: - Demeter (Sector) State
    @Published var demeterScores: [DemeterScore] = []
    @Published var demeterMatrix: CorrelationMatrix?
    @Published var isRunningDemeter = false
    @Published var activeShocks: [ShockFlag] = []

    // MARK: - Dependencies
    private let analysisViewModel: AnalysisViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(analysisViewModel: AnalysisViewModel? = nil) {
        self.analysisViewModel = analysisViewModel ?? AnalysisViewModel()
        setupBindings()
    }

    // MARK: - Bindings
    private func setupBindings() {
        analysisViewModel.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Accessors (Facade to AnalysisViewModel)

    var orionAnalysis: [String: MultiTimeframeAnalysis] {
        analysisViewModel.orionAnalysis
    }

    var patterns: [String: [OrionChartPattern]] {
        analysisViewModel.patterns
    }

    var grandDecisions: [String: ArgusGrandDecision] {
        get { analysisViewModel.grandDecisions }
        set { analysisViewModel.grandDecisions = newValue }
    }

    var chimeraSignals: [String: ChimeraSignal] {
        get { analysisViewModel.chimeraSignals }
        set { analysisViewModel.chimeraSignals = newValue }
    }

    var orionScores: [String: OrionScoreResult] {
        analysisViewModel.orionScores
    }

    // MARK: - Signal Operations

    func ensureOrionAnalysis(for symbol: String) async {
        await OrionStore.shared.ensureAnalysis(for: symbol)
    }

    func runDemeterAnalysis() async {
        self.isRunningDemeter = true
        await DemeterEngine.shared.analyze()

        let scores = await DemeterEngine.shared.sectorScores
        let matrix = await DemeterEngine.shared.correlationMatrix
        let shocks = await DemeterEngine.shared.activeShocks

        self.demeterScores = scores
        self.demeterMatrix = matrix
        self.activeShocks = shocks
        self.isRunningDemeter = false
    }

    func getDemeterMultipliers(for symbol: String) async -> (priority: Double, size: Double, cooldown: Bool) {
        return await DemeterEngine.shared.getMultipliers(for: symbol)
    }

    func getDemeterScore(for symbol: String) -> DemeterScore? {
        guard let sector = SectorMap.getSector(for: symbol) else { return nil }
        return demeterScores.first(where: { $0.sector == sector })
    }
}
