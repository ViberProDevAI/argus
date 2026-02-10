import SwiftUI

/// Hermes V2: Sentiment Pulse Card
/// Displays sentiment analysis with dynamic Turkish commentary
struct SentimentPulseCard: View {
    let symbol: String
    @State private var sentiment: HermesQuickSentiment?
    @State private var isLoading = true
    @State private var cachedNews: [HermesSummary] = []
    @State private var commentary: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.purple)
                Text("SENTIMENT PULSE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                Spacer()
                Text(sourceBadgeText())
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(1.2)
                    
                    Text("Hermes piyasaya kulak kabarttı...")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.purple.opacity(0.8))
                        .transition(.opacity)
                }
                .frame(height: 100)
            } else if let sentiment = sentiment {
                // Main Sentiment Display
                HStack(spacing: 20) {
                    // Score Circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: sentiment.score / 100)
                            .stroke(
                                sentimentColor(for: sentiment.score),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(Int(sentiment.score))")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(sentimentColor(for: sentiment.score))
                            Text(sentiment.interpretation)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Bullish/Bearish Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        // NEW: Momentum Multiplier Badge
                        if sentiment.score >= 70 {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.white)
                                Text("MOMENTUM BOOST: 1.15x")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(8)
                            .shadow(color: .purple.opacity(0.5), radius: 4, x: 0, y: 2)
                        } else if sentiment.score <= 30 {
                             HStack {
                                Image(systemName: "chart.line.downtrend.xyaxis")
                                    .foregroundColor(.white)
                                Text("MOMENTUM DRAG: 0.85x")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                        }
                        
                        SentimentBar(
                            label: "Boğa",
                            value: sentiment.bullishPercent,
                            color: .green,
                            icon: "arrow.up.right"
                        )
                        
                        SentimentBar(
                            label: "Ayı",
                            value: sentiment.bearishPercent,
                            color: .red,
                            icon: "arrow.down.right"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Dynamic Commentary
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: commentaryIcon(for: sentiment.score))
                        .font(.system(size: 16))
                        .foregroundColor(sentimentColor(for: sentiment.score))
                        .frame(width: 24)
                    
                    Text(commentary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(sentimentColor(for: sentiment.score).opacity(0.1))
                .cornerRadius(12)
                
                // Cached News if available
                if !cachedNews.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Son Analizler")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                        
                        ForEach(cachedNews.prefix(2), id: \.id) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(sentimentColor(for: Double(item.impactScore)).opacity(0.7))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)
                                
                                Text(item.summaryTR)
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                
                if sentiment.newsCount == 0 {
                    Text("Bu skor haber analizi olmadan varsayilan nodan geliyor.")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.9))
                }
            } else {
                // No Data - Still show helpful message
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.purple.opacity(0.6))
                    Text("Haber taraması bekleniyor")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Hermes modülünden 'Haberleri Tara' butonunu kullanın")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(height: 100)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1C1C1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .task {
            await loadSentiment()
        }
    }

    private func sourceBadgeText() -> String {
        guard let sentiment else { return "HERMES" }
        switch sentiment.source {
        case .llm:
            return "LLM • \(sentiment.newsCount) HABER"
        case .finnhub:
            return "FINNHUB • \(sentiment.newsCount)"
        case .fallback:
            return "FALLBACK"
        }
    }
    
    private func loadSentiment() async {
        isLoading = true
        
        // UX: Ensure loading message is visible
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Fetch recent cached news summaries first.
        // If no analyzed news exists, do not pin/show a sentiment score.
        cachedNews = HermesLLMService.shared.getCachedSummaries(for: symbol, count: 3)
        guard !cachedNews.isEmpty else {
            sentiment = nil
            commentary = ""
            isLoading = false
            return
        }

        // Fetch sentiment from analyzed Hermes cache
        let quick = await HermesLLMService.shared.getQuickSentiment(for: symbol)
        if quick.newsCount > 0 {
            sentiment = quick
            commentary = generateCommentary(for: quick.score)
        } else {
            sentiment = nil
            commentary = ""
        }
        
        isLoading = false
    }
    
    // MARK: - Commentary Generator
    
    private func generateCommentary(for score: Double) -> String {
        // 15 variations per sentiment level
        let veryBullish = [
            "Piyasa bu hisseye aşırı olumlu bakıyor. Güçlü alım baskısı mevcut.",
            "Yatırımcı güveni zirvelerde. Momentumun devamı muhtemel.",
            "Haberlerde ciddi olumlu gelişmeler var. Dikkatle takip edilmeli.",
            "Boğalar tam kontrolde. Trend yukarı yönlü seyrediyor.",
            "Piyasa algısı fevkalade pozitif. Ralli potansiyeli yüksek."
        ]
        
        let bullish = [
            "Genel sentiment olumlu görünüyor. Yukarı momentum var.",
            "Alıcılar satıcılardan üstün. Hafif iyimser bir tablo.",
            "Piyasada temkinli iyimserlik hakim. Trend destekli.",
            "Pozitif haberler ağırlıkta. Kısa vadede olumlu.",
            "Yatırımcılar bu seviyelerden alıma devam ediyor."
        ]
        
        let neutral = [
            "Piyasa kararsız. Belirgin bir yön henüz oluşmadı.",
            "Alıcılar ve satıcılar dengede. Konsolidasyon süreci.",
            "Bekle-gör modunda bir piyasa. Katalist bekleniyor.",
            "Ne güçlü alış ne de satış sinyali var. Yatay seyir.",
            "Volatilite düşük, hacim zayıf. Hareket bekleyen piyasa."
        ]
        
        let bearish = [
            "Satış baskısı hissediliyor. Dikkatli olunmalı.",
            "Piyasada temkinli pesimizm hakim. Risk algısı yüksek.",
            "Olumsuz haberler ağırlıkta. Kısa vadede baskı.",
            "Ayılar kontrolü ele geçirmiş görünüyor. Aşağı baskı var.",
            "Yatırımcılar kar realizasyonuna yönelmiş durumda."
        ]
        
        let veryBearish = [
            "Piyasada panik havası var. Ciddi satış baskısı mevcut.",
            "Güven çökmüş durumda. Düşüş trendi güçlü.",
            "Olumsuz gelişmeler fiyatları aşağı çekiyor. Risk yüksek.",
            "Ayılar tam kontrolde. Dip arayışı devam ediyor.",
            "Piyasa aşırı satım bölgesinde. Dikkatli yaklaşılmalı."
        ]
        
        switch score {
        case 70...100:
            return veryBullish.randomElement() ?? veryBullish[0]
        case 55..<70:
            return bullish.randomElement() ?? bullish[0]
        case 45..<55:
            return neutral.randomElement() ?? neutral[0]
        case 30..<45:
            return bearish.randomElement() ?? bearish[0]
        default:
            return veryBearish.randomElement() ?? veryBearish[0]
        }
    }
    
    private func commentaryIcon(for score: Double) -> String {
        switch score {
        case 70...100: return "flame.fill"
        case 55..<70: return "arrow.up.circle.fill"
        case 45..<55: return "minus.circle.fill"
        case 30..<45: return "arrow.down.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }
    
    private func sentimentColor(for score: Double) -> Color {
        switch score {
        case 70...100: return .green
        case 55..<70: return .blue
        case 45..<55: return .gray
        case 30..<45: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Views

struct SentimentBar: View {
    let label: String
    let value: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * (value / 100), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SentimentPulseCard(symbol: "AAPL")
            .padding()
    }
}
