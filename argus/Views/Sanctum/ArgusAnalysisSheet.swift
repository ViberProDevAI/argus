import SwiftUI

// MARK: - Argus Analysis Sheet (V5.H-34)
//
// Sanctum'da "Argus analizini aç" düğmesi basıldığında açılır.
//
// İlk versiyon: ArgusGrandDecision'da var olan veriler (motor skorları,
// gerekçe template'leri, çelişki haritası) detaylı bir okuma formatında
// sunulur. Hiçbir nil/boş alan yoktur.
//
// İleride: ArgusExplanationService.generateExplanation(for:) çağrılır,
// Groq/Gemini'den gelen `ArgusExplanation` (title + summary + bullets)
// üst kısma eklenir. Şu an o entegrasyon yapılmadan da sheet işe yarar
// halde duruyor — yine kanonik içerik var.

struct ArgusAnalysisSheet: View {
    let symbol: String
    let decision: ArgusGrandDecision?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBlock
                    finalDecisionBlock
                    motorReasoningList
                    conflictBlock
                    closingNote
                }
                .padding(16)
            }
            .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Argus analizi")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(InstitutionalTheme.Colors.holo)
                }
            }
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text("Konsey detaylı analizi")
                .font(.system(size: 13))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
    }

    // MARK: - Konsey kararı

    @ViewBuilder
    private var finalDecisionBlock: some View {
        if let d = decision {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sonuç")
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text(actionText(d.finalActionCore))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(actionColor(d.finalActionCore))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Güven")
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("%\(Int(d.finalScoreCore.rounded()))")
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                }
                Divider().background(InstitutionalTheme.Colors.border)
                Text(summarySentence(d))
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(actionColor(d.finalActionCore).opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            placeholderBlock(text: "Konsey kararı henüz hesaplanmadı.")
        }
    }

    private func summarySentence(_ d: ArgusGrandDecision) -> String {
        // Kısa bir tek cümle: en güçlü destekçi + en güçlü itirazcı.
        let r = d.motorReasonings.sorted { $0.score > $1.score }
        guard let top = r.first, let bottom = r.last else {
            return "Veri yetersiz, konsey net bir tavır almadı."
        }
        if top.motor == bottom.motor {
            return "Sadece \(top.motor.displayName) verisi var. Konsey tek motordan beslendiği için kararı temkinli al."
        }
        return "\(top.motor.displayName) (\(Int(top.score))) en güçlü destekçi, \(bottom.motor.displayName) (\(Int(bottom.score))) en zayıf halka. Konsey kararı bu iki uç arasında dengelendi."
    }

    // MARK: - Motor list

    @ViewBuilder
    private var motorReasoningList: some View {
        if let d = decision, !d.motorReasonings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Motor oyları")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                ForEach(d.motorReasonings, id: \.motor) { r in
                    motorRow(r)
                }
            }
        }
    }

    private func motorRow(_ r: MotorReasoning) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(r.motor.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
                // Chiron gibi sayısal olmayan motorlar için valueText doğrudan gösterilir.
                if let value = r.valueText {
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundColor(stanceColor(r.stance))
                } else if r.score <= 0 {
                    Text("Bekleniyor")
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                } else {
                    Text("\(r.stance.arrowGlyph) \(r.stance.rawValue) · \(Int(r.score))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(stanceColor(r.stance))
                }
            }
            if !r.summary.isEmpty {
                Text(r.summary)
                    .font(.system(size: 12))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let w = r.weight {
                Text("Konsey ağırlığı %\(Int((w * 100).rounded()))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(stanceColor(r.stance).opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Çelişki haritası

    @ViewBuilder
    private var conflictBlock: some View {
        if let d = decision, !d.motorReasonings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Çelişki haritası")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(d.conflictMapText)
                    .font(.system(size: 13))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var closingNote: some View {
        Text("Bu sayfa motor verilerinden üretilen yapısal analizi gösterir. Daha derin (LLM destekli) yorum için ileride bu sayfaya ek bir bölüm gelecek.")
            .font(.system(size: 11))
            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            .padding(.top, 8)
    }

    private func placeholderBlock(text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Helpers

    private func actionText(_ a: SignalAction) -> String {
        switch a {
        case .buy:  return "Al"
        case .sell: return "Sat"
        case .hold: return "Bekle"
        case .wait: return "İzle"
        case .skip: return "Pas"
        }
    }

    private func actionColor(_ a: SignalAction) -> Color {
        switch a {
        case .buy:                return InstitutionalTheme.Colors.aurora
        case .hold, .wait, .skip: return InstitutionalTheme.Colors.holo
        case .sell:               return InstitutionalTheme.Colors.crimson
        }
    }

    private func stanceColor(_ s: MotorStance) -> Color {
        switch s {
        case .strongBuy, .buy:   return InstitutionalTheme.Colors.aurora
        case .wait:              return InstitutionalTheme.Colors.holo
        case .neutral:           return InstitutionalTheme.Colors.textSecondary
        case .sell, .strongSell: return InstitutionalTheme.Colors.crimson
        }
    }
}
