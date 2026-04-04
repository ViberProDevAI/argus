import Foundation

// MARK: - Correlation Heat Gate
/// Portföydeki gerçek riski ölçer. 5 açık pozisyon ≠ 5 bağımsız risk.
/// Eğer 5 BIST hissesi BİST100 ile %90 korelasyonsa → bu 1 pozisyon riski.
///
/// Basit yaklaşım: Fiyat hareketlerinden pairwise korelasyon hesapla.
/// Eğer 2 pozisyon > 0.75 korelasyonsa → aynı "risk grubu" say.

struct CorrelationHeatGate {

    // MARK: - Modeller

    struct CorrelationResult {
        let effectivePositionCount: Double  // Gerçek bağımsız pozisyon sayısı
        let rawPositionCount: Int           // Ham pozisyon sayısı
        let concentrationRisk: ConcentrationLevel
        let groups: [CorrelationGroup]      // Gruplandırılmış pozisyonlar
        let positionMultiplier: Double      // Yeni alıma uygulanacak çarpan

        enum ConcentrationLevel: Equatable {
            case healthy    // Gerçek çeşitlendirme var
            case moderate   // Orta konsantrasyon
            case high       // Yüksek konsantrasyon
            case critical   // Tek risk faktörü → yeni alım engelle

            var multiplier: Double {
                switch self {
                case .healthy:  return 1.0
                case .moderate: return 0.7
                case .high:     return 0.4
                case .critical: return 0.0
                }
            }

            var label: String {
                switch self {
                case .healthy:  return "Sağlıklı Çeşitlendirme"
                case .moderate: return "Orta Konsantrasyon"
                case .high:     return "Yüksek Konsantrasyon"
                case .critical: return "Kritik: Tek Risk Faktörü"
                }
            }
        }
    }

    struct CorrelationGroup {
        let symbols: [String]
        let avgCorrelation: Double
        let label: String  // "BIST Banka", "US Tech" gibi
    }

    // MARK: - Ana Değerlendirme

    /// Mevcut portföy ve fiyat geçmişiyle korelasyon analizi yap
    static func assess(
        portfolio: [Trade],
        priceHistory: [String: [Double]], // symbol → son 20 günlük kapanış
        maxIndependentPositions: Int = 8
    ) -> CorrelationResult {

        let openTrades = portfolio.filter { $0.isOpen }
        guard openTrades.count >= 2 else {
            return CorrelationResult(
                effectivePositionCount: Double(openTrades.count),
                rawPositionCount: openTrades.count,
                concentrationRisk: .healthy,
                groups: [],
                positionMultiplier: 1.0
            )
        }

        let symbols = openTrades.map { $0.symbol }
        let matrix = buildCorrelationMatrix(symbols: symbols, history: priceHistory)
        let groups = clusterByCorrelation(symbols: symbols, matrix: matrix, threshold: 0.75)

        // Efektif pozisyon sayısı = korelasyon grupları
        let effectiveCount = Double(groups.count)
        let ratio = effectiveCount / Double(maxIndependentPositions)

        let concentration: CorrelationResult.ConcentrationLevel
        switch ratio {
        case ..<0.5:   concentration = .healthy
        case 0.5..<0.7: concentration = .moderate
        case 0.7..<0.9: concentration = .high
        default:        concentration = .critical
        }

        return CorrelationResult(
            effectivePositionCount: effectiveCount,
            rawPositionCount: openTrades.count,
            concentrationRisk: concentration,
            groups: groups,
            positionMultiplier: concentration.multiplier
        )
    }

    // MARK: - Korelasyon Matrisi

    private static func buildCorrelationMatrix(
        symbols: [String],
        history: [String: [Double]]
    ) -> [[Double]] {
        let n = symbols.count
        var matrix = Array(repeating: Array(repeating: 1.0, count: n), count: n)

        for i in 0..<n {
            for j in (i+1)..<n {
                let symA = symbols[i]
                let symB = symbols[j]
                guard let histA = history[symA], let histB = history[symB],
                      histA.count >= 11, histB.count >= 11 else {  // min 11 fiyat → 10 getiri → güvenilir Pearson
                    matrix[i][j] = 0.5
                    matrix[j][i] = 0.5
                    continue
                }

                let corr = pearsonCorrelation(
                    returns(from: histA),
                    returns(from: histB)
                )
                matrix[i][j] = corr
                matrix[j][i] = corr
            }
        }
        return matrix
    }

    private static func returns(from prices: [Double]) -> [Double] {
        guard prices.count >= 2 else { return [] }
        return zip(prices.dropFirst(), prices).map { ($0 - $1) / max(0.01, $1) }
    }

    private static func pearsonCorrelation(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n >= 10 else { return 0.5 }  // < 10 günlük veri → güvenilmez, nötr döndür

        let ax = Array(a.prefix(n))
        let bx = Array(b.prefix(n))

        let aMean = ax.reduce(0, +) / Double(n)
        let bMean = bx.reduce(0, +) / Double(n)

        let num = zip(ax, bx).reduce(0.0) { $0 + ($1.0 - aMean) * ($1.1 - bMean) }
        let denA = ax.reduce(0.0) { $0 + ($1 - aMean) * ($1 - aMean) }
        let denB = bx.reduce(0.0) { $0 + ($1 - bMean) * ($1 - bMean) }

        let den = sqrt(denA * denB)
        guard den > 0 else { return 0 }
        return max(-1, min(1, num / den))
    }

    // MARK: - Kümeleme (Union-Find)

    private static func clusterByCorrelation(
        symbols: [String],
        matrix: [[Double]],
        threshold: Double
    ) -> [CorrelationGroup] {
        let n = symbols.count
        var parent = Array(0..<n)

        func find(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { i = parent[i] }
            return i
        }

        func union(_ a: Int, _ b: Int) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        for i in 0..<n {
            for j in (i+1)..<n {
                if matrix[i][j] >= threshold {
                    union(i, j)
                }
            }
        }

        // Grupları topla
        var groupMap: [Int: [String]] = [:]
        for i in 0..<n {
            let root = find(i)
            groupMap[root, default: []].append(symbols[i])
        }

        return groupMap.map { (root, syms) in
            // Grup içi ortalama korelasyon
            let pairs = syms.count > 1 ? calculateAvgCorrelation(syms: syms, symbols: symbols, matrix: matrix) : 1.0
            let label = guessGroupLabel(symbols: syms)
            return CorrelationGroup(symbols: syms, avgCorrelation: pairs, label: label)
        }.sorted { $0.symbols.count > $1.symbols.count }
    }

    private static func calculateAvgCorrelation(syms: [String], symbols: [String], matrix: [[Double]]) -> Double {
        var total = 0.0, count = 0
        for i in 0..<syms.count {
            for j in (i+1)..<syms.count {
                guard let idxA = symbols.firstIndex(of: syms[i]),
                      let idxB = symbols.firstIndex(of: syms[j]) else { continue }
                total += matrix[idxA][idxB]
                count += 1
            }
        }
        return count > 0 ? total / Double(count) : 1.0
    }

    private static func guessGroupLabel(symbols: [String]) -> String {
        let hasBIST = symbols.contains { SymbolResolver.shared.isBistSymbol($0) }
        let hasUS   = symbols.contains { !SymbolResolver.shared.isBistSymbol($0) }

        if hasBIST && !hasUS { return "BIST Grubu" }
        if hasUS && !hasBIST {
            let techSymbols = ["AAPL","MSFT","GOOGL","META","NVDA","AMZN","TSLA"]
            if symbols.contains(where: { techSymbols.contains($0) }) { return "ABD Teknoloji" }
            return "ABD Hisse"
        }
        if symbols.count == 1 { return symbols[0] }
        return "Karma Grup"
    }
}
