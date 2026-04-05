import SwiftUI

struct SignalsView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var isScanning = false

    var body: some View {
        NavigationView {
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
                            SignalSection(title: "Sat", signals: sell, color: Theme.negative, viewModel: viewModel)
                        }
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .navigationTitle("Sinyaller")
            .navigationBarTitleDisplayMode(.large)
            .background(Theme.background)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SignalJournalView()) {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(Theme.tint)
                    }
                    if isScanning {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button(action: scan) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Theme.tint)
                        }
                    }
                }
            }
            .onAppear {
                if viewModel.aiSignals.isEmpty { scan() }
            }
        }
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
    let macro: MacroRating

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: bannerIcon)
                .font(.system(size: 18))
                .foregroundColor(bannerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(bannerTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(macro.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(bannerColor.opacity(0.10))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(bannerColor.opacity(0.25), lineWidth: 1))
    }

    private var bannerTitle: String {
        switch macro.regime {
        case .riskOn:  return "Piyasa ortamı elverişli"
        case .neutral: return "Piyasa ortamı karışık"
        case .riskOff: return "Piyasa ortamı olumsuz"
        }
    }

    private var bannerIcon: String {
        switch macro.regime {
        case .riskOn:  return "checkmark.shield.fill"
        case .neutral: return "minus.circle.fill"
        case .riskOff: return "exclamationmark.shield.fill"
        }
    }

    private var bannerColor: Color {
        switch macro.regime {
        case .riskOn:  return .green
        case .neutral: return .yellow
        case .riskOff: return .red
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
            // Bölüm başlığı — sade
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text("(\(signals.count))")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
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
            // Logo
            CompanyLogoView(symbol: signal.symbol, size: 40, cornerRadius: 20)
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Orta: sembol + neden
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(signal.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    // Aksiyon pill
                    Text(localizedAction)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(actionColor)
                        .cornerRadius(6)

                    Spacer()

                    Text(timeAgo(signal.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                // Birincil neden — büyük ve net
                Text(primaryReason)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(14)
        .background(Theme.secondaryBackground)
        .cornerRadius(14)
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

    private var actionColor: Color {
        switch signal.action {
        case .buy:  return .green
        case .sell: return .red
        case .hold: return Color(white: 0.4)
        case .wait: return Color(white: 0.4)
        case .skip: return Color(white: 0.4)
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
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 52))
                .foregroundColor(.gray.opacity(0.4))

            VStack(spacing: 6) {
                Text(isScanning ? "Taranıyor..." : "Sinyal bulunamadı")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
                Text(isScanning
                    ? "İzleme listendeki hisseler analiz ediliyor."
                    : "Şu an güçlü bir sinyal yok. Tekrar taramayı dene.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            if !isScanning {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("Tara")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Theme.tint)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.top, 60)
    }
}
