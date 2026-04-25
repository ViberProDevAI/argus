import SwiftUI

// MARK: - Argus Analyst Report (V5)
//
// **2026-04-23 V5.C estetik refactor.**
// Council modülünün nihai kararı. Eski: `.sparkles + primary` başlık,
// XMark close (HoloPanel zaten kendi close'unu veriyor), basit
// monospaced metin akışı.
// Yeni: motor(.council) tint kart chrome'u, mono caps section caption,
// ArgusChip durum rozeti, ArgusHair ayırıcılar, typewriter rapor gövdesi
// korundu. Standalone push (NavigationRouter, SymbolDebateView) ve
// embed (HoloPanel.contentForModule(.council)) ikisinde de temiz duruyor.
struct ArgusAnalystReportView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel

    @State private var displayedText: String = ""
    @State private var fullReportText: String = ""
    @State private var isLoading: Bool = true
    @State private var typewriterTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading {
                loadingBlock
            } else {
                reportBody
            }

            ArgusHair()
            footerLine
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.Motors.council.opacity(0.3), lineWidth: 1)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
        )
        .onAppear { loadAIReport() }
        .onDisappear { typewriterTimer?.invalidate() }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            MotorLogo(.council, size: 14)
            ArgusSectionCaption("ARGUS ANALİST · \(symbol.uppercased())")
            Spacer()
            if isLoading {
                ArgusChip("HAZIRLANIYOR", tone: .motor(.council))
            } else {
                ArgusChip("RAPOR HAZIR", tone: .aurora)
            }
        }
    }

    private var loadingBlock: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(InstitutionalTheme.Colors.Motors.council)
            Text("\(symbol.uppercased()) ANALİZ EDİLİYOR…")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.Motors.council)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private var reportBody: some View {
        ScrollView {
            Text(displayedText)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md,
                                     style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface2)
                )
        }
        .frame(minHeight: 280, maxHeight: 500)
    }

    private var footerLine: some View {
        HStack(spacing: 6) {
            ArgusDot(color: InstitutionalTheme.Colors.Motors.council, size: 5)
            Text("POWERED BY ARGUS AI ENGINE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Spacer()
        }
    }

    // MARK: - AI Report Loading

    private func loadAIReport() {
        isLoading = true

        Task {
            let aiReport = await ArgusNarrativeEngine.generateAIReport(
                symbol: symbol,
                viewModel: viewModel,
                type: .comprehensive
            )

            await MainActor.run {
                fullReportText = aiReport
                isLoading = false
                startTypewriterEffect()
            }
        }
    }

    private func startTypewriterEffect() {
        displayedText = ""
        let chars = Array(fullReportText)
        var index = 0

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.003, repeats: true) { timer in
            if index < chars.count {
                displayedText.append(chars[index])
                index += 1
            } else {
                timer.invalidate()
            }
        }
    }
}
