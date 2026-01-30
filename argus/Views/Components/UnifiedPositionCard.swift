import SwiftUI

// MARK: - Unified Position Card
/// BIST ve Global piyasalar için tek, birleşik pozisyon kartı.
/// Pazar türüne göre tema ve özellikleri otomatik ayarlar.

struct UnifiedPositionCard: View {
    let trade: Trade
    let currentPrice: Double
    let market: TradeMarket
    var onEdit: (() -> Void)?
    var onSell: (() -> Void)?
    
    // State
    @State private var plan: PositionPlan?
    @State private var delta: PositionDeltaTracker.PositionDelta?
    
    // Computed Properies
    private var isBist: Bool { market == .bist }
    
    private var accentColor: Color {
        isBist ? Theme.bistAccent : Theme.accent
    }
    
    private var positiveColor: Color {
        isBist ? Theme.bistPositive : Theme.positive
    }
    
    private var negativeColor: Color {
        isBist ? Theme.bistNegative : Theme.negative
    }
    
    private var pnlPercent: Double {
        guard trade.entryPrice > 0 else { return 0 }
        return ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100
    }
    
    private var pnlValue: Double {
        (currentPrice - trade.entryPrice) * trade.quantity
    }
    
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
            } else {
                // Plan yoksa teşvik mesajı veya boş alan
                noPlanSection
            }
            
            // MARK: - Delta Badge (Smart Alerts)
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
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Symbol Badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(pnlPercent >= 0 ? positiveColor.opacity(0.2) : negativeColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(trade.symbol.prefix(4)))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            // Ticker & Name
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displaySymbol)
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // Market Badge
                    Text(isBist ? "BIST" : "GLOBAL")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.gray)
                        .cornerRadius(2)
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
                    .foregroundColor(pnlPercent >= 0 ? positiveColor : negativeColor)
                
                Text("\(pnlValue >= 0 ? "+" : "")\(formatPrice(pnlValue))")
                    .font(.caption)
                    .foregroundColor(pnlPercent >= 0 ? positiveColor.opacity(0.8) : negativeColor.opacity(0.8))
            }
        }
        .padding()
    }
    
    private var noPlanSection: some View {
        HStack {
            Image(systemName: "doc.badge.plus")
                .foregroundColor(accentColor)
            Text("Akıllı plan oluşturulmadı")
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Button("Oluştur") {
                onEdit?()
            }
            .font(.caption.bold())
            .foregroundColor(accentColor)
        }
        .padding()
        .background(Color.white.opacity(0.02))
    }
    
    private var priceProgressSection: some View {
        VStack(spacing: 8) {
            // Progress Bar (Simplified for MVP)
            GeometryReader { geo in
                let width = geo.size.width
                
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    
                    // PnL Indicator (Middle is entry)
                    // This is a simplified visual representation
                    let entryX = width / 2
                    
                    // Entry Marker
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .position(x: entryX, y: 3)
                    
                    // Current Price Marker (Relative to entry)
                    // Clamped to avoid overflow
                    let offset = max(-width/2 + 10, min(width/2 - 10, (CGFloat(pnlPercent) * 2))) // Scale factor
                    
                    Circle()
                        .fill(pnlPercent >= 0 ? positiveColor : negativeColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .position(x: entryX + offset, y: 3)
                }
            }
            .frame(height: 10)
            
            HStack {
                Text(formatPrice(trade.entryPrice))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(formatPrice(currentPrice))
                    .font(.caption2.bold())
                    .foregroundColor(pnlPercent >= 0 ? positiveColor : negativeColor)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    private func planStatusSection(_ plan: PositionPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(accentColor)
                Text("Plan: \(plan.intent.rawValue)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Active Scenario Steps
            if let activeScenario = [plan.bullishScenario, plan.bearishScenario].first(where: { $0.isActive }) {
                ForEach(activeScenario.steps.prefix(2)) { step in
                    HStack {
                        Image(systemName: plan.executedSteps.contains(step.id) ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundColor(plan.executedSteps.contains(step.id) ? .green : .gray)
                        Text(step.description)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
    }
    
    private func deltaBadgeSection(_ delta: PositionDeltaTracker.PositionDelta) -> some View {
        HStack {
            Text(delta.significanceEmoji)
            Text(delta.significance.rawValue)
                .font(.caption.bold())
                .foregroundColor(significanceColor(delta.significance))
            
            Text(delta.summaryText)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(significanceColor(delta.significance).opacity(0.1))
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: { onEdit?() }) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.caption)
                    Text("Yönet")
                        .font(.caption.bold())
                }
                .foregroundColor(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: { onSell?() }) {
                HStack {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                    Text("Kapat")
                        .font(.caption.bold())
                }
                .foregroundColor(negativeColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(negativeColor.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                pnlPercent >= 0 ? positiveColor.opacity(0.3) : negativeColor.opacity(0.3),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    private var displaySymbol: String {
        isBist ? trade.symbol.replacingOccurrences(of: ".IS", with: "") : trade.symbol
    }
    
    private func formatPrice(_ price: Double) -> String {
        if isBist {
            return String(format: "%.2f ₺", price)
        }
        return String(format: "$%.2f", price)
    }
    
    private func significanceColor(_ sig: PositionDeltaTracker.ChangeSignificance) -> Color {
        switch sig {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func loadData() {
        if let existingPlan = PositionPlanStore.shared.getPlan(for: trade.id) {
            self.plan = existingPlan
        }
        
        // Simüle edilmiş delta (gerçek entegrasyon için PositionDeltaTracker kullanılmalı)
        // MVP için boş bırakıyorum, normalde asenkron yüklenir
    }
}

// MARK: - Enums (Models/TradeMarket.swift içinde tanımlı)
// enum TradeMarket silindi
