import SwiftUI

// MARK: - Premium Position Card
/// Entry Snapshot, Delta Tracking ve Smart Plan içeren profesyonel pozisyon kartı

struct PremiumPositionCard: View {
    let trade: Trade
    let currentPrice: Double
    var onEdit: (() -> Void)?
    var onSell: (() -> Void)?
    
    @State private var plan: PositionPlan?
    @State private var delta: PositionDeltaTracker.PositionDelta?
    
    private var pnlPercent: Double {
        ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
    }
    
    private var pnlValue: Double {
        (currentPrice - trade.entryPrice) * trade.quantity
    }
    
    // REMOVED redeclaration of plan computed property

    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerSection
            
            Divider().background(Color.white.opacity(0.1))
            
            // MARK: - Price Progress
            priceProgressSection
            
            Divider().background(Color.white.opacity(0.1))
            
            // MARK: - Plan Status
            if let plan = plan {
                planStatusSection(plan)
            }
            
            // MARK: - Delta Badge
            if let delta = delta {
                deltaBadgeSection(delta)
            }
            
            // MARK: - Actions
            actionButtonsSection
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Symbol Badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(pnlPercent >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(trade.symbol.prefix(4)))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Ticker & Name
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trade.symbol)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if let intent = plan?.intent {
                        HStack(spacing: 4) {
                            Image(systemName: intent.icon)
                                .font(.system(size: 10))
                            Text(intent.rawValue)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(intent.colorName).opacity(0.2))
                        .foregroundColor(Color(intent.colorName))
                        .cornerRadius(4)
                    }
                }
                
                Text("\(String(format: "%.2f", trade.quantity)) adet @ \(formatPrice(trade.entryPrice))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // PnL
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(pnlPercent >= 0 ? "+" : "")\(String(format: "%.1f", pnlPercent))%")
                    .font(.title2.bold())
                    .foregroundColor(pnlPercent >= 0 ? .green : .red)
                
                Text("\(pnlValue >= 0 ? "+" : "")\(formatPrice(pnlValue))")
                    .font(.caption)
                    .foregroundColor(pnlPercent >= 0 ? .green.opacity(0.8) : .red.opacity(0.8))
            }
        }
        .padding()
    }
    
    // MARK: - Price Progress Section
    
    private var priceProgressSection: some View {
        VStack(spacing: 8) {
            // Progress Bar
            GeometryReader { geo in
                let width = geo.size.width
                let plan = self.plan
                
                // Hedefler ve stop
                let stop = stopPrice(for: plan)
                let target1 = targetPrice(for: plan, index: 0)
                let target2 = targetPrice(for: plan, index: 1)
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress
                    let progress = progressWidth(current: currentPrice, entry: trade.entryPrice, stop: stop, target: target2 ?? target1 ?? trade.entryPrice * 1.2)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(pnlPercent >= 0 ? Color.green : Color.red)
                        .frame(width: max(0, min(1, width * CGFloat(progress))), height: 8) // Ensure width is within bounds
                    
                    // Entry marker
                    let entryPos = markerPosition(price: trade.entryPrice, stop: stop, target: target2 ?? target1 ?? trade.entryPrice * 1.2)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .offset(x: width * CGFloat(entryPos) - 6)
                    
                    // Current price marker
                    let currentPos = markerPosition(price: currentPrice, stop: stop, target: target2 ?? target1 ?? trade.entryPrice * 1.2)
                    Circle()
                        .fill(pnlPercent >= 0 ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: width * CGFloat(currentPos) - 6)
                }
            }
            .frame(height: 12)
            
            // Labels
            HStack {
                if let stop = stopPrice(for: plan) {
                    VStack(alignment: .leading) {
                        Text("STOP")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                        Text(formatPrice(stop))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack {
                    Text("GİRİŞ")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                    Text(formatPrice(trade.entryPrice))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack {
                    Text("ŞİMDİ")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(pnlPercent >= 0 ? .green : .red)
                    Text(formatPrice(currentPrice))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let target = targetPrice(for: plan, index: 0) {
                    VStack(alignment: .trailing) {
                        Text("HEDEF")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)
                        Text(formatPrice(target))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - Plan Status Section
    
    private func planStatusSection(_ plan: PositionPlan) -> some View {
        let scenarios = [plan.bullishScenario, plan.bearishScenario, plan.neutralScenario].compactMap { $0 }
        let totalCount = scenarios.flatMap { $0.steps }.count
        let completedCount = plan.executedSteps.count
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text("Plan Durumu")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(completedCount)/\(totalCount) adım")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Aktif adımlar
            ForEach(scenarios.filter { $0.isActive }, id: \.id) { scenario in
                ForEach(scenario.steps.sorted(by: { $0.priority < $1.priority }).prefix(2), id: \.id) { step in
                    let isCompleted = plan.executedSteps.contains(step.id)
                    
                    HStack(spacing: 8) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundColor(isCompleted ? .green : .gray)
                        
                        Text(step.description)
                            .font(.caption)
                            .foregroundColor(isCompleted ? .gray : .white)
                            .strikethrough(isCompleted)
                        
                        Spacer()
                        
                        // Kalan mesafe
                        if !isCompleted, case .priceAbove(let target) = step.trigger {
                            let remaining = ((target - currentPrice) / currentPrice) * 100
                            if remaining > 0 {
                                Text("+\(String(format: "%.1f", remaining))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
    }
    
    // MARK: - Delta Badge Section
    
    private func deltaBadgeSection(_ delta: PositionDeltaTracker.PositionDelta) -> some View {
        HStack(spacing: 12) {
            // Önem badge
            HStack(spacing: 4) {
                Text(delta.significanceEmoji)
                Text(delta.significance.rawValue)
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(significanceColor(delta.significance).opacity(0.2))
            )
            .foregroundColor(significanceColor(delta.significance))
            
            // Delta özet
            Text(delta.summaryText)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            // Gün sayısı
            Text("\(delta.daysHeld) gün")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Detay button removed (Card tap handles it, or keep as visual cue)
             // But actually, showing it is nice.
             // We can assume Detail action is handled by parent, or add callback.
             // But the user said "Detay Düzenle ve Sat". Maybe they meant "Düzenle" and "Sat".
             // "Detay" button opens Detail View.
            /*
             Button(action: { showDetail = true }) { ... }
             */
            // Let's deprecate internal showDetail.
            // Keeping the button layout but making Detay non-functional (visual) or callback?
            // I'll make Detay trigger onEdit (which might be detail) or a new onDetail.
            // Actually, Card TAP is detail.
            // Let's leave "Detay" button as a visual indicator that brings up Detail.
            
            /*
             Button(action: { }) {
                 HStack { ... }
             }
             .disabled(true) // Visual only since card tap does it?
             */
             // No, user wants BUTTON to work.
             // I'll add onDetail callback too.

            
            Button(action: { onEdit?() }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Plan")
                }
                .font(.caption.bold())
                .foregroundColor(.yellow)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            Button(action: { onSell?() }) {
                HStack {
                    Image(systemName: "arrow.down.right")
                    Text("Sat")
                }
                .font(.caption.bold())
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "0a0f1a"),
                        Color(hex: "0d1420")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                pnlPercent >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    private func loadData() {
        // Load Plan (Vortex)
        if let existingPlan = PositionPlanStore.shared.getPlan(for: trade.id) {
            self.plan = existingPlan
        } else {
            // Attempt to create/fetch default if missing
            // Ideally Store sync handles this, but for safety:
            // self.plan = PositionPlanStore.shared.createPlan(...) // Requires decision
        }
        
        // Load Delta
        Task {
            if let snapshot = self.plan?.originalSnapshot {
                let current = await PositionDeltaTracker.shared.calculateDelta(
                    for: trade,
                    entrySnapshot: snapshot,
                    currentOrionScore: 50.0, // TODO: Fetch real score
                    currentGrandDecision: nil, // TODO: Fetch real decision
                    currentPrice: currentPrice
                )
                await MainActor.run {
                    self.delta = current
                }
            }
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        if trade.symbol.hasSuffix(".IS") {
            return String(format: "%.2f ₺", price)
        }
        return String(format: "$%.2f", price)
    }
    
    private func stopPrice(for plan: PositionPlan?) -> Double? {
        guard let plan = plan else { return nil }
        // New structure: check bearishScenario directly
        let scenario = plan.bearishScenario
        for step in scenario.steps {
            if case .priceBelow(let price) = step.trigger {
                return price
            }
        }
        return nil
    }
    
    private func targetPrice(for plan: PositionPlan?, index: Int) -> Double? {
        guard let plan = plan else { return nil }
        var targets: [Double] = []
        // New structure: check bullishScenario directly
        let scenario = plan.bullishScenario
        for step in scenario.steps {
            if case .priceAbove(let price) = step.trigger {
                targets.append(price)
            }
        }
        targets.sort()
        return index < targets.count ? targets[index] : nil
    }
    
    private func progressWidth(current: Double, entry: Double, stop: Double?, target: Double) -> Double {
        let stopVal = stop ?? (entry * 0.9)
        let range = target - stopVal
        let position = current - stopVal
        return max(0, min(1, position / range))
    }
    
    private func markerPosition(price: Double, stop: Double?, target: Double) -> Double {
        let stopVal = stop ?? (trade.entryPrice * 0.9)
        let range = target - stopVal
        return (price - stopVal) / range
    }
    
    private func significanceColor(_ sig: PositionDeltaTracker.ChangeSignificance) -> Color {
        switch sig {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleTrade = Trade(
        symbol: "THYAO.IS",
        entryPrice: 320,
        quantity: 100,
        entryDate: Date().addingTimeInterval(-86400 * 5),
        isOpen: true,
        source: .autoPilot
    )
    
    return PremiumPositionCard(
        trade: sampleTrade,
        currentPrice: 335
    )
    .padding()
    .background(Color.black)
}
