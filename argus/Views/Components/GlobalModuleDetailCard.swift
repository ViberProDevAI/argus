import SwiftUI

// MARK: - Global Modül Detay Kartı
// CouncilDecision verilerini gösterir (Orion, Atlas, Aether, Hermes için)

struct GlobalModuleDetailCard: View {
    let moduleName: String
    let decision: CouncilDecision
    let moduleColor: Color
    let moduleIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: max(0, decision.netSupport))
                        .stroke(supportColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(decision.netSupport * 100))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(supportColor)
                        Text("%")
                            .font(.system(size: 9))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("SİNYAL")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)

                    Text(actionText)
                        .font(.headline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(actionColor.opacity(0.2))
                        .foregroundColor(actionColor)
                        .cornerRadius(8)

                    Text(decision.signalStrength)
                        .font(.caption2)
                        .foregroundColor(signalStrengthColor)
                }
            }

            if let proposal = decision.winningProposal {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(moduleColor)
                        Text("Kazanan Öneri")
                            .font(.subheadline.bold())
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }

                    Text(cleanReasoning(proposal.reasoning))
                        .font(.body)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                        .background(InstitutionalTheme.Colors.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Oylama")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text("Onay: \(Int(decision.approveWeight * 100))% | Veto: \(Int(decision.vetoWeight * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }

                GeometryReader { geo in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.positive)
                            .frame(width: geo.size.width * decision.approveWeight)

                        Rectangle()
                            .fill(InstitutionalTheme.Colors.negative)
                            .frame(width: geo.size.width * decision.vetoWeight)

                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
            }

            if !decision.vetoReasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                        Text("Veto Gerekçeleri")
                            .font(.caption.bold())
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                    }

                    ForEach(decision.vetoReasons.prefix(3), id: \.self) { reason in
                        Text("• \(reason)")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.negative.opacity(0.85))
                    }
                }
                .padding()
                .background(InstitutionalTheme.Colors.negative.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.negative.opacity(0.24), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .institutionalCard(scale: .insight, elevated: false)
    }

    private func cleanReasoning(_ text: String) -> String {
        text
            .replacingOccurrences(of: "weak_positive", with: "Olumlu (Zayıf)")
            .replacingOccurrences(of: "strong_positive", with: "Güçlü Olumlu")
            .replacingOccurrences(of: "weak_negative", with: "Olumsuz (Zayıf)")
            .replacingOccurrences(of: "strong_negative", with: "Güçlü Olumsuz")
            .replacingOccurrences(of: "neutral", with: "Nötr")
    }

    private var supportColor: Color {
        if decision.netSupport >= 0.5 { return InstitutionalTheme.Colors.positive }
        if decision.netSupport >= 0.2 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }

    private var actionText: String {
        switch decision.action {
        case .buy: return " AL"
        case .sell: return " SAT"
        case .hold: return "⏸️ BEKLE"
        }
    }

    private var actionColor: Color {
        switch decision.action {
        case .buy: return InstitutionalTheme.Colors.positive
        case .sell: return InstitutionalTheme.Colors.negative
        case .hold: return InstitutionalTheme.Colors.warning
        }
    }

    private var signalStrengthColor: Color {
        switch decision.signalStrength {
        case "GÜÇLÜ": return InstitutionalTheme.Colors.positive
        case "ZAYIF": return InstitutionalTheme.Colors.warning
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
}
