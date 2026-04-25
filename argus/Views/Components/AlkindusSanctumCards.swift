import SwiftUI

// MARK: - Alkindus Indicator Card
/// Shows trusted/avoided indicators for a symbol in Sanctum.

// MARK: - Alkindus Sage Card (Header)
/// The "Persona" card. Shows the animated Avatar and a high-level summary/message.
struct AlkindusSageCard: View {
    let symbol: String
    @State private var message: String = "Piyasadaki izleri okuyorum..."
    @State private var isThinking: Bool = true
    
    // Theme Colors
    private let cardBg = Color(red: 0.05, green: 0.07, blue: 0.10)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            AlkindusAvatarView(size: 80, isThinking: isThinking, hasIdea: false)
            
            // Message Bubble
            VStack(alignment: .leading, spacing: 6) {
                Text("ALKINDUS")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(gold)
                    .tracking(2)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(gold.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .padding()
        .background(cardBg)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [gold.opacity(0.3), Color.clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .task {
            // Simulate "Thinking" phase then show wisdom
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isThinking = false
            message = "\(symbol) için yıldızlar ve fraktallar belirginleşiyor. Trend yapısında ilginç bir uyum var."
        }
    }
}


struct AlkindusIndicatorCard: View {
    let symbol: String
    
    @State private var advice: IndicatorAdvice?
    @State private var isLoading = true
    
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(gold)
                Text("İNDİKATÖR TAVSİYELERİ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                Spacer()
            }
            
            if isLoading {
                loadingView
            } else if let advice = advice {
                contentView(advice: advice)
            } else {
                emptyView
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
        .task {
            await loadData()
        }
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Yükleniyor...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private func contentView(advice: IndicatorAdvice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Trust indicators
            if !advice.trustIndicators.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(green)
                        .font(.caption)
                    Text("Güven:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(advice.trustIndicators, id: \.rawValue) { ind in
                        indicatorBadge(ind.displayName, color: green)
                    }
                }
            }
            
            // Avoid indicators
            if !advice.avoidIndicators.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(red)
                        .font(.caption)
                    Text("Kaçın:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(advice.avoidIndicators, id: \.rawValue) { ind in
                        indicatorBadge(ind.displayName, color: red)
                    }
                }
            }
            
            // Summary
            Text(advice.trustMessage)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func indicatorBadge(_ name: String, color: Color) -> some View {
        Text(name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(DesignTokens.Opacity.glassCard))
            .cornerRadius(4)
    }
    
    private var emptyView: some View {
        Text("Henüz \(symbol) için indikatör verisi yok")
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.vertical, 4)
    }
    
    private func loadData() async {
        isLoading = true
        advice = await AlkindusIndicatorLearner.shared.getIndicatorAdvice(for: symbol, timeframe: "1d")
        isLoading = false
    }
}

// MARK: - Alkindus Pattern Card
/// Shows trusted/avoided patterns for a symbol in Sanctum.

struct AlkindusPatternCard: View {
    let symbol: String
    
    @State private var bestPatterns: [PatternStat] = []
    @State private var worstPatterns: [PatternStat] = []
    @State private var isLoading = true
    
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(cyan)
                Text("FORMASYON TAVSİYELERİ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                Spacer()
            }
            
            if isLoading {
                loadingView
            } else if !bestPatterns.isEmpty || !worstPatterns.isEmpty {
                contentView
            } else {
                emptyView
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
        .task {
            await loadData()
        }
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Yükleniyor...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Best patterns
            if !bestPatterns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(gold)
                            .font(.caption2)
                        Text("Bu hissede işe yarayan:")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    ForEach(bestPatterns.prefix(3), id: \.pattern.rawValue) { stat in
                        patternRow(stat, isGood: true)
                    }
                }
            }
            
            // Worst patterns
            if !worstPatterns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text("Dikkatli ol:")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    ForEach(worstPatterns.prefix(2), id: \.pattern.rawValue) { stat in
                        patternRow(stat, isGood: false)
                    }
                }
            }
        }
    }
    
    private func patternRow(_ stat: PatternStat, isGood: Bool) -> some View {
        HStack {
            Text(stat.pattern.displayName)
                .font(.caption)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(Int(stat.hitRate * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isGood ? green : red)
            
            Text("(\(stat.samples))")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    private var emptyView: some View {
        Text("Henüz \(symbol) için formasyon verisi yok")
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.vertical, 4)
    }
    
    private func loadData() async {
        isLoading = true
        let stats = await AlkindusPatternLearner.shared.getPatternStats(for: symbol)
        bestPatterns = stats.filter { $0.hitRate >= 0.60 }
        worstPatterns = stats.filter { $0.hitRate < 0.45 }
        isLoading = false
    }
}

// MARK: - Alkindus Multi-Frame Summary Card
/// Shows multi-timeframe consensus in a compact format.

struct AlkindusMultiFrameCard: View {
    let symbol: String
    
    @State private var report: OrionMultiFrameEngine.MultiFrameReport?
    @State private var isLoading = true
    
    private let cardBg = Color(red: 0.06, green: 0.08, blue: 0.12)
    private let gold = Color(red: 1.0, green: 0.8, blue: 0.2)
    private let green = Color(red: 0.0, green: 0.8, blue: 0.4)
    private let red = Color(red: 0.9, green: 0.2, blue: 0.2)
    private let cyan = Color(red: 0.0, green: 0.8, blue: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(gold)
                Text("MULTI-TIMEFRAME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(1)
                Spacer()
            }
            
            if isLoading {
                loadingView
            } else if let report = report {
                contentView(report: report)
            } else {
                emptyView
            }
        }
        .padding()
        .background(cardBg)
        .cornerRadius(12)
        .task {
            await loadData()
        }
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Analiz yapılıyor...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private func contentView(report: OrionMultiFrameEngine.MultiFrameReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Consensus badge
            HStack {
                Text(report.consensus.overallSignal.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(signalColor(report.consensus.overallSignal))
                
                Spacer()
                
                Text(report.consensus.alignment.rawValue)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Timeframe dots
            HStack(spacing: 8) {
                ForEach(report.analyses, id: \.timeframe.rawValue) { analysis in
                    VStack(spacing: 2) {
                        Circle()
                            .fill(signalColor(analysis.signal))
                            .frame(width: 10, height: 10)
                        Text(analysis.timeframe.shortName)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Summary
            Text(report.consensus.summary)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func signalColor(_ signal: OrionMultiFrameEngine.TimeframeAnalysis.Signal) -> Color {
        switch signal {
        case .strongBuy: return green
        case .buy: return green.opacity(0.7)
        case .neutral: return .gray
        case .sell: return red.opacity(0.7)
        case .strongSell: return red
        }
    }
    
    private var emptyView: some View {
        Text("Multi-timeframe analiz yapılamadı")
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.vertical, 4)
    }
    
    private func loadData() async {
        isLoading = true
        // Simplified - in production would fetch actual candles
        report = await OrionMultiFrameEngine.shared.analyzeMultiFrame(symbol: symbol) { _, _ in
            nil // Would return actual candles in production
        }
        isLoading = false
    }
}

// MARK: - Previews

#Preview("Indicator Card") {
    AlkindusIndicatorCard(symbol: "AAPL")
        .padding()
        .background(Color.black)
}

#Preview("Pattern Card") {
    AlkindusPatternCard(symbol: "AAPL")
        .padding()
        .background(Color.black)
}

#Preview("Multi-Frame Card") {
    AlkindusMultiFrameCard(symbol: "AAPL")
        .padding()
        .background(Color.black)
}
