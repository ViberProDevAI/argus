import SwiftUI

/// V5 mockup "03 · Portföy" header'ının Swift karşılığı.
/// (`Argus_Mockup_V5.html` satır 682-718).
///
/// Layout sırası:
///   1. Üst control bar — menu + GLOBAL/BIST pill toggle + refresh + bell
///   2. Ortalı TOPLAM VARLIK caption + büyük skor
///   3. Aurora kapsül — +$değişim · +% (varsa)
///   4. 3 tile — NAKİT / NET K/Z / ANLIK
///
/// Gradient bg: linear #0B1426 → #060C18.
struct LiquidDashboardHeader: View {
    @ObservedObject var viewModel: TradingViewModel
    @Binding var selectedMarket: TradeMarket

    var onBrainTap: () -> Void
    var onHistoryTap: () -> Void
    var onDrawerTap: () -> Void

    private var isBist: Bool { selectedMarket == .bist }
    private var currencySymbol: String { isBist ? "₺" : "$" }

    private var equity: Double {
        isBist ? viewModel.getBistEquity() : viewModel.getEquity()
    }

    private var balance: Double {
        isBist ? viewModel.bistBalance : viewModel.balance
    }

    private var realized: Double { viewModel.getRealizedPnL(market: selectedMarket) }

    private var unrealized: Double {
        isBist ? viewModel.getBistUnrealizedPnL() : viewModel.getUnrealizedPnL()
    }

    private var netPnL: Double { realized + unrealized }

    /// Anlık net değişim yüzdesi (unrealized / positionValue)
    private var instantPct: Double {
        let positionValue = equity - balance
        guard positionValue > 0 else { return 0 }
        return (unrealized / positionValue) * 100
    }

    // 2026-04-30 H-45 — sade. Hero gradient + 34pt black mono equity +
    // ortalı caps başlık + per-card stat tile'lar gitti. Sol-aligned
    // sentence case + 28pt medium equity + inline delta + 3 sütunlu
    // dikey-ayraçlı stat satırı. Toggle: caps pill → underline tab.
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            controlBar

            marketTabs

            VStack(alignment: .leading, spacing: 2) {
                Text(isBist ? "BIST değeri" : "Toplam varlık")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(currencySymbol)\(formatLarge(equity))")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .monospacedDigit()
                    if netPnL != 0 {
                        let positive = netPnL >= 0
                        let color = positive ? InstitutionalTheme.Colors.aurora
                                             : InstitutionalTheme.Colors.crimson
                        let sign = positive ? "+" : ""
                        Text("\(sign)\(currencySymbol)\(formatLarge(netPnL))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(color)
                            .monospacedDigit()
                        Text("\(sign)\(String(format: "%.2f", instantPct))%")
                            .font(.system(size: 13))
                            .foregroundColor(color)
                            .monospacedDigit()
                    }
                }
                Text("Bugünkü değişim")
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            }

            HStack(spacing: 0) {
                statColumn(title: "Nakit",
                           value: "\(currencySymbol)\(formatLarge(balance))",
                           tone: InstitutionalTheme.Colors.textPrimary,
                           leadingDivider: false)
                statColumn(title: "Pozisyon",
                           value: "\(currencySymbol)\(formatLarge(equity - balance))",
                           tone: InstitutionalTheme.Colors.textPrimary,
                           leadingDivider: true)
                statColumn(title: "Toplam K/Z",
                           value: "\(netPnL >= 0 ? "+" : "")\(currencySymbol)\(formatLarge(netPnL))",
                           tone: netPnL >= 0 ? InstitutionalTheme.Colors.aurora
                                             : InstitutionalTheme.Colors.crimson,
                           leadingDivider: true)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    // MARK: - Control bar (sade — sol drawer + başlık + sağ ikonlar)

    private var controlBar: some View {
        HStack(spacing: 8) {
            navIcon(icon: "line.3.horizontal", action: onDrawerTap)

            Text("Portföy")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            Spacer()

            navIcon(icon: "arrow.clockwise", action: onHistoryTap)

            // Trade Brain — özel asset (TB beyin logosu, template mode)
            Button(action: onBrainTap) {
                Image("TradeBrainIcon")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Sade nav ikonu — kart/dolgu yok.
    private func navIcon(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Market tabs — caps capsule pill yerine underline tab

    private var marketTabs: some View {
        HStack(spacing: 4) {
            marketTab("Global", selected: selectedMarket == .global) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedMarket = .global }
            }
            marketTab("BIST", selected: selectedMarket == .bist) {
                withAnimation(.easeInOut(duration: 0.2)) { selectedMarket = .bist }
            }
            Spacer()
        }
    }

    private func marketTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: selected ? .medium : .regular))
                    .foregroundColor(selected
                                     ? InstitutionalTheme.Colors.textPrimary
                                     : InstitutionalTheme.Colors.textSecondary)
                Rectangle()
                    .fill(selected
                          ? InstitutionalTheme.Colors.textPrimary
                          : Color.clear)
                    .frame(height: 1.5)
            }
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stat column — kart yerine dikey-ayraçlı sütun

    private func statColumn(title: String, value: String, tone: Color, leadingDivider: Bool) -> some View {
        HStack(spacing: 0) {
            if leadingDivider {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(width: 0.5)
                    .padding(.vertical, 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Format helpers

    private func formatLarge(_ value: Double) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        }
        if abs >= 1_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}
