import SwiftUI

struct ArgusDecisionCardView: View {
    let decision: ArgusDecisionResult
    let explanation: ArgusExplanation?
    let isLoading: Bool
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {

            // ── Aksiyon Bandı ────────────────────────────────────────────
            HStack(spacing: 14) {
                // Büyük aksiyon etiketi
                Text(actionText)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(actionColor)

                VStack(alignment: .leading, spacing: 3) {
                    // Güven: bar
                    DecisionConfidenceBar(value: decision.finalScoreCore / 100.0, color: actionColor)
                        .frame(width: 120, height: 6)

                    Text(confidenceLabel)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Saat damgası
                if !isLoading {
                    Text(decision.generatedAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                } else {
                    ProgressView().scaleEffect(0.75)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(actionColor.opacity(0.08))

            Divider().background(Color.white.opacity(0.06))

            // ── Açıklama ──────────────────────────────────────────────────
            if let exp = explanation {
                VStack(alignment: .leading, spacing: 12) {
                    // Ana sebep — büyük ve net
                    Text(exp.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)

                    // Destekleyici noktalar — sade, bullet ile
                    if !exp.bullets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(exp.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(actionColor.opacity(0.7))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 5)
                                    Text(bullet)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.75))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // Risk uyarısı — yalnızca varsa
                    if let risk = exp.riskNote, !risk.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.orange)
                            Text(risk)
                                .font(.system(size: 13))
                                .foregroundColor(.orange)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(8)
                    }

                    // Yeniden dene (offline)
                    if exp.isOffline, let retry = onRetry {
                        Button(action: retry) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Tekrar dene")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.75))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(16)

            } else if isLoading {
                // Yükleme iskeleti
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.65)
                        Text("Analiz yorumlanıyor...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .italic()
                    }
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 13)
                            .frame(maxWidth: i == 2 ? 160 : .infinity)
                    }
                }
                .padding(16)

            } else {
                Text("Analiz alınamadı.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(16)
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(actionColor.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    var actionText: String {
        switch decision.finalActionCore {
        case .buy:  return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        case .wait: return "İZLE"
        case .skip: return "PAS"
        }
    }

    var actionColor: Color {
        switch decision.finalActionCore {
        case .buy:  return .green
        case .sell: return .red
        case .hold: return .yellow
        case .wait: return .gray
        case .skip: return .gray
        }
    }

    /// "72/100" yerine sade etiket
    var confidenceLabel: String {
        let s = decision.finalScoreCore
        switch s {
        case 85...: return "Güçlü sinyal"
        case 70..<85: return "Orta güven"
        case 50..<70: return "Zayıf sinyal"
        default:      return "Düşük güven"
        }
    }
}

// MARK: - Confidence Bar (thin, reusable)

private struct DecisionConfidenceBar: View {
    let value: Double    // 0..1
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
    }
}
