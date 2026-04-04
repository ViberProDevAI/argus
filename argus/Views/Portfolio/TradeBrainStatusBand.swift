import SwiftUI

struct TradeBrainStatusBand: View {
    @ObservedObject var viewModel: TradingViewModel
    let market: TradeMarket
    let openTradeBrain: () -> Void

    // MARK: - Derived

    private var filteredOpenTrades: [Trade] {
        switch market {
        case .global: return viewModel.globalPortfolio.filter { $0.isOpen }
        case .bist:   return viewModel.bistOpenPortfolio.filter { $0.isOpen }
        }
    }

    private var filteredBalance: Double {
        market == .bist ? viewModel.bistBalance : viewModel.balance
    }

    private var filteredEquity: Double {
        let value = filteredOpenTrades.reduce(0.0) { total, trade in
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            return total + trade.quantity * price
        }
        return filteredBalance + value
    }

    private var health: PortfolioRiskManager.PortfolioHealth {
        PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: filteredOpenTrades,
            cashBalance: filteredBalance,
            totalEquity: max(filteredEquity, 1),
            quotes: viewModel.quotes
        )
    }

    private var dominantSignal: ChimeraSignal? {
        filteredOpenTrades
            .compactMap { SignalStateViewModel.shared.chimeraSignals[$0.symbol] }
            .max(by: { $0.severity < $1.severity })
    }

    // MARK: - Display Helpers

    /// Kullanıcının anlayacağı portföy durumu cümlesi
    private var statusSentence: String {
        let count = filteredOpenTrades.count
        if count == 0 { return "Açık pozisyon yok — sistem izlemede" }

        switch health.status {
        case .healthy:
            if let sig = dominantSignal {
                return "\(sig.symbol): \(localizedSignalTitle(sig))"
            }
            return "\(count) pozisyon dengeli seyrediyor"
        case .warning:
            if let sig = dominantSignal {
                return "Dikkat — \(sig.symbol): \(localizedSignalTitle(sig))"
            }
            return "\(count) pozisyon var, bazıları izleniyor"
        case .critical:
            if let sig = dominantSignal {
                return "Risk yüksek — \(sig.symbol): \(localizedSignalTitle(sig))"
            }
            return "Portföyde yüksek risk var, pozisyonları gözden geçir"
        }
    }

    private var statusColor: Color {
        switch health.status {
        case .healthy:  return InstitutionalTheme.Colors.positive
        case .warning:  return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    private var statusLabel: String {
        switch health.status {
        case .healthy:  return "Dengeli"
        case .warning:  return "İzleniyor"
        case .critical: return "Risk Var"
        }
    }

    private var statusIcon: String {
        switch health.status {
        case .healthy:  return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.circle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    // MARK: - Body

    var body: some View {
        Button(action: openTradeBrain) {
            HStack(spacing: 12) {
                // Sol: durum ikonu + cümle
                HStack(spacing: 10) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusSentence)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(filteredOpenTrades.count) pozisyon")
                            .font(.system(size: 11))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }

                Spacer()

                // Sağ: durum etiketi + ok
                HStack(spacing: 6) {
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
            }
            .padding(InstitutionalTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(statusColor.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Signal Title Localizer

    private func localizedSignalTitle(_ signal: ChimeraSignal) -> String {
        switch signal.type {
        case .deepValueBuy:        return "derin değer fırsatı"
        case .bullTrap:            return "boğa tuzağı riski"
        case .momentumBreakout:    return "momentum kırılımı"
        case .fallingKnife:        return "düşen bıçak — dikkat"
        case .sentimentDivergence: return "duygu-fiyat ayrışması"
        case .perfectStorm:        return "mükemmel fırtına sinyali"
        }
    }
}
