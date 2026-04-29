import SwiftUI

// 2026-04-24 H-27: Eski panel "239.23 SAT / AL 239.23" şeklinde fiyatı her
// iki butonda tekrar ediyordu — fiyat zaten SanctumHeader'da en üstte. Yeni
// panel sade "Sat" ve "Al" — eylem netleşti, fiyat tek yerde yaşıyor.
// Aurora glow shadow kaldırıldı (AI-tell), butonlar institutional dilde:
// fill + stroke + sentence case label.

struct SanctumTradePanel: View {
    let symbol: String
    let currentPrice: Double
    let onBuy: () -> Void
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            tradeButton(
                label: "Sat",
                tint: SanctumTheme.crimsonRed,
                action: onSell
            )
            tradeButton(
                label: "Al",
                tint: SanctumTheme.auroraGreen,
                action: onBuy
            )
        }
        .padding(.horizontal, 16)
    }

    private func tradeButton(label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(tint.opacity(0.45), lineWidth: 1)
                        )
                )
        }
    }
}
