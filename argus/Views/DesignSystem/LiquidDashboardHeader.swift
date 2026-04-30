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

    var body: some View {
        VStack(spacing: 14) {
            // 1. Üst control bar
            controlBar

            // 2. Ortalı TOPLAM VARLIK
            VStack(spacing: 4) {
                Text(isBist ? "BIST DEĞERİ" : "TOPLAM VARLIK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)

                Text("\(currencySymbol)\(formatLarge(equity))")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            // 3. Aurora delta capsule
            if netPnL != 0 {
                instantChangeCapsule
            }

            // 4. 3 tile
            HStack(spacing: 8) {
                statTile(title: "NAKİT",
                         value: "\(currencySymbol)\(formatLarge(balance))",
                         tone: InstitutionalTheme.Colors.textPrimary)
                statTile(title: "NET K/Z",
                         value: "\(netPnL >= 0 ? "+" : "")\(currencySymbol)\(formatLarge(netPnL))",
                         tone: netPnL >= 0 ? InstitutionalTheme.Colors.aurora
                                           : InstitutionalTheme.Colors.crimson)
                statTile(title: "ANLIK",
                         value: "\(unrealized >= 0 ? "+" : "")\(currencySymbol)\(formatLarge(unrealized))",
                         tone: unrealized >= 0 ? InstitutionalTheme.Colors.aurora
                                               : InstitutionalTheme.Colors.crimson)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "0B1426"),
                    Color(hex: "060C18")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Control bar (menu + toggle + refresh/bell)

    private var controlBar: some View {
        HStack {
            iconButton(icon: "line.3.horizontal", action: onDrawerTap)

            Spacer()

            // V5 pill capsule toggle
            HStack(spacing: 4) {
                toggleChip("GLOBAL", selected: selectedMarket == .global) {
                    withAnimation(.spring(response: 0.3)) { selectedMarket = .global }
                }
                toggleChip("BIST", selected: selectedMarket == .bist) {
                    withAnimation(.spring(response: 0.3)) { selectedMarket = .bist }
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(Capsule().stroke(InstitutionalTheme.Colors.border, lineWidth: 1))
            )

            Spacer()

            HStack(spacing: 4) {
                iconButton(icon: "arrow.clockwise", action: onHistoryTap)
                iconButton(icon: "brain.head.profile", action: onBrainTap)
            }
        }
    }

    private func iconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(InstitutionalTheme.Colors.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggleChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(selected ? .white : InstitutionalTheme.Colors.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                // PERFORMANCE: AnyView ternary yerine .background { @ViewBuilder }
                // closure formu — SwiftUI'nin tip kimliğini bozmaz.
                .background {
                    if selected {
                        Capsule().fill(InstitutionalTheme.Colors.holo)
                    } else {
                        Color.clear
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Instant change capsule

    private var instantChangeCapsule: some View {
        let positive = netPnL >= 0
        let color = positive ? InstitutionalTheme.Colors.aurora : InstitutionalTheme.Colors.crimson
        let sign = positive ? "+" : ""
        return HStack(spacing: 6) {
            Image(systemName: positive ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text("\(sign)\(currencySymbol)\(formatLarge(netPnL)) · \(sign)\(String(format: "%.2f", instantPct))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Stat tile

    private func statTile(title: String, value: String, tone: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg, style: .continuous))
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
