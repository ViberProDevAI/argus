import Foundation

// MARK: - Sirkiye Aether Engine
/// Türkiye Makro Zeka Merkezi
/// EVDS/TCMB verilerini analiz ederek Türkiye ekonomisinin nabzını tutar
/// BIST yatırım kararlarını güçlendirir

actor SirkiyeAetherEngine {
    static let shared = SirkiyeAetherEngine()
    
    private init() {}
    
    // MARK: - Türkiye Makro Skoru
    
    struct TurkeyMacroScore: Sendable {
        let overallScore: Double           // 0-100 Genel Türkiye Skoru
        let monetaryStance: PolicyStance   // Para politikası duruşu
        let growthMomentum: Momentum       // Büyüme ivmesi
        let externalRisk: RiskLevel        // Dış kırılganlık
        let inflationPressure: Pressure    // Enflasyon baskısı
        
        let components: [ScoreComponent]   // Detay bileşenler
        let insights: [String]             // AI yorumları
        let timestamp: Date
        
        static let empty = TurkeyMacroScore(
            overallScore: 50,
            monetaryStance: .neutral,
            growthMomentum: .stable,
            externalRisk: .medium,
            inflationPressure: .medium,
            components: [],
            insights: ["Veri bekleniyor..."],
            timestamp: Date()
        )
        
        /// Risk seviyesi (yatırım kararları için)
        var investmentRisk: InvestmentRisk {
            if overallScore >= 70 { return .low }
            if overallScore >= 50 { return .moderate }
            if overallScore >= 30 { return .elevated }
            return .high
        }
    }
    
    struct ScoreComponent: Sendable, Identifiable {
        var id: String { name }
        let name: String
        let value: Double
        let score: Double      // 0-100
        let weight: Double     // Ağırlık
        let trend: Trend
        let icon: String
    }
    
    // MARK: - Enums
    
    enum PolicyStance: String, Sendable {
        case tight = "Sıkı"
        case neutral = "Nötr"
        case loose = "Gevşek"
        
        var color: String {
            switch self {
            case .tight: return "green"
            case .neutral: return "yellow"
            case .loose: return "red"
            }
        }
    }
    
    enum Momentum: String, Sendable {
        case accelerating = "Hızlanıyor"
        case stable = "Stabil"
        case decelerating = "Yavaşlıyor"
        
        var icon: String {
            switch self {
            case .accelerating: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .decelerating: return "arrow.down.right"
            }
        }
    }
    
    enum RiskLevel: String, Sendable {
        case low = "Düşük"
        case medium = "Orta"
        case high = "Yüksek"
        case critical = "Kritik"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    enum Pressure: String, Sendable {
        case low = "Düşük"
        case medium = "Orta"
        case high = "Yüksek"
        case severe = "Şiddetli"
    }
    
    enum Trend: String, Sendable {
        case up = "Yükseliyor"
        case stable = "Stabil"
        case down = "Düşüyor"
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .stable: return "minus"
            case .down: return "arrow.down"
            }
        }
    }
    
    enum InvestmentRisk: String, Sendable {
        case low = "Düşük Risk"
        case moderate = "Orta Risk"
        case elevated = "Yüksek Risk"
        case high = "Çok Yüksek Risk"
        
        var recommendation: String {
            switch self {
            case .low: return "Agresif pozisyon alınabilir"
            case .moderate: return "Normal pozisyon boyutu"
            case .elevated: return "Pozisyon küçültülmeli"
            case .high: return "Nakit ağırlıklı ol"
            }
        }
    }
    
    // MARK: - Ana Analiz
    
    func analyze() async -> TurkeyMacroScore {
        let snapshot = await TCMBDataService.shared.getMacroSnapshot()
        
        // ORACLE ENTEGRASYONU (Neural Link)
        let oracleInput = await TCMBDataService.shared.getOracleInput()
        let oracleSignals = await OracleEngine.shared.analyze(input: oracleInput)
        
        var components: [ScoreComponent] = []
        var insights: [String] = []
        var totalWeightedScore: Double = 0
        var totalWeight: Double = 0
        
        // 1. ENFLASYON ANALİZİ (Ağırlık: %25)
        let inflationComponent = analyzeInflation(snapshot)
        components.append(inflationComponent)
        totalWeightedScore += inflationComponent.score * inflationComponent.weight
        totalWeight += inflationComponent.weight
        
        // 2. KUR STABİLİTESİ (Ağırlık: %20)
        let fxComponent = analyzeFXStability(snapshot)
        components.append(fxComponent)
        totalWeightedScore += fxComponent.score * fxComponent.weight
        totalWeight += fxComponent.weight
        
        // 3. FAİZ ORTAMI (Ağırlık: %20)
        let rateComponent = analyzeInterestRates(snapshot)
        components.append(rateComponent)
        totalWeightedScore += rateComponent.score * rateComponent.weight
        totalWeight += rateComponent.weight
        
        // 4. BÜYÜME (Ağırlık: %15)
        let growthComponent = analyzeGrowth(snapshot)
        components.append(growthComponent)
        totalWeightedScore += growthComponent.score * growthComponent.weight
        totalWeight += growthComponent.weight
        
        // 5. CARİ DENGE (Ağırlık: %10)
        let externalComponent = analyzeExternalBalance(snapshot)
        components.append(externalComponent)
        totalWeightedScore += externalComponent.score * externalComponent.weight
        totalWeight += externalComponent.weight
        
        // 6. REZERVLER (Ağırlık: %10)
        let reserveComponent = analyzeReserves(snapshot)
        components.append(reserveComponent)
        totalWeightedScore += reserveComponent.score * reserveComponent.weight
        totalWeight += reserveComponent.weight
        
        // Toplam Skor (Temel Makro)
        var overallScore = totalWeight > 0 ? totalWeightedScore / totalWeight : 50
        
        // ORACLE MODIFIER (Sinyal Etkisi)
        // Her bir sinyal skoru +/- 2-5 puan etkiler
        var oracleModifier: Double = 0
        for signal in oracleSignals {
            switch signal.sentiment {
            case .bullish: oracleModifier += 3
            case .bearish: oracleModifier -= 3
            case .neutral: break
            }
            // Sinyal mesajını insight'a ekle
            insights.append("👁️ Oracle: \(signal.message)")
        }
        
        // Modifier'ı uygula (Max +/- 15 puan)
        oracleModifier = max(-15, min(15, oracleModifier))
        overallScore += oracleModifier
        
        // Durum Belirleme
        let monetaryStance = determineMonetaryStance(snapshot)
        let growthMomentum = determineGrowthMomentum(snapshot)
        let externalRisk = determineExternalRisk(snapshot)
        let inflationPressure = determineInflationPressure(snapshot)
        
        // Standart Insight'lar
        let standardInsights = generateInsights(
            score: overallScore,
            snapshot: snapshot,
            monetaryStance: monetaryStance,
            growthMomentum: growthMomentum,
            externalRisk: externalRisk
        )
        insights.append(contentsOf: standardInsights)
        
        return TurkeyMacroScore(
            overallScore: min(100, max(0, overallScore)),
            monetaryStance: monetaryStance,
            growthMomentum: growthMomentum,
            externalRisk: externalRisk,
            inflationPressure: inflationPressure,
            components: components,
            insights: insights,
            timestamp: Date()
        )
    }
    
    // MARK: - Bileşen Analizleri
    
    private func analyzeInflation(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> ScoreComponent {
        let inflation = snapshot.inflation ?? 50
        
        // Enflasyon ne kadar düşükse skor o kadar yüksek
        let score: Double
        let trend: Trend
        
        if inflation < 10 { score = 100 }
        else if inflation < 20 { score = 80 }
        else if inflation < 40 { score = 60 }
        else if inflation < 60 { score = 40 }
        else if inflation < 80 { score = 20 }
        else { score = 10 }
        
        // Trend belirleme (core vs headline karşılaştırması)
        if let core = snapshot.coreInflation {
            if core < inflation - 5 { trend = .down }
            else if core > inflation + 5 { trend = .up }
            else { trend = .stable }
        } else {
            trend = .stable
        }
        
        return ScoreComponent(
            name: "Enflasyon",
            value: inflation,
            score: score,
            weight: 0.25,
            trend: trend,
            icon: "percent"
        )
    }
    
    private func analyzeFXStability(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> ScoreComponent {
        // USD/TRY volatilitesi (basit yaklaşım)
        let usdTry = snapshot.usdTry ?? 35
        
        // Kur ne kadar stabil (düşük) olursa skor yüksek
        // Bu basit bir yaklaşım - gerçekte volatilite hesaplanmalı
        let score: Double
        if usdTry < 30 { score = 80 }
        else if usdTry < 35 { score = 65 }
        else if usdTry < 40 { score = 50 }
        else if usdTry < 45 { score = 35 }
        else { score = 20 }
        
        return ScoreComponent(
            name: "Kur Stabilitesi",
            value: usdTry,
            score: score,
            weight: 0.20,
            trend: .stable,
            icon: "dollarsign.circle"
        )
    }
    
    private func analyzeInterestRates(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> ScoreComponent {
        // Reel faiz pozitif olmalı
        let realRate = snapshot.realInterestRate ?? 0
        
        let score: Double
        let trend: Trend
        
        if realRate > 10 { score = 90; trend = .up }
        else if realRate > 5 { score = 75; trend = .up }
        else if realRate > 0 { score = 60; trend = .stable }
        else if realRate > -10 { score = 40; trend = .down }
        else { score = 20; trend = .down }
        
        return ScoreComponent(
            name: "Reel Faiz",
            value: realRate,
            score: score,
            weight: 0.20,
            trend: trend,
            icon: "banknote"
        )
    }
    
    private func analyzeGrowth(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> ScoreComponent {
        let gdp = snapshot.gdpGrowth ?? 3
        
        let score: Double
        let trend: Trend
        
        if gdp > 5 { score = 90; trend = .up }
        else if gdp > 3 { score = 70; trend = .up }
        else if gdp > 0 { score = 50; trend = .stable }
        else if gdp > -3 { score = 30; trend = .down }
        else { score = 10; trend = .down }
        
        return ScoreComponent(
            name: "Büyüme",
            value: gdp,
            score: score,
            weight: 0.15,
            trend: trend,
            icon: "chart.line.uptrend.xyaxis"
        )
    }
    
    private func analyzeExternalBalance(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> ScoreComponent {
        let currentAccount = snapshot.currentAccount ?? -30
        
        let score: Double
        if currentAccount > 0 { score = 90 }
        else if currentAccount > -10 { score = 70 }
        else if currentAccount > -30 { score = 50 }
        else if currentAccount > -50 { score = 30 }
        else { score = 15 }
        
        return ScoreComponent(
            name: "Cari Denge",
            value: currentAccount,
            score: score,
            weight: 0.10,
            trend: currentAccount > -20 ? .up : .down,
            icon: "arrow.left.arrow.right"
        )
    }
    
    private func analyzeReserves(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> ScoreComponent {
        let reserves = snapshot.reserves ?? 100
        
        let score: Double
        if reserves > 150 { score = 90 }
        else if reserves > 120 { score = 70 }
        else if reserves > 90 { score = 50 }
        else if reserves > 60 { score = 30 }
        else { score = 15 }
        
        return ScoreComponent(
            name: "MB Rezervleri",
            value: reserves,
            score: score,
            weight: 0.10,
            trend: reserves > 100 ? .up : .down,
            icon: "building.columns"
        )
    }
    
    // MARK: - Durum Belirleme
    
    private func determineMonetaryStance(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> PolicyStance {
        guard let realRate = snapshot.realInterestRate else { return .neutral }
        
        if realRate > 5 { return .tight }
        if realRate < -5 { return .loose }
        return .neutral
    }
    
    private func determineGrowthMomentum(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> Momentum {
        guard let gdp = snapshot.gdpGrowth else { return .stable }
        
        if gdp > 4 { return .accelerating }
        if gdp < 1 { return .decelerating }
        return .stable
    }
    
    private func determineExternalRisk(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> RiskLevel {
        let currentAccount = snapshot.currentAccount ?? -30
        let reserves = snapshot.reserves ?? 100
        
        // Cari açık yüksek ve rezervler düşükse risk yüksek
        if currentAccount < -40 && reserves < 80 { return .critical }
        if currentAccount < -30 && reserves < 100 { return .high }
        if currentAccount < -20 { return .medium }
        return .low
    }
    
    private func determineInflationPressure(_ snapshot: TCMBDataService.TCMBMacroSnapshot) -> Pressure {
        guard let inflation = snapshot.inflation else { return .medium }
        
        if inflation > 60 { return .severe }
        if inflation > 40 { return .high }
        if inflation > 20 { return .medium }
        return .low
    }
    
    // MARK: - Insight Üretimi
    
    private func generateInsights(
        score: Double,
        snapshot: TCMBDataService.TCMBMacroSnapshot,
        monetaryStance: PolicyStance,
        growthMomentum: Momentum,
        externalRisk: RiskLevel
    ) -> [String] {
        var insights: [String] = []
        
        // Genel Değerlendirme
        if score >= 70 {
            insights.append("🟢 Makro görünüm olumlu. BIST için uygun ortam.")
        } else if score >= 50 {
            insights.append("🟡 Makro görünüm nötr. Seçici olmak önemli.")
        } else if score >= 30 {
            insights.append("🟠 Makro riskler yüksek. Defansif duruş önerilir.")
        } else {
            insights.append("🔴 Makro görünüm olumsuz. Nakit ağırlıklı ol.")
        }
        
        // Reel Faiz
        if let realRate = snapshot.realInterestRate {
            if realRate > 5 {
                insights.append("💰 Reel faiz pozitif (%\(String(format: "%.1f", realRate))). TL varlıklar cazip.")
            } else if realRate < 0 {
                insights.append("⚠️ Reel faiz negatif. Döviz/altın hedge düşünülebilir.")
            }
        }
        
        // Sektör Önerileri
        if monetaryStance == .tight {
            insights.append("🏦 Sıkı para politikası bankalar için olumlu olabilir.")
        }
        
        if externalRisk == .high || externalRisk == .critical {
            insights.append("📦 Dış kırılganlık yüksek. İhracatçı şirketler değer kazanabilir.")
        }
        
        return insights
    }
}
