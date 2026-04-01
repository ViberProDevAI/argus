import SwiftUI

// MARK: - Argus Performance Dashboard
/// Faz 2: Argus'un geçmiş performansını görsel olarak sunar.
/// Hangi modül güvenilir, hangi rejimde iyi çalışıyor, güven skoru kazandırıyor mu?
/// Settings → "Performans Paneli" menüsünden erişilir.

struct ArgusPerformanceDashboard: View {

    @State private var data: PerfData? = nil
    @State private var isLoading = true
    @State private var selectedPeriod: Period = .all

    enum Period: String, CaseIterable {
        case last30 = "30 Gün"
        case last90 = "90 Gün"
        case all    = "Tümü"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Analiz ediliyor...")
                        .padding(60)
                        .foregroundColor(.gray)
                } else if let d = data {
                    if d.isEmpty {
                        emptyState
                    } else {
                        periodPicker
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        summaryRow(d)
                            .padding(.horizontal, 16)

                        modulePerformanceCard(d)
                            .padding(.horizontal, 16)

                        regimeCard(d)
                            .padding(.horizontal, 16)

                        confidenceCard(d)
                            .padding(.horizontal, 16)

                        verdictTimelineCard(d)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Performans Paneli")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: selectedPeriod) { _ in Task { await reload() } }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { p in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedPeriod = p }
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 12, weight: selectedPeriod == p ? .bold : .regular, design: .monospaced))
                        .foregroundColor(selectedPeriod == p ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selectedPeriod == p ? Theme.tint : Color.clear)
                }
            }
        }
        .background(Color.white.opacity(0.07))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Summary Row

    @ViewBuilder
    private func summaryRow(_ d: PerfData) -> some View {
        HStack(spacing: 0) {
            summaryCell(
                value: "\(d.filteredVerdicts.count)",
                label: "Analiz",
                color: .white
            )
            divider()
            summaryCell(
                value: d.overallAccuracyText,
                label: "Doğruluk",
                color: d.overallAccuracy >= 0.55 ? .green : d.overallAccuracy >= 0.45 ? .orange : .red
            )
            divider()
            summaryCell(
                value: "\(d.tradeWinCount)W/\(d.tradeLossCount)L",
                label: "Trade",
                color: .white
            )
            divider()
            summaryCell(
                value: d.tradeWinRateText,
                label: "Win Rate",
                color: d.tradeWinRate >= 0.5 ? .green : .red
            )
        }
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Module Performance Card

    @ViewBuilder
    private func modulePerformanceCard(_ d: PerfData) -> some View {
        perfCard(title: "MODÜL BAZLI DOĞRULUK", icon: "chart.bar.fill", color: .purple) {
            if d.moduleStats.isEmpty {
                emptyCardState("Yeterli modül verisi yok henüz")
            } else {
                VStack(spacing: 10) {
                    ForEach(d.moduleStats.sorted(by: { $0.hitRate > $1.hitRate }), id: \.module) { ms in
                        moduleBar(ms)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private func moduleBar(_ ms: ModuleStat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ms.module.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(ms.hitRateText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(ms.barColor)
                Text("(\(ms.attempts) veri)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ms.barColor)
                        .frame(width: geo.size.width * ms.hitRate, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Regime Card

    @ViewBuilder
    private func regimeCard(_ d: PerfData) -> some View {
        perfCard(title: "REJİM BAZLI PERFORMANS", icon: "waveform.path.ecg", color: .cyan) {
            if d.regimeStats.isEmpty {
                emptyCardState("Yeterli rejim verisi yok henüz")
            } else {
                VStack(spacing: 0) {
                    ForEach(d.regimeStats, id: \.regime) { rs in
                        HStack {
                            Text(rs.regimeLabel)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Text("\(rs.correct)/\(rs.total)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(rs.hitRateText)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(rs.hitRate >= 0.55 ? .green : rs.hitRate >= 0.45 ? .orange : .red)
                                .frame(width: 45, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        if rs.regime != d.regimeStats.last?.regime {
                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Confidence Calibration Card

    @ViewBuilder
    private func confidenceCard(_ d: PerfData) -> some View {
        perfCard(title: "GÜVEN SKORU KALIBRASYONU", icon: "scope", color: .yellow) {
            if d.confidenceBuckets.isEmpty {
                emptyCardState("Kalibrasyon verisi yok henüz")
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("Güven Aralığı")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Gerçek Doğruluk")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    ForEach(d.confidenceBuckets, id: \.bracket) { cb in
                        HStack(spacing: 10) {
                            Text(cb.bracket)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.07))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(cb.hitRate > cb.expectedRate ? Color.green : Color.orange)
                                        .frame(width: geo.size.width * min(cb.hitRate, 1.0), height: 6)
                                    // Expected marker
                                    Rectangle()
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: 1.5, height: 10)
                                        .offset(x: geo.size.width * cb.expectedRate - 0.75)
                                }
                            }
                            .frame(height: 10)

                            Text(String(format: "%.0f%%", cb.hitRate * 100))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(cb.hitRate > cb.expectedRate ? .green : .orange)
                                .frame(width: 38, alignment: .trailing)

                            Text("n=\(cb.n)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                    }

                    Text("Beyaz çizgi = beklenen (declare ettiğin güven). Yeşil = iyi kalibre. Turuncu = güvenin yanlış ayarlı.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Verdict Timeline Card

    @ViewBuilder
    private func verdictTimelineCard(_ d: PerfData) -> some View {
        perfCard(title: "SON KARARLAR", icon: "clock.arrow.circlepath", color: .blue) {
            if d.filteredVerdicts.isEmpty {
                emptyCardState("Henüz tamamlanmış analiz yok")
            } else {
                VStack(spacing: 0) {
                    // Dot timeline
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(d.filteredVerdicts.suffix(40), id: \.id) { v in
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(v.wasCorrect ? Color.green : Color.red)
                                        .frame(width: 10, height: 10)
                                    Text(v.symbol.prefix(4))
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Divider().background(Color.white.opacity(0.06))

                    // Last 5 verdicts
                    ForEach(d.filteredVerdicts.suffix(5).reversed(), id: \.id) { v in
                        HStack(spacing: 10) {
                            Image(systemName: v.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(v.wasCorrect ? .green : .red)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(v.symbol) · \(v.action) · T+\(v.horizon)")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Text(v.evaluationDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Text(String(format: "%+.1f%%", v.priceChange))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(v.priceChange >= 0 ? .green : .red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Common Components

    @ViewBuilder
    private func perfCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            content()
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.15), lineWidth: 1))
    }

    @ViewBuilder
    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    @ViewBuilder private func divider() -> some View {
        Divider().frame(height: 40).background(Color.white.opacity(0.1))
    }

    @ViewBuilder
    private func emptyCardState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .italic()
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            AlkindusAvatarView(size: 60, isThinking: true)
            Text("Henüz yeterli veri yok")
                .font(.headline)
                .foregroundColor(.white)
            Text("Argus kararlar verdikçe ve pozisyonlar kapandıkça\nperformans verileri burada görünecek.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Data Loading

    private func reload() async {
        isLoading = true
        let verdicts = await AlkindusMemoryStore.shared.loadVerdicts()
        let cal = await AlkindusMemoryStore.shared.loadCalibration()
        let trades = TradeLogStore.shared.fetchLogs()

        let cutoff: Date? = {
            switch selectedPeriod {
            case .last30: return Calendar.current.date(byAdding: .day, value: -30, to: Date())
            case .last90: return Calendar.current.date(byAdding: .day, value: -90, to: Date())
            case .all:    return nil
            }
        }()

        let filtered = cutoff == nil ? verdicts : verdicts.filter { $0.evaluationDate >= cutoff! }
        let filteredTrades = cutoff == nil ? trades : trades.filter { $0.date >= cutoff! }

        data = PerfData(
            filteredVerdicts: filtered,
            calibration: cal,
            trades: filteredTrades
        )
        isLoading = false
    }
}

// MARK: - Data Models

private struct PerfData {
    let filteredVerdicts: [AlkindusVerdict]
    let calibration: CalibrationData
    let trades: [TradeLog]

    var isEmpty: Bool { filteredVerdicts.isEmpty && trades.isEmpty }

    // Overall accuracy
    var overallAccuracy: Double {
        guard !filteredVerdicts.isEmpty else { return 0 }
        return Double(filteredVerdicts.filter { $0.wasCorrect }.count) / Double(filteredVerdicts.count)
    }
    var overallAccuracyText: String {
        filteredVerdicts.isEmpty ? "—" : String(format: "%%%.0f", overallAccuracy * 100)
    }

    // Trade stats
    var tradeWinCount: Int { trades.filter { $0.isWin }.count }
    var tradeLossCount: Int { trades.filter { !$0.isWin }.count }
    var tradeWinRate: Double { trades.isEmpty ? 0 : Double(tradeWinCount) / Double(trades.count) }
    var tradeWinRateText: String { trades.isEmpty ? "—" : String(format: "%%%.0f", tradeWinRate * 100) }

    // Module stats from verdicts
    var moduleStats: [ModuleStat] {
        var map: [String: (correct: Int, total: Int)] = [:]
        for v in filteredVerdicts {
            for mv in v.moduleVerdicts {
                var cur = map[mv.module] ?? (0, 0)
                cur.total += 1
                if mv.wasCorrect { cur.correct += 1 }
                map[mv.module] = cur
            }
        }
        // Supplement with calibration data if verdict module data sparse
        for (module, moduleCal) in calibration.modules {
            if map[module] == nil {
                var total = 0.0, correct = 0.0
                for (_, bs) in moduleCal.brackets {
                    total += bs.attempts
                    correct += bs.correct
                }
                if total > 0 {
                    map[module] = (Int(correct), Int(total))
                }
            }
        }
        return map.map { ModuleStat(module: $0.key, correct: $0.value.correct, attempts: $0.value.total) }
    }

    // Regime stats from verdicts
    var regimeStats: [RegimeStat] {
        var map: [String: (correct: Int, total: Int)] = [:]
        for v in filteredVerdicts {
            var cur = map[v.regime] ?? (0, 0)
            cur.total += 1
            if v.wasCorrect { cur.correct += 1 }
            map[v.regime] = cur
        }
        return map.map { RegimeStat(regime: $0.key, correct: $0.value.correct, total: $0.value.total) }
            .sorted { $0.total > $1.total }
    }

    // Confidence calibration buckets
    var confidenceBuckets: [ConfidenceBucket] {
        var buckets: [(bracket: String, correct: Double, total: Double, expected: Double)] = []
        let bracketOrder = ["0-40", "40-60", "60-70", "70-80", "80-100"]

        for bracket in bracketOrder {
            var totalAttempts = 0.0
            var totalCorrect = 0.0
            for (_, moduleCal) in calibration.modules {
                if let bs = moduleCal.brackets[bracket] {
                    totalAttempts += bs.attempts
                    totalCorrect += bs.correct
                }
            }
            guard totalAttempts > 0 else { continue }
            let expectedRate = expectedWinRate(for: bracket)
            buckets.append((bracket, totalCorrect, totalAttempts, expectedRate))
        }

        return buckets.map {
            ConfidenceBucket(
                bracket: $0.bracket + "%%",
                hitRate: $0.total > 0 ? $0.correct / $0.total : 0,
                expectedRate: $0.expected,
                n: Int($0.total)
            )
        }
    }

    private func expectedWinRate(for bracket: String) -> Double {
        switch bracket {
        case "0-40":   return 0.35
        case "40-60":  return 0.50
        case "60-70":  return 0.62
        case "70-80":  return 0.72
        case "80-100": return 0.82
        default:       return 0.5
        }
    }
}

private struct ModuleStat {
    let module: String
    let correct: Int
    let attempts: Int
    var hitRate: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }
    var hitRateText: String { String(format: "%%%.0f", hitRate * 100) }
    var barColor: Color { hitRate >= 0.6 ? .green : hitRate >= 0.45 ? .orange : .red }
}

private struct RegimeStat {
    let regime: String
    let correct: Int
    let total: Int
    var hitRate: Double { total == 0 ? 0 : Double(correct) / Double(total) }
    var hitRateText: String { String(format: "%%%.0f", hitRate * 100) }
    var regimeLabel: String {
        switch regime.lowercased() {
        case let r where r.contains("bull"):     return "↑ Yükselen"
        case let r where r.contains("bear"):     return "↓ Düşen"
        case let r where r.contains("neutral"):  return "→ Nötr"
        case let r where r.contains("volatile"): return "⚡ Volatil"
        default: return regime
        }
    }
}

private struct ConfidenceBucket {
    let bracket: String
    let hitRate: Double
    let expectedRate: Double
    let n: Int
}
