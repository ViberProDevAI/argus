import SwiftUI
struct TradeBrainStatusBand: View {
    @ObservedObject var viewModel: TradingViewModel
    let market: TradeMarket
    let openTradeBrain: () -> Void

    private var filteredOpenTrades: [Trade] {
        switch market {
        case .global:
            return viewModel.globalPortfolio.filter { $0.isOpen }
        case .bist:
            return viewModel.bistOpenPortfolio.filter { $0.isOpen }
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

    private var filteredPlans: [PositionPlan] {
        filteredOpenTrades.compactMap { PositionPlanStore.shared.getPlan(for: $0.id) }
    }

    private var health: PortfolioRiskManager.PortfolioHealth {
        PortfolioRiskManager.shared.checkPortfolioHealth(
            portfolio: filteredOpenTrades,
            cashBalance: filteredBalance,
            totalEquity: max(filteredEquity, 1),
            quotes: viewModel.quotes
        )
    }

    private var dominantDecision: ArgusGrandDecision? {
        filteredOpenTrades
            .compactMap { viewModel.grandDecisions[$0.symbol] }
            .max(by: { $0.confidence < $1.confidence })
    }

    private var topSignal: ChimeraSignal? {
        filteredOpenTrades
            .compactMap { SignalStateViewModel.shared.chimeraSignals[$0.symbol] }
            .max(by: { $0.severity < $1.severity })
    }

    private var planCoverage: Double {
        guard !filteredOpenTrades.isEmpty else { return 0 }
        return Double(filteredPlans.count) / Double(filteredOpenTrades.count)
    }

    private var pendingStepCount: Int {
        filteredPlans.filter { $0.nextPendingStep != nil }.count
    }

    private var actionColor: Color {
        guard let decision = dominantDecision else { return InstitutionalTheme.Colors.textSecondary }
        switch decision.action {
        case .aggressiveBuy: return InstitutionalTheme.Colors.positive
        case .accumulate: return InstitutionalTheme.Colors.primary
        case .neutral: return InstitutionalTheme.Colors.textSecondary
        case .trim: return InstitutionalTheme.Colors.warning
        case .liquidate: return InstitutionalTheme.Colors.negative
        }
    }

    private var healthColor: Color {
        switch health.status {
        case .healthy: return InstitutionalTheme.Colors.positive
        case .warning: return InstitutionalTheme.Colors.warning
        case .critical: return InstitutionalTheme.Colors.negative
        }
    }

    var body: some View {
        Button(action: openTradeBrain) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRADE BRAIN DURUMU")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .tracking(1.0)

                    if let decision = dominantDecision {
                        Text("\(decision.symbol) • \(decision.action.rawValue) • %\(Int(decision.confidence * 100)) güven")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("Açık pozisyon yok, yeni plan oluşmadı")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text("%\(Int(planCoverage * 100)) plan")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.primary)
                        Text("•")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("\(pendingStepCount) bekleyen adım")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    if let topSignal {
                        Text("Sinyal: \(topSignal.title)")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(chimeraColor(topSignal.type))
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text("Skor \(Int(health.score))")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(healthColor)
                    Text("\(filteredOpenTrades.count) pozisyon")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(actionColor)
            }
            .padding(InstitutionalTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(actionColor.opacity(0.28), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func chimeraColor(_ type: ChimeraSignalType) -> Color {
        switch type {
        case .deepValueBuy: return Color.purple
        case .bullTrap: return InstitutionalTheme.Colors.warning
        case .momentumBreakout: return InstitutionalTheme.Colors.positive
        case .fallingKnife: return InstitutionalTheme.Colors.negative
        case .sentimentDivergence: return InstitutionalTheme.Colors.primary
        case .perfectStorm: return InstitutionalTheme.Colors.warning
        }
    }
}

// MARK: - History Sheet
