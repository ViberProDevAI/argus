import SwiftUI

/// Hermes V2 — Sentiment Pulse.
///
/// **2026-04-23 V5.C estetik refactor.**
/// Eski kart hardcoded `.purple/.gray/.blue` ve `Color(hex: "1C1C1E")`
/// dolu "bilgi yığını" karışımıydı. Artık tamamı V5 primitive'leriyle
/// çalışıyor: `InstitutionalTheme` renkleri, motor-tint kenarlık,
/// mono caps section caption, `ArgusBar`, `ArgusChip`, `ArgusDot`,
/// `ArgusHair`. Ring gauge korundu ama tema renkleriyle çizildi.
///
/// Data sözleşmesi aynı: `HermesQuickSentiment`, `HermesLLMService`,
/// `HermesSummary`. Yalnızca görsel dil değişti.
struct SentimentPulseCard: View {
    let symbol: String
    @State private var sentiment: HermesQuickSentiment?
    @State private var isLoading = true
    @State private var cachedNews: [HermesSummary] = []
    @State private var commentary: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                loadingBlock
            } else if let sentiment = sentiment {
                heroRow(sentiment)
                ArgusHair()
                commentaryRow(sentiment)

                if !cachedNews.isEmpty {
                    recentList
                }

                if sentiment.newsCount == 0 {
                    fallbackNote
                }
            } else {
                emptyBlock
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.hermes.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
        )
        .task { await loadSentiment() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.hermes, size: 14)
            ArgusSectionCaption("SENTIMENT PULSE")
            Spacer()
            ArgusChip(sourceBadgeText(), tone: .neutral)
        }
    }

    private func heroRow(_ s: HermesQuickSentiment) -> some View {
        let tone = sentimentTone(s.score)
        return HStack(spacing: 16) {
            ringGauge(score: s.score, interpretation: s.interpretation, tone: tone)

            VStack(alignment: .leading, spacing: 10) {
                if let multiplier = momentumChip(for: s.score) {
                    ArgusChip(multiplier.text, tone: multiplier.tone)
                }
                sentimentRow(label: "BOĞA",
                             value: s.bullishPercent,
                             color: InstitutionalTheme.Colors.aurora,
                             icon: "arrow.up.right")
                sentimentRow(label: "AYI",
                             value: s.bearishPercent,
                             color: InstitutionalTheme.Colors.crimson,
                             icon: "arrow.down.right")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func ringGauge(score: Double,
                            interpretation: String,
                            tone: ArgusChipTone) -> some View {
        ZStack {
            Circle()
                .stroke(InstitutionalTheme.Colors.surface3, lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(100, score)) / 100))
                .stroke(tone.foreground,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: score)

            VStack(spacing: 2) {
                Text("\(Int(score))")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(interpretation.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(tone.foreground)
                    .lineLimit(1)
            }
        }
        .frame(width: 80, height: 80)
    }

    private func sentimentRow(label: String,
                               value: Double,
                               color: Color,
                               icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("%\(Int(value))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            ArgusBar(value: max(0, min(1, value / 100)), color: color, height: 4)
        }
    }

    private func commentaryRow(_ s: HermesQuickSentiment) -> some View {
        let tone = sentimentTone(s.score)
        return HStack(alignment: .top, spacing: 10) {
            ArgusDot(color: tone.foreground, size: 6)
                .padding(.top, 5)
            Text(commentary)
                .font(.system(size: 11.5))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArgusSectionCaption("SON ANALİZLER")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(cachedNews.prefix(2), id: \.id) { item in
                    HStack(alignment: .top, spacing: 10) {
                        ArgusDot(color: impactColor(for: item.impactScore).opacity(0.85))
                            .padding(.top, 5)
                        Text(item.summaryTR)
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                    .overlay(ArgusHair(), alignment: .bottom)
                }
            }
        }
    }

    private var fallbackNote: some View {
        HStack(spacing: 6) {
            ArgusDot(color: InstitutionalTheme.Colors.titan, size: 5)
            Text("Varsayılan skor — haber analizi yok.")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundColor(InstitutionalTheme.Colors.titan)
        }
    }

    private var loadingBlock: some View {
        VStack(spacing: 8) {
            ProgressView().tint(InstitutionalTheme.Colors.Motors.hermes)
            Text("HERMES DİNLİYOR…")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.Motors.hermes)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private var emptyBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 18))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text("Haber taraması bekleniyor")
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text("Hermes · Haberleri Tara")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.7)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    // MARK: - Helpers (visual mapping)

    private func sourceBadgeText() -> String {
        guard let sentiment else { return "HERMES" }
        switch sentiment.source {
        case .llm:      return "LLM · \(sentiment.newsCount)"
        case .finnhub:  return "FINNHUB · \(sentiment.newsCount)"
        case .fallback: return "FALLBACK"
        }
    }

    /// V5 dilinde momentum modifier.
    /// Çok boğa (>=70): hermes motor rengi pozitif multiplier.
    /// Çok ayı (<=30): crimson negatif multiplier.
    private func momentumChip(for score: Double) -> (text: String, tone: ArgusChipTone)? {
        if score >= 70 { return ("MOMENTUM × 1.15", .motor(.hermes)) }
        if score <= 30 { return ("DRAG × 0.85", .crimson) }
        return nil
    }

    /// 5 kademeli sentiment → 4 V5 tone (aurora / motor(.hermes) / titan / crimson).
    private func sentimentTone(_ score: Double) -> ArgusChipTone {
        if score >= 65 { return .aurora }
        if score >= 45 { return .motor(.hermes) }
        if score >= 30 { return .titan }
        return .crimson
    }

    private func impactColor(for impact: Int) -> Color {
        let v = Double(impact)
        if v >= 65 { return InstitutionalTheme.Colors.aurora }
        if v >= 45 { return InstitutionalTheme.Colors.Motors.hermes }
        if v >= 30 { return InstitutionalTheme.Colors.titan }
        return InstitutionalTheme.Colors.crimson
    }

    // MARK: - Data loading (unchanged)

    private func loadSentiment() async {
        isLoading = true

        // UX: Ensure loading message is visible
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        cachedNews = HermesLLMService.shared.getCachedSummaries(for: symbol, count: 3)
        guard !cachedNews.isEmpty else {
            sentiment = nil
            commentary = ""
            isLoading = false
            return
        }

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

    // MARK: - Commentary Generator (unchanged)

    private func generateCommentary(for score: Double) -> String {
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
}

#Preview {
    ZStack {
        InstitutionalTheme.Colors.background.ignoresSafeArea()
        SentimentPulseCard(symbol: "AAPL")
            .padding()
    }
}
