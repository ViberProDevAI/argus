import SwiftUI
struct PortfolioPlanBoard: View {
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

    private var plansByTrade: [UUID: PositionPlan] {
        var plans: [UUID: PositionPlan] = [:]
        for trade in filteredOpenTrades {
            if let plan = PositionPlanStore.shared.getPlan(for: trade.id) {
                plans[trade.id] = plan
            }
        }
        return plans
    }

    private var coveredCount: Int {
        plansByTrade.count
    }

    private var coverageRatio: Double {
        guard !filteredOpenTrades.isEmpty else { return 0 }
        return Double(coveredCount) / Double(filteredOpenTrades.count)
    }

    private var pendingActionCount: Int {
        plansByTrade.values.filter { $0.nextPendingStep != nil }.count
    }

    private var nearRiskCount: Int {
        filteredOpenTrades.filter { trade in
            guard let plan = plansByTrade[trade.id], let riskStep = plan.primaryRiskStep else { return false }
            return isTriggerNear(riskStep.trigger, for: trade, plan: plan)
        }.count
    }

    private var topSignal: ChimeraSignal? {
        filteredOpenTrades
            .compactMap { SignalStateViewModel.shared.chimeraSignals[$0.symbol] }
            .max(by: { $0.severity < $1.severity })
    }

    private var focusText: String? {
        var best: (trade: Trade, step: PlannedAction)?
        for trade in filteredOpenTrades {
            guard let plan = plansByTrade[trade.id], let next = plan.nextPendingStep else { continue }
            if best == nil || next.priority < best!.step.priority {
                best = (trade, next)
            }
        }
        guard let best else { return nil }
        return "\(best.trade.symbol) • \(best.step.trigger.displayText)"
    }

    var body: some View {
        Button(action: openTradeBrain) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PLAN PANOSU")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .tracking(1.0)
                    Spacer()
                    Text("%\(Int(coverageRatio * 100)) kapsama")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(InstitutionalTheme.Colors.primary.opacity(0.14))
                        )
                }

                HStack(spacing: 8) {
                    metricCell(title: "Planlı", value: "\(coveredCount)/\(filteredOpenTrades.count)", color: InstitutionalTheme.Colors.primary)
                    metricCell(title: "Hazır Aksiyon", value: "\(pendingActionCount)", color: InstitutionalTheme.Colors.positive)
                    metricCell(title: "Risk Yakın", value: "\(nearRiskCount)", color: nearRiskCount > 0 ? InstitutionalTheme.Colors.warning : InstitutionalTheme.Colors.textSecondary)
                }

                if let topSignal {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(chimeraColor(topSignal.type))
                        Text("Premium Sinyal: \(topSignal.title)")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(chimeraColor(topSignal.type))
                        Spacer()
                    }
                }

                if let focusText {
                    Text("Odak adım: \(focusText)")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(InstitutionalTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.primary.opacity(0.20), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func metricCell(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                .fill(InstitutionalTheme.Colors.surface3.opacity(0.75))
        )
    }

    private func isTriggerNear(_ trigger: ActionTrigger, for trade: Trade, plan: PositionPlan) -> Bool {
        let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
        let pnl = ((price - trade.entryPrice) / max(trade.entryPrice, 0.0001)) * 100

        switch trigger {
        case .priceAbove(let target):
            let remaining = ((target - price) / max(price, 0.0001)) * 100
            return remaining <= 2.0
        case .priceBelow(let stop):
            let remaining = ((price - stop) / max(price, 0.0001)) * 100
            return remaining <= 2.0
        case .gainPercent(let target):
            return (target - pnl) <= 3.0
        case .lossPercent(let target):
            return (pnl + target) <= 3.0
        case .daysElapsed(let days):
            return (days - plan.ageInDays) <= 1
        default:
            return false
        }
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

// MARK: - Trade Brain Status Band
