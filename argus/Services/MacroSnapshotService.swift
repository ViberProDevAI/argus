import Foundation

/// Service to fetch and aggregate Macro Economic and Market Sentiment data.
/// Source of Truth for Argus Grand Council "Aether" context.
/// Combines FRED (Economic) and Yahoo (Market/Sentiment) data.
@MainActor
final class MacroSnapshotService: Sendable {
    static let shared = MacroSnapshotService()
    
    private let fred = FredProvider.shared
    private let yahoo = YahooFinanceProvider.shared
    
    private init() {}
    
    /// Generates a comprehensive Macro Snapshot
    func getSnapshot() async -> MacroSnapshot {
        // 1. Fetch Parallel Data
        async let fredData = fetchFredData()
        async let marketData = fetchMarketData()
        
        let (econ, rates) = await fredData
        let (sentiment, breadth) = await marketData
        
        // 2. Synthesize Mode
        let mode = determineMarketMode(vix: sentiment.vix, fearGreed: sentiment.fearGreed)
        
        // 3. Synthesize Sector Rotation (Placeholder logic for now)
        let rotation = analyzeSectorRotation()
        
        return MacroSnapshot(
            timestamp: Date(),
            
            // Sentiment
            vix: sentiment.vix,
            fearGreedIndex: sentiment.fearGreed,
            putCallRatio: sentiment.putCallRatio,
            
            // Rates
            fedFundsRate: econ.fedFunds,
            tenYearYield: rates.tenYear,
            twoYearYield: rates.twoYear,
            yieldCurveInverted: (rates.tenYear ?? 0) < (rates.twoYear ?? 0),
            
            // Breadth
            advanceDeclineRatio: breadth.adRatio,
            percentAbove200MA: breadth.above200,
            newHighsNewLows: breadth.nhNl,
            
            // Economic
            gdpGrowth: econ.gdp,
            unemploymentRate: econ.unemployment,
            inflationRate: econ.cpi,
            consumerConfidence: nil, // Michigan Sentiment not yet implemented
            
            // Sector
            sectorRotation: rotation.phase,
            leadingSectors: rotation.leaders,
            laggingSectors: rotation.laggards
        )
    }
    
    // MARK: - Sub-Fetchers
    
    private struct EconomicData {
        let gdp: Double?
        let unemployment: Double?
        let cpi: Double?
        let fedFunds: Double?
    }
    
    private struct RatesData {
        let tenYear: Double?
        let twoYear: Double?
    }
    
    private func fetchFredData() async -> (EconomicData, RatesData) {
        // Fetch series from FredProvider
        // We use 'fetchSeries' which returns [(Date, Double)]
        // We take the latest value
        
        async let gdpSeq = try? fred.fetchSeries(series: .growth, limit: 1)
        async let unrateSeq = try? fred.fetchSeries(series: .unemployment, limit: 1)
        async let cpiSeq = try? fred.fetchSeries(series: .cpi, limit: 1) // Headline CPI
        async let fedSeq = try? fred.fetchSeries(series: .fedFunds, limit: 1)
        
        async let tenYSeq = try? fred.fetchSeries(series: .treasury10Y, limit: 1)
        async let twoYSeq = try? fred.fetchSeries(series: .treasury2Y, limit: 1)
        
        let gdp = await gdpSeq?.first?.1
        let unrate = await unrateSeq?.first?.1
        
        // CPI logic: Calculate YoY if possible? 
        // FredProvider returns Index value (e.g. 308.5). We need YoY change.
        // Let's fetch 13 months to calc YoY.
        // But here we just fetch 1. If we fetch 1, we just get Index.
        // Let's improve CPI fetching to get YoY.
        
        let cpiVal = await fetchCPIYoY()
        
        let fed = await fedSeq?.first?.1
        
        // Rates are in Percent (e.g. 4.5)
        let ten = await tenYSeq?.first?.1
        let two = await twoYSeq?.first?.1
        
        return (
            EconomicData(gdp: gdp, unemployment: unrate, cpi: cpiVal, fedFunds: fed),
            RatesData(tenYear: ten, twoYear: two)
        )
    }
    
    private func fetchCPIYoY() async -> Double? {
        guard let data = try? await fred.fetchSeries(series: .cpi, limit: 13),
              data.count >= 13,
              let current = data.first?.1,
              let prior = data.last?.1 else {
            return nil
        }
        return ((current - prior) / prior) * 100.0
    }
    
    private struct SentimentData {
        let vix: Double?
        let fearGreed: Double?
        let putCallRatio: Double?
    }
    
    private struct BreadthData {
        let adRatio: Double?
        let above200: Double?
        let nhNl: Double?
    }
    
    private func fetchMarketData() async -> (SentimentData, BreadthData) {
        // Yahoo for VIX
        // Fear Greed is CNN (scraped?) or synthesized.
        // Let's use VIX and maybe simple synthesize.
        
        // Put/Call Ratio -> tricky.
        
        // Use Yahoo Macro
        let vixData = try? await yahoo.fetchMacro(symbol: "^VIX")
        let vix = vixData?.value
        
        // Synthesize Fear/Greed from VIX and Momentum
        // 0-100. VIX 20 -> 50. VIX 10 -> 80 (Greed). VIX 40 -> 20 (Fear).
        // Simple heuristic for now:
        var fg: Double? = nil
        if let v = vix {
            // VIX 10 = 90 Greed
            // VIX 20 = 50 Neutral
            // VIX 30 = 20 Fear
            // VIX 40 = 10 Extreme Fear
            
            if v <= 10 { fg = 90 }
            else if v >= 40 { fg = 10 }
            else {
                // Linear map 10..40 to 90..10
                // Slope = (10 - 90) / (40 - 10) = -80 / 30 = -2.66
                // y - 50 = -2.66 * (x - 20)
                fg = 50 - 2.66 * (v - 20)
            }
        }
        
        // Breadth - Requires scanning many symbols or fetching specific index internals (^AD)
        // Yahoo symbols: ^NYAD (Maybe?)
        // Else nil for now.
        
        return (
            SentimentData(vix: vix, fearGreed: fg, putCallRatio: nil),
            BreadthData(adRatio: nil, above200: nil, nhNl: nil)
        )
    }
    
    private func determineMarketMode(vix: Double?, fearGreed: Double?) -> MarketMode {
        if let v = vix {
            if v > 35 { return .panic }
            if v > 25 { return .fear }
            if v < 12 { return .complacency }
            if v < 15 { return .greed }
        }
        return .neutral
    }
    
    private struct RotationData {
        let phase: SectorRotationPhase?
        let leaders: [String]
        let laggards: [String]
    }
    
    private func analyzeSectorRotation() -> RotationData {
        // Requires comparing Sector ETFs (XLK, XLF, XLE, XLV, XLP, XLY, XLI, XLB, XLU, XLRE, XLC)
        // Not implemented in this first pass.
        return RotationData(phase: nil, leaders: [], laggards: [])
    }
}
