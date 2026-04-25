import SwiftUI

struct SanctumTradePanel: View {
    let symbol: String
    let currentPrice: Double
    let onBuy: () -> Void
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSell) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(format: "%.2f", currentPrice))
                            .font(InstitutionalTheme.Typography.dataSmall)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                            .monospacedDigit()
                    }
                    Text("SAT")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SanctumTheme.crimsonRed.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SanctumTheme.crimsonRed.opacity(0.45), lineWidth: 1)
                        )
                )
            }

            Spacer()
            Spacer()

            Button(action: onBuy) {
                HStack(spacing: 6) {
                    Text("AL")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(String(format: "%.2f", currentPrice))
                            .font(InstitutionalTheme.Typography.dataSmall)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SanctumTheme.auroraGreen.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SanctumTheme.auroraGreen.opacity(0.45), lineWidth: 1)
                        )
                )
                .shadow(color: SanctumTheme.auroraGreen.opacity(0.2), radius: 4, x: 0, y: 0)
            }
        }
        .padding(.horizontal, 16)
    }
}
