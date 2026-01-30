import Foundation

struct MetricDetail: Sendable {
    let value: Double
    let date: Date
    let ageDays: Int
    let status: String // "OK", "STALE", "MISSING"
}

struct MacroEvidence: Sendable {
    let source: String // "Aether 4.0"
    let confidence: Double
    
    // Raw Components with Metadata
    let inflation: MetricDetail? // Holds CPI YoY
    let labor: MetricDetail?     // Holds Sahm Value
    let rates: MetricDetail?     // Holds Yield Curve
    let growth: MetricDetail?    // Holds Payrolls MoM
    
    // Context Values
    let fedFunds: Double?
    let dgs10: Double?
    
    let missingSeries: [String]
}

struct MacroResult: Sendable {
    let output: EngineOutput
    let legacyRating: MacroEnvironmentRating
    let evidence: MacroEvidence
}

final class MacroRegimeService: @unchecked Sendable {
    static let shared = MacroRegimeService()
    
    // Internal Cache
    private var cachedResult: MacroResult?
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 5 * 60 // 5 Minutes (reduced for faster updates)
    
    private init() {
        // Startup Protection
        AetherCardsManifest.verify()
    }
    
    // MARK: - Public API (Heimdall 4.0)
    
    func evaluate(forceRefresh: Bool = false) async -> MacroResult {
        // 1. Check Cache
        if !forceRefresh, let cached = cachedResult, let last = lastFetchTime, -last.timeIntervalSinceNow < cacheDuration {
        // DEBUG: print("✅ Aether: Using Valid Cached Result (Score: \(cached.output.score10))")
            return cached
        }
        
        print("🌐 AETHER: Full refresh başlatılıyor...")
        let startTime = Date()

        
        // 2. Fetch Data (Parallel)
        async let fredPayload = fetchFredData()
        async let marketPayload = fetchMarketData()
        
        let (fredData, fredMissing) = await fredPayload
        let (marketData, marketMissing) = await marketPayload
        
        // 3. Compute Deterministic Score
        let config = AetherScoringConfig.load()
        let detResult = computeDeterministicScore(fred: fredData, market: marketData, config: config)
        
        var explain: [String] = []
        
        // Decision Logic
        if !fredMissing.isEmpty {
            explain.append("FRED verileri eksik: \(fredMissing.joined(separator: ",")).")
            print("⚠️ AETHER: FRED eksik = \(fredMissing)")
        }
        if !marketMissing.isEmpty {
            explain.append("Piyasa verileri eksik: \(marketMissing.joined(separator: ",")).")
            print("⚠️ AETHER: Market eksik = \(marketMissing)")
        }
        
        if detResult.penalty > 0 {
            explain.append("⚠️ STALE veri cezası uygulandı (\(Int(detResult.penalty)) birim).")
            print("⚠️ AETHER: STALE penalty = \(Int(detResult.penalty))")
        }
        
        // 5. Construct EngineOutput
        let finalScore10 = detResult.totalScore / 10.0
        let confidence = 1.0 - (Double(fredMissing.count + marketMissing.count) * 0.1) - (detResult.penalty > 0 ? 0.2 : 0.0)
        let duration = Date().timeIntervalSince(startTime) * 1000
        
        let output = EngineOutput(
            score10: finalScore10,
            confidence: max(confidence, 0.1),
            coverage: confidence, // Simplified
            freshnessSec: 0,
            status: confidence < 0.5 ? .degraded : .ok,
            explain: explain + ["Skor: \(Int(detResult.totalScore))/100", "Grade: \(MacroEnvironmentRating.letterGrade(for: detResult.totalScore))"],
            diagnostics: EngineDiagnostics(
                providerPath: "Heimdall->Aether",
                attemptCount: 1,
                lastErrorCategory: .none,
                symbolsUsed: marketMissing + fredMissing,
                latencyMs: duration
            )
        )
        
        // 6. Construct Legacy Rating (Adapter)
        // We use the breakdown to populate legacy fields
        let breakdown = detResult.breakdown
        
        // Extract individual scores
        let ratesScore = breakdown["rates"] ?? 50.0
        let vixScore = breakdown["vix"] ?? 50.0
        let claimsScoreVal = breakdown["claims"] ?? 50.0
        let btcScore = breakdown["btc"] ?? 50.0
        let trendScore = breakdown["trend"] ?? 50.0
        let growthScoreVal = breakdown["growth"] ?? 50.0
        let dxyScore = breakdown["dxy"] ?? 50.0
        let cpiScore = breakdown["cpi"] ?? 50.0
        let laborScoreVal = breakdown["labor"] ?? 50.0
        let gldScore = breakdown["gld"] ?? 50.0
        let creditScore = breakdown["credit"] ?? 50.0
        
        // Calculate raw category averages
        let leadingAvg = (ratesScore + vixScore + claimsScoreVal + btcScore) / 4.0
        let coincidentAvg = (trendScore + growthScoreVal + dxyScore) / 3.0
        let laggingAvg = (cpiScore + laborScoreVal + gldScore) / 3.0
        
        // Calculate weighted contributions
        let totalWeight = 3.3
        let leadingContrib = (leadingAvg * 1.5) / totalWeight
        let coincidentContrib = (coincidentAvg * 1.0) / totalWeight
        let laggingContrib = (laggingAvg * 0.8) / totalWeight
        
        // Calculate regime
        let regime: MacroRegime
        if detResult.totalScore > 60 { regime = .riskOn }
        else if detResult.totalScore < 40 { regime = .riskOff }
        else { regime = .neutral }
        
        let legacy = MacroEnvironmentRating(
            equityRiskScore: trendScore,
            volatilityScore: vixScore,
            safeHavenScore: gldScore,
            cryptoRiskScore: btcScore,
            interestRateScore: ratesScore,
            currencyScore: dxyScore,
            inflationScore: cpiScore,
            laborScore: laborScoreVal,
            growthScore: growthScoreVal,
            creditSpreadScore: creditScore,
            claimsScore: claimsScoreVal,
            leadingScore: leadingAvg,
            coincidentScore: coincidentAvg,
            laggingScore: laggingAvg,
            leadingContribution: leadingContrib,
            coincidentContribution: coincidentContrib,
            laggingContribution: laggingContrib,
            numericScore: detResult.totalScore,
            letterGrade: MacroEnvironmentRating.letterGrade(for: detResult.totalScore),
            regime: regime,
            summary: "Aether v5",
            details: explain.joined(separator: "\n"),
            missingComponents: fredMissing + marketMissing
        )
        
        // Metadata Injection
        var finalRating = legacy
        for (k, v) in detResult.statuses {
            finalRating.componentStatuses[k] = v
        }
        
        // Populate Changes
        finalRating.componentChanges["equity"] = calculateReturn(candles: marketData.spy)
        finalRating.componentChanges["volatility"] = calculateReturn(candles: marketData.vix)
        finalRating.componentChanges["gold"] = calculateReturn(candles: marketData.gld)
        finalRating.componentChanges["crypto"] = calculateReturn(candles: marketData.btc)
        finalRating.componentChanges["dollar"] = calculateReturn(candles: marketData.dxy)
        
        let evidence = MacroEvidence(
            source: "Aether 4.0",
            confidence: confidence,
            inflation: nil, labor: nil, rates: nil, growth: nil, fedFunds: nil, dgs10: nil, missingSeries: []
        )
        
        let result = MacroResult(output: output, legacyRating: finalRating, evidence: evidence)
        
        // 7. Update Cache
        self.cachedResult = result
        self.lastFetchTime = Date()
        self.saveWidgetData(rating: legacy, market: marketData)
        
        // 🔍 AETHER FORENSIC REPORT (ACTIVE)
        print("\n═══════════════════════════════════════════════════════════════")
        print("🔍 AETHER FORENSIC CARD REPORT")
        print("───────────────────────────────────────────────────────────────")
        print("[01] Enflasyon (CPI):   \(Int(breakdown["cpi"] ?? 0))/100 [\(detResult.statuses["cpi"] ?? "MISSING")]")
        print("[02] İstihdam (Labor):  \(Int(breakdown["labor"] ?? 0))/100 [\(detResult.statuses["labor"] ?? "MISSING")]")
        print("[03] Faizler (Rates):   \(Int(breakdown["rates"] ?? 0))/100 [\(detResult.statuses["rates"] ?? "MISSING")]")
        print("[04] Büyüme (Growth):   \(Int(breakdown["growth"] ?? 0))/100 [\(detResult.statuses["growth"] ?? "MISSING")]")
        print("[05] Trend (Equity):    \(Int(breakdown["trend"] ?? 0))/100 [\(detResult.statuses["trend"] ?? "MISSING")]")
        print("[06] Volatilite (VIX):  \(Int(breakdown["vix"] ?? 0))/100 [\(detResult.statuses["vix"] ?? "MISSING")]")
        print("[07] Altın (GLD):       \(Int(breakdown["gld"] ?? 0))/100 [\(detResult.statuses["gld"] ?? "MISSING")]")
        print("[08] Kripto (BTC):      \(Int(breakdown["btc"] ?? 0))/100 [\(detResult.statuses["btc"] ?? "MISSING")]")
        print("[09] Dolar (DXY):       \(Int(breakdown["dxy"] ?? 0))/100 [\(detResult.statuses["dxy"] ?? "MISSING")]")
        print("[10] Claims:            \(Int(breakdown["claims"] ?? 0))/100 [\(detResult.statuses["claims"] ?? "MISSING")]")
        print("[11] Credit:            \(Int(breakdown["credit"] ?? 0))/100 [\(detResult.statuses["credit"] ?? "MISSING")]")
        print("───────────────────────────────────────────────────────────────")
        print("📊 FINAL SCORE: \(Int(detResult.totalScore))/100 → Grade: \(MacroEnvironmentRating.letterGrade(for: detResult.totalScore))")
        print("⏱️ Duration: \(Int(duration))ms")
        print("═══════════════════════════════════════════════════════════════\n")
        
        return result

    }
    
    // Legacy Wrapper for UI
    func computeMacroEnvironment(forceRefresh: Bool = false) async -> MacroEnvironmentRating {
        let res = await evaluate(forceRefresh: forceRefresh)
        return res.legacyRating
    }
    
    func getCachedRating() -> MacroEnvironmentRating? {
        return cachedResult?.legacyRating
    }
    
    func getLastUpdate() -> Date? {
        return lastFetchTime
    }
    
    func getCurrentVix() -> Double {
        if let data = WidgetDataService.shared.loadAether() {
            return data.vixValue
        }
        return 20.0
    }
    
    // MARK: - Data Models
    
    private struct FredDataBundle {
        let cpi: [(Date, Double)]
        let unrate: [(Date, Double)]
        let payems: [(Date, Double)]
        let fedfunds: [(Date, Double)]
        let dgs10: [(Date, Double)]
        let dgs2: [(Date, Double)]
        let claims: [(Date, Double)] // ICSA - Initial Jobless Claims (Leading)
    }
    
    // MARK: - Trend Analysis (Aether v5)
    
    enum TrendDirection { case up, down, flat }
    
    struct TrendResult {
        let direction: TrendDirection
        let strength: Double      // 0-100 trend gücü
        let percentChange: Double // % değişim
    }
    
    /// Trend analizi - son N gözlemin yönü ve gücünü hesaplar
    private func analyzeTrend(_ values: [(Date, Double)], periods: Int = 3) -> TrendResult? {
        guard values.count >= periods else { return nil }

        let recent = Array(values.suffix(periods))
        guard let firstValue = recent.first?.1,
              let lastValue = recent.last?.1,
              firstValue != 0 else {
            return nil
        }
        let first = firstValue
        let last = lastValue
        let change = ((last - first) / first) * 100
        
        let direction: TrendDirection
        if change > 1.0 { direction = .up }
        else if change < -1.0 { direction = .down }
        else { direction = .flat }
        
        // Güç: Değişim büyüklüğüne göre (max ±20% → 100)
        let strength = min(100, abs(change) * 5)
        
        return TrendResult(direction: direction, strength: strength, percentChange: change)
    }
    
    private struct MarketDataBundle {
        let spy: [Candle]
        let vix: [Candle]
        let dxy: [Candle]
        let gld: [Candle]
        let btc: [Candle]
        let hyg: [Candle]  // NEW: High Yield Bond ETF
        let lqd: [Candle]  // NEW: Investment Grade Bond ETF
    }
    
    // MARK: - Fetching
    
    private func fetchFredData() async -> (FredDataBundle, [String]) {
        // Heimdall 6.2: SEQUENTIAL FRED Fetching with Rate Limiting Protection
        // FRED API bazen rate limiting uyguluyor, istekleri sıralı + gecikmeli yapıyoruz
        
        var rCpi: [(Date, Double)] = []
        var rUnrate: [(Date, Double)] = []
        var rPayems: [(Date, Double)] = []
        var rFed: [(Date, Double)] = []
        var rDgs10: [(Date, Double)] = []
        var rDgs2: [(Date, Double)] = []
        var rClaims: [(Date, Double)] = []
        var rGdp: [(Date, Double)] = []
        
        // Sıralı istekler - aralarına 500ms gecikme
        rCpi = await fetchSeriesSafe(instrument: .cpi)
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        rUnrate = await fetchSeriesSafe(instrument: .labor)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        rPayems = await fetchSeriesSafe(instrument: CanonicalInstrument(internalId: "PAYEMS", displayName: "Payrolls", assetType: .index, yahooSymbol: nil, fredSeriesId: "PAYEMS", twelveDataSymbol: nil, sourceType: .macroSeries))
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        rFed = await fetchSeriesSafe(instrument: CanonicalInstrument(internalId: "FEDFUNDS", displayName: "Fed Funds", assetType: .index, yahooSymbol: nil, fredSeriesId: "FEDFUNDS", twelveDataSymbol: nil, sourceType: .macroSeries))
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        rDgs10 = await fetchSeriesSafe(instrument: .rates) // DGS10
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        rDgs2 = await fetchSeriesSafe(instrument: .bond2y) // DGS2
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        rClaims = await fetchSeriesSafe(instrument: .claims) // ICSA
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        rGdp = await fetchSeriesSafe(instrument: .growth) // GDPC1
        
        var missing: [String] = []
        if rCpi.isEmpty { missing.append("CPI") }
        if rUnrate.isEmpty { missing.append("UNRATE") }
        if rGdp.isEmpty { missing.append("GDP") }
        if rClaims.isEmpty { missing.append("ICSA") }
        
        return (FredDataBundle(cpi: rCpi, unrate: rUnrate, payems: rPayems, fedfunds: rFed, dgs10: rDgs10, dgs2: rDgs2, claims: rClaims), missing)
    }
    
    // Helper to safely fetch series or return empty
    private func fetchSeriesSafe(instrument: CanonicalInstrument) async -> [(Date, Double)] {
        do {
            let result = try await HeimdallOrchestrator.shared.requestMacroSeries(instrument: instrument, limit: 12)
            // DEBUG: print("✅ FRED: \(instrument.internalId) -> \(result.count) observations")
            return result
        } catch {
            // DEBUG: print("❌ FRED FAIL: \(instrument.internalId) -> \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchMarketData() async -> (MarketDataBundle, [String]) {
        async let spy = fetchWithResilience(asset: .spy, count: 60)
        async let vix = fetchWithResilience(asset: .vix, count: 60)
        async let dxy = fetchWithResilience(asset: .dxy, count: 60)
        async let gld = fetchWithResilience(asset: .gold, count: 60)
        async let btc = fetchWithResilience(asset: .btc, count: 60)
        // NEW: Credit Spread Components
        async let hyg = fetchWithResilience(asset: CanonicalInstrument(internalId: "HYG", displayName: "High Yield Bond", assetType: .etf, yahooSymbol: "HYG", fredSeriesId: nil, twelveDataSymbol: "HYG", sourceType: .market), count: 60)
        async let lqd = fetchWithResilience(asset: CanonicalInstrument(internalId: "LQD", displayName: "Investment Grade Bond", assetType: .etf, yahooSymbol: "LQD", fredSeriesId: nil, twelveDataSymbol: "LQD", sourceType: .market), count: 60)
        
        let s = await spy
        let v = await vix
        let d = await dxy
        let g = await gld
        let b = await btc
        let h = await hyg
        let l = await lqd
        
        var missing: [String] = []
        if s == nil { missing.append("SPY") }
        if v == nil { missing.append("VIX") }
        if d == nil { missing.append("DXY") }
        if g == nil { missing.append("GLD") }
        if b == nil { missing.append("BTC") }
        // HYG/LQD missing is not critical, just noted
        
        return (MarketDataBundle(spy: s ?? [], vix: v ?? [], dxy: d ?? [], gld: g ?? [], btc: b ?? [], hyg: h ?? [], lqd: l ?? []), missing)
    }
    
    // MARK: - Aether 4.0 Deterministic Scoring
    
    struct DeterministicResult {
        let totalScore: Double
        let breakdown: [String: Double]
        let statuses: [String: String]
        let penalty: Double
    }

    private func computeDeterministicScore(fred: FredDataBundle, market: MarketDataBundle, config: AetherScoringConfig) -> DeterministicResult {
        var weightedSum = 0.0
        var totalWeight = 0.0
        var breakdown: [String: Double] = [:]
        var statuses: [String: String] = [:]
        var penaltyFlag = 0.0
        
        let now = Date()
        
        // HEIMDALL 6.1: Frequency-Based Stale Logic
        func process(_ key: String, _ score: Double, _ date: Date?, _ frequency: String, _ weight: Double) {
            var finalWeight = weight
            
            // Determine Threshold
            let staleDays: Int
            switch frequency {
            case "Daily": staleDays = 5
            case "Weekly": staleDays = 14
            case "Monthly": staleDays = 45 // CPI, Labor: ~1 month + lag
            case "Quarterly": staleDays = 150 // GDP: ~3 months + lag
            default: staleDays = 7
            }
            
            if let d = date {
                // Ensure age is positive
                let age = max(0, Calendar.current.dateComponents([.day], from: d, to: now).day ?? 999)
                if age > staleDays {
                    statuses[key] = "STALE (\(age)d)"
                    finalWeight *= 0.5
                    penaltyFlag += 2.0 // Penalize score confidence
                } else {
                    statuses[key] = "OK"
                }
            } else {
                statuses[key] = "MISSING"
                finalWeight = 0.0
            }
            
            weightedSum += score * finalWeight
            totalWeight += finalWeight
            breakdown[key] = score
        }
        
        // 1. CPI (Monthly) - YoY Inflation Analysis
        // High CPI -> Risk Off -> Low Score
        // Target 2%: Score 100. >5%: Score 0.
        var cpiScore = 50.0
        if fred.cpi.count >= 12,
           let currentCPI = fred.cpi.last?.1 {
            // Calculate Year-over-Year inflation (güvenli index erişimi)
            let yearAgoIndex = fred.cpi.count - 12
            let current = currentCPI
            let yearAgo = fred.cpi[yearAgoIndex].1
            if yearAgo > 0 {
                let yoyInflation = ((current - yearAgo) / yearAgo) * 100
                
                // Score: 2% = 100, 5%+ = 0, linear in between
                if yoyInflation <= 2.0 {
                    cpiScore = 100.0
                } else if yoyInflation >= 5.0 {
                    cpiScore = 0.0
                } else {
                    cpiScore = 100.0 - ((yoyInflation - 2.0) / 3.0 * 100.0)
                }
                // DEBUG: print("📊 AETHER CPI: YoY=\(String(format: "%.2f", yoyInflation))% -> Score=\(Int(cpiScore))")
            }
        } else if fred.cpi.count > 0 {
            // Not enough for YoY but have some data
            // DEBUG: print("⚠️ AETHER CPI: Only \(fred.cpi.count) observations, need 12 for YoY")
        }
        
        // AETHER v5.1: Beklenti Sürprizi Etkisi
        // Kullanıcının girdiği beklentilerden sapma skora etki eder (±10 puan)
        let cpiSurprise = ExpectationsStore.shared.getSurpriseImpactSync(for: .cpi)
        if cpiSurprise != 0 {
            cpiScore = min(100, max(0, cpiScore + cpiSurprise))
            print("📊 AETHER: CPI Sürpriz Etkisi = \(String(format: "%+.1f", cpiSurprise)) puan → Yeni Skor: \(Int(cpiScore))")
        }
        process("cpi", cpiScore, fred.cpi.last?.0, "Monthly", config.weights.cpi)
        
        // 2. Labor (Monthly) - Granular Unemployment Scoring
        // Natural Rate ~4%, Full Employment < 4%, Crisis > 7%
        var laborScore = 50.0
        if let ur = fred.unrate.last?.1 {
            if ur < 4.0 {
                laborScore = 90 // Full employment = very bullish
            } else if ur < 5.0 {
                laborScore = 80 - ((ur - 4.0) * 20) // 4-5% = 60-80
            } else if ur < 6.0 {
                laborScore = 60 - ((ur - 5.0) * 20) // 5-6% = 40-60
            } else if ur < 8.0 {
                laborScore = 40 - ((ur - 6.0) * 15) // 6-8% = 10-40
            } else {
                laborScore = 10 // Crisis
            }
            // DEBUG: print("📊 AETHER LABOR: Unemployment=\(String(format: "%.1f", ur))% -> Score=\(Int(laborScore))")
        }
        
        // AETHER v5.1: Beklenti Sürprizi - İşsizlik
        let laborSurprise = ExpectationsStore.shared.getSurpriseImpactSync(for: .unemployment)
        if laborSurprise != 0 {
            laborScore = min(100, max(0, laborScore + laborSurprise))
            print("📊 AETHER: Labor Sürpriz Etkisi = \(String(format: "%+.1f", laborSurprise)) puan → Yeni Skor: \(Int(laborScore))")
        }
        process("labor", laborScore, fred.unrate.last?.0, "Monthly", config.weights.labor)
        
        // 3. Rates (Yield Curve) - Granular Spread Scoring
        // Positive slope = healthy, Inverted = recession warning
        var ratesScore = 50.0
        if let y10 = fred.dgs10.last?.1, let y2 = fred.dgs2.last?.1 {
            let spread = y10 - y2
            if spread > 1.5 {
                ratesScore = 90 // Very healthy curve
            } else if spread > 0.5 {
                ratesScore = 70 + ((spread - 0.5) * 20) // 0.5-1.5 = 70-90
            } else if spread > 0 {
                ratesScore = 50 + (spread * 40) // 0-0.5 = 50-70
            } else if spread > -0.5 {
                ratesScore = 30 + ((spread + 0.5) * 40) // -0.5-0 = 30-50
            } else {
                ratesScore = max(10, 30 + (spread * 20)) // < -0.5 = 10-30
            }
            // DEBUG: print("📊 AETHER RATES: 10Y-2Y Spread=\(String(format: "%.2f", spread))% -> Score=\(Int(ratesScore))")
        }
        process("rates", ratesScore, fred.dgs10.last?.0, "Daily", config.weights.rates)
        
        // 4. Growth (Payrolls MoM Change) - Granular
        var growthScore = 50.0
        if fred.payems.count >= 2,
           let currentPayems = fred.payems.last?.1 {
            // Güvenli index erişimi
            let previousIndex = fred.payems.count - 2
            let current = currentPayems
            let previous = fred.payems[previousIndex].1
            let momChange = (current - previous) // Actual job gains/losses in thousands
            
            if momChange > 200 {
                growthScore = 95 // Strong expansion
            } else if momChange > 100 {
                growthScore = 80 + ((momChange - 100) * 0.15) // 100-200K = 80-95
            } else if momChange > 0 {
                growthScore = 60 + (momChange * 0.2) // 0-100K = 60-80
            } else if momChange > -100 {
                growthScore = 40 + (momChange * 0.2) // -100-0K = 20-40
            } else {
                growthScore = max(5, 40 + (momChange * 0.15)) // < -100K = 5-20
            }
            // DEBUG: print("📊 AETHER GROWTH: Payrolls MoM=\(String(format: "%.0f", momChange))K -> Score=\(Int(growthScore))")
        }
        process("growth", growthScore, fred.payems.last?.0, "Monthly", config.weights.growth)
        
        // 5. Currency (DXY)
        var dxyScore = 50.0
        if let last = market.dxy.last?.close, !market.dxy.isEmpty {
           let count = market.dxy.count
           if count >= 50 {
               // Standard SMA Logic
               let sma = market.dxy.reduce(0) { $0 + $1.close } / Double(count)
               dxyScore = last > sma ? 40 : 70
               statuses["dxy"] = "OK"
           } else {
               // Flash Trend Logic
               let first = market.dxy.first?.close ?? last
               dxyScore = last > first ? 45 : 65 // Less confidence
               statuses["dxy"] = "FLASH (\(count))"
           }
        } else {
           statuses["dxy"] = "MISSING"
        }
        process("dxy", dxyScore, market.dxy.last?.date, "Daily", 1.0)
        
        // 6. VIX (Fear Gauge)
        var vixScore = 50.0
        if let v = market.vix.last?.close {
             // VIX < 15 -> Calm (Score 90)
             // VIX > 30 -> Panic (Score 10)
             // Linear interpolation 15...30
             if v < 15 { vixScore = 90 }
             else if v > 30 { vixScore = 10 }
             else {
                 vixScore = 90 - ((v - 15) / 15.0 * 80.0)
             }
        }
        process("vix", vixScore, market.vix.last?.date, "Daily", config.weights.vix)
        
        // 6. Trend (SPY)
        var trendScore = 50.0
        if let s = market.spy.last?.close, !market.spy.isEmpty {
             let count = market.spy.count
             if count >= 50 {
                 let sma = market.spy.reduce(0) { $0 + $1.close } / Double(count)
                 if s > sma {
                     trendScore = 80
                 } else {
                     let dist = (sma - s) / sma
                     trendScore = dist > 0.05 ? 20 : 40
                 }
                 statuses["trend"] = "OK"
             } else {
                 // Flash Mode
                 let first = market.spy.first?.close ?? s
                 trendScore = s > first ? 65 : 45
                 statuses["trend"] = "FLASH (\(count))"
             }
        } else {
             statuses["trend"] = "MISSING"
        }
        process("trend", trendScore, market.spy.last?.date, "Daily", config.weights.trend)
        
        // 7. GLD (Safe Haven) - Granular vs SMA
        // Rising Gold = Flight to Safety = Risk Off = Lower Score
        var gldScore = 50.0
        if let last = market.gld.last?.close, !market.gld.isEmpty {
            let count = market.gld.count
            if count >= 20 {
                let sma = market.gld.suffix(20).reduce(0) { $0 + $1.close } / 20.0
                let deviation = (last - sma) / sma * 100 // % deviation from SMA20
                
                // Gold above SMA = people fleeing to safety = bearish for risk
                if deviation > 5 {
                    gldScore = 15 // Strong flight to safety
                } else if deviation > 2 {
                    gldScore = 30 - ((deviation - 2) * 5) // 2-5% above = 15-30
                } else if deviation > 0 {
                    gldScore = 50 - (deviation * 10) // 0-2% above = 30-50
                } else if deviation > -2 {
                    gldScore = 50 + (-deviation * 15) // 0-2% below = 50-80
                } else {
                    gldScore = 85 // Gold weak = risk on
                }
                statuses["gld"] = "OK"
                // DEBUG: print("📊 AETHER GLD: Deviation=\(String(format: "%.1f", deviation))% -> Score=\(Int(gldScore))")
            } else {
                statuses["gld"] = "FLASH (\(count))"
            }
        } else {
            statuses["gld"] = "MISSING"
        }
        process("gld", gldScore, market.gld.last?.date, "Daily", config.weights.gld)
        
        // 8. BTC (Risk Appetite Proxy) - Granular vs SMA
        // BTC rising = Risk On appetite, BTC falling = Risk Off
        var btcScore = 50.0
        if let last = market.btc.last?.close, !market.btc.isEmpty {
            let count = market.btc.count
            if count >= 20 {
                let sma = market.btc.suffix(20).reduce(0) { $0 + $1.close } / 20.0
                let deviation = (last - sma) / sma * 100 // % deviation
                
                // BTC above SMA = risk appetite = bullish
                if deviation > 10 {
                    btcScore = 95 // Strong risk on
                } else if deviation > 5 {
                    btcScore = 80 + ((deviation - 5) * 3) // 5-10% = 80-95
                } else if deviation > 0 {
                    btcScore = 60 + (deviation * 4) // 0-5% = 60-80
                } else if deviation > -5 {
                    btcScore = 40 + ((5 + deviation) * 4) // -5-0% = 40-60
                } else if deviation > -10 {
                    btcScore = 20 + ((10 + deviation) * 4) // -10--5% = 20-40
                } else {
                    btcScore = 10 // Crypto crash = risk off
                }
                statuses["btc"] = "OK"
                // DEBUG: print("📊 AETHER BTC: Deviation=\(String(format: "%.1f", deviation))% -> Score=\(Int(btcScore))")
            } else {
                statuses["btc"] = "FLASH (\(count))"
            }
        } else {
            statuses["btc"] = "MISSING"
        }
        process("btc", btcScore, market.btc.last?.date, "Daily", config.weights.btc)
        
        // 9. CREDIT SPREAD (NEW - Financial Stress Indicator)
        // HYG (High Yield) vs LQD (Investment Grade)
        // Widening spread = Risk Off, Narrowing = Risk On
        var creditScore = 50.0
        if let hygLast = market.hyg.last?.close, let lqdLast = market.lqd.last?.close,
           let hygFirst = market.hyg.first?.close, let lqdFirst = market.lqd.first?.close,
           !market.hyg.isEmpty && !market.lqd.isEmpty {
            // Calculate relative performance (HYG/LQD ratio)
            let currentRatio = hygLast / lqdLast
            let pastRatio = hygFirst / lqdFirst
            let ratioChange = (currentRatio - pastRatio) / pastRatio * 100
            
            // HYG outperforming LQD = Risk On
            // HYG underperforming LQD = Risk Off (flight to quality)
            if ratioChange > 2.0 { creditScore = 85 }  // Strong Risk On
            else if ratioChange > 0 { creditScore = 70 }
            else if ratioChange > -2.0 { creditScore = 45 }
            else { creditScore = 20 }  // Credit stress
            statuses["credit"] = "OK"
        } else {
            statuses["credit"] = "MISSING"
        }
        process("credit", creditScore, market.hyg.last?.date, "Daily", 1.5)  // 15% weight
        
        // 10. CLAIMS (Initial Jobless Claims - LEADING INDICATOR)
        // Falling claims = Strong labor market = Bullish
        // Rising claims = Weakening economy = Bearish
        var claimsScore = 50.0
        if fred.claims.count >= 4 {
            // Use trend analysis for weekly data
            if let trend = analyzeTrend(fred.claims, periods: 4) {
                // Falling claims = good (inverse scoring)
                if trend.direction == .down {
                    claimsScore = 70 + min(30, trend.strength * 0.5) // 70-100
                } else if trend.direction == .flat {
                    claimsScore = 50
                } else {
                    claimsScore = 50 - min(40, trend.strength * 0.6) // 10-50
                }
                // DEBUG: print("📊 AETHER CLAIMS: Trend=\(trend.direction) (\(String(format: "%.1f", trend.percentChange))%) -> Score=\(Int(claimsScore))")
                statuses["claims"] = "OK"
            }
        } else {
            statuses["claims"] = "MISSING"
        }
        process("claims", claimsScore, fred.claims.last?.0, "Weekly", 1.0)
        
        // ═══════════════════════════════════════════════════════════════════
        // AETHER v5: KATEGORİZE SKOR HESAPLAMA
        // ═══════════════════════════════════════════════════════════════════
        
        // 🟢 ÖNCÜ (Leading) - x1.5 ağırlık - Geleceği tahmin eder
        let leadingScores: [Double] = [
            breakdown["rates"] ?? 50,   // Yield Curve
            breakdown["vix"] ?? 50,     // VIX
            breakdown["claims"] ?? 50,  // Initial Claims
            breakdown["btc"] ?? 50      // Bitcoin
        ]
        let leadingAvg = leadingScores.reduce(0.0, +) / Double(leadingScores.count)
        
        // 🟡 EŞZAMANLI (Coincident) - x1.0 ağırlık - Şu anı gösterir
        let coincidentScores: [Double] = [
            breakdown["trend"] ?? 50,   // SPY Trend
            breakdown["growth"] ?? 50,  // Payrolls
            breakdown["dxy"] ?? 50      // DXY
        ]
        let coincidentAvg = coincidentScores.reduce(0.0, +) / Double(coincidentScores.count)
        
        // 🔴 GECİKMELİ (Lagging) - x0.8 ağırlık - Geçmişi onaylar
        let laggingScores: [Double] = [
            breakdown["cpi"] ?? 50,     // CPI Inflation
            breakdown["labor"] ?? 50,   // Unemployment
            breakdown["gld"] ?? 50      // Gold
        ]
        let laggingAvg = laggingScores.reduce(0.0, +) / Double(laggingScores.count)
        
        // Ağırlıklı ortalama: Leading x1.5, Coincident x1.0, Lagging x0.8
        let totalCatWeight = 1.5 + 1.0 + 0.8
        let categorizedScore = (leadingAvg * 1.5 + coincidentAvg * 1.0 + laggingAvg * 0.8) / totalCatWeight
        
        // DEBUG: print("═══════════════════════════════════════════════════════════════")
        // DEBUG: print("📊 AETHER v5 KATEGORİ SKORLARI:")
        // DEBUG: print("   🟢 Öncü (x1.5):     \(String(format: "%.0f", leadingAvg))")
        // DEBUG: print("   🟡 Eşzamanlı (x1.0): \(String(format: "%.0f", coincidentAvg))")
        // DEBUG: print("   🔴 Gecikmeli (x0.8): \(String(format: "%.0f", laggingAvg))")
        // DEBUG: print("   ══════════════════════════════════")
        // DEBUG: print("   📈 FİNAL SKOR:      \(String(format: "%.0f", categorizedScore))/100")
        // DEBUG: print("═══════════════════════════════════════════════════════════════")
        
        return DeterministicResult(totalScore: categorizedScore, breakdown: breakdown, statuses: statuses, penalty: penaltyFlag)
    }

    private func fetchWithResilience(asset: CanonicalInstrument, count: Int) async -> [Candle]? {
        // Heimdall 5.4: Use Canonical Resolver via Orchestrator
        return try? await HeimdallTelepresence.shared.trace(
            engine: .aether,
            provider: .unknown,
            symbol: asset.rawValue,
            canonicalAsset: asset
        ) {
            let candles = try await HeimdallOrchestrator.shared.requestInstrumentCandles(instrument: asset, timeframe: "1D", limit: count)
            // HEIMDALL 6.3: "No Missing" Policy
            // We accept whatever data we have. Logic layer will handle low-resolution data.
            return candles
        }
    }
    
    private func saveWidgetData(rating: MacroEnvironmentRating, market: MarketDataBundle) {
        let widgetData = WidgetAetherData(
            score: rating.numericScore,
            regime: rating.regime.displayName,
            summary: rating.summary,
            lastUpdated: Date(),
            spyChange: calculateReturn(candles: market.spy), 
            vixValue: market.vix.last?.close ?? 0,
            gldChange: calculateReturn(candles: market.gld), 
            btcChange: calculateReturn(candles: market.btc)
        )
        WidgetDataService.shared.saveAether(data: widgetData)
    }
    
    private func calculateReturn(candles: [Candle]) -> Double {
        // FIX: Günlük değişim hesapla (son 2 candle), 60 günlük DEĞİL!
        guard candles.count >= 2 else { return 0 }
        let current = candles[candles.count - 1].close
        let previous = candles[candles.count - 2].close
        guard previous != 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
}

extension MacroEnvironmentRating {
    static func letterGrade(for score: Double) -> String {
        switch score {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 45..<60: return "D"
        default: return "F"
        }
    }
}
