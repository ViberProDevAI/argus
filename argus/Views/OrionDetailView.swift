import SwiftUI

// MARK: - BIST TREND INDICATOR (NEW)
struct BistTrendIndicator: View {
    let momentum: Double
    let trend: Double
    let volatility: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Trend Icon
            Image(systemName: trendIcon)
                .font(.title3)
                .foregroundColor(trendColor)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("BIST TREND")
                        .font(.caption).bold().foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    
                    Text(trendState.rawValue)
                        .font(.caption).bold().foregroundColor(trendColor)
                }
                
                HStack(spacing: 8) {
                    Text("Momentum: \(String(format: "%.1f", momentum * 100))%")
                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("ADX: \(String(format: "%.1f", trend))")
                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text("Volatilite: \(volatility)")
                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.primary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(trendColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var trendIcon: String {
        switch trendState {
        case .strongUptrend: return "arrow.up.right.fill"
        case .uptrend: return "arrow.up.right"
        case .downtrend: return "arrow.down.right"
        case .strongDowntrend: return "arrow.down.right.fill"
        case .sideways: return "arrow.right"
        }
    }
    
    private var trendColor: Color {
        switch trendState {
        case .strongUptrend: return InstitutionalTheme.Colors.positive
        case .uptrend: return InstitutionalTheme.Colors.positive.opacity(0.75)
        case .downtrend: return InstitutionalTheme.Colors.negative.opacity(0.75)
        case .strongDowntrend: return InstitutionalTheme.Colors.negative
        case .sideways: return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    private var trendState: BistTrendState {
        if trend > 40 { return .strongUptrend }
        if trend > 25 { return .uptrend }
        if trend < 10 { return .strongDowntrend }
        if trend < 20 { return .downtrend }
        return .sideways
    }
}

enum BistTrendState: String {
    case strongUptrend = "Güçlü Yükseliş"
    case uptrend = "Yükseliş"
    case downtrend = "Düşüş"
    case strongDowntrend = "Güçlü Düşüş"
    case sideways = "Yatay"
}

// MARK: - EXTENSIONS FOR COMPATIBILITY
extension OrionScoreResult {
    var patternName: String? {
        if components.patternDesc.isEmpty || components.patternDesc == "Formasyon Yok" { return nil }
        return components.patternDesc
    }
}

// MARK: - PROFESSIONAL ORION DETAIL VIEW
struct OrionDetailView: View {
    let symbol: String
    let orion: OrionScoreResult
    let candles: [Candle]?
    let patterns: [OrionChartPattern]?
    
    @Environment(\.presentationMode) var presentationMode
    
    // Constant Theme Colors
    private let accentColor = SanctumTheme.orionColor
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: 1. COMPACT HEADER
                headerView
                
                Divider()
                    .background(InstitutionalTheme.Colors.borderSubtle)
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // MARK: BIST TREND INDICATOR
                        if symbol.hasSuffix(".IS") {
                            BistTrendIndicator(
                                momentum: orion.components.momentum,
                                trend: orion.components.trend,
                                volatility: orion.components.patternDesc
                            )
                            .padding(.horizontal)
                            
                            // BIST VOLATILITY MONITOR
                            if let candles = candles {
                                BistVolatilityMonitor(candles: candles)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // MARK: 2. HERO COMPONENT: ORION CONSTELLATION
                        OrionConstellationView(orion: orion, candles: candles ?? [])
                            .frame(height: 340)
                            .padding(.bottom, 8)
                        
                        // MARK: 3. VERBAL SUMMARY (Dynamic Narrative)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PİYASA DURUMU")
                                .font(.caption)
                                .bold()
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .tracking(1)
                            
                            Text(generateVerbalSummary(orion: orion))
                                .font(.subheadline)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(InstitutionalTheme.Colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        
                        // MARK: 4. DETAILED METRICS GRID
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // A. MOMENTUM
                            let momentumSignal = momentumSignal(for: resolvedRSI)
                            OrionCommandCard(
                                title: "MOMENTUM",
                                icon: "speedometer",
                                status: momentumSignal.title,
                                statusColor: momentumSignal.color
                            ) {
                                VStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("RSI")
                                                .font(.caption2)
                                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            Spacer()
                                            Text(String(format: "%.0f", resolvedRSI))
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                                .monospacedDigit()
                                        }
                                        LinearGauge(value: resolvedRSI, min: 0, max: 100, accent: momentumSignal.color)
                                        SegmentStrip(
                                            labels: ["Aşırı Satım", "Denge", "Aşırı Alım"],
                                            activeIndex: momentumSignal.index,
                                            activeColor: momentumSignal.color
                                        )
                                    }
                                    OrionMetricRow(label: "Skor", value: String(format: "%.1f / 25", orion.components.momentum))
                                    OrionMetricRow(label: "Ritim", value: momentumPaceText(for: resolvedRSI))
                                }
                            }
                            
                            // B. TREND
                            let trendSignal = trendSignal(for: resolvedTrendStrength)
                            OrionCommandCard(
                                title: "TREND",
                                icon: "chart.line.uptrend.xyaxis",
                                status: trendSignal.title,
                                statusColor: trendSignal.color
                            ) {
                                VStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text("GÜÇ (ADX)")
                                                .font(.caption2)
                                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                            Spacer()
                                            Text(String(format: "%.1f", resolvedTrendStrength))
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                                .monospacedDigit()
                                        }
                                        LinearGauge(value: resolvedTrendStrength, min: 0, max: 50, accent: trendSignal.color)
                                        SegmentStrip(
                                            labels: ["Zayıf", "Aktif", "Güçlü"],
                                            activeIndex: trendSignal.index,
                                            activeColor: trendSignal.color
                                        )
                                    }
                                    OrionMetricRow(label: "Yön", value: getTrendState(orion.components.trend))
                                    OrionMetricRow(label: "Skor", value: String(format: "%.1f / 25", orion.components.trend))
                                }
                            }
                            
                            // C. STRUCTURE
                            if let candles = candles, let last = candles.last {
                                let high = candles.map(\.high).max() ?? last.high
                                let low = candles.map(\.low).min() ?? last.low
                                let range = max(high - low, 0.0001)
                                let support = last.low - (range * 0.2)
                                let resistance = last.high + (range * 0.2)
                                let state = getStructureState(current: last.close, support: support, resistance: resistance)
                                let supportGap = max(0, ((last.close - support) / last.close) * 100)
                                let resistanceGap = max(0, ((resistance - last.close) / last.close) * 100)
                                
                                OrionCommandCard(
                                    title: "YAPI",
                                    icon: "building.columns.fill",
                                    status: state,
                                    statusColor: structureColor(for: state)
                                ) {
                                    VStack(spacing: 10) {
                                        StructureLinearMap(current: last.close, support: support, resistance: resistance)
                                        HStack(spacing: 8) {
                                            MiniDataPill(
                                                label: "Destek Mesafe",
                                                value: String(format: "%.1f%%", supportGap),
                                                color: InstitutionalTheme.Colors.positive
                                            )
                                            MiniDataPill(
                                                label: "Direnç Mesafe",
                                                value: String(format: "%.1f%%", resistanceGap),
                                                color: InstitutionalTheme.Colors.negative
                                            )
                                        }
                                        OrionMetricRow(label: "Konum", value: state)
                                    }
                                }
                            } else {
                                OrionCommandCard(
                                    title: "YAPI",
                                    icon: "building.columns.fill",
                                    status: "Veri Bekleniyor",
                                    statusColor: InstitutionalTheme.Colors.warning
                                ) {
                                    Text("Fiyat mumları henüz hazır değil")
                                        .font(.caption)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            
                            // D. PATTERN (Context)
                            let patternContext = patternContextInfo
                            OrionCommandCard(
                                title: "FORMASYON",
                                icon: "eye.fill",
                                status: patternContext.state,
                                statusColor: patternContext.color
                            ) {
                                VStack(spacing: 10) {
                                    Text(patternContext.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                    
                                    if let candles = candles, !candles.isEmpty {
                                        if let firstPattern = patterns?.first {
                                            OrionPatternGraphView(pattern: firstPattern, candles: candles)
                                                .frame(height: 60)
                                        } else {
                                            Sparkline(data: candles.suffix(20).map { $0.close }, color: InstitutionalTheme.Colors.primary)
                                                .frame(height: 30)
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        MiniDataPill(
                                            label: "Güven",
                                            value: patternContext.confidenceText,
                                            color: patternContext.color
                                        )
                                        if let targetText = patternContext.targetText {
                                            MiniDataPill(
                                                label: "Hedef",
                                                value: targetText,
                                                color: InstitutionalTheme.Colors.primary
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: 4. CHIMERA SUMMARY (Simplified)
                        // Reduced to a simple data row block
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SİSTEM ÖZETİ")
                                .font(.caption)
                                .bold()
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("DNA Sürücü")
                                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    Text(dominantDriverTitle)
                                        .font(.caption).bold().foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Güven")
                                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    Text("%\(Int(orion.score))")
                                        .font(.caption).bold().foregroundColor(scoreColor(orion.score))
                                }
                            }
                            Divider().background(InstitutionalTheme.Colors.borderSubtle)
                            
                            HStack {
                                Circle().fill(riskHintColor).frame(width: 6, height: 6)
                                Text(riskHintText)
                                    .font(.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                        }
                        .padding()
                        .background(InstitutionalTheme.Colors.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    // MARK: - HEADER
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(symbol)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("TEKNİK ANALİZ RAPORU")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(orion.score))")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(scoreColor(orion.score))
                
                Text(getVerdictSummary(score: orion.score))
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(scoreColor(orion.score).opacity(0.2))
                    .foregroundColor(scoreColor(orion.score))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding()
        .background(InstitutionalTheme.Colors.background)
    }
    
    // MARK: - HELPERS
    private var resolvedRSI: Double {
        let fallback = min(max(orion.components.momentum * 4.0, 0), 100)
        return min(max(orion.components.rsi ?? fallback, 0), 100)
    }

    private var resolvedTrendStrength: Double {
        let fallback = min(max(orion.components.trend * 2.0, 0), 50)
        return min(max(orion.components.trendStrength ?? fallback, 0), 50)
    }

    private func momentumSignal(for rsi: Double) -> (title: String, color: Color, index: Int) {
        if rsi >= 70 { return ("Aşırı Alım", InstitutionalTheme.Colors.warning, 2) }
        if rsi <= 30 { return ("Aşırı Satım", InstitutionalTheme.Colors.negative, 0) }
        if rsi >= 55 { return ("Pozitif", InstitutionalTheme.Colors.positive, 1) }
        if rsi <= 45 { return ("Negatif", InstitutionalTheme.Colors.negative.opacity(0.75), 1) }
        return ("Denge", InstitutionalTheme.Colors.textSecondary, 1)
    }

    private func momentumPaceText(for rsi: Double) -> String {
        if rsi >= 70 || rsi <= 30 { return "Volatil" }
        if rsi >= 60 || rsi <= 40 { return "Hızlı" }
        return "Dengeli"
    }

    private func trendSignal(for strength: Double) -> (title: String, color: Color, index: Int) {
        if strength >= 35 { return ("Güçlü Trend", InstitutionalTheme.Colors.positive, 2) }
        if strength >= 25 { return ("Aktif Trend", InstitutionalTheme.Colors.primary, 1) }
        if strength >= 15 { return ("Kırılgan", InstitutionalTheme.Colors.warning, 1) }
        return ("Yatay/Zayıf", InstitutionalTheme.Colors.textSecondary, 0)
    }

    private func structureColor(for state: String) -> Color {
        switch state {
        case "Dirence Yakın":
            return InstitutionalTheme.Colors.warning
        case "Desteğe Yakın":
            return InstitutionalTheme.Colors.positive
        case "Kanal İçi":
            return InstitutionalTheme.Colors.primary
        default:
            return InstitutionalTheme.Colors.textSecondary
        }
    }

    private var patternContextInfo: (title: String, state: String, color: Color, confidenceText: String, targetText: String?) {
        let fallbackConfidence = min(max((orion.components.pattern / 15.0) * 100.0, 0), 100)
        let fallbackConfidenceText = "%\(Int(fallbackConfidence.rounded()))"

        if let pattern = patterns?.first {
            let state = pattern.type.isBullish ? "Boğa" : (pattern.type.isBearish ? "Ayı" : "Nötr")
            let color = pattern.type.isBullish ? InstitutionalTheme.Colors.positive : (pattern.type.isBearish ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textSecondary)
            let confidence = "%\(Int(pattern.confidence.rounded()))"
            let targetText = pattern.targetPrice.map { String(format: "%.2f", $0) }
            return (pattern.type.rawValue, state, color, confidence, targetText)
        }

        let title = orion.patternName ?? "Formasyon Yok"
        let lower = title.lowercased()
        let bullish = ["dip", "boğa", "bull", "tobo"].contains { lower.contains($0) }
        let bearish = ["tepe", "ayı", "bear", "obo"].contains { lower.contains($0) }
        let state = bullish ? "Boğa" : (bearish ? "Ayı" : "Nötr")
        let color = bullish ? InstitutionalTheme.Colors.positive : (bearish ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textSecondary)
        return (title, state, color, fallbackConfidenceText, nil)
    }
    
    func getTrendState(_ val: Double) -> String {
        if val > 15 { return "Yükseliş" }
        if val > 10 { return "Yatay" }
        return "Düşüş/Zayıf"
    }
    
    func getStructureState(current: Double, support: Double, resistance: Double) -> String {
        let range = resistance - support
        guard range > 0 else { return "Belirsiz" }
        let pos = (current - support) / range
        if pos > 0.8 { return "Dirence Yakın" }
        if pos < 0.2 { return "Desteğe Yakın" }
        return "Kanal İçi"
    }
    
    func scoreColor(_ score: Double) -> Color {
        score >= 60 ? InstitutionalTheme.Colors.positive : (score <= 40 ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.warning)
    }
    
    func getVerdictSummary(score: Double) -> String {
        if score >= 75 { return "GÜÇLÜ AL" }
        if score >= 60 { return "AL" }
        if score >= 40 { return "TUT" }
        return "SAT"
    }

    private var dominantDriverTitle: String {
        let pairs: [(String, Double)] = [
            ("Trend", orion.components.trend),
            ("Momentum", orion.components.momentum),
            ("Yapı", orion.components.structure),
            ("Formasyon", orion.components.pattern)
        ]
        return pairs.max(by: { $0.1 < $1.1 })?.0 ?? "Nötr"
    }

    private var riskHintText: String {
        if let rsi = orion.components.rsi {
            if rsi > 70 { return "RSI aşırı alım bölgesinde, temkinli kal" }
            if rsi < 30 { return "RSI aşırı satım bölgesinde, tepki olasılığı var" }
        }
        if let trendStrength = orion.components.trendStrength, trendStrength < 15 {
            return "Trend gücü zayıf, kırılım teyidi bekle"
        }
        return "Sinyaller dengeli, plan disiplinini koru"
    }

    private var riskHintColor: Color {
        if let rsi = orion.components.rsi, (rsi > 70 || rsi < 30) {
            return InstitutionalTheme.Colors.warning
        }
        if let trendStrength = orion.components.trendStrength, trendStrength < 15 {
            return InstitutionalTheme.Colors.negative
        }
        return InstitutionalTheme.Colors.positive
    }
    
    // MARK: - NARRATIVE ENGINE
    func generateVerbalSummary(orion: OrionScoreResult) -> String {
        var narrative = ""
        
        // 1. Trend Context
        if orion.components.trend > 15 {
            narrative += "Fiyat güçlü bir yükseliş trendinde hareket ediyor. "
        } else if orion.components.trend > 10 {
            narrative += "Piyasa şu anda kararsız (yatay) bir seyir izliyor. "
        } else {
            narrative += "Düşüş baskısı hakim, satıcılar kontrolü elinde tutuyor. "
        }
        
        // 2. Momentum & Divergence Check
        // Simplified Logic: High Score + Low Momentum = Divergence Risk
        if orion.score > 70 && orion.components.momentum < 50 {
            narrative += "ANCAK DİKKAT: Fiyat yükselmesine rağmen momentum zayıflıyor (Negatif Uyumsuzluk). Bu, yükselişin 'yakıtsız' kaldığını ve bir düzeltme gelebileceğini işaret eder."
        } else if orion.score < 30 && orion.components.momentum > 50 {
            narrative += "ÖNEMLİ: Fiyat diplerde olsa da momentum toparlanıyor (Pozitif Uyumsuzluk). Akıllı para (Smart Money) buralardan topluyor olabilir."
        } else if orion.components.momentum > 80 {
            narrative += "Momentum 'Aşırı Alım' bölgesinde. Fiyat çok hızlı yükseldi, kar realizasyonu (satış) gelmesi doğaldır."
        } else {
            narrative += "Momentum ise fiyat hareketini destekliyor, trend sağlıklı görünüyor."
        }
        
        return narrative
    }
}

// MARK: - COMPONENTS

struct OrionCommandCard<Content: View>: View {
    let title: String
    let icon: String
    let status: String?
    let statusColor: Color?
    let content: () -> Content

    init(
        title: String,
        icon: String,
        status: String? = nil,
        statusColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.status = status
        self.statusColor = statusColor
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1)
                Spacer()
                if let status {
                    Text(status.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(statusColor ?? InstitutionalTheme.Colors.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background((statusColor ?? InstitutionalTheme.Colors.textSecondary).opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            
            content()
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

struct OrionMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
        }
        .padding(.top, 4)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(InstitutionalTheme.Colors.borderSubtle),
            alignment: .top
        )
    }
}

struct SegmentStrip: View {
    let labels: [String]
    let activeIndex: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(index == activeIndex ? activeColor : InstitutionalTheme.Colors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(index == activeIndex ? activeColor.opacity(0.16) : InstitutionalTheme.Colors.surface2)
                    )
            }
        }
    }
}

struct MiniDataPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

struct LinearGauge: View {
    let value: Double
    let min: Double
    let max: Double
    let accent: Color
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 4)
                
                let width = geo.size.width
                let range = max - min
                let percent = (value - min) / (range > 0 ? range : 1.0)
                let fillWidth = width * CGFloat(Swift.min(Swift.max(percent, 0), 1.0))
                
                Capsule()
                    .fill(accent)
                    .frame(width: fillWidth, height: 4)
            }
        }
        .frame(height: 4)
    }
}

struct StructureLinearMap: View {
    let current: Double
    let support: Double
    let resistance: Double
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule().fill(InstitutionalTheme.Colors.borderSubtle).frame(height: 4)
                    
                    // Markers
                    let w = geo.size.width
                    let range = resistance - support
                    let p = range > 0 ? (current - support) / range : 0.5
                    
                    // Current Price Dot
                    Circle()
                        .fill(InstitutionalTheme.Colors.textPrimary)
                        .frame(width: 8, height: 8)
                        .offset(x: w * CGFloat(Swift.min(Swift.max(p, 0), 1.0)) - 4)
                }
            }
            .frame(height: 10)
            
            HStack {
                Text("S").font(.system(size: 8, weight: .black)).foregroundColor(InstitutionalTheme.Colors.positive)
                Spacer()
                Text("R").font(.system(size: 8, weight: .black)).foregroundColor(InstitutionalTheme.Colors.negative)
            }
        }
    }
}

struct PatternCommandCard: View {
    let pattern: OrionChartPattern
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("FORMASYON UYARISI")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1)
                
                Text(pattern.type.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("GÜVEN")
                    .font(.system(size: 8))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text("%\(Int(pattern.confidence))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(pattern.type.isBullish ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(pattern.type.isBullish ? InstitutionalTheme.Colors.positive.opacity(0.12) : InstitutionalTheme.Colors.negative.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(pattern.type.isBullish ? InstitutionalTheme.Colors.positive.opacity(0.3) : InstitutionalTheme.Colors.negative.opacity(0.3), lineWidth: 1)
        )
    }
}

struct Sparkline: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let points = data
            let minVal = points.min() ?? 0
            let maxVal = points.max() ?? 1
            let range = maxVal - minVal
            let stepX = geo.size.width / CGFloat(max(1, points.count - 1))
            
            Path { path in
                for (i, val) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height - ((val - minVal) / (range > 0 ? range : 1.0) * geo.size.height)
                    
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}

// MARK: - BIST VOLATILITY COMPONENT
struct BistVolatilityMonitor: View {
    let candles: [Candle]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                Text("BIST VOLATİLİTE")
                    .font(.caption).bold().foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text(String(format: "%.2f%%", volatility))
                    .font(.caption).bold().foregroundColor(volatilityColor)
            }
            
            HStack(spacing: 12) {
                VolatilityBar(label: "Gündüz", value: intradayVolatility, color: InstitutionalTheme.Colors.warning)
                VolatilityBar(label: "Gece", value: overnightVolatility, color: Color(hex: "8B5CF6"))
                VolatilityBar(label: "Seans", value: sessionVolatility, color: InstitutionalTheme.Colors.primary)
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(volatilityColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    var volatility: Double {
        guard !candles.isEmpty else { return 0 }
        let closePrices = candles.map { $0.close }
        let mean = closePrices.reduce(0, +) / Double(closePrices.count)
        let variance = closePrices.map { pow($0 - mean, 2) }.reduce(0, +) / Double(closePrices.count)
        return sqrt(variance) / mean * 100
    }
    
    var intradayVolatility: Double {
        guard !candles.isEmpty else { return 0 }
        let ranges = candles.map { $0.high - $0.low }
        let avg = ranges.reduce(0, +) / Double(ranges.count)
        return avg / candles.first!.close * 100
    }
    
    var overnightVolatility: Double {
        guard candles.count >= 2 else { return 0 }
        let gaps = zip(candles, candles.dropFirst()).map { abs($0.close - $1.open) / $0.close }
        return gaps.reduce(0, +) / Double(gaps.count) * 100
    }
    
    var sessionVolatility: Double {
        // Simplified: Use current volatility
        return volatility
    }
    
    var volatilityColor: Color {
        switch volatility {
        case 0..<1: return InstitutionalTheme.Colors.positive
        case 1..<2: return InstitutionalTheme.Colors.positive.opacity(0.75)
        case 2..<3: return InstitutionalTheme.Colors.warning
        case 3..<5: return InstitutionalTheme.Colors.warning.opacity(0.85)
        default: return InstitutionalTheme.Colors.negative
        }
    }
}

struct VolatilityBar: View {
    let label: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 6)
                
                Capsule()
                    .fill(color)
                    .frame(width: min(CGFloat(value * 20), CGFloat(60)), height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
