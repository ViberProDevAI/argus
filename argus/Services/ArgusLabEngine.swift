import Foundation

@MainActor
class ArgusLabEngine {
    static let shared = ArgusLabEngine()
    
    // Storage
    private let storage = ArgusStorage.shared
    
    private init() {}
    
    // MARK: - 1. Unified Logging (v2)
    
    func log(event: ArgusLabEvent) {
        // Validation: Only log if coverage is not invalid (unless debugging, but prompt says maybe ignore)
        if event.dataCoverage.level == .invalid {
            print("⚠️ ArgusLab: Event Ignored for \(event.symbol) due to INVALID Data Coverage.")
            return
        }
        
        storage.appendUnifiedEvent(event)
    }
    
    // Legacy support for older code until fully migrated
    func logDecision(symbol: String, decision: ArgusDecisionResult, currentPrice: Double) {
        // Also log as generic event for Argus Core
        let coverage = DataCoverage(
            technical: .present(quality: 0.8),
            fundamental: .present(quality: 0.8),
            macro: .present(quality: 0.8),
            news: .present(quality: 0.5)
        )
        
        // Map Legacy Action
        var labAction: LabAction = .hold
        switch decision.finalActionCore {
        case .buy: labAction = .buy
        case .sell: labAction = .sell
        case .hold: labAction = .hold
        case .skip: labAction = .hold
        case .wait: labAction = .hold
        }
        
        let event = ArgusLabEvent(
            symbol: symbol,
            algoId: ArgusAlgoId.argusCoreV1,
            action: labAction,
            confidence: decision.finalScoreCore,
            orionScore: decision.orionScore,
            atlasScore: decision.atlasScore,
            aetherScore: decision.aetherScore,
            hermesScore: decision.hermesScore,
            dataCoverage: coverage,
            regimeTag: decision.aetherScore < 40 ? "RiskOff" : "RiskOn",
            notes: "Legacy Decision Log",
            signalPrice: currentPrice,
            horizonDays: 5
        )
        
        log(event: event)
        
        // Keep old logs for compatibility if needed
        let coreEntry = ArgusDecisionLogEntry(decision: decision, mode: .core, currentPrice: currentPrice)
        storage.appendLabEvent(coreEntry)
    }
    
    // MARK: - 2. Unified Resolution (Ex-Post)
    
    func resolveUnifiedEvents(using provider: MarketDataProvider) async {
        let events = storage.loadUnifiedEvents()
        
        // Filter unresolved events where horizon has passed
        let pendingEvents = events.filter { event in
            guard event.resolvedAt == nil else { return false }
            
            // Check if horizon days + 1 had passed (to be safe/close of day)
            // Or just horizon days.
            if let targetDate = Calendar.current.date(byAdding: .day, value: event.horizonDays, to: event.createdAt) {
                return Date() >= targetDate
            }
            return false
        }
        
        guard !pendingEvents.isEmpty else { return }
        print("🧪 ArgusLab (Unified): Resolving \(pendingEvents.count) events...")
        
        // Group by symbol to batch fetch
        let eventsBySymbol = Dictionary(grouping: pendingEvents, by: { $0.symbol })
        var updates: [ArgusLabEvent] = []
        
        for (symbol, symbolEvents) in eventsBySymbol {
            do {
                // Fetch candles (e.g. 100 days to be safe)
                let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1G", limit: 100)
                let sortedCandles = candles.sorted { $0.date < $1.date }
                
                for event in symbolEvents {
                    if let targetPrice = getFuturePrice(for: event, candles: sortedCandles) {
                        var updatedEvent = event
                        updatedEvent.resolvedAt = Date()
                        updatedEvent.resolvedPrice = targetPrice
                        
                        let ret = (targetPrice - event.signalPrice) / event.signalPrice * 100
                        updatedEvent.returnPercent = ret
                        
                        // Determine "Hit" logic loosely (can be refined per Algo later)
                        updatedEvent.isHit = isHit(action: event.action, returnPct: ret)
                        
                        updates.append(updatedEvent)
                    }
                }
            } catch {
                print("❌ ArgusLabEngine: Failed resolution for \(symbol): \(error)")
            }
        }
        
        if !updates.isEmpty {
            storage.updateUnifiedEventsBatch(updates)
        }
    }
    
    private func getFuturePrice(for event: ArgusLabEvent, candles: [Candle]) -> Double? {
        guard let targetDate = Calendar.current.date(byAdding: .day, value: event.horizonDays, to: event.createdAt) else { return nil }
        
        // Find candle closest to targetDate (or >= targetDate)
        // Candles are EOD. If event was created at T, horizon 5, target is T+5.
        // We look for candle[date] >= targetDate
        return candles.first(where: { Calendar.current.isDate($0.date, inSameDayAs: targetDate) || $0.date > targetDate })?.close
    }
    
    private func isHit(action: LabAction, returnPct: Double) -> Bool {
        let threshold = 0.5 // 0.5% threshold for noise
        switch action {
        case .buy:
            return returnPct >= threshold
        case .sell:
            return returnPct <= -threshold
        case .hold, .riskOff:
            return abs(returnPct) < threshold // Stability is a hit for hold?
        default:
            return returnPct > 0 // Default bullish assumption
        }
    }
    
    // MARK: - 3. Unified Statistics
    
    func getStats(for algoId: String) -> UnifiedAlgoStats {
        let events = storage.getEvents(for: algoId)
        
        // Filter out coverage partial if we want strict stats?
        // User said: "DataCoverage.partial -> istersen logla ama Argus Lab çekirdek başarı oranına karıştırma"
        // So we filter for .full
        let validEvents = events.filter { $0.dataCoverage.level == .full }
        
        let resolvedAndValid = validEvents.filter { $0.resolvedAt != nil && $0.returnPercent != nil }
        
        let total = validEvents.count
        let resolvedCount = resolvedAndValid.count
        
        if resolvedCount == 0 {
            return UnifiedAlgoStats(
                algoId: algoId,
                totalSignals: total,
                hitRate: 0,
                avgReturn: 0,
                winCount: 0,
                lossCount: 0,
                coverageFullCount: total,
                recentEvents: Array(validEvents.suffix(20).reversed())
            )
        }
        
        let hits = resolvedAndValid.filter { $0.isHit == true }.count
        let hitRate = Double(hits) / Double(resolvedCount) * 100.0
        
        // Avg Return (Only for BUY signals usually meaningful for avg return calc, or invert sell?)
        // Let's take directional return: If SELL and price down, return is Positive for the ALGO.
        let directionalReturns = resolvedAndValid.compactMap { event -> Double? in
            guard let ret = event.returnPercent else { return nil }
            if event.action == .sell {
                return -ret // If ret is -5% (price drop), algo made +5%
            }
            return ret
        }
        
        let avgReturn = directionalReturns.reduce(0.0, +) / Double(directionalReturns.count)
        
        return UnifiedAlgoStats(
            algoId: algoId,
            totalSignals: total,
            hitRate: hitRate,
            avgReturn: avgReturn,
            winCount: hits,
            lossCount: resolvedCount - hits,
            coverageFullCount: total,
            recentEvents: Array(validEvents.suffix(50).reversed()) // Last 50 reversed
        )
    }
}
