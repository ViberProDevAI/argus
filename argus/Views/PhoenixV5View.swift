import SwiftUI

/// V5 mockup "12 · Phoenix · Külden Diriliş" ekranının Swift karşılığı.
/// (`Argus_Mockup_V5.html` satır 2244-2324).
///
/// Dip dedektörü — aşırı-satım + destek testi + dönüş mumu onayları.
/// Veri: `PhoenixAdvice` modeli (PhoenixScenarioEngine'den).
struct PhoenixV5View: View {
    @EnvironmentObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode

    /// Ana sembol (mevcut StockDetail'ten gelebilir) veya liste modu (nil).
    let primarySymbol: String?

    init(primarySymbol: String? = nil) {
        self.primarySymbol = primarySymbol
    }

    var body: some View {
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    navbar
                    if let main = mainAdvice {
                        mainCandidateCard(advice: main)
                        checklistCard(advice: main)
                    } else {
                        ArgusEmptyState(
                            icon: "flame",
                            title: "Phoenix verisi yok",
                            message: "Bu sembol için dip dedektörü henüz uyanmadı."
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 20)
                    }
                    otherCandidates
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - 1. Navbar

    private var navbar: some View {
        HStack(spacing: 8) {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(InstitutionalTheme.Colors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            ZStack {
                Circle()
                    .fill(InstitutionalTheme.Colors.Motors.prometheus.opacity(0.12))
                    .frame(width: 36, height: 36)
                MotorLogo(.phoenix, size: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("PHOENIX")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text("Dip avcısı · dönüş motoru")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            Spacer()

            ArgusChip("\(otherSymbols.count + (mainAdvice != nil ? 1 : 0)) KÜL",
                      tone: .motor(.prometheus))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            InstitutionalTheme.Colors.surface1
                .overlay(ArgusHair().frame(maxHeight: .infinity, alignment: .bottom))
        )
    }

    // MARK: - 2. Ana aday kartı

    private func mainCandidateCard(advice: PhoenixAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "3B0A0A"), InstitutionalTheme.Colors.crimson],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(advice.symbol)
                            .font(.system(size: 14, weight: .bold, design: .default))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        if let price = currentPrice(for: advice.symbol) {
                            Text(formatPrice(price, symbol: advice.symbol))
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                    Text(scenarioSummary(advice))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.Motors.prometheus)
                }

                Spacer()

                ArgusChip("GÜVEN \(Int(advice.confidence))",
                          tone: advice.confidence >= 65 ? .aurora :
                                 (advice.confidence >= 40 ? .titan : .crimson))
            }

            // Mini grafik — candles kullanılacak
            if let candles = viewModel.candles[advice.symbol], candles.count >= 2 {
                MiniLineChart(candles: candles.suffix(60).map { $0 },
                              positive: (advice.status == .active))
                    .frame(height: 66)
            }

            HStack(spacing: 6) {
                statTile(title: "DÜŞÜŞ", value: drawdownText(advice), tone: .crimson)
                statTile(title: "DESTEK", value: formatPriceOptional(advice.channelLower, advice.symbol), tone: .neutral)
                statTile(title: "HEDEF", value: formatPriceOptional(advice.targets.first, advice.symbol), tone: .aurora)
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.prometheus.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private func statTile(title: String, value: String, tone: ArgusChipTone) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(tone.foreground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
    }

    // MARK: - 3. Checklist

    private func checklistCard(advice: PhoenixAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("DÖNÜŞ KONTROL LİSTESİ")

            VStack(spacing: 8) {
                checklistRow(done: advice.triggers.touchLowerBand,
                             text: "Aşırı-satım (RSI < 25) / Kanal dibi")
                checklistRow(done: advice.triggers.trendOk,
                             text: "Temel destek test edildi")
                checklistRow(done: advice.triggers.bullishDivergence,
                             text: "Boğa ayrışması (divergence)")
                checklistRow(done: advice.triggers.rsiReversal,
                             text: "RSI dönüş mumu")
                checklistRow(done: nil,
                             text: "Hermes: pozitif katalizör (bekleniyor)")
            }
            .padding(12)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private func checklistRow(done: Bool?, text: String) -> some View {
        let (icon, bg, fg) = statusStyle(done: done)
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(bg).frame(width: 16, height: 16)
                Text(icon)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(fg)
            }
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(done == true
                                 ? InstitutionalTheme.Colors.textPrimary
                                 : InstitutionalTheme.Colors.textSecondary)
            Spacer()
        }
    }

    private func statusStyle(done: Bool?) -> (String, Color, Color) {
        if done == true  { return ("✓", InstitutionalTheme.Colors.aurora, Color(hex: "0A1F0A")) }
        if done == false { return ("◐", InstitutionalTheme.Colors.titan, Color(hex: "1A0A00")) }
        return ("○", InstitutionalTheme.Colors.surface3, InstitutionalTheme.Colors.textSecondary)
    }

    // MARK: - 4. Diğer küller

    private var otherCandidates: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !otherSymbols.isEmpty {
                ArgusSectionCaption("DİĞER KÜLDENİRİŞ ADAYLARI")

                VStack(spacing: 6) {
                    ForEach(otherSymbols.prefix(6), id: \.self) { sym in
                        if let adv = phoenixAdvice(for: sym) {
                            otherCandidateRow(sym: sym, advice: adv)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 120)
    }

    private func otherCandidateRow(sym: String, advice: PhoenixAdvice) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: candidateColor(for: sym),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(sym)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(advice.reasonShort.isEmpty ? "İzle" : advice.reasonShort)
                    .font(.system(size: 10))
                    .foregroundColor(
                        advice.status == .active
                            ? InstitutionalTheme.Colors.Motors.prometheus
                            : InstitutionalTheme.Colors.textSecondary
                    )
                    .lineLimit(1)
            }

            Spacer()

            ArgusChip("\(Int(advice.confidence))",
                      tone: advice.confidence >= 60 ? .titan : .neutral)
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Veri

    private var allPhoenixResults: [String: PhoenixAdvice] {
        SignalStateViewModel.shared.phoenixResults
    }

    private var mainAdvice: PhoenixAdvice? {
        if let sym = primarySymbol {
            return allPhoenixResults[sym]
        }
        // Listede en yüksek güvenli active/inactive
        return allPhoenixResults.values
            .filter { $0.status == .active }
            .max(by: { $0.confidence < $1.confidence })
    }

    private var otherSymbols: [String] {
        let mainSym = mainAdvice?.symbol
        return allPhoenixResults
            .filter { $0.value.status != .error && $0.key != mainSym }
            .sorted { $0.value.confidence > $1.value.confidence }
            .map { $0.key }
    }

    private func phoenixAdvice(for symbol: String) -> PhoenixAdvice? {
        allPhoenixResults[symbol]
    }

    private func currentPrice(for symbol: String) -> Double? {
        MarketDataStore.shared.getQuote(for: symbol)?.currentPrice
            ?? viewModel.quotes[symbol]?.currentPrice
    }

    private func formatPrice(_ price: Double, symbol: String) -> String {
        let isBist = symbol.uppercased().hasSuffix(".IS")
        return String(format: isBist ? "₺%.2f" : "$%.2f", price)
    }

    private func formatPriceOptional(_ price: Double?, _ symbol: String) -> String {
        guard let p = price else { return "—" }
        return formatPrice(p, symbol: symbol)
    }

    private func drawdownText(_ advice: PhoenixAdvice) -> String {
        guard let lower = advice.channelLower,
              let price = currentPrice(for: advice.symbol),
              price > 0 else { return "—" }
        let pct = ((lower - price) / price) * 100
        return String(format: "%.0f%%", pct)
    }

    private func scenarioSummary(_ advice: PhoenixAdvice) -> String {
        var parts: [String] = []
        if advice.triggers.touchLowerBand { parts.append("KANAL DİBİ") }
        if advice.triggers.rsiReversal    { parts.append("RSI DÖNÜŞ") }
        if advice.triggers.bullishDivergence { parts.append("AYRIŞMA") }
        if parts.isEmpty { return advice.reasonShort }
        return parts.joined(separator: " · ")
    }

    private func candidateColor(for symbol: String) -> [Color] {
        // Sembol harflerinden deterministic renk — görsel çeşitlilik
        let hash = symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        switch hash % 5 {
        case 0: return [Color(hex: "1F0A1A"), Color(hex: "BE185D")] // kırmızı/pembe
        case 1: return [Color(hex: "0A1530"), Color(hex: "2563EB")] // mavi
        case 2: return [Color(hex: "14161F"), Color(hex: "475569")] // gri
        case 3: return [Color(hex: "1F2A0A"), Color(hex: "16A34A")] // yeşil
        default: return [Color(hex: "1A0A00"), Color(hex: "F5C244")] // altın
        }
    }
}
