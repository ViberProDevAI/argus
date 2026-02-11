import Foundation

// MARK: - BIST Sektör Engine
// Sektör rotasyonu ve güç analizi
// XBANK, XUSIN, XHOLD gibi endeksleri takip eder

actor BistSektorEngine {
    static let shared = BistSektorEngine()
    
    private init() {}
    
    // MARK: - Sektör Listesi
    
    // MARK: - Sektör Listesi
    
    // BistSectorRegistry'den dinamik liste
    static let sectors: [BistSector] = BistSector.allCases.filter { $0 != .unknown }
    
    // MARK: - Ana Analiz
    
    func analyze() async throws -> BistSektorResult {
        var sectorData: [BistSektorItem] = []
        
        // Her sektör için veri çek
        for sector in Self.sectors {
            do {
                let quote = try await BorsaPyProvider.shared.getSectorIndex(code: sector.rawValue)
                
                // Performans hesapla
                let dailyChange = quote.changePercent
                let momentum: SektorMomentum
                
                if dailyChange > BistThresholds.Momentum.strong { momentum = .strong }
                else if dailyChange > BistThresholds.Momentum.positive { momentum = .positive }
                else if dailyChange > BistThresholds.Momentum.negativeUpper { momentum = .neutral }
                else if dailyChange > BistThresholds.Momentum.negative { momentum = .negative }
                else { momentum = .weak }
                
                sectorData.append(BistSektorItem(
                    code: sector.rawValue,
                    name: sector.displayName,
                    icon: sector.icon,
                    value: quote.last,
                    dailyChange: dailyChange,
                    momentum: momentum,
                    volume: quote.volume
                ))
            } catch {
                print("⚠️ Sektör verisi alınamadı: \(sector.rawValue)")
            }
        }
        
        // Sıralama (en güçlüden en zayıfa)
        sectorData.sort { $0.dailyChange > $1.dailyChange }
        
        // Rotasyon Analizi
        let rotationMetrics = analyzeRotationMetrics(strongest: sectorData.first, weakest: sectorData.last, avgChange: sectorData.map { $0.dailyChange }.reduce(0, +) / Double(sectorData.count))
        
        return BistSektorResult(
            sectors: sectorData,
            strongestSector: sectorData.first,
            weakestSector: sectorData.last,
            rotation: rotationMetrics.rotation,
            rotationMetrics: rotationMetrics.metrics,
            timestamp: Date()
        )
    }
    
    // MARK: - Rotasyon Analizi
    
    private func analyzeRotationMetrics(strongest: BistSektorItem?, weakest: BistSektorItem?, avgChange: Double) -> (rotation: SektorRotasyon, metrics: [AnalysisMetric]) {
        var metrics: [AnalysisMetric] = []
        var rotation: SektorRotasyon = .belirsiz
        
        guard let strong = strongest, let weak = weakest else {
            return (.belirsiz, [])
        }
        
        // 1. Bankacılık Liderliği (Risk-On)
        if strong.code == "XBANK" && strong.dailyChange > 1 {
            rotation = .riskOn
            metrics.append(AnalysisMetric(
                label: "Rotasyon Lideri",
                value: "Bankacılık",
                context: "Yabancı Girişi Var",
                scoreImpact: 0,
                education: "Bankacılık endeksinin (XBANK) lider olması, piyasada yabancı yatırımcı ilgisinin ve risk iştahının yüksek olduğunu (Risk-On) gösterir."
            ))
        }
        // 2. Sınai Liderliği (Büyüme)
        else if strong.code == "XUSIN" && strong.dailyChange > 0.5 {
            rotation = .buyume
             metrics.append(AnalysisMetric(
                label: "Rotasyon Lideri",
                value: "Sınai",
                context: "Reel Sektör",
                scoreImpact: 0,
                education: "Sınai endeksinin (XUSIN) öne çıkması, ekonomik büyüme beklentilerinin fiyatlandığını gösterir."
            ))
        }
        // 3. Teknoloji (Momentum)
        else if strong.code == "XBLSM" {
            rotation = .teknoloji
             metrics.append(AnalysisMetric(
                label: "Momentum Odaklı",
                value: "Teknoloji",
                context: "Yüksek Beta",
                scoreImpact: 0,
                education: "Teknoloji hisselerine yönelim, yatırımcıların yüksek getiri arayışında olduğunu gösterir."
            ))
        }
        // 4. Defansif
        else if strong.code == "XHOLD" || strong.code == "XGMYO" || strong.code == "XTRZM" {
            rotation = .defansif
            metrics.append(AnalysisMetric(
                label: "Defansif Mod",
                value: strong.name,
                context: "Güvenli Liman",
                scoreImpact: 0,
                education: "Piyasa belirsizlik dönemlerinde Holding veya GYO gibi daha defansif sektörlere sığınabilir."
            ))
        }
        // 5. Genel Piyasaya Bakış
        else {
             if avgChange > 1 {
                rotation = .riskOn
                metrics.append(AnalysisMetric(
                    label: "Genel Piyasa",
                    value: "Pozitif",
                    context: "Yaygın Alım",
                    scoreImpact: 0,
                    education: "Sektörlerin geneline yayılan bir alım dalgası var. Boğa piyasası işareti."
                ))
            } else if avgChange < -1 {
                rotation = .riskOff
                metrics.append(AnalysisMetric(
                    label: "Genel Piyasa",
                    value: "Negatif",
                    context: "Yaygın Satış",
                    scoreImpact: 0,
                    education: "Sektörlerin genelinde satış baskısı hakim. Nakite geçiş (Risk-Off) var."
                ))
            } else {
                rotation = .karisik
                 metrics.append(AnalysisMetric(
                    label: "Piyasa Yönü",
                    value: "Yatay",
                    context: "Kararsız",
                    scoreImpact: 0,
                    education: "Net bir sektör ayrışması yok. Piyasa yön arayışında."
                ))
            }
        }
        
        // Zayıf Halka Analizi
        metrics.append(AnalysisMetric(
            label: "Zayıf Halka",
            value: weak.name,
            context: "\(String(format: "%.1f", weak.dailyChange))%",
            scoreImpact: 0,
            education: "En çok satış yiyen sektör. Genelde fon çıkışının olduğu yeri işaret eder."
        ))
        
        return (rotation, metrics)
    }
    
    // MARK: - Sembolün Sektörünü Bul

    func getSector(for symbol: String) -> String? {
        // BistSectorRegistry'den merkezi erişim
        return BistSectorRegistry.sectorCode(for: symbol)
        }
    
    // MARK: - Tekil Hisse Sektör Analizi
    
    func analyze(symbol: String) -> (score: Double, sector: String) {
        guard let sectorCode = getSector(for: symbol) else {
            return (50.0, "Bilinmiyor")
        }
        
        // Basit skor mantığı (şimdilik)
        // Gerçek implementasyonda sektörün o anki momentumuna bakılmalı
        return (50.0, sectorCode)
    }
}


// MARK: - Modeller

struct BistSektorResult: Sendable {
    let sectors: [BistSektorItem]
    let strongestSector: BistSektorItem?
    let weakestSector: BistSektorItem?
    let rotation: SektorRotasyon
    let rotationMetrics: [AnalysisMetric] // NEW: Educational metrics explaining the rotation
    let timestamp: Date
}

struct BistSektorItem: Sendable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let icon: String
    let value: Double
    let dailyChange: Double
    let momentum: SektorMomentum
    let volume: Double
}

enum SektorMomentum: String, Sendable {
    case strong = "Güçlü"
    case positive = "Pozitif"
    case neutral = "Nötr"
    case negative = "Negatif"
    case weak = "Zayıf"
    
    var color: String {
        switch self {
        case .strong, .positive: return "green"
        case .neutral: return "yellow"
        case .negative, .weak: return "red"
        }
    }
}

enum SektorRotasyon: String, Sendable {
    case riskOn = "Risk Açık"
    case riskOff = "Risk Kapalı"
    case defansif = "Defansif"
    case buyume = "Büyüme"
    case teknoloji = "Teknoloji"
    case karisik = "Karışık"
    case belirsiz = "Veri Yok"
}
