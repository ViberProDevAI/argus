import Foundation

// MARK: - Component Performance Service
/// Orion bileşenlerinin trade performansına katkısını analiz eder.
/// Chiron'un akıllı ağırlık öğrenmesi için temel veri sağlar.
final class ComponentPerformanceService: @unchecked Sendable {
    static let shared = ComponentPerformanceService()
    
    private let lock = NSLock()
    
    // Cache
    private var globalStatsCache: [ComponentStats]?
    private var symbolStatsCache: [String: [ComponentStats]] = [:]
    private var lastAnalysisTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 dakika
    
    private init() {}
    
    // MARK: - Data Types
    
    struct ComponentStats: Sendable {
        let component: String           // "structure", "trend", etc.
        let totalTrades: Int
        let signalCount: Int            // Kaç trade'de sinyal verdi (skor > 60)
        let winningSignals: Int         // Sinyal verip kazanan trade'ler
        let winRate: Double             // 0-100
        let avgScoreWhenWin: Double     // Kazançlı trade'lerde ortalama skor
        let avgScoreWhenLoss: Double    // Kayıplı trade'lerde ortalama skor
        let predictivePower: Double     // -1 to +1 arası (yüksek = güvenilir)
        
        var reliability: Double {
            // 0-1 arası güvenilirlik skoru
            // Win rate ve predictive power kombinasyonu
            let normalizedWR = winRate / 100.0
            let normalizedPP = (predictivePower + 1) / 2.0
            return (normalizedWR * 0.6) + (normalizedPP * 0.4)
        }
        
        var isReliable: Bool { reliability > 0.55 }
        var isUnreliable: Bool { reliability < 0.45 }
    }
    
    // MARK: - Public API
    
    /// Tüm trade'ler üzerinden global bileşen performansını analiz eder
    func analyzeGlobalPerformance(forceRefresh: Bool = false) -> [ComponentStats] {
        lock.lock()
        defer { lock.unlock() }
        
        // Cache kontrolü
        if !forceRefresh,
           let cached = globalStatsCache,
           let lastTime = lastAnalysisTime,
           Date().timeIntervalSince(lastTime) < cacheDuration {
            return cached
        }
        
        let logs = TradeLogStore.shared.fetchLogs()
        let stats = calculateStats(from: logs)
        
        globalStatsCache = stats
        lastAnalysisTime = Date()
        
        return stats
    }
    
    /// Belirli bir sembol için bileşen performansını analiz eder
    func analyzePerformance(for symbol: String, forceRefresh: Bool = false) -> [ComponentStats] {
        lock.lock()
        defer { lock.unlock() }
        
        // Cache kontrolü
        if !forceRefresh, let cached = symbolStatsCache[symbol] {
            return cached
        }
        
        let logs = TradeLogStore.shared.fetchLogs().filter { $0.symbol == symbol }
        
        guard logs.count >= 3 else {
            // Yeterli veri yok, global'e fallback
            return globalStatsCache ?? []
        }
        
        let stats = calculateStats(from: logs)
        symbolStatsCache[symbol] = stats
        
        return stats
    }
    
    /// Belirli bir bileşenin güvenilirliğini döndürür (0-1)
    func getReliability(component: String, symbol: String? = nil) -> Double {
        let stats: [ComponentStats]
        if let sym = symbol {
            stats = analyzePerformance(for: sym)
        } else {
            stats = analyzeGlobalPerformance()
        }
        
        return stats.first(where: { $0.component == component })?.reliability ?? 0.5
    }
    
    /// En güvenilir bileşenleri sıralı döndürür
    func getRankedComponents(symbol: String? = nil) -> [(component: String, reliability: Double)] {
        let stats: [ComponentStats]
        if let sym = symbol {
            stats = analyzePerformance(for: sym)
        } else {
            stats = analyzeGlobalPerformance()
        }
        
        return stats
            .sorted { $0.reliability > $1.reliability }
            .map { ($0.component, $0.reliability) }
    }
    
    /// Öğrenilmiş ağırlıkları hesaplar
    func calculateLearnedWeights(symbol: String? = nil) -> OrionWeightSnapshot? {
        let stats = symbol != nil ? analyzePerformance(for: symbol!) : analyzeGlobalPerformance()
        
        guard stats.count >= 4 else { return nil }
        
        // Reliability bazlı ağırlık
        var weights: [String: Double] = [:]
        let baseWeight = 0.15
        let bonusRange = 0.25 // Maksimum bonus
        
        for stat in stats {
            // reliability 0-1, weight 0.15-0.40 arası
            weights[stat.component] = baseWeight + (stat.reliability * bonusRange)
        }
        
        let raw = OrionWeightSnapshot(
            structure: weights["structure"] ?? 0.30,
            trend: weights["trend"] ?? 0.30,
            momentum: weights["momentum"] ?? 0.25,
            pattern: weights["pattern"] ?? 0.10,
            volatility: weights["volatility"] ?? 0.05
        )
        
        return raw.normalized()
    }
    
    // MARK: - Private Helpers
    
    private func calculateStats(from logs: [TradeLog]) -> [ComponentStats] {
        let components = ["structure", "trend", "momentum", "pattern", "volatility"]
        var stats: [ComponentStats] = []
        
        for component in components {
            var signalCount = 0
            var winningSignals = 0
            var scoresWhenWin: [Double] = []
            var scoresWhenLoss: [Double] = []
            
            for log in logs {
                guard let snapshot = log.entryOrionSnapshot else { continue }
                
                let score = snapshot.componentDict[component] ?? 0
                
                // Sinyal verdi mi? (Skor > 60)
                if score > 60 {
                    signalCount += 1
                    if log.isWin {
                        winningSignals += 1
                    }
                }
                
                // Ortalama skor hesabı için
                if log.isWin {
                    scoresWhenWin.append(score)
                } else {
                    scoresWhenLoss.append(score)
                }
            }
            
            let avgWin = scoresWhenWin.isEmpty ? 50.0 : scoresWhenWin.reduce(0, +) / Double(scoresWhenWin.count)
            let avgLoss = scoresWhenLoss.isEmpty ? 50.0 : scoresWhenLoss.reduce(0, +) / Double(scoresWhenLoss.count)
            
            // Predictive Power: Win'de yüksek, Loss'ta düşük skor veriyorsa pozitif
            let predictivePower = (avgWin - avgLoss) / 100.0 // -1 to +1
            
            let winRate = signalCount > 0 ? (Double(winningSignals) / Double(signalCount)) * 100.0 : 50.0
            
            stats.append(ComponentStats(
                component: component,
                totalTrades: logs.count,
                signalCount: signalCount,
                winningSignals: winningSignals,
                winRate: winRate,
                avgScoreWhenWin: avgWin,
                avgScoreWhenLoss: avgLoss,
                predictivePower: predictivePower
            ))
        }
        
        return stats
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        globalStatsCache = nil
        symbolStatsCache.removeAll()
        lastAnalysisTime = nil
    }
}
