import SwiftUI

// MARK: - Daily Agenda View
/// Portföyün en tepesinde: "Bugün ne yapmalıyım?" sorusuna doğrudan cevap verir.
/// Sadece aksiyon gerektiren durumlar varsa görünür. Sessiz kaldığında her şey yolunda demektir.

struct DailyAgendaView: View {
    @ObservedObject var viewModel: TradingViewModel
    let market: TradeMarket

    // MARK: - Acil Durum Hesaplama

    private var openTrades: [Trade] {
        switch market {
        case .global: return viewModel.globalPortfolio.filter { $0.isOpen }
        case .bist:   return viewModel.bistOpenPortfolio.filter { $0.isOpen }
        }
    }

    private var agendaItems: [AgendaItem] {
        var items: [AgendaItem] = []

        for trade in openTrades {
            let price = viewModel.quotes[trade.symbol]?.currentPrice ?? trade.entryPrice
            let symbol = trade.symbol.replacingOccurrences(of: ".IS", with: "")
            let decision = SignalStateViewModel.shared.grandDecisions[trade.symbol]
            let chimera  = SignalStateViewModel.shared.chimeraSignals[trade.symbol]
            let plan     = PositionPlanStore.shared.getPlan(for: trade.id)

            // 1. Çıkış sinyali
            if let d = decision, d.action == .liquidate {
                items.append(AgendaItem(
                    symbol: symbol,
                    urgency: .high,
                    message: "Argus çıkış öneriyor",
                    icon: "xmark.circle.fill"
                ))
                continue
            }

            // 2. Stop noktasına yakın
            if let plan = plan, trade.entryPrice > 0 {
                let stopPrice = firstStopPrice(plan: plan)
                if let stop = stopPrice, stop > 0, price > 0 {
                    let distancePct = ((price - stop) / price) * 100
                    if distancePct < 3 {
                        items.append(AgendaItem(
                            symbol: symbol,
                            urgency: .high,
                            message: "Stop'a \(String(format: "%.1f", distancePct))% yakın",
                            icon: "shield.slash.fill"
                        ))
                        continue
                    }
                }
            }

            // 3. Azalt kararı
            if let d = decision, d.action == .trim {
                items.append(AgendaItem(
                    symbol: symbol,
                    urgency: .medium,
                    message: "Pozisyonun bir kısmını sat",
                    icon: "arrow.down.circle.fill"
                ))
                continue
            }

            // 4. Yüksek şiddetli Chimera sinyali
            if let cs = chimera, cs.severity >= 0.65 {
                let msg = chimeraMessage(cs)
                items.append(AgendaItem(
                    symbol: symbol,
                    urgency: .medium,
                    message: msg,
                    icon: "exclamationmark.triangle.fill"
                ))
                continue
            }

            // 5. Çok uzun süredir tutuluyor (45+ gün, hedef yakın)
            let days = Calendar.current.dateComponents([.day], from: trade.entryDate, to: Date()).day ?? 0
            if days >= 45, let plan = plan {
                let target = firstTargetPrice(plan: plan)
                if let t = target, t > 0, price > 0 {
                    let distToPct = ((t - price) / price) * 100
                    if distToPct < 5 {
                        items.append(AgendaItem(
                            symbol: symbol,
                            urgency: .low,
                            message: "\(days) gündür tutuluyor, hedefe \(String(format: "%.1f", distToPct))% kaldı",
                            icon: "clock.badge.exclamationmark.fill"
                        ))
                    }
                }
            }
        }

        // En acil olanlar üstte, max 4 adet göster
        return items.sorted { $0.urgency.priority > $1.urgency.priority }.prefix(4).map { $0 }
    }

    // MARK: - Body

    var body: some View {
        let items = agendaItems
        if items.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Başlık
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    Text("Dikkat Gereken Pozisyonlar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(items.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(Color.orange.opacity(0.2))

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14))
                                .foregroundColor(item.urgency.color)
                                .frame(width: 20)

                            Text(item.symbol)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 52, alignment: .leading)

                            Text(item.message)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if idx < items.count - 1 {
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 14)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                    )
            )
        )
    }

    // MARK: - Helpers

    private func firstStopPrice(plan: PositionPlan) -> Double? {
        for step in plan.bearishScenario.steps.sorted(by: { $0.priority < $1.priority })
            where !plan.executedSteps.contains(step.id) {
            if case .priceBelow(let p) = step.trigger { return p }
        }
        return nil
    }

    private func firstTargetPrice(plan: PositionPlan) -> Double? {
        for step in plan.bullishScenario.steps.sorted(by: { $0.priority < $1.priority })
            where !plan.executedSteps.contains(step.id) {
            if case .priceAbove(let p) = step.trigger { return p }
        }
        return nil
    }

    private func chimeraMessage(_ cs: ChimeraSignal) -> String {
        switch cs.type {
        case .deepValueBuy:        return "Güçlü değer fırsatı tespit edildi"
        case .bullTrap:            return "Boğa tuzağı riski — dikkat"
        case .momentumBreakout:    return "Momentum kırılımı, hız kazanıyor"
        case .fallingKnife:        return "Düşen bıçak — çıkışı değerlendir"
        case .sentimentDivergence: return "Duygu-fiyat ayrışması görülüyor"
        case .perfectStorm:        return "Çoklu sinyal çakışması — kritik"
        }
    }
}

// MARK: - Data Models

private struct AgendaItem {
    let symbol: String
    let urgency: Urgency
    let message: String
    let icon: String

    enum Urgency {
        case high, medium, low
        var color: Color {
            switch self {
            case .high:   return .red
            case .medium: return .orange
            case .low:    return .yellow
            }
        }
        var priority: Int {
            switch self {
            case .high:   return 3
            case .medium: return 2
            case .low:    return 1
            }
        }
    }
}
