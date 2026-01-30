import SwiftUI

// MARK: - Observatory Health View
/// Displays system health metrics, drift detection, and data quality alerts
// MARK: - Observatory Health View
/// Displays system health metrics, drift detection, and data quality alerts
struct ObservatoryHealthView: View {
    @State private var metrics: PerformanceMetrics = .empty
    @State private var distribution: PredictionDistribution = .empty
    @State private var alerts: [DataQualityAlert] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Performance HUD (Grid)
                performanceHUD
                
                // 2. Drift Analysis (Energy Bar)
                driftEnergyBar
                
                // 3. System Logs (Alerts)
                systemLogConsole
            }
            .padding(.top, 20)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Performance HUD
    private var performanceHUD: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SYSTEM_PERFORMANCE", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                HoloMetricCard(
                    title: "SHARPE",
                    value: String(format: "%.2f", metrics.sharpe),
                    icon: "chart.xyaxis.line",
                    color: metrics.sharpe > 1.0 ? SanctumTheme.auroraGreen : (metrics.sharpe > 0.5 ? SanctumTheme.titanGold : SanctumTheme.crimsonRed)
                )
                
                HoloMetricCard(
                    title: "HIT_RATE",
                    value: String(format: "%.0f%%", metrics.hitRate * 100),
                    icon: "target",
                    color: metrics.hitRate > 0.55 ? SanctumTheme.auroraGreen : (metrics.hitRate > 0.45 ? SanctumTheme.titanGold : SanctumTheme.crimsonRed)
                )
                
                HoloMetricCard(
                    title: "PROFIT_FACTOR",
                    value: String(format: "%.2f", metrics.profitFactor),
                    icon: "dollarsign.circle",
                    color: metrics.profitFactor > 1.5 ? SanctumTheme.auroraGreen : (metrics.profitFactor > 1.0 ? SanctumTheme.titanGold : SanctumTheme.crimsonRed)
                )
                
                HoloMetricCard(
                    title: "MAX_DD",
                    value: String(format: "%.1f%%", metrics.maxDrawdown),
                    icon: "arrow.down.right",
                    color: metrics.maxDrawdown < 10 ? SanctumTheme.auroraGreen : (metrics.maxDrawdown < 20 ? SanctumTheme.titanGold : SanctumTheme.crimsonRed)
                )
            }
        }
    }
    
    // MARK: - Drift Energy Bar
    private var driftEnergyBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PREDICTION_DRIFT", systemImage: "chart.pie")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
            
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // BUY
                    Rectangle()
                        .fill(SanctumTheme.auroraGreen)
                        .frame(width: max(0, CGFloat(distribution.buyPercent / 100) * (UIScreen.main.bounds.width - 40)))
                    
                    // HOLD
                    Rectangle()
                        .fill(SanctumTheme.ghostGrey.opacity(0.3))
                        .frame(width: max(0, CGFloat(distribution.holdPercent / 100) * (UIScreen.main.bounds.width - 40)))
                    
                    // SELL
                    Rectangle()
                        .fill(SanctumTheme.crimsonRed)
                        .frame(width: max(0, CGFloat(distribution.sellPercent / 100) * (UIScreen.main.bounds.width - 40)))
                }
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                
                // Labels below bar
                HStack {
                    Text("BUY \(Int(distribution.buyPercent))%")
                        .foregroundColor(SanctumTheme.auroraGreen)
                    Spacer()
                    Text("HOLD \(Int(distribution.holdPercent))%")
                        .foregroundColor(SanctumTheme.ghostGrey)
                    Spacer()
                    Text("SELL \(Int(distribution.sellPercent))%")
                        .foregroundColor(SanctumTheme.crimsonRed)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.top, 6)
            }
            .padding(12)
            .background(SanctumTheme.glassMaterial)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Drift Warning
            if distribution.isDrifting {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(SanctumTheme.titanGold)
                    Text("DRIFT DETECTED: \(distribution.driftReason)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(SanctumTheme.titanGold)
                }
                .padding(8)
                .background(SanctumTheme.titanGold.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    // MARK: - System Log Console
    private var systemLogConsole: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("SYSTEM_LOGS", systemImage: "exclamationmark.shield")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(SanctumTheme.ghostGrey)
            
            if alerts.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SanctumTheme.auroraGreen)
                    Text("ALL SYSTEMS NOMINAL")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(SanctumTheme.ghostGrey)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SanctumTheme.glassMaterial)
                .cornerRadius(8)
            } else {
                ForEach(alerts) { alert in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: alert.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(alert.color)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text(alert.message)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(SanctumTheme.ghostGrey)
                        }
                        
                        Spacer()
                        
                        Text(alert.formattedTime)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(SanctumTheme.ghostGrey.opacity(0.5))
                    }
                    .padding(12)
                    .background(SanctumTheme.glassMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(alert.color.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        isLoading = true
        Task {
            // Load metrics from validation results
            let decisions = ArgusLedger.shared.loadRecentDecisions(limit: 100)
            
            // Calculate metrics
            let matured = decisions.filter { $0.outcome == .matured }
            let wins = matured.filter { ($0.actualPnl ?? 0) > 0 }
            let hitRate = matured.isEmpty ? 0.5 : Double(wins.count) / Double(matured.count)
            
            let pnls = matured.compactMap { $0.actualPnl }
            let profits = pnls.filter { $0 > 0 }.reduce(0, +)
            let losses = abs(pnls.filter { $0 < 0 }.reduce(0, +))
            let profitFactor = losses > 0 ? profits / losses : 2.0
            
            // Simple Sharpe approximation (dummy calculation for UI demo if no proper history)
            let avgPnl = pnls.isEmpty ? 0 : pnls.reduce(0, +) / Double(pnls.count)
            let variance = pnls.isEmpty ? 1 : pnls.map { pow($0 - avgPnl, 2) }.reduce(0, +) / Double(pnls.count)
            let stdDev = sqrt(variance)
            let sharpe = stdDev > 0 ? avgPnl / stdDev : 0
            
            // Max Drawdown (simplified)
            var maxDD = 0.0
            var peak = 0.0
            var equity = 0.0
            for pnl in pnls {
                equity += pnl
                if equity > peak { peak = equity }
                let dd = peak > 0 ? (peak - equity) / peak * 100 : 0
                if dd > maxDD { maxDD = dd }
            }
            
            // Distribution
            let buyCount = decisions.filter { $0.action.contains("BİRİKTİR") || $0.action.contains("HÜCUM") }.count
            let sellCount = decisions.filter { $0.action.contains("AZALT") || $0.action.contains("ÇIK") }.count
            let holdCount = decisions.count - buyCount - sellCount
            
            let total = max(1, Double(decisions.count))
            let buyPct = Double(buyCount) / total * 100
            let sellPct = Double(sellCount) / total * 100
            let holdPct = Double(holdCount) / total * 100
            
            let isDrifting = buyPct > 70 || sellPct > 70 || holdPct > 80
            let driftReason = buyPct > 70 ? "EXCESS BUY" : (sellPct > 70 ? "EXCESS SELL" : (holdPct > 80 ? "EXCESS HOLD" : ""))
            
            await MainActor.run {
                self.metrics = PerformanceMetrics(
                    sharpe: sharpe,
                    hitRate: hitRate,
                    profitFactor: profitFactor,
                    maxDrawdown: maxDD
                )
                
                self.distribution = PredictionDistribution(
                    buyPercent: buyPct,
                    holdPercent: holdPct,
                    sellPercent: sellPct,
                    isDrifting: isDrifting,
                    driftReason: driftReason
                )
                
                self.alerts = []
                self.isLoading = false
            }
        }
    }
}

// MARK: - Holo Metric Card
struct HoloMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 14))
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(SanctumTheme.ghostGrey)
        }
        .padding()
        .background(SanctumTheme.glassMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Supporting Models

struct PerformanceMetrics {
    let sharpe: Double
    let hitRate: Double
    let profitFactor: Double
    let maxDrawdown: Double
    
    static var empty: PerformanceMetrics {
        PerformanceMetrics(sharpe: 0, hitRate: 0, profitFactor: 0, maxDrawdown: 0)
    }
}

struct PredictionDistribution {
    let buyPercent: Double
    let holdPercent: Double
    let sellPercent: Double
    let isDrifting: Bool
    let driftReason: String
    
    static var empty: PredictionDistribution {
        PredictionDistribution(buyPercent: 33, holdPercent: 34, sellPercent: 33, isDrifting: false, driftReason: "")
    }
}

struct DataQualityAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    
    enum AlertSeverity {
        case warning, error, info
    }
    
    var icon: String {
        switch severity {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
    
    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Preview
#Preview {
    ObservatoryHealthView()
}
