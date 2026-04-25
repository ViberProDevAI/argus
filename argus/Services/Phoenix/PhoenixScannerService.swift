import Foundation
import Combine
import SwiftUI // Often needed for AppStorage or similar


/// The Phoenix Engine Reborn.
/// Implements the 2-Stage Pipeline (Level 0 -> Level 1) with Heimdall Budget Control.
@MainActor
final class PhoenixScannerService: ObservableObject {
    static let shared = PhoenixScannerService()
    
    // Dependencies
    private let heimdall = HeimdallOrchestrator.shared
    private let chiron = ChironRegimeEngine.shared
    
    // State
    @Published var isScanning = false
    @Published var currentStatus: String = "Hazır"
    @Published var progress: Double = 0.0
    @Published var latestCandidates: [PhoenixCandidate] = []
    
    // Live Pipeline Stats
    @Published var lastReport: PhoenixRunReport?
    
    private init() {}
    
    // MARK: - Main Pipeline Entry
    
    func runPipeline(mode: PhoenixScanMode) async -> PhoenixRunReport {
        guard !isScanning else { return createEmptyReport(mode: mode, error: "Scan already in progress") }
        
        self.isScanning = true
        self.progress = 0.0
        self.currentStatus = "Başlatılıyor..."
        
        // Defer cannot have async, but since we are on MainActor, simple assignment works.
        // However, defer executes when scope exits.
        // We will manually set isScanning = false at return points or ensure execution flows there.
        // Or simply:
        defer {
            self.isScanning = false
        }
        
        let budget = HeimdallBudgetManager(mode: mode)
        var logs: [String] = []
        var errors: [String] = []
        
        logs.append("🚀 Phoenix Pipeline Başlatıldı. Mod: \(mode.rawValue)")
        logs.append("💰 Bütçe: \(budget.snapshot())")
        
        // 0. Chiron Context
        let regime = await measureRegime()
        logs.append("🌍 Chiron Rejimi: \(regime)")
        
        // 1. Level 0: Universe Scan (Cheap)
        self.currentStatus = "Level 0: Evren Taranıyor..."
        self.progress = 0.1
        
        var candidates: [PhoenixCandidate] = []
        
        do {
            // Source 1: Yahoo Top Losers
            if budget.canSpend() {
                let losers = try await fetchUniverse(type: .losers, budget: budget)
                candidates.append(contentsOf: losers)
                logs.append("📥 Kaynak (Losers): \(losers.count) aday alındı.")
            }
            
            // Source 2: Yahoo Most Active (If Aggressive or Balanced)
            if mode != .saver && budget.canSpend() {
                let active = try await fetchUniverse(type: .mostActive, budget: budget)
                candidates.append(contentsOf: active)
                logs.append("📥 Kaynak (Active): \(active.count) aday alındı.")
            }
            
        } catch {
            errors.append("Level 0 Hatası: \(error.localizedDescription)")
            logs.append("⚠️ Level 0 kısmen başarısız oldu.")
        }
        
        // 1.1 Filters (ETF Cleanup & Rules)
        let rawCount = candidates.count
        candidates = filterCandidates(candidates, mode: mode, regime: regime)
        logs.append("🧹 Filtreleme: \(rawCount) -> \(candidates.count) (ETF ve Çöp ayıklandı)")
        
        // 2. Shortlist Selection
        self.currentStatus = "Adaylar Puanlanıyor..."
        self.progress = 0.3
        
        let shortlistLimit = getShortlistLimit(mode: mode)
        let shortlist = selectShortlist(from: candidates, limit: shortlistLimit)
        logs.append("📋 Shortlist: \(shortlist.count) aday seçildi (Limit: \(shortlistLimit)).")
        
        // 3. Level 1: Evidence Gathering (Expensive)
        self.currentStatus = "Level 1: Kanıt Toplanıyor..."
        self.progress = 0.5
        
        var verifiedCandidates: [PhoenixCandidate] = []
        
        for (index, candidate) in shortlist.enumerated() {
            // Check Budget
            if !budget.canSpend(isHeavy: true) {
                logs.append("🛑 Bütçe Doldu. Tarama erken bitiriliyor.")
                break
            }
            
            self.progress = 0.5 + (0.4 * Double(index) / Double(shortlist.count))
            self.currentStatus = "İnceleniyor: \(candidate.symbol)"
            
            var enriched = candidate
            // Fetch Evidence (Candles -> Technicals)
            let evidence = await collectEvidence(for: candidate.symbol, budget: budget)
            enriched.evidence = evidence
            
            // Verification Rule
            if evidence.canVerify {
                verifiedCandidates.append(enriched)
                logs.append("✅ Onaylandı: \(candidate.symbol) (Skor: \(evidence.trendScore ?? 0))")
                budget.spend(isHeavy: true)
            } else {
                logs.append("❌ Reddedildi: \(candidate.symbol)")
            }
        }
        
        // 4. Send to Council (Decision Engine)
        self.currentStatus = "Konseye Gönderiliyor..."
        self.progress = 0.95
        
        let report = PhoenixRunReport(
            id: UUID().uuidString.prefix(8).description,
            timestamp: Date(),
            mode: mode,
            regime: regime,
            candidatesFound: rawCount,
            shortlistCount: shortlist.count,
            verifiedCount: verifiedCandidates.count,
            sentCount: verifiedCandidates.count,
            budgetUsed: budget.requestsUsed,
            budgetLimit: budget.remainingRequests() + budget.requestsUsed,
            stoppedByBudget: !budget.canSpend(),
            logs: logs,
            errors: errors,
            sentSymbols: verifiedCandidates.map { $0.symbol }
        )
        
        self.lastReport = report
        self.latestCandidates = verifiedCandidates
        self.currentStatus = "Tamamlandı"
        self.progress = 1.0
        
        return report
    }
    
    // MARK: - Level 0: Universe
    
    private func fetchUniverse(type: ScreenerType, budget: HeimdallBudgetManager) async throws -> [PhoenixCandidate] {
        budget.spend()
        
        // Since we are on MainActor, we need to be careful not to block.
        // YahooFinanceProvider is an actor or has async methods, so 'await' will suspend, not block.
        
        // Use Heimdall Orchestrator to benefit from Fallback (Local Scanner) and Circuit Breaker
        let quotes = try await heimdall.requestScreener(type: type, limit: 50)
        
        return quotes.compactMap { quote -> PhoenixCandidate? in
            guard let symbol = quote.symbol else { return nil }
            let isETF = detectETF(symbol: symbol, shortName: quote.shortName ?? "")
            
            return PhoenixCandidate(
                symbol: symbol,
                assetType: isETF ? .etf : .stock,
                lastPrice: quote.c,
                dayChangePct: quote.dp ?? 0.0,
                volume: 0,
                universeSource: "Yahoo:\(type)",
                level0Reason: "\(type) List",
                isPartial: false
            )
        }
    }
    
    private func detectETF(symbol: String, shortName: String) -> Bool {
        let name = shortName.uppercased()
        
        if name.contains("ETF") { return true }
        if name.contains("SHARES") { return true }
        if name.contains("VANGUARD") { return true }
        if name.contains("SPDR") { return true }
        if name.contains("TRUST") { return true }
        if name.contains("INDEX") { return true }
        if name.contains("FUND") { return true }
        if symbol.count > 4 { return true }
        
        if name.contains("2X") || name.contains("3X") || name.contains("ULTRA") || name.contains("BEAR") || name.contains("BULL") {
            return true
        }
        
        return false
    }

    // ... (Rest of file helpers similar, stripped for brevity in replacement but I need to keep them or use view_file to replace partially)
    // I am replacing almost the whole file content to be safe with structure changes.
    // I need to include the rest of the methods calculateSMA etc.
    
    // MARK: - Filter & Select
    
    private func filterCandidates(_ candidates: [PhoenixCandidate], mode: PhoenixScanMode, regime: String) -> [PhoenixCandidate] {
        return candidates.filter { c in
            if c.assetType == .etf || c.assetType == .crypto { return false }
            if c.lastPrice < 2.0 { return false }
            if mode == .saver && abs(c.dayChangePct) < 3.0 { return false }
            return true
        }
    }
    
    private func selectShortlist(from candidates: [PhoenixCandidate], limit: Int) -> [PhoenixCandidate] {
        let sorted = candidates.sorted { abs($0.dayChangePct) > abs($1.dayChangePct) }
        return Array(sorted.prefix(limit))
    }
    
    private func getShortlistLimit(mode: PhoenixScanMode) -> Int {
        switch mode {
        case .saver: return 8
        case .balanced: return 18
        case .aggressive: return 30
        }
    }
    
    // MARK: - Level 1: Evidence
    
    private func collectEvidence(for symbol: String, budget: HeimdallBudgetManager) async -> PhoenixEvidence {
        budget.spend()
        do {
            // runPipeline is MainActor. calling heimdall (Actor) is async. Fine.
            let candles = try await heimdall.requestCandles(symbol: symbol, timeframe: "1d", limit: 60)
            guard !candles.isEmpty else {
                 return PhoenixEvidence(candlesAvailable: false, liquidityOk: false, volatilityATR: nil, trendScore: nil, channelStatus: nil, atlasConfidence: nil)
            }
            
            let closePrices = candles.map { $0.close }
            let sma20 = calculateSMA(data: closePrices, period: 20)
            let sma50 = calculateSMA(data: closePrices, period: 50)
            
            var trend: Double = 0
            if let s20 = sma20.last, let s50 = sma50.last {
                if s20 > s50 { trend = 1.0 }
                else { trend = -1.0 }
            }
            
            return PhoenixEvidence(
                candlesAvailable: true,
                liquidityOk: true,
                volatilityATR: 0.0,
                trendScore: trend,
                channelStatus: "Pending",
                atlasConfidence: nil
            )
        } catch {
            return PhoenixEvidence(candlesAvailable: false, liquidityOk: false, volatilityATR: nil, trendScore: nil, channelStatus: nil, atlasConfidence: nil)
        }
    }
    
    // MARK: - Helpers
    
    private func measureRegime() async -> String {
        return "Nötr (Dengeli)"
    }
    
    private func createEmptyReport(mode: PhoenixScanMode, error: String) -> PhoenixRunReport {
        return PhoenixRunReport(id: "ERR", timestamp: Date(), mode: mode, regime: "Unknown", candidatesFound: 0, shortlistCount: 0, verifiedCount: 0, sentCount: 0, budgetUsed: 0, budgetLimit: 0, stoppedByBudget: false, logs: [], errors: [error], sentSymbols: [])
    }
    
    private func calculateSMA(data: [Double], period: Int) -> [Double] {
        guard data.count >= period else { return [] }
        var result: [Double] = []
        for i in (period-1)..<data.count {
            let slice = data[(i-period+1)...i]
            let avg = slice.reduce(0, +) / Double(period)
            result.append(avg)
        }
        return result
    }
}


private extension PhoenixEvidence {
    var canVerify: Bool {
        return candlesAvailable && liquidityOk // && (trendScore ?? 0) > 0 (example rule)
    }
}
