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

        
        let previousRating = cachedResult?.legacyRating

        // 2. Fetch Data (Parallel)
        async let fredPayload = fetchFredData()
        async let marketPayload = fetchMarketData()
        
        let (fredData, fredMissing) = await fredPayload
        let (marketData, marketMissing) = await marketPayload
        
        // 3. Compute Deterministic Score
        let config = AetherScoringConfig.load()
        let detResult = computeDeterministicScore(
            fred: fredData,
            market: marketData,
            config: config,
            previousRating: previousRating
        )
        
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

        if detResult.shockState != .stable {
            var shockText = "VIX şok kapısı aktif: \(detResult.shockState.rawValue)"
            if let pulse = detResult.vixPulse {
                shockText += String(
                    format: " (VIX %.1f | 1G %+.1f | 5G %+.1f)",
                    pulse.level,
                    pulse.oneDayChangePct,
                    pulse.fiveDayChangePct
                )
            }
            explain.append(shockText)
        }

        explain.append(contentsOf: detResult.adjustmentNotes)
        
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
        
        let regime = determineRegime(
            score: detResult.totalScore,
            previous: previousRating?.regime,
            shockState: detResult.shockState
        )
        
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
        if let pulse = detResult.vixPulse {
            print("[12] Shock Gate:        \(detResult.shockState.rawValue) (VIX \(String(format: "%.1f", pulse.level)) | 1G \(String(format: "%+.1f%%", pulse.oneDayChangePct)) | 5G \(String(format: "%+.1f%%", pulse.fiveDayChangePct)))")
        } else {
            print("[12] Shock Gate:        \(detResult.shockState.rawValue)")
        }
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

    private enum ShockState: String {
        case stable = "STABLE"
        case caution = "CAUTION"
        case riskOff = "RISK_OFF"
        case panic = "PANIC"
    }

    private struct VixPulse {
        let level: Double
        let oneDayChangePct: Double
        let fiveDayChangePct: Double
        let oneDayChangePoints: Double
        let fiveDayChangePoints: Double
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
        // Heimdall 6.3: Parallel + Timeout fetch.
        // Amaç: tek bir seri geciktiğinde tüm Aether pipeline'ının 15-30sn kilitlenmesini önlemek.
        async let rCpi = fetchSeriesSafe(instrument: .cpi)
        async let rUnrate = fetchSeriesSafe(instrument: .labor)
        async let rPayems = fetchSeriesSafe(
            instrument: CanonicalInstrument(
                internalId: "PAYEMS",
                displayName: "Payrolls",
                assetType: .index,
                yahooSymbol: nil,
                fredSeriesId: "PAYEMS",
                twelveDataSymbol: nil,
                sourceType: .macroSeries
            )
        )
        async let rFed = fetchSeriesSafe(
            instrument: CanonicalInstrument(
                internalId: "FEDFUNDS",
                displayName: "Fed Funds",
                assetType: .index,
                yahooSymbol: nil,
                fredSeriesId: "FEDFUNDS",
                twelveDataSymbol: nil,
                sourceType: .macroSeries
            )
        )
        async let rDgs10 = fetchSeriesSafe(instrument: .rates)
        async let rDgs2 = fetchSeriesSafe(instrument: .bond2y)
        async let rClaims = fetchSeriesSafe(instrument: .claims)
        async let rGdp = fetchSeriesSafe(instrument: .growth)

        let cpi = await rCpi
        let unrate = await rUnrate
        let payems = await rPayems
        let fedFunds = await rFed
        let dgs10 = await rDgs10
        let dgs2 = await rDgs2
        let claims = await rClaims
        let gdp = await rGdp
        
        var missing: [String] = []
        if cpi.isEmpty { missing.append("CPI") }
        if unrate.isEmpty { missing.append("UNRATE") }
        if gdp.isEmpty { missing.append("GDP") }
        if claims.isEmpty { missing.append("ICSA") }
        
        return (
            FredDataBundle(
                cpi: cpi,
                unrate: unrate,
                payems: payems,
                fedfunds: fedFunds,
                dgs10: dgs10,
                dgs2: dgs2,
                claims: claims
            ),
            missing
        )
    }
    
    // Helper to safely fetch series or return empty
    private func fetchSeriesSafe(instrument: CanonicalInstrument, timeoutSeconds: Double = 7.0) async -> [(Date, Double)] {
        await withTaskGroup(of: [(Date, Double)].self) { group in
            group.addTask {
                do {
                    return try await HeimdallOrchestrator.shared.requestMacroSeries(instrument: instrument, limit: 12)
                } catch {
                    return []
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return []
            }

            let result = await group.next() ?? []
            group.cancelAll()
            return result
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
    
    private struct DeterministicResult {
        let totalScore: Double
        let breakdown: [String: Double]
        let statuses: [String: String]
        let penalty: Double
        let shockState: ShockState
        let vixPulse: VixPulse?
        let adjustmentNotes: [String]
    }

    private func calculateChange(candles: [Candle], lookbackDays: Int) -> (pct: Double, points: Double)? {
        let ordered = normalizeCandles(candles)
        guard ordered.count > lookbackDays else { return nil }
        let current = ordered[ordered.count - 1].close
        let previous = ordered[ordered.count - 1 - lookbackDays].close
        guard previous != 0 else { return nil }
        let pct = ((current - previous) / previous) * 100.0
        let points = current - previous
        return (pct, points)
    }

    private func buildVixPulse(from candles: [Candle]) -> VixPulse? {
        let ordered = normalizeCandles(candles)
        guard let level = ordered.last?.close else { return nil }
        let oneDay = calculateChange(candles: ordered, lookbackDays: 1) ?? (0.0, 0.0)
        let fiveDay = calculateChange(candles: ordered, lookbackDays: 5) ?? (0.0, 0.0)
        return VixPulse(
            level: level,
            oneDayChangePct: oneDay.pct,
            fiveDayChangePct: fiveDay.pct,
            oneDayChangePoints: oneDay.points,
            fiveDayChangePoints: fiveDay.points
        )
    }

    private func classifyShock(vixPulse: VixPulse?) -> ShockState {
        guard let pulse = vixPulse else { return .stable }

        let severeVelocity = pulse.oneDayChangePct >= 18 || pulse.fiveDayChangePct >= 35 || pulse.oneDayChangePoints >= 4 || pulse.fiveDayChangePoints >= 8
        let moderateVelocity = pulse.oneDayChangePct >= 10 || pulse.fiveDayChangePct >= 20 || pulse.oneDayChangePoints >= 2.5 || pulse.fiveDayChangePoints >= 5

        if pulse.level >= 35 || (pulse.level >= 28 && severeVelocity) {
            return .panic
        }
        if pulse.level >= 28 || (pulse.level >= 24 && moderateVelocity) {
            return .riskOff
        }
        if pulse.level >= 22 || (pulse.level >= 18 && moderateVelocity) {
            return .caution
        }

        return .stable
    }

    private func determineRegime(score: Double, previous: MacroRegime?, shockState: ShockState) -> MacroRegime {
        if shockState == .panic || shockState == .riskOff {
            return .riskOff
        }

        let riskOnEntry = 62.0
        let riskOnExit = 48.0
        let riskOffEntry = 38.0
        let riskOffExit = 52.0

        switch previous {
        case .riskOn:
            if score <= riskOnExit {
                return score <= riskOffEntry ? .riskOff : .neutral
            }
            return .riskOn

        case .riskOff:
            if score >= riskOffExit {
                return score >= riskOnEntry ? .riskOn : .neutral
            }
            return .riskOff

        case .neutral, .none:
            if score >= riskOnEntry { return .riskOn }
            if score <= riskOffEntry { return .riskOff }
            return .neutral
        }
    }

    private func computeDeterministicScore(
        fred: FredDataBundle,
        market: MarketDataBundle,
        config: AetherScoringConfig,
        previousRating: MacroEnvironmentRating?
    ) -> DeterministicResult {
        var weightedSum = 0.0
        var totalWeight = 0.0
        var breakdown: [String: Double] = [:]
        var statuses: [String: String] = [:]
        var penaltyFlag = 0.0
        var adjustmentNotes: [String] = []
        let vixPulse = buildVixPulse(from: market.vix)
        let shockState = classifyShock(vixPulse: vixPulse)
        
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
        if let pulse = vixPulse {
             let v = pulse.level

             // Seviye skoru: VIX yükseldikçe skor monoton düşer.
             if v < 12 {
                 vixScore = 95
             } else if v < 18 {
                 vixScore = 95 - ((v - 12) / 6.0 * 20.0) // 95 -> 75
             } else if v < 24 {
                 vixScore = 75 - ((v - 18) / 6.0 * 25.0) // 75 -> 50
             } else if v < 30 {
                 vixScore = 50 - ((v - 24) / 6.0 * 25.0) // 50 -> 25
             } else if v < 40 {
                 vixScore = 25 - ((v - 30) / 10.0 * 20.0) // 25 -> 5
             } else {
                 vixScore = 5
             }

             // İvme etkisi: VIX yukarı hızlanıyorsa ekstra ceza, düşüyorsa sınırlı bonus.
             let upwardPenalty1D = max(0, pulse.oneDayChangePct - 4) * 0.8
             let upwardPenalty5D = max(0, pulse.fiveDayChangePct - 8) * 0.35
             let downwardBonus1D = max(0, -pulse.oneDayChangePct - 4) * 0.3
             let downwardBonus5D = max(0, -pulse.fiveDayChangePct - 8) * 0.15

             vixScore -= min(20, upwardPenalty1D)
             vixScore -= min(14, upwardPenalty5D)
             vixScore += min(8, downwardBonus1D + downwardBonus5D)
             vixScore = max(0, min(100, vixScore))

             statuses["vix_pulse"] = String(
                 format: "L%.1f 1G%+.1f 5G%+.1f",
                 pulse.level,
                 pulse.oneDayChangePct,
                 pulse.fiveDayChangePct
             )
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
        
        // 8. BTC (Risk Appetite Proxy)
        // Trend (SMA sapması) + Momentum (1G/5G) birlikte değerlendirilir.
        var btcScore = 50.0
        if let last = market.btc.last?.close, !market.btc.isEmpty {
            let count = market.btc.count
            if count >= 20 {
                let sma = market.btc.suffix(20).reduce(0) { $0 + $1.close } / 20.0
                let deviation = sma != 0 ? ((last - sma) / sma * 100.0) : 0.0

                // Trend skoru: SMA üstü yüksek, altı düşük.
                let trendScore = 50.0 + max(-45.0, min(45.0, deviation * 3.2))

                // Momentum skoru: kısa vadeli ivme.
                let oneDayPct = calculateChange(candles: market.btc, lookbackDays: 1)?.pct ?? 0.0
                let fiveDayPct = calculateChange(candles: market.btc, lookbackDays: 5)?.pct ?? 0.0
                let momentumMix = (oneDayPct * 0.35) + (fiveDayPct * 0.65)
                let momentumScore = 50.0 + max(-35.0, min(35.0, momentumMix * 2.1))

                btcScore = (trendScore * 0.65) + (momentumScore * 0.35)

                // Aynı yönde güçleniyorsa ekstra etki; çatışma varsa yumuşatma.
                if momentumMix > 3, deviation > 0 { btcScore += 4 }
                if momentumMix < -3, deviation < 0 { btcScore -= 4 }
                if momentumMix > 0, deviation < -8 { btcScore = max(btcScore, 42) }

                btcScore = max(0, min(100, btcScore))
                statuses["btc_signal"] = String(
                    format: "d%+.1f 1G%+.1f 5G%+.1f",
                    deviation,
                    oneDayPct,
                    fiveDayPct
                )
            } else {
                let first = market.btc.first?.close ?? last
                let flashPct = first != 0 ? ((last - first) / first) * 100.0 : 0.0
                btcScore = 50.0 + max(-20.0, min(20.0, flashPct * 1.8))
                btcScore = max(0, min(100, btcScore))
                statuses["btc_signal"] = "FLASH (\(count))"
            }
        } else {
            statuses["btc_signal"] = "MISSING"
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
        
        // Şok döneminde trend/BTC katkı tavanı sadece final skora uygulanır.
        // UI kartındaki ham bileşen skoru korunur.
        let rawTrendScore = breakdown["trend"] ?? 50
        let rawBtcScore = breakdown["btc"] ?? 50
        var effectiveTrendScore = rawTrendScore
        var effectiveBtcScore = rawBtcScore

        if shockState != .stable {
            let trendCeiling: Double
            let btcCeiling: Double
            switch shockState {
            case .panic:
                trendCeiling = 52
                btcCeiling = 48
            case .riskOff:
                trendCeiling = 58
                btcCeiling = 55
            case .caution:
                trendCeiling = 65
                btcCeiling = 62
            case .stable:
                trendCeiling = 100
                btcCeiling = 100
            }

            if effectiveTrendScore > trendCeiling {
                effectiveTrendScore = trendCeiling
                adjustmentNotes.append("Şok filtresi: Trend katkısı sınırlandı.")
            }

            if effectiveBtcScore > btcCeiling {
                effectiveBtcScore = btcCeiling
                adjustmentNotes.append("Şok filtresi: BTC katkısı sınırlandı.")
            }

            statuses["shock_filter"] = String(
                format: "trend %.0f->%.0f btc %.0f->%.0f",
                rawTrendScore,
                effectiveTrendScore,
                rawBtcScore,
                effectiveBtcScore
            )
        }

        // 🟢 ÖNCÜ (Leading) - x1.5 ağırlık - Geleceği tahmin eder
        let leadingScores: [Double] = [
            breakdown["rates"] ?? 50,   // Yield Curve
            breakdown["vix"] ?? 50,     // VIX
            breakdown["claims"] ?? 50,  // Initial Claims
            effectiveBtcScore           // Bitcoin (şok filtresiyle efektif)
        ]
        let leadingAvg = leadingScores.reduce(0.0, +) / Double(leadingScores.count)
        
        // 🟡 EŞZAMANLI (Coincident) - x1.0 ağırlık - Şu anı gösterir
        let coincidentScores: [Double] = [
            effectiveTrendScore,        // SPY Trend (şok filtresiyle efektif)
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

        var finalScore = categorizedScore
        var scoreCap: Double?
        var shockPenalty = 0.0

        switch shockState {
        case .panic:
            shockPenalty = 18
            scoreCap = 28
            adjustmentNotes.append("Şok kapısı: PANIC modunda skor üst limiti 28.")
        case .riskOff:
            shockPenalty = 10
            scoreCap = 38
            adjustmentNotes.append("Şok kapısı: RISK_OFF modunda skor üst limiti 38.")
        case .caution:
            shockPenalty = 4
            scoreCap = 48
            adjustmentNotes.append("Şok kapısı: CAUTION modunda skor üst limiti 48.")
        case .stable:
            break
        }

        if shockPenalty > 0 {
            finalScore -= shockPenalty
        }
        if let cap = scoreCap {
            finalScore = min(finalScore, cap)
        }
        finalScore = min(100, max(0, finalScore))

        if let previous = previousRating {
            let delta = finalScore - previous.numericScore
            if abs(delta) >= 12 {
                adjustmentNotes.append(String(format: "Skor geçiş filtresi: Δ %+.1f", delta))
            }
        }
        statuses["shock"] = shockState.rawValue
        
        // DEBUG: print("═══════════════════════════════════════════════════════════════")
        // DEBUG: print("📊 AETHER v5 KATEGORİ SKORLARI:")
        // DEBUG: print("   🟢 Öncü (x1.5):     \(String(format: "%.0f", leadingAvg))")
        // DEBUG: print("   🟡 Eşzamanlı (x1.0): \(String(format: "%.0f", coincidentAvg))")
        // DEBUG: print("   🔴 Gecikmeli (x0.8): \(String(format: "%.0f", laggingAvg))")
        // DEBUG: print("   ══════════════════════════════════")
        // DEBUG: print("   📈 FİNAL SKOR:      \(String(format: "%.0f", categorizedScore))/100")
        // DEBUG: print("═══════════════════════════════════════════════════════════════")
        
        return DeterministicResult(
            totalScore: finalScore,
            breakdown: breakdown,
            statuses: statuses,
            penalty: penaltyFlag,
            shockState: shockState,
            vixPulse: vixPulse,
            adjustmentNotes: adjustmentNotes
        )
    }

    private func fetchWithResilience(asset: CanonicalInstrument, count: Int) async -> [Candle]? {
        // Heimdall 6.3: per-asset timeout guard to avoid long UI stalls.
        return await withTaskGroup(of: [Candle]?.self) { group in
            group.addTask {
                try? await HeimdallTelepresence.shared.trace(
                    engine: .aether,
                    provider: .unknown,
                    symbol: asset.rawValue,
                    canonicalAsset: asset
                ) {
                    let candles = try await HeimdallOrchestrator.shared.requestInstrumentCandles(
                        instrument: asset,
                        timeframe: "1D",
                        limit: count
                    )
                    return await self.normalizeCandles(candles)
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000) // 8s timeout
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
    
    private func saveWidgetData(rating: MacroEnvironmentRating, market: MarketDataBundle) {
        let widgetData = WidgetAetherData(
            score: rating.numericScore,
            regime: rating.regime.displayName,
            summary: rating.summary,
            lastUpdated: Date(),
            spyChange: calculateReturn(candles: market.spy), 
            vixValue: normalizeCandles(market.vix).last?.close ?? 0,
            gldChange: calculateReturn(candles: market.gld), 
            btcChange: calculateReturn(candles: market.btc)
        )
        WidgetDataService.shared.saveAether(data: widgetData)
    }
    
    private func calculateReturn(candles: [Candle]) -> Double {
        // FIX: Günlük değişim hesapla (son 2 candle), 60 günlük DEĞİL!
        let ordered = normalizeCandles(candles)
        guard ordered.count >= 2 else { return 0 }
        let current = ordered[ordered.count - 1].close
        let previous = ordered[ordered.count - 2].close
        guard previous != 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }

    private func normalizeCandles(_ candles: [Candle]) -> [Candle] {
        candles.sorted { $0.date < $1.date }
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
