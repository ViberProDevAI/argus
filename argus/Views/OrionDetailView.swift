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
                        .font(.caption).bold().foregroundColor(.gray)
                    
                    Text(trendState.rawValue)
                        .font(.caption).bold().foregroundColor(trendColor)
                }
                
                HStack(spacing: 8) {
                    Text("Momentum: \(String(format: "%.1f", momentum * 100))%")
                        .font(.caption2).foregroundColor(.gray)
                    Text("ADX: \(String(format: "%.1f", trend))")
                        .font(.caption2).foregroundColor(.gray)
                    Text("Volatilite: \(volatility)")
                        .font(.caption2).foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
        case .strongUptrend: return .green
        case .uptrend: return Color.green.opacity(0.7)
        case .downtrend: return Color.red.opacity(0.7)
        case .strongDowntrend: return .red
        case .sideways: return .gray
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
    
    // Constant Theme Colors for Professional Look
    private let accentColor = Color.cyan // Professional Terminal Color
    private let neutralColor = Color.gray.opacity(0.4)
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: 1. COMPACT HEADER
                headerView
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
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
                                .foregroundColor(.gray)
                                .tracking(1)
                            
                            Text(generateVerbalSummary(orion: orion))
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // MARK: 4. DETAILED METRICS GRID
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            
                            // A. MOMENTUM
                            OrionCommandCard(title: "MOMENTUM", icon: "speedometer") {
                                VStack(spacing: 12) {
                                    // RSI Linear Gauge
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("RSI")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(String(format: "%.0f", orion.components.momentum * 4.0)) // Approx RSI Mapping
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.white)
                                        }
                                        LinearGauge(value: orion.components.momentum * 4.0, min: 0, max: 100, accent: accentColor)
                                    }
                                    
                                    OrionMetricRow(label: "Durum", value: getMomentumState(orion.components.momentum))
                                }
                            }
                            
                            // B. TREND
                            OrionCommandCard(title: "TREND", icon: "chart.line.uptrend.xyaxis") {
                                VStack(spacing: 12) {
                                    // ADX / Strength
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("GÜÇ (ADX)")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(String(format: "%.1f", orion.components.trend))
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.white)
                                        }
                                        // Trend Score is 0-25 typically in Orion v2 logic, mapping to bar
                                        LinearGauge(value: orion.components.trend, min: 0, max: 25, accent: .purple)
                                    }
                                    
                                    OrionMetricRow(label: "Yön", value: getTrendState(orion.components.trend))
                                }
                            }
                            
                            // C. STRUCTURE
                            OrionCommandCard(title: "YAPI", icon: "building.columns.fill") {
                                VStack(spacing: 12) {
                                    if let candles = candles, let last = candles.last {
                                        let h = candles.map { $0.high }.max() ?? last.high
                                        let l = candles.map { $0.low }.min() ?? last.low
                                        let range = h - l
                                        let sup = last.low - (range * 0.2)
                                        let res = last.high + (range * 0.2)
                                        
                                        StructureLinearMap(current: last.close, support: sup, resistance: res)
                                        
                                        OrionMetricRow(label: "Konum", value: getStructureState(current: last.close, support: sup, resistance: res))
                                    } else {
                                        Text("Veri Yok").font(.caption).foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            // D. PATTERN (Context)
                            OrionCommandCard(title: "FORMASYON", icon: "eye.fill") {
                                VStack(spacing: 12) {
                                    Text(orion.patternName ?? "Nötr")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                    
                                    if let candles = candles, !candles.isEmpty {
                                        // Simple Sparkline
                                        Sparkline(data: candles.suffix(10).map { $0.close }, color: .pink)
                                            .frame(height: 20)
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
                                .foregroundColor(.gray)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("DNA Sürücü")
                                        .font(.caption2).foregroundColor(.gray)
                                    Text("Teknik") // Placeholder or logic
                                        .font(.caption).bold().foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Güven")
                                        .font(.caption2).foregroundColor(.gray)
                                    Text("%85") // Placeholder
                                        .font(.caption).bold().foregroundColor(.green)
                                }
                            }
                            Divider().background(Color.white.opacity(0.1))
                            
                            HStack {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                Text("Volatilite Yüksek - Temkinli Ol")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
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
                    .foregroundColor(.white)
                Text("TEKNİK ANALİZ RAPORU")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
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
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Theme.background)
    }
    
    // MARK: - HELPERS
    func getMomentumState(_ val: Double) -> String {
        if val > 20 { return "Aşırı Alım" }
        if val > 15 { return "Güçlü" }
        if val < 5 { return "Aşırı Satım" }
        return "Nötr"
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
        score >= 60 ? .green : (score <= 40 ? .red : .yellow)
    }
    
    func getVerdictSummary(score: Double) -> String {
        if score >= 75 { return "GÜÇLÜ AL" }
        if score >= 60 { return "AL" }
        if score >= 40 { return "TUT" }
        return "SAT"
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
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1)
                Spacer()
            }
            
            content()
        }
        .padding(12)
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

struct OrionMetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.top, 4)
        .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.05)), alignment: .top)
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
                    .fill(Color.white.opacity(0.1))
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
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                    
                    // Markers
                    let w = geo.size.width
                    let range = resistance - support
                    let p = range > 0 ? (current - support) / range : 0.5
                    
                    // Current Price Dot
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: w * CGFloat(Swift.min(Swift.max(p, 0), 1.0)) - 4)
                }
            }
            .frame(height: 10)
            
            HStack {
                Text("S").font(.system(size: 8, weight: .black)).foregroundColor(.green)
                Spacer()
                Text("R").font(.system(size: 8, weight: .black)).foregroundColor(.red)
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
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                
                Text(pattern.type.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("GÜVEN")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Text("%\(Int(pattern.confidence))")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(pattern.type.isBullish ? .green : .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(pattern.type.isBullish ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pattern.type.isBullish ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
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
                    .foregroundColor(.orange)
                Text("BIST VOLATİLİTE")
                    .font(.caption).bold().foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.2f%%", volatility))
                    .font(.caption).bold().foregroundColor(volatilityColor)
            }
            
            HStack(spacing: 12) {
                VolatilityBar(label: "Gündüz", value: intradayVolatility, color: .yellow)
                VolatilityBar(label: "Gece", value: overnightVolatility, color: .purple)
                VolatilityBar(label: "Seans", value: sessionVolatility, color: .blue)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
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
        case 0..<1: return .green
        case 1..<2: return Color.green.opacity(0.7)
        case 2..<3: return .yellow
        case 3..<5: return .orange
        default: return .red
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
                .font(.caption2).foregroundColor(.gray)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 6)
                
                Capsule()
                    .fill(color)
                    .frame(width: min(CGFloat(value * 20), CGFloat(60)), height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
