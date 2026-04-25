import Foundation
import Combine
import SwiftUI

// MARK: - Diagnostics ViewModel
/// Extracted from TradingViewModel (God Object Decomposition - Phase 2)
/// Responsibilities: Data health monitoring, performance metrics, bootstrap timing

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    static let shared = DiagnosticsViewModel()
    
    // MARK: - Published Properties
    
    /// Data health per symbol - Pillar 1
    @Published var dataHealthBySymbol: [String: DataHealth] = [:]
    
    /// Performance Metrics (Freeze Detective)
    @Published var bootstrapDuration: Double = 0.0
    @Published var lastBatchFetchDuration: Double = 0.0
    
    /// Heimdall Health Status
    @Published var heimdallHealth: HeimdallHealthStatus = HeimdallHealthStatus(
        isHealthy: false,
        uptime: 0,
        activeStreams: [],
        lastError: nil
    )
    
    /// Provider capabilities registry status
    @Published var providerCapabilities: [String: ProviderCapability] = [:]
    
    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // Observe Heimdall health changes
        NotificationCenter.default.publisher(for: NSNotification.Name("HeimdallHealthUpdate"))
            .receive(on: DispatchQueue.main)
            .compactMap { $0.userInfo?["health"] as? HeimdallHealthStatus }
            .sink { [weak self] health in
                self?.heimdallHealth = health
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Health
    
    /// Update data health for a symbol
    func updateDataHealth(symbol: String, health: DataHealth) {
        dataHealthBySymbol[symbol] = health
    }
    
    /// Calculate overall system health score (0-100)
    var systemHealthScore: Int {
        guard !dataHealthBySymbol.isEmpty else { return 0 }
        let total = dataHealthBySymbol.values.reduce(0) { $0 + $1.qualityScore }
        return total / dataHealthBySymbol.count
    }
    
    /// Get symbols with poor data quality (< 50)
    var poorQualitySymbols: [String] {
        dataHealthBySymbol
            .filter { $0.value.qualityScore < 50 }
            .map { $0.key }
            .sorted()
    }
    
    // MARK: - Performance
    
    /// Record bootstrap completion time
    func recordBootstrapDuration(_ duration: Double) {
        bootstrapDuration = duration
        print("📊 DiagnosticsVM: Bootstrap completed in \(String(format: "%.2f", duration))s")
    }
    
    /// Record batch fetch duration
    func recordBatchFetchDuration(_ duration: Double) {
        lastBatchFetchDuration = duration
    }
    
    /// Performance summary for UI
    var performanceSummary: String {
        """
        Bootstrap: \(String(format: "%.2f", bootstrapDuration))s
        Last Fetch: \(String(format: "%.2f", lastBatchFetchDuration))s
        Health: \(systemHealthScore)%
        """
    }
    
    // MARK: - Provider Status
    
    func updateProviderCapability(provider: String, capability: ProviderCapability) {
        providerCapabilities[provider] = capability
    }
    
    /// Get available providers for a symbol
    func availableProviders(for symbol: String) -> [String] {
        providerCapabilities
            .filter { $0.value.supportedMarkets.contains(where: { symbol.hasSuffix($0) || $0 == "*" }) }
            .map { $0.key }
    }
}

// MARK: - Supporting Types

/// Provider capability information
struct ProviderCapability {
    let name: String
    let supportedMarkets: [String] // ["*", ".IS", "ETF"]
    let hasQuotes: Bool
    let hasFundamentals: Bool
    let hasNews: Bool
    let rateLimit: Int // requests per minute
    let isHealthy: Bool
}

/// Heimdall system health status
struct HeimdallHealthStatus {
    let isHealthy: Bool
    let uptime: TimeInterval
    let activeStreams: [String]
    let lastError: String?
    
    var statusText: String {
        isHealthy ? "✅ Healthy" : "⚠️ Degraded"
    }
}
