import Foundation

/// Sirkiye Engine (Project Turquoise)
/// Specialized Political & Macro Cortex for Turkey Markets
/// Replaces standard Aether analysis with "Street Smart" logic.
/// Tracks: FX Volatility, Political Atmosphere, Global Pressure.
actor SirkiyeEngine {
    static let shared = SirkiyeEngine()
    
    struct SirkiyeInput {
        let usdTry: Double          // Current USD/TRY rate
        let usdTryPrevious: Double  // Previous Close
        let dxy: Double?            // Global Dollar Strength
        let brentOil: Double?       // Energy Cost
        let globalVix: Double?      // Global Fear
        let newsSnapshot: HermesNewsSnapshot? // For Political Cortex
        
        // V2 Fields
        // V2 Fields
        var currentInflation: Double? = nil
        var policyRate: Double? = nil
        var xu100Change: Double? = nil
        var xu100Value: Double? = nil
        var goldPrice: Double? = nil
        
        // Custom Init for Backward Compatibility
        init(
            usdTry: Double, 
            usdTryPrevious: Double, 
            dxy: Double?, 
            brentOil: Double?, 
            globalVix: Double?, 
            newsSnapshot: HermesNewsSnapshot?, 
            currentInflation: Double? = nil, 
            policyRate: Double? = nil, 
            xu100Change: Double? = nil, 
            xu100Value: Double? = nil, 
            goldPrice: Double? = nil
        ) {
            self.usdTry = usdTry
            self.usdTryPrevious = usdTryPrevious
            self.dxy = dxy
            self.brentOil = brentOil
            self.globalVix = globalVix
            self.newsSnapshot = newsSnapshot
            self.currentInflation = currentInflation
            self.policyRate = policyRate
            self.xu100Change = xu100Change
            self.xu100Value = xu100Value
            self.goldPrice = goldPrice
        }
    }
    
    // V2: Reel Getiri Analizi sonucu
    struct RealReturnAnalysis: Sendable {
        let nominalReturn: Double    // Yıllık nominal getiri (XU100 1Y)
        let inflation: Double        // Yıllık enflasyon
        let realReturn: Double       // Reel getiri = Nominal - Enflasyon
        let verdict: String          // "Pozitif Reel Getiri" veya "Negatif Reel Getiri"
        let isPositive: Bool
    }
    
    // V3: BIST Piyasa Rüzgarı & Çarpan
    struct SirkiyeRegime: Sendable {
        let multiplier: Double       // 0.5x - 1.5x (Skor çarpanı)
        let score: Double            // 0-100 (BIST İştah Skoru)
        let description: String      // "Yabancı girişi ve negatif reel faiz borsayı destekliyor"
        let foreignFlowTrend: String // "Pozitif" / "Negatif"
        let macroOutlook: String     // "Enflasyonist Ortam" vs
    }
    
    // MARK: - Public API
    
    func analyze(input: SirkiyeInput) -> AetherDecision {
        let timestamp = Date()
        
        // 1. Political Cortex (The "Sirkiye" Special)
        // Detects systemic risks regardless of financial data.
        let (politicalScore, politicalMode, politicalReason) = analyzePoliticalAtmosphere(news: input.newsSnapshot)
        
        // If Political Panic is triggered, it overrides everything.
        if politicalMode == .panic {
            return createPanicDecision(reason: politicalReason, timestamp: timestamp)
        }
        
        // 2. Local Stress (USD/TRY)
        // TRY volatility: Normal ~1%, Elevated 1.5-2.5%, High 2.5-4%, Crisis >4%
        let fxChange = (input.usdTry - input.usdTryPrevious) / input.usdTryPrevious * 100.0
        let localStressScore: Double

        if fxChange > 5.0 {
            localStressScore = 0.0   // Crisis - immediate action required
        } else if fxChange > 3.0 {
            localStressScore = 15.0  // Severe stress
        } else if fxChange > 2.0 {
            localStressScore = 35.0  // High stress - notable but not crisis
        } else if fxChange > 1.0 {
            localStressScore = 50.0  // Elevated - normal TRY volatility
        } else if fxChange < -1.0 {
            localStressScore = 80.0  // FX relief - meaningful TRY strength
        } else if fxChange < -0.3 {
            localStressScore = 70.0  // Slight FX relief
        } else {
            localStressScore = 60.0  // Stable range
        }
        
        // 3. Global Pressure
        var globalScore = 50.0
        if let dxy = input.dxy {
            if dxy > 106 { globalScore -= 15 }
            else if dxy < 100 { globalScore += 15 }
        }
        if let oil = input.brentOil {
            if oil > 90 { globalScore -= 10 }
            else if oil < 75 { globalScore += 10 }
        }
        if let vix = input.globalVix {
            if vix > 30 { globalScore -= 20 }
            else if vix > 20 { globalScore -= 10 }
            else if vix < 15 { globalScore += 10 }
        }
        
        // 4. Synthesis
        // Weights: Political (Hidden hand) > FX (50%) > Global (20%) > News Sentiment (30%)
        
        var newsSentimentScore = 50.0
        if let snapshot = input.newsSnapshot, let sentiment = snapshot.aggregatedSentiment {
            newsSentimentScore = ((sentiment + 1.0) / 2.0) * 100.0
        }
        
        // Apply "Sirkiye" weighting
        // If Political Cortex is uneasy (but not panic), it drags score down.
        var finalScore = (localStressScore * 0.5) + (globalScore * 0.2) + (newsSentimentScore * 0.3)
        
        // Political Penalty
        if politicalMode == .fear {
            finalScore -= 20.0
            finalScore = max(0, finalScore)
        }
        
        let finalStance: MacroStance
        if finalScore < 30 { finalStance = .riskOff }
        else if finalScore < 50 { finalStance = .defensive }
        else if finalScore < 75 { finalStance = .cautious }
        else { finalStance = .riskOn }
        
        let reason = "Kur: %\(String(format: "%.2f", fxChange)) | \(politicalReason) | Global: \(Int(globalScore))"
        
        let proposal = MacroProposal(
            proposer: "Sirkiye",
            proposerName: "Sirkiye (Turquoise)",
            stance: finalStance,
            confidence: finalScore / 100.0,
            reasoning: reason
        )
        
        return AetherDecision(
            stance: finalStance,
            marketMode: politicalMode == .neutral ? .neutral : politicalMode,
            netSupport: finalScore / 100.0,
            isStrongSignal: finalScore > 75 || finalScore < 25,
            winningProposal: proposal,
            votes: [],
            warnings: politicalMode == .fear ? [politicalReason] : [],
            timestamp: timestamp
        )
    }
    
    // MARK: - Market Regime Calculation (V3)
    
    func calculateMarketRegime(input: SirkiyeInput, foreignFlowScore: Double?) -> SirkiyeRegime {
        var score = 50.0
        var reasons: [String] = []
        var flowTrend = "Nötr"
        var macroOutlook = "Dengeli"
        
        // 1. Reel Getiri Analizi (Inflation vs Policy Rate)
        if let inflation = input.currentInflation, let rate = input.policyRate {
            let realRate = rate - inflation
            
            if realRate < -5 {
                // Derin Negatif Reel Faiz -> Enflasyondan Korunma Talebi
                score += 20
                reasons.append("Negatif Reel Faiz (Enflasyon Rallisi)")
                macroOutlook = "Yüksek Enflasyon"
            } else if realRate > 5 {
                // Pozitif Reel Faiz -> Alternatif Maliyet Artışı
                score -= 15
                reasons.append("Mevduat Faizi Cazip (Borsadan Çıkış)")
                macroOutlook = "Sıkı Para Politikası"
            } else {
                macroOutlook = "Nötr Reel Faiz"
            }
        }
        
        // 2. Yabancı Yatırımcı Algısı (Smart Money)
        if let flow = foreignFlowScore {
            if flow > 65 {
                score += 25
                reasons.append("Güçlü Yabancı Girişi")
                flowTrend = "Pozitif (Giriş)"
            } else if flow > 55 {
                score += 10
                reasons.append("Ilımlı Yabancı Girişi")
                flowTrend = "Hafif Pozitif"
            } else if flow < 35 {
                score -= 20
                reasons.append("Yabancı Çıkışı")
                flowTrend = "Negatif (Çıkış)"
            } else {
                flowTrend = "Yatay"
            }
        }
        
        // 3. Kur Stresi (USD/TRY)
        // Realistic thresholds for TRY volatility
        let fxChange = (input.usdTry - input.usdTryPrevious) / input.usdTryPrevious * 100.0
        if fxChange > 5.0 {
            score -= 40
            reasons.append("Kur Krizi (>%5)")
        } else if fxChange > 3.0 {
            score -= 25
            reasons.append("Kur Soku (>%3)")
        } else if fxChange > 2.0 {
            score -= 12
            reasons.append("Kurda Belirgin Hareket")
        } else if fxChange > 1.0 {
            // Normal TRY volatility - no penalty
            reasons.append("Kur Normal Volatilite")
        } else if fxChange < -1.0 {
            score += 10
            reasons.append("TRY Guclu Gerileme")
        } else if fxChange < -0.3 {
            score += 3
            reasons.append("Kur Stabil/Hafif Gerileme")
        }
        
        // 4. Politik Stres (Kısaca)
        let (_, politicalMode, _) = analyzePoliticalAtmosphere(news: input.newsSnapshot)
        if politicalMode == .fear {
            score -= 20
            reasons.append("Politik Gerginlik")
        } else if politicalMode == .panic {
            score = 0 // Panik durumunda rejim çöker
            reasons.append("POLİTİK KRİZ")
        }
        
        // Normalizasyon ve Çarpan
        score = max(0, min(100, score))
        let multiplier = 0.5 + (score / 100.0) // 0.5x ile 1.5x arası
        
        let desc = reasons.isEmpty ? "Piyasa dinamikleri nötr." : reasons.joined(separator: ", ")
        
        return SirkiyeRegime(
            multiplier: multiplier,
            score: score,
            description: desc,
            foreignFlowTrend: flowTrend,
            macroOutlook: macroOutlook
        )
    }

    
    // 1. Regime & Systemic Crisis (Severity: 100 - PANIC)
    // Triggers: Regime change, legal coups, direct democracy threats.
    private let regimeKeywords = [
        "siyasi yasak", "hapis cezası", "kayyum", "darbe", "sıkıyönetim",
        "kapatma davası", "anayasa kitapçığı", "erken seçim", "dokunulmazlık"
    ]
    
    // 2. Economic Management Crisis (Severity: 80 - CRASH)
    // Triggers: Loss of central bank independence, irrational policy shifts.
    private let economicManKeywords = [
        "görevden alma", "merkez bankası başkanı", "naci ağbal", "gece yarısı kararnamesi",
        "arka kapı", "kur korumalı", "faiz inadı", "tüik başkanı", "istifa"
    ]
    
    // 3. Diplomatic & Geopolitical (Severity: 60 - HIGH STRESS)
    // Triggers: Sanctions, war risks, isolation.
    private let diplomaticKeywords = [
        "rahip brunson", "yaptırım", "halkbank davası", "s400", "f16 krizi",
        "gri liste", "büyükelçi", "istenmeyen adam", "nota verilmesi", "sınır ötesi"
    ]
    
    // 4. Social & Civil Unrest (Severity: 40 - TENSION)
    // Triggers: Protests, social instability.
    private let socialKeywords = [
        "gezi", "boğaziçi", "sokak çağrısı", "eylem", "gaz müdahalesi", "gözaltı"
    ]

    private func analyzePoliticalAtmosphere(news: HermesNewsSnapshot?) -> (Double, MarketMode, String) {
        guard let news = news, !news.insights.isEmpty else {
            return (50.0, .neutral, "Politik Veri Yok (Nötr)")
        }
        
        var totalImpact = 0.0
        var criticalTopicsFound: [String] = []
        var maxCategorySeverity = 0
        
        for insight in news.insights {
            let text = (insight.headline + " " + insight.summaryTRLong).lowercased()
            var categoryMultiplier = 0.5 // Default noise weight
            var detectedTopic: String? = nil
            var currentSeverity = 0
            
            // 1. Regime & Systemic (Multiplier: 4.0 - Critical)
            for word in regimeKeywords {
                if text.contains(word) {
                    categoryMultiplier = 4.0
                    detectedTopic = word.uppercased()
                    currentSeverity = 4
                    break
                }
            }
            
            // 2. Economic Management (Multiplier: 3.0 - High)
            if detectedTopic == nil {
                for word in economicManKeywords {
                    // Context check: Must be related to officials/institutions
                    if text.contains(word) && (text.contains("merkez") || text.contains("başkan") || text.contains("bakan") || text.contains("kurul")) {
                        categoryMultiplier = 3.0
                        detectedTopic = word.uppercased()
                        currentSeverity = 3
                        break
                    }
                }
            }
            
            // 3. Diplomatic (Multiplier: 2.0 - Moderate)
            if detectedTopic == nil {
                for word in diplomaticKeywords {
                    if text.contains(word) {
                        categoryMultiplier = 2.0
                        detectedTopic = word.uppercased()
                        currentSeverity = 2
                        break
                    }
                }
            }
            
            // 4. Social (Multiplier: 1.5)
            if detectedTopic == nil {
                for word in socialKeywords {
                    if text.contains(word) {
                        categoryMultiplier = 1.5
                        detectedTopic = word.uppercased()
                        currentSeverity = 1
                        break
                    }
                }
            }
            
            // 5. Positive Catalysts (Multiplier: 3.0 - Bullish Booster)
            // Triggers: Credit upgrades, rational policy moves, gray list exit.
            if detectedTopic == nil {
                let positiveKeywords = [
                    "not artışı", "not artırımı", "görünüm pozitif", "yatırım yapılabilir seviye",
                    "moody's", "fitch", "s&p",
                    "gri liste çıkış", "gri listeden çıktı",
                    "mehmet şimşek", "rasyonel zemin", "cds düşüş",
                    "swap hattı", "swap kanalı açıldı", "yabancı girişi"
                ]
                
                for word in positiveKeywords {
                    if text.contains(word) {
                        // Only boost if sentiment is actually positive
                        if insight.sentiment == .strongPositive || insight.sentiment == .weakPositive {
                            categoryMultiplier = 3.0 // Significant Boost
                            detectedTopic = word.uppercased()
                            // No severity for positive
                        }
                        break
                    }
                }
            }
            
            // Calculate Raw Sentiment Value (-10 to +10)
            let sentimentValue: Double
            switch insight.sentiment {
            case .strongPositive: sentimentValue = 10.0
            case .weakPositive: sentimentValue = 5.0
            case .neutral: sentimentValue = 0.0
            case .weakNegative: sentimentValue = -5.0
            case .strongNegative: sentimentValue = -10.0
            }
            
            // Apply Multiplier if a topic was found, otherwise ignore general news in this context
            if let topic = detectedTopic {
                let weightedImpact = sentimentValue * categoryMultiplier
                totalImpact += weightedImpact
                criticalTopicsFound.append("\(topic)(\(insight.sentiment.rawValue))")
                if currentSeverity > maxCategorySeverity && sentimentValue < 0 {
                    maxCategorySeverity = currentSeverity
                }
            }
        }
        
        // Final Score Calculation (Baseline 55)
        // Max theoretical negative impact: -10 * 4 * 3 items = -120 -> Score 0
        var finalScore = 55.0 + totalImpact
        finalScore = max(0.0, min(100.0, finalScore))
        
        // Determine Mode based on Final Score and Max Severity of Negative topics
        let detectedMode: MarketMode
        let description: String
        
        if finalScore < 20 {
            detectedMode = .panic // Explicit Panic
            description = "SİRKİYE ALARMI: Kritik Seviyede Risk! (\(criticalTopicsFound.prefix(2).joined(separator: ", ")))"
        } else if finalScore < 40 {
            detectedMode = .fear // General Fear
            description = "Yüksek Politik Tansiyon (%100 Koruma Önerilir). Konu: \(criticalTopicsFound.first ?? "Bilinmiyor")"
        } else if finalScore < 60 {
            detectedMode = .neutral
            description = "Politik Atmosfer Kararsız/Nötr"
        } else {
            detectedMode = .greed // Or Neutral-Positive
            description = "Politik Risk Priminde Düşüş (Olumlu)"
        }
        
        // Safety Override: If keywords found but sentiment was somehow positive, we trust the score.
        // But if score suggests Panic, we return panic.
        
        return (finalScore, detectedMode, description)
    }
    
    private func createPanicDecision(reason: String, timestamp: Date) -> AetherDecision {
        let proposal = MacroProposal(
            proposer: "Sirkiye",
            proposerName: "Sirkiye (Kırmızı Alarm)",
            stance: .riskOff,
            confidence: 1.0,
            reasoning: reason
        )
        
        return AetherDecision(
            stance: .riskOff,
            marketMode: .panic,
            netSupport: 0.0,
            isStrongSignal: true,
            winningProposal: proposal,
            votes: [],
            warnings: ["⚠️ \(reason)"],
            timestamp: timestamp
        )
    }
}
