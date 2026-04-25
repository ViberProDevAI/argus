import SwiftUI

struct ArgusHeroPanel: View {
    let symbol: String
    let quote: Quote?
    let decision: ArgusDecisionResult?
    let explanation: ArgusExplanation?
    let isLoading: Bool
    let viewModel: TradingViewModel?

    @State private var showArgusDetail = false

    private var finalScore: Double { decision?.finalScoreCore ?? 0 }

    var body: some View {
        VStack(spacing: 16) {

            // ── Karar Bandı ──────────────────────────────────────────────
            // Tek soru: "Ne yapmalıyım?" — en büyük eleman bu
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView().scaleEffect(0.9)
                    Text("Analiz ediliyor...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(20)

            } else if let d = decision {
                Button(action: { showArgusDetail = true }) {
                    HStack(spacing: 16) {
                        // Aksiyon — tek büyük mesaj
                        Text(humanAction(d.finalActionCore))
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundColor(actionColor(d.finalActionCore))

                        VStack(alignment: .leading, spacing: 5) {
                            // Güven barı — tek satır, sade
                            HStack(spacing: 6) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.1)).frame(height: 5)
                                        Capsule()
                                            .fill(actionColor(d.finalActionCore))
                                            .frame(width: geo.size.width * CGFloat(finalScore / 100), height: 5)
                                    }
                                }
                                .frame(height: 5)
                            }

                            Text(confidenceLabel(finalScore))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(actionColor(d.finalActionCore).opacity(0.07))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(actionColor(d.finalActionCore).opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // ── Ana Sebep — açık dil ──────────────────────────────
                if let exp = explanation {
                    Text(exp.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                // ── Piyasa durumu — tek chip, iç isim yok ────────────
                if let chiron = decision?.chironResult {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(chironColor(chiron.regime))
                            .frame(width: 7, height: 7)
                        Text(chironLabel(chiron.regime))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }

            } else {
                Text("Bu hisse için analiz henüz hazır değil.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(20)
            }

            // ── Aksiyon Butonu — sadece AL/SAT ────────────────────────
            if let d = decision, let vm = viewModel, let q = quote {
                if d.finalActionCore == .buy || d.finalActionCore == .sell {
                    Button(action: {
                        if d.finalActionCore == .buy {
                            let price = q.currentPrice
                            if price > 0 {
                                vm.buy(symbol: symbol, quantity: 1000.0 / price,
                                       source: .user, rationale: "Manuel AL sinyali")
                            }
                        } else {
                            vm.closeAllPositions(for: symbol)
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }) {
                        Text(d.finalActionCore == .buy ? "Alım Emri Ver" : "Pozisyonu Kapat")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(actionColor(d.finalActionCore))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showArgusDetail) {
            ArgusDetailSheet(
                decision: decision,
                explanation: explanation,
                symbol: symbol,
                viewModel: viewModel
            )
        }
    }

    // MARK: - Helpers

    private func humanAction(_ action: SignalAction) -> String {
        switch action {
        case .buy:  return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        case .wait: return "İZLE"
        case .skip: return "PAS"
        }
    }

    private func actionColor(_ action: SignalAction) -> Color {
        switch action {
        case .buy:  return .green
        case .sell: return .red
        case .hold: return .yellow
        case .wait: return .gray
        case .skip: return .gray
        }
    }

    private func confidenceLabel(_ score: Double) -> String {
        switch score {
        case 85...: return "Güçlü sinyal"
        case 70..<85: return "Orta güven"
        case 50..<70: return "Zayıf sinyal"
        default:      return "Düşük güven"
        }
    }

    private func chironLabel(_ regime: MarketRegime) -> String {
        regime.descriptor
    }

    private func chironColor(_ regime: MarketRegime) -> Color {
        switch regime {
        case .trend:     return .green
        case .riskOff:   return .red
        case .newsShock: return .orange
        case .neutral:   return .gray
        case .chop:      return .yellow
        }
    }
}

// MARK: - Argus Detail Sheet (sadeleştirilmiş)

struct ArgusDetailSheet: View {
    let decision: ArgusDecisionResult?
    let explanation: ArgusExplanation?
    let symbol: String
    let viewModel: TradingViewModel?

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if let d = decision {
                            ArgusDecisionCardView(
                                decision: d,
                                explanation: explanation,
                                isLoading: false
                            )
                        } else {
                            Text("Karar verisi yok.")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Analiz Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - System Score Card (kept for backwards compatibility)

struct SystemScoreCard: View {
    let name: String
    let score: Double
    let mode: ArgusMode

    var body: some View {
        HStack(spacing: 12) {
            ArgusEyeView(mode: mode, size: 32)
                .frame(width: 32, height: 32)
                .background(mode.color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(String(format: "%.0f / 100", score))
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            Spacer()

            // Minimal bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule()
                        .fill(mode.color.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(score / 100), height: 4)
                }
            }
            .frame(width: 70, height: 4)
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(10)
    }
}
