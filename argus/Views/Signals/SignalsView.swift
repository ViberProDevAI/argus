import SwiftUI
/// V5 mockup dil bütünlüğü için in-place refactor.
/// 2026-04-22 Sprint 3 — üst chrome `ArgusNavHeader`'a alındı (bars3 holo deco
/// + clipboard/refresh aksiyon ikonları, status satırı aktif sinyal sayısını
/// gösterir). SignalJournal rotası gizli NavigationLink ile korundu; tarama
/// akışı ve `AISignal` filter mantığı değiştirilmedi.
struct SignalsView: View {
    @ObservedObject private var analysis = AnalysisViewModel.shared
    @ObservedObject private var signalState = SignalStateViewModel.shared
    @ObservedObject private var market = MarketViewModel.shared
    @State private var isScanning = false
    @State private var showJournal = false

    // 2026-05-09: View NavigationRouter case .signals üzerinden push'lanıyor.
    // Eski leadingDeco `.bars3` geri butonu bırakmıyordu; push'tan kullanıcı
    // çıkış yapamıyordu.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // 2026-05-03 H-59: nested NavigationStack kaldırıldı — ContentView
        // root NavigationStack ile çakışıyordu.
        ZStack {
            InstitutionalTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                    ArgusNavHeader(
                        title: "Sinyaller",
                        subtitle: "Al, sat, izle",
                        leadingDeco: .back(onTap: { dismiss() }),
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
                            if let macro = analysis.macroRating {
                                MacroStatusBanner(macro: macro)
                                    .padding(.horizontal)
                            }

                            if analysis.aiSignals.isEmpty {
                                SignalsEmptyStateView(action: scan, isScanning: isScanning)
                            } else {
                                // Güçlü Al
                                let strongBuy = analysis.aiSignals.filter { $0.action == .buy && $0.confidenceScore >= 85 }
                                if !strongBuy.isEmpty {
                                    SignalSection(title: "Güçlü Al", signals: strongBuy, color: .green)
                                }

                                // Al
                                let buy = analysis.aiSignals.filter { $0.action == .buy && $0.confidenceScore < 85 }
                                if !buy.isEmpty {
                                    SignalSection(title: "Al", signals: buy, color: Color(red: 0.3, green: 0.85, blue: 0.4))
                                }

                                // Sat
                                let sell = analysis.aiSignals.filter { $0.action == .sell }
                                if !sell.isEmpty {
                                    SignalSection(title: "Sat", signals: sell, color: InstitutionalTheme.Colors.crimson)
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                    }
                }

        }
        .navigationBarHidden(true)
        // SignalJournal — sheet olarak açılıyor (nested NavigationStack
        // kaldırıldığından navigationDestination dış stack'e ekleniyor).
        .navigationDestination(isPresented: $showJournal) {
            SignalJournalView()
        }
        .onAppear {
            if analysis.aiSignals.isEmpty { scan() }
        }
    }

    private var headerStatus: ArgusNavHeader.Status {
        if isScanning {
            return .custom(dotColor: InstitutionalTheme.Colors.textTertiary,
                           label: "Taranıyor",
                           trailing: "Sinyal akışı")
        }
        let total = analysis.aiSignals.count
        let strongBuy = analysis.aiSignals.filter { $0.action == .buy && $0.confidenceScore >= 85 }.count
        if total == 0 {
            return .custom(dotColor: InstitutionalTheme.Colors.textTertiary,
                           label: "Sinyal yok",
                           trailing: "Taramayı çalıştır")
        }
        return .custom(dotColor: InstitutionalTheme.Colors.aurora,
                       label: "\(total) sinyal",
                       trailing: strongBuy > 0 ? "\(strongBuy) güçlü al" : "Takipte")
    }

    private func scan() {
        isScanning = true
        Task {
            let signals = await AISignalService.shared.generateSignals(
                quotes: market.quotes, candles: market.candles
            )
            analysis.aiSignals = signals
            isScanning = false
        }
    }
}

// MARK: - Macro Status Banner

private struct MacroStatusBanner: View {
    let macro: MacroEnvironmentRating

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bannerIcon)
                .font(DesignTokens.Fonts.custom(size: 14))
                .foregroundColor(tone.foreground)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(regimeLabel)
                    .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                    .foregroundColor(tone.foreground)
                Text(macro.summary)
                    .font(DesignTokens.Fonts.custom(size: 11))
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
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 0.5)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ArgusDot(color: color, size: 6)
                Text(title.uppercased())
                    .font(DesignTokens.Fonts.custom(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(color)
                Spacer()
                Text("\(signals.count)")
                    .font(DesignTokens.Fonts.custom(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(color.opacity(0.18))
                    )
            }
            .padding(.horizontal, 16)

            ForEach(signals) { signal in
                NavigationLink(destination: ArgusSanctumView(symbol: signal.symbol)) {
                    AISignalCard(signal: signal, orion: SignalStateViewModel.shared.orionScores[signal.symbol])
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
                        .font(DesignTokens.Fonts.custom(size: 14, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text(localizedAction)
                        .font(DesignTokens.Fonts.custom(size: 12, weight: .medium))
                        .foregroundColor(actionTone.foreground)
                    Spacer()
                    Text(timeAgo(signal.timestamp))
                        .font(DesignTokens.Fonts.custom(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Text(primaryReason)
                    .font(DesignTokens.Fonts.custom(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Image(systemName: "chevron.right")
                .font(DesignTokens.Fonts.custom(size: 10, weight: .semibold))
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
        VStack(spacing: 16) {
            if isScanning {
                ProgressView()
            } else {
                Image(systemName: "magnifyingglass")
                    .font(DesignTokens.Fonts.custom(size: 28))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            VStack(spacing: 4) {
                Text(isScanning ? "Taranıyor" : "Sinyal bulunamadı")
                    .font(DesignTokens.Fonts.custom(size: 14, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(isScanning
                     ? "İzleme listendeki hisseler analiz ediliyor."
                     : "Şu an güçlü bir sinyal yok. Tekrar taramayı deneyebilirsin.")
                    .font(DesignTokens.Fonts.custom(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if !isScanning {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(DesignTokens.Fonts.custom(size: 12))
                        Text("Tara")
                            .font(DesignTokens.Fonts.custom(size: 13, weight: .medium))
                    }
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(InstitutionalTheme.Colors.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 48)
    }
}
