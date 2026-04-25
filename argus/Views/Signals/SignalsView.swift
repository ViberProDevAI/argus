import SwiftUI
/// V5 mockup dil bütünlüğü için in-place refactor.
/// 2026-04-22 Sprint 3 — üst chrome `ArgusNavHeader`'a alındı (bars3 holo deco
/// + clipboard/refresh aksiyon ikonları, status satırı aktif sinyal sayısını
/// gösterir). SignalJournal rotası gizli NavigationLink ile korundu; tarama
/// akışı ve `AISignal` filter mantığı değiştirilmedi.
struct SignalsView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var isScanning = false
    @State private var showJournal = false

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "SİNYALLER",
                        subtitle: "AL · SAT · İZLE",
                        leadingDeco: .bars3([.holo, .text, .text]),
                        actions: [
                            .custom(sfSymbol: "list.bullet.clipboard",
                                    action: { showJournal = true }),
                            .custom(sfSymbol: isScanning ? "hourglass" : "arrow.clockwise",
                                    action: { if !isScanning { scan() } })
                        ],
                        status: headerStatus
                    )

                    ScrollView {
                        VStack(spacing: 20) {
                            // ── Makro durum bandı ────────────────────────────────
                            if let macro = viewModel.macroRating {
                                MacroStatusBanner(macro: macro)
                                    .padding(.horizontal)
                            }

                            if viewModel.aiSignals.isEmpty {
                                SignalsEmptyStateView(action: scan, isScanning: isScanning)
                            } else {
                                // Güçlü Al
                                let strongBuy = viewModel.aiSignals.filter { $0.action == .buy && $0.confidenceScore >= 85 }
                                if !strongBuy.isEmpty {
                                    SignalSection(title: "Güçlü Al", signals: strongBuy, color: .green, viewModel: viewModel)
                                }

                                // Al
                                let buy = viewModel.aiSignals.filter { $0.action == .buy && $0.confidenceScore < 85 }
                                if !buy.isEmpty {
                                    SignalSection(title: "Al", signals: buy, color: Color(red: 0.3, green: 0.85, blue: 0.4), viewModel: viewModel)
                                }

                                // Sat
                                let sell = viewModel.aiSignals.filter { $0.action == .sell }
                                if !sell.isEmpty {
                                    SignalSection(title: "Sat", signals: sell, color: InstitutionalTheme.Colors.crimson, viewModel: viewModel)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                    }
                }

                // SignalJournal rotası — V5 header'daki clipboard aksiyonuyla açılır.
                NavigationLink(
                    destination: SignalJournalView(),
                    isActive: $showJournal
                ) { EmptyView() }
                .hidden()
            }
            .navigationBarHidden(true)
            .onAppear {
                if viewModel.aiSignals.isEmpty { scan() }
            }
        }
    }

    private var headerStatus: ArgusNavHeader.Status {
        if isScanning {
            return .custom(dotColor: InstitutionalTheme.Colors.holo,
                           label: "TARANIYOR",
                           trailing: "SİNYAL AKIŞI")
        }
        let total = viewModel.aiSignals.count
        let strongBuy = viewModel.aiSignals.filter { $0.action == .buy && $0.confidenceScore >= 85 }.count
        if total == 0 {
            return .custom(dotColor: InstitutionalTheme.Colors.textTertiary,
                           label: "SİNYAL YOK",
                           trailing: "TARAMAYI ÇALIŞTIR")
        }
        return .custom(dotColor: InstitutionalTheme.Colors.aurora,
                       label: "\(total) SİNYAL",
                       trailing: strongBuy > 0 ? "\(strongBuy) GÜÇLÜ AL" : "TAKİPTE")
    }

    private func scan() {
        isScanning = true
        Task {
            await viewModel.generateAISignals()
            isScanning = false
        }
    }
}

// MARK: - Macro Status Banner

private struct MacroStatusBanner: View {
    let macro: MacroEnvironmentRating

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tone.foreground.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: bannerIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tone.foreground)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    ArgusChip(regimeLabel.uppercased(), tone: tone)
                    MotorLogo(.aether, size: 10)
                }
                Text(macro.summary)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(tone.foreground.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
    }

    private var regimeLabel: String {
        switch macro.regime {
        case .riskOn:  return "Piyasa elverişli"
        case .neutral: return "Piyasa karışık"
        case .riskOff: return "Piyasa olumsuz"
        }
    }

    private var bannerIcon: String {
        switch macro.regime {
        case .riskOn:  return "checkmark.shield.fill"
        case .neutral: return "minus.circle.fill"
        case .riskOff: return "exclamationmark.shield.fill"
        }
    }

    private var tone: ArgusChipTone {
        switch macro.regime {
        case .riskOn:  return .aurora
        case .neutral: return .titan
        case .riskOff: return .crimson
        }
    }
}

// MARK: - Signal Section

struct SignalSection: View {
    let title: String
    let signals: [AISignal]
    let color: Color
    @ObservedObject var viewModel: TradingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ArgusDot(color: color, size: 6)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(color)
                Spacer()
                Text("\(signals.count)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(color.opacity(0.18))
                    )
            }
            .padding(.horizontal, 16)

            ForEach(signals) { signal in
                NavigationLink(destination: StockDetailView(symbol: signal.symbol, viewModel: viewModel)) {
                    AISignalCard(signal: signal, orion: viewModel.orionScores[signal.symbol])
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - AI Signal Card (skor dairesi yok, aksiyon + neden ön planda)

struct AISignalCard: View {
    let signal: AISignal
    var orion: OrionScoreResult? = nil

    var body: some View {
        HStack(spacing: 14) {
            CompanyLogoView(symbol: signal.symbol, size: 40, cornerRadius: 20)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(signal.symbol)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    ArgusPill(localizedAction, tone: actionTone)
                    Spacer()
                    Text(timeAgo(signal.timestamp))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Text(primaryReason)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
        }
        .padding(14)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(actionTone.foreground.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var localizedAction: String {
        switch signal.action {
        case .buy:  return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        case .wait: return "İZLE"
        case .skip: return "PAS"
        }
    }

    private var actionTone: ArgusChipTone {
        switch signal.action {
        case .buy:  return .aurora
        case .sell: return .crimson
        case .hold: return .neutral
        case .wait: return .motor(.chiron)
        case .skip: return .neutral
        }
    }

    /// Orion varsa onun net yorumunu, yoksa signal.reason'ı göster
    private var primaryReason: String {
        if let o = orion, !o.verdict.isEmpty {
            return o.verdict
        }
        return signal.reason.isEmpty ? signal.strategyName : signal.reason
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "şimdi" }
        if diff < 3600 { return "\(diff / 60) dk" }
        if diff < 86400 { return "\(diff / 3600) sa" }
        return "\(diff / 86400) gün"
    }
}

// MARK: - Empty State

struct SignalsEmptyStateView: View {
    let action: () -> Void
    let isScanning: Bool

    var body: some View {
        VStack(spacing: 20) {
            ArgusOrb(size: 88,
                     ringColor: InstitutionalTheme.Colors.holo,
                     glowColor: isScanning ? InstitutionalTheme.Colors.holo : nil) {
                Image(systemName: isScanning ? "waveform.path.ecg" : "magnifyingglass")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.holo)
            }

            VStack(spacing: 4) {
                Text(isScanning ? "TARANIYOR…" : "SİNYAL BULUNAMADI")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(isScanning
                     ? "İzleme listendeki hisseler analiz ediliyor."
                     : "Şu an güçlü bir sinyal yok. Tekrar taramayı dene.")
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if !isScanning {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .bold))
                        Text("TARA")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                    }
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .fill(InstitutionalTheme.Colors.holo.opacity(0.14))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.holo.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 48)
    }
}
