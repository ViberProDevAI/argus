import SwiftUI
import Charts

// MARK: - Phoenix Detail View (V5)
//
// **2026-04-23 V5.H-2.** Eski `NavigationView` + `toolbar` + `navigationTitle`
// chrome'u atıldı. Yeni iskelet:
//
//   • `ModuleSheetShell` → `ArgusNavHeader` + dismiss + scroll sarmal.
//   • Hero kart: dairesel güven skoru ring + status chip + timeframe chip.
//   • Regresyon Kanalı kartı (`PhoenixChannelChart` korundu, SwiftUI Charts).
//   • Analiz Detayı kartı: `advice.reasonShort` + statik pedagoji metni.
//   • 6'lı istatistik grid: Eğim / Sigma / Pivot / Kanal Genişliği /
//     R² Güvenilirlik / Lookback — V5 token'larıyla (eski StatBox gitti).
//   • Sinyal Kontrol Listesi: 4 tetik, V5 `ArgusDot` + durum chip.
//   • BIST Seans Tetikleri: sadece `.IS` sembollerde — V5 chrome.
//   • Pedagoji footer: "Phoenix dip avcısıdır..."
//
// Eski `Badge`, `StatBox`, `CheckRow` support view'ları kaldırıldı
// (sadece bu dosyada kullanılıyordu). Yerlerine V5 token'ları kullanıldı.

struct PhoenixDetailView: View {
    let symbol: String
    let advice: PhoenixAdvice
    let candles: [Candle]
    var onRunBacktest: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Institution Rates (global metalar için — yan görev)
    @State private var institutionRates: [InstitutionRate] = []
    @State private var showInstitutionRates = false

    var body: some View {
        ModuleSheetShell(title: "PHOENIX · DÖNÜŞ", motor: .phoenix) {
            heroCard
            chartCard
            analysisCard
            statsGridCard
            checklistCard

            if symbol.uppercased().hasSuffix(".IS") {
                bistSessionCard
            }

            if onRunBacktest != nil {
                backtestButton
            }

            pedagogyFooter
        }
        .task {
            await loadInstitutionRates()
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        let color = InstitutionalTheme.Colors.Motors.phoenix
        let conf = max(0, min(100, advice.confidence))

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(conf / 100.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int(conf))")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("/ 100")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(color)
                }
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                ArgusSectionCaption("GÜVEN SKORU")
                Text(symbol.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    ArgusChip(statusText, tone: statusTone)
                    ArgusChip("UFUK · \(advice.timeframe.localizedName)", tone: .motor(.phoenix))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArgusSectionCaption("REGRESYON KANALI")

            ZStack {
                if candles.count > 20 {
                    PhoenixChannelChart(candles: candles, advice: advice)
                        .frame(height: 220)
                } else {
                    VStack(spacing: 8) {
                        ArgusDot(color: InstitutionalTheme.Colors.titan)
                        Text("Grafik için yetersiz veri (en az 20 mum gerekli)")
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Analysis

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArgusSectionCaption("ANALİZ DETAYI")
            Text(advice.reasonShort)
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            Rectangle()
                .fill(InstitutionalTheme.Colors.Motors.phoenix)
                .frame(width: 2)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Stats grid

    private var statsGridCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("İSTATİSTİK · 6 METRİK")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                statBox(label: "Eğim (Slope)",
                        value: advice.regressionSlope.map { String(format: "%.4f", $0) } ?? "—",
                        tone: .neutral)
                statBox(label: "Sigma (Sapma)",
                        value: advice.sigma.map { String(format: "%.2f", $0) } ?? "—",
                        tone: .neutral)
                statBox(label: "Pivot (Orta)",
                        value: advice.channelMid.map { String(format: "%.2f", $0) } ?? "—",
                        tone: .neutral)
                statBox(label: "Kanal Genişliği",
                        value: channelWidthText,
                        tone: .neutral)
                statBox(label: "R² Güvenilirlik",
                        value: advice.rSquared.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
                        tone: rSquaredTone)
                statBox(label: "Lookback",
                        value: "\(advice.lookback) gün",
                        tone: .neutral)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func statBox(label: String, value: String, tone: ArgusChipTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundColor(tone == .neutral
                                 ? InstitutionalTheme.Colors.textPrimary
                                 : tone.foreground)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface2.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
    }

    private var channelWidthText: String {
        guard let sigma = advice.sigma, let mid = advice.channelMid, mid != 0 else { return "—" }
        return String(format: "%%%.1f", (sigma / mid) * 400)
    }

    private var rSquaredTone: ArgusChipTone {
        guard let r = advice.rSquared else { return .neutral }
        if r > 0.5 { return .aurora }
        if r > 0.25 { return .titan }
        return .crimson
    }

    // MARK: - Checklist

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("SİNYAL KONTROL LİSTESİ")

            VStack(alignment: .leading, spacing: 6) {
                checkRow("Kanal dibi teması", advice.triggers.touchLowerBand)
                checkRow("RSI dönüş sinyali", advice.triggers.rsiReversal)
                checkRow("Pozitif uyumsuzluk", advice.triggers.bullishDivergence)
                checkRow("Trend onayı", advice.triggers.trendOk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private func checkRow(_ title: String, _ isActive: Bool) -> some View {
        HStack(spacing: 10) {
            ArgusDot(
                color: isActive
                    ? InstitutionalTheme.Colors.aurora
                    : InstitutionalTheme.Colors.textTertiary,
                size: 8
            )
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Spacer()
            Text(isActive ? "EVET" : "BEKLİYOR")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(
                    isActive
                        ? InstitutionalTheme.Colors.aurora
                        : InstitutionalTheme.Colors.textTertiary
                )
        }
        .padding(.vertical, 4)
    }

    // MARK: - BIST Session Triggers

    private var bistSessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArgusSectionCaption("BIST SEANS TETİKLERİ")
            BistSessionTriggers(advice: advice)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.aether.opacity(0.25), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Backtest button

    private var backtestButton: some View {
        Button {
            dismiss()
            if let run = onRunBacktest {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { run() }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                Text("GEÇMİŞ TEST")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .foregroundColor(InstitutionalTheme.Colors.holo)
            .background(InstitutionalTheme.Colors.holo.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.holo.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pedagogy footer

    private var pedagogyFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArgusSectionCaption("PHOENIX NEDİR?")
            Text("Phoenix bir dip avcısıdır. Fiyat regresyon kanalının dibine değdiğinde, RSI toparlandığında ve hacim dönüş mumu geldiğinde güven skoru yükselir. Sadece teknik sinyal — temel analiz Atlas'ın işidir.")
                .font(.system(size: 11))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .strokeBorder(
                    InstitutionalTheme.Colors.border,
                    style: StrokeStyle(lineWidth: 0.5, dash: [4, 3])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    // MARK: - Helpers

    private var statusText: String {
        switch advice.confidence {
        case 80...100: return "FIRSAT (A+)"
        case 60..<80:  return "GÜÇLÜ"
        case 40..<60:  return "NÖTR"
        default:       return "ZAYIF"
        }
    }

    private var statusTone: ArgusChipTone {
        switch advice.confidence {
        case 70...100: return .aurora
        case 40..<70:  return .titan
        default:       return .crimson
        }
    }

    // MARK: - Data loading

    private func loadInstitutionRates() async {
        let slug: String?
        if symbol.contains("ALTIN") || symbol == "GRAM" || symbol == "GLD" {
            slug = "gram-altin"
        } else if symbol.contains("GUMUS") {
            slug = "gram-gumus"
        } else if symbol == "USD" || symbol == "USDTRY" {
            slug = "USD"
        } else {
            slug = nil
        }

        if let asset = slug,
           ["gram-altin", "gram-gumus", "ons-altin"].contains(asset) {
            do {
                let rates = try await DovizComService.shared.fetchMetalInstitutionRates(asset: asset)
                await MainActor.run {
                    self.institutionRates = rates
                    self.showInstitutionRates = true
                }
            } catch {
                print("Failed to load rates: \(error)")
            }
        }
    }
}

// MARK: - BIST Session Triggers (V5)

struct BistSessionTriggers: View {
    let advice: PhoenixAdvice
    @State private var currentSession: BistSession = .none

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $currentSession) {
                Text("Genel").tag(BistSession.none)
                Text("Rönesan").tag(BistSession.ronesan)
                Text("Kur Şoku").tag(BistSession.kurSoku)
                Text("Seans Kapanışı").tag(BistSession.seansKapanisi)
            }
            .pickerStyle(.segmented)

            switch currentSession {
            case .ronesan:       sessionList(items: ronesanItems, caption: "Rönesan günü özel:")
            case .kurSoku:       sessionList(items: kurSokuItems, caption: "Kur şoku durumunda:")
            case .seansKapanisi: sessionList(items: seansKapanisiItems, caption: "Seans kapanışında:")
            case .none:          sessionList(items: generalItems, caption: "Genel BIST tetikleri:")
            }
        }
    }

    private struct SessionItem: Identifiable {
        let id = UUID()
        let condition: String
        let action: String
        let isActive: Bool
    }

    private func sessionList(items: [SessionItem], caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(.system(size: 10))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    ArgusDot(
                        color: item.isActive
                            ? InstitutionalTheme.Colors.aurora
                            : InstitutionalTheme.Colors.textTertiary,
                        size: 6
                    )
                    .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.condition)
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(item.action)
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(InstitutionalTheme.Colors.surface2.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous))
            }
        }
    }

    // Session-specific tetik listeleri. Şu an hepsi placeholder `isActive: false`
    // (kodda advice.triggers'a bağlı custom session trigger yok). Motor bu
    // alanları üretmeye başladığında buraya bağlanır.
    private var ronesanItems: [SessionItem] {
        [
            SessionItem(condition: "Gündüz seans 09:30'dan önce", action: "Alış yap", isActive: false),
            SessionItem(condition: "Seyahat hacmi %2'nin altına düşerse", action: "Alış beklenir", isActive: false),
        ]
    }
    private var kurSokuItems: [SessionItem] {
        [
            SessionItem(condition: "USD/TRY %3 yükselirse", action: "XU030 satışı beklenir", isActive: false),
            SessionItem(condition: "XU100 %2 düşerse", action: "BIST genel satışı beklenir", isActive: false),
        ]
    }
    private var seansKapanisiItems: [SessionItem] {
        [
            SessionItem(condition: "Son 30 dakika hacim artışı", action: "Kapanış alımı için uygun", isActive: false),
            SessionItem(condition: "Seans sonuna doğru düşüş", action: "Short pozisyon kapat", isActive: false),
        ]
    }
    private var generalItems: [SessionItem] {
        [
            SessionItem(condition: "Genel tetikler yükleniyor…", action: "Motor tamamlanınca doldurulacak", isActive: false),
        ]
    }
}

enum BistSession: String, CaseIterable {
    case none = "Genel"
    case ronesan = "Rönesan"
    case kurSoku = "Kur Şoku"
    case seansKapanisi = "Seans Kapanışı"
}

// MARK: - Chart Component

struct PhoenixChannelChart: View {
    let candles: [Candle]
    let advice: PhoenixAdvice

    var body: some View {
        let displayCandles = candles.suffix(advice.lookback + 20)
        let sorted = Array(displayCandles).sorted { $0.date < $1.date }

        return Chart {
            // 1. Candles
            ForEach(sorted) { candle in
                RectangleMark(
                    x: .value("Tarih", candle.date),
                    yStart: .value("Open", candle.open),
                    yEnd: .value("Close", candle.close),
                    width: .fixed(4)
                )
                .foregroundStyle(
                    candle.close >= candle.open
                        ? InstitutionalTheme.Colors.aurora
                        : InstitutionalTheme.Colors.crimson
                )

                RuleMark(
                    x: .value("Tarih", candle.date),
                    yStart: .value("Low", candle.low),
                    yEnd: .value("High", candle.high)
                )
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(InstitutionalTheme.Colors.neutral)
            }

            // 2. Channel Lines
            if !sorted.isEmpty {
                ForEach(Array(sorted.enumerated()), id: \.offset) { index, candle in
                    if index >= (sorted.count - advice.lookback) {
                        let relativeX = Double(index - (sorted.count - advice.lookback))
                        let distFromEnd = Double(advice.lookback - 1) - relativeX
                        let midY = (advice.channelMid ?? 0.0) - ((advice.regressionSlope ?? 0.0) * distFromEnd)
                        let upperY = midY + (2.0 * (advice.sigma ?? 0.0))
                        let lowerY = midY - (2.0 * (advice.sigma ?? 0.0))

                        LineMark(x: .value("Tarih", candle.date), y: .value("Mid", midY))
                            .foregroundStyle(InstitutionalTheme.Colors.Motors.chiron)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                        LineMark(x: .value("Tarih", candle.date), y: .value("Upper", upperY))
                            .foregroundStyle(InstitutionalTheme.Colors.Motors.phoenix.opacity(0.55))

                        LineMark(x: .value("Tarih", candle.date), y: .value("Lower", lowerY))
                            .foregroundStyle(InstitutionalTheme.Colors.Motors.phoenix.opacity(0.55))
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }
}
