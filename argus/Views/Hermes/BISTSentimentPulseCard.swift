import SwiftUI

// MARK: - BIST Sentiment Pulse Card
// SentimentPulseCard'ın BIST versiyonu - RSS haberlerinden sentiment gösterir

struct BISTSentimentPulseCard: View {
    let symbol: String
    
    @State private var result: BISTSentimentResult?
    @State private var isLoading = true
    @State private var isExpanded = false
    @State private var showAllHeadlines = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - Header
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    // Icon ve Başlık
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result?.isGeneralMarketSentiment == true ? "Piyasa Nabzı (Genel)" : "Piyasa Nabzı")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if let r = result, r.newsVolume > 0 {
                                Text("\(r.relevantNewsCount) ilgili haber")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Sentiment Badge
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if let r = result, r.newsVolume > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(sentimentColor(r.overallScore))
                                .frame(width: 8, height: 8)
                            Text(r.sentimentLabel)
                                .font(.caption)
                                .foregroundColor(sentimentColor(r.overallScore))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(sentimentColor(r.overallScore).opacity(DesignTokens.Opacity.glassCard))
                        .cornerRadius(8)
                    } else {
                        Text("Veri Yok")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if let result = result, result.newsVolume > 0 {
                // MARK: - Sentiment Gauge
                VStack(spacing: 12) {
                    
                    // GENEL PIYASA UYARISI
                    if result.isGeneralMarketSentiment {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("Hisseye özel haber yok. Genel piyasa görünümü.")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        .padding(6)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // Ana Gauge
                    ZStack {
                        // Background Arc
                        Circle()
                            .trim(from: 0.25, to: 0.75)
                            .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(180))
                        
                        // Value Arc
                        Circle()
                            .trim(from: 0.25, to: 0.25 + (result.overallScore / 200))
                            .stroke(
                                sentimentGradient(result.overallScore),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(180))
                        
                        // Center Value
                        VStack(spacing: 2) {
                            Text("\(Int(result.overallScore))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(sentimentColor(result.overallScore))
                            Text("Sentiment")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(height: 80)
                    
                    // Trend Badge
                    HStack(spacing: 6) {
                        Image(systemName: trendIcon(result.mentionTrend))
                            .font(.caption)
                            .foregroundColor(trendColor(result.mentionTrend))
                        Text("Haber Akışı: \(result.mentionTrend.rawValue)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - Sentiment Breakdown
                HStack(spacing: 12) {
                    SentimentMiniCard(
                        title: "Olumlu",
                        percent: result.bullishPercent,
                        color: .green
                    )
                    SentimentMiniCard(
                        title: "Nötr",
                        percent: result.neutralPercent,
                        color: .gray
                    )
                    SentimentMiniCard(
                        title: "Olumsuz",
                        percent: result.bearishPercent,
                        color: .red
                    )
                }
                
                // MARK: - Expanded Content
                if isExpanded && !result.keyHeadlines.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider().background(Color.white.opacity(0.2))
                        
                        // Key Headlines
                        Text("Öne Çıkan Başlıklar")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.gray)
                        
                        let headlinesToShow = showAllHeadlines ? result.keyHeadlines : Array(result.keyHeadlines.prefix(3))
                        
                        ForEach(headlinesToShow, id: \.self) { headline in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                
                                Text(headline)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                        }
                        
                        if result.keyHeadlines.count > 3 {
                            Button(action: { withAnimation { showAllHeadlines.toggle() } }) {
                                Text(showAllHeadlines ? "Daha az göster" : "Tümünü göster (\(result.keyHeadlines.count))")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Son Güncelleme
                        HStack {
                            Spacer()
                            Text("Güncelleme: \(result.lastUpdated, style: .relative)")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    .transition(.opacity)
                }
            } else if !isLoading {
                // No Data State
                VStack(spacing: 12) {
                    Image(systemName: "newspaper")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Bu hisse için güncel haber bulunamadı")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear { loadData() }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            do {
                let sentiment = try await BISTSentimentEngine.shared.analyzeSentiment(for: symbol)
                await MainActor.run {
                    self.result = sentiment
                    self.isLoading = false
                }
            } catch {
                print("⚠️ BISTSentimentPulseCard: \(symbol) için sentiment alınamadı: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func sentimentColor(_ score: Double) -> Color {
        if score >= 65 { return .green }
        if score >= 55 { return Color(red: 0.6, green: 0.8, blue: 0.3) }
        if score >= 45 { return .yellow }
        if score >= 35 { return .orange }
        return .red
    }
    
    private func sentimentGradient(_ score: Double) -> LinearGradient {
        let color = sentimentColor(score)
        return LinearGradient(
            colors: [color.opacity(0.7), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func trendIcon(_ trend: MentionTrend) -> String {
        switch trend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    private func trendColor(_ trend: MentionTrend) -> Color {
        switch trend {
        case .increasing: return .green
        case .decreasing: return .red
        case .stable: return .gray
        }
    }
}

// MARK: - Sentiment Mini Card

private struct SentimentMiniCard: View {
    let title: String
    let percent: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            Text("\(Int(percent))%")
                .font(.headline.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BISTSentimentPulseCard(symbol: "THYAO.IS")
            .padding()
    }
}
