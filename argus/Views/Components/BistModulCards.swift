import SwiftUI

// MARK: - HEIMDALL ENLIGHTENMENT CARDS
// "Project Enlightenment": Data-First, Educational, Insightful

// ═══════════════════════════════════════════════════════════════════
// MARK: - SHARED: INSIGHT ROW
// ═══════════════════════════════════════════════════════════════════

struct MetricInsightRow: View {
    let metric: AnalysisMetric
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.snappy) { isExpanded.toggle() } }) {
                HStack {
                    // Label & Context
                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(metric.context)
                            .font(.caption2)
                            .foregroundColor(impactColor)
                    }
                    
                    Spacer()
                    
                    // Value
                    Text(metric.value)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(metric.scoreImpact > 0 ? InstitutionalTheme.Colors.positive : (metric.scoreImpact < 0 ? InstitutionalTheme.Colors.negative : InstitutionalTheme.Colors.textPrimary))
                    
                    // Expand Icon
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle()) // Make full row tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.primary.opacity(0.85))
                        .offset(y: 2)
                    
                    Text(metric.education)
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(InstitutionalTheme.Colors.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
        }
    }

    private var impactColor: Color {
        if metric.scoreImpact > 0 { return InstitutionalTheme.Colors.positive }
        if metric.scoreImpact < 0 { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.textSecondary
    }
}


// ═══════════════════════════════════════════════════════════════════
// MARK: - 1. BIST FAKTOR CARD (DATA & EDUCATION)
// ═══════════════════════════════════════════════════════════════════

struct BistFaktorCard: View {
    let symbol: String
    @State private var result: BistFaktorResult?
    @State private var isLoading = true
    @State private var showDetails = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Total Score
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TEMEL ANALİZ & FAKTÖRLER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text(symbol)
                        .font(.title3)
                        .bold()
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                if let r = result {
                    HStack(spacing: 4) {
                        Text("\(Int(r.totalScore))")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(scoreColor(r.totalScore))
                            .monospacedDigit()
                        Text("/100")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .offset(y: 6)
                    }
                } else if isLoading {
                    ProgressView()
                        .tint(InstitutionalTheme.Colors.primary)
                } else {
                    Text("VERİ YOK")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(InstitutionalTheme.Colors.warning)
                }
            }
            .padding(16)
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
            
            // Factor Summary Grid (Interactive)
            if let r = result {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(r.factors) { factor in
                        FactorSummaryCell(factor: factor)
                    }
                }
                .padding(16)
                
                // Detailed Metrics List
                VStack(alignment: .leading, spacing: 12) {
                    Text("DETAYLI ANALİZ RAPORU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        .padding(.top, 8)
                    
                    ForEach(r.factors) { factor in
                        if !factor.metrics.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(factor.name.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(factorColor(factor.color).opacity(0.8))
                                    .padding(.bottom, 4)
                                
                                ForEach(factor.metrics) { metric in
                                    MetricInsightRow(metric: metric)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else if !isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Faktör analizi şu an yüklenemedi.")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    if let errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
        .background(InstitutionalTheme.Colors.surface1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: InstitutionalTheme.Colors.background.opacity(0.35), radius: 8, x: 0, y: 4)
        .onAppear { loadData() }
    }
    
    private func loadData() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }

            do {
                // 1. Oracle verilerini cache katmanından al
                let oracleSignals = await OracleEngine.shared.getLatestSignals()

                // 2. Faktör Analizi (Oracle Sinyalleri ile)
                let data = try await BistFaktorEngine.shared.analyze(symbol: symbol, oracleSignals: oracleSignals)
                await MainActor.run {
                    self.result = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.result = nil
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return InstitutionalTheme.Colors.positive }
        if score >= 50 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
    
    private func factorColor(_ name: String) -> Color {
        switch name {
        case "blue": return InstitutionalTheme.Colors.primary
        case "green": return InstitutionalTheme.Colors.positive
        case "purple": return InstitutionalTheme.Colors.primary
        case "yellow": return InstitutionalTheme.Colors.warning
        case "orange": return InstitutionalTheme.Colors.warning
        case "red": return InstitutionalTheme.Colors.negative
        case "mint": return InstitutionalTheme.Colors.positive
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
}

struct FactorSummaryCell: View {
    let factor: BistFaktor
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: factor.icon)
                .font(.system(size: 14))
                .foregroundColor(factorColor(factor.color))
            
            Text(factor.name.components(separatedBy: " ").first ?? "")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            Text("\(Int(factor.score))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                .monospacedDigit()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    func factorColor(_ name: String) -> Color {
        switch name {
        case "blue": return InstitutionalTheme.Colors.primary
        case "green": return InstitutionalTheme.Colors.positive
        case "purple": return InstitutionalTheme.Colors.primary
        case "yellow": return InstitutionalTheme.Colors.warning
        case "orange": return InstitutionalTheme.Colors.warning
        case "red": return InstitutionalTheme.Colors.negative
        case "mint": return InstitutionalTheme.Colors.positive
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 2. BIST SEKTOR CARD (CONTEXTUAL ROTATION)
// ═══════════════════════════════════════════════════════════════════

struct BistSektorCard: View {
    @State private var result: BistSektorResult?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEKTÖR ROTASYONU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    if let r = result {
                        Text(r.rotation.rawValue)
                            .font(.headline)
                            .bold()
                            .foregroundColor(rotationColor(r.rotation))
                    } else {
                        Text("Yükleniyor...")
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
            }
            .padding(16)
            
            Divider().background(Color.white.opacity(0.1))
            
            if let r = result {
                // Top Sectors (Visual)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(r.sectors.prefix(5)) { sector in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: sector.icon)
                                        .font(.caption)
                                    Text(sector.name)
                                        .font(.caption)
                                        .bold()
                                }
                                .foregroundColor(.white)
                                
                                Text("\(sector.dailyChange >= 0 ? "+" : "")\(String(format: "%.1f", sector.dailyChange))%")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(sector.dailyChange >= 0 ? .green : .red)
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Educational Insights
                VStack(alignment: .leading, spacing: 0) {
                    Text("NEDEN BU HAREKET VAR?")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                    
                    ForEach(r.rotationMetrics) { metric in
                        MetricInsightRow(metric: metric)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "08080A"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear { loadData() }
    }
    
    private func loadData() {
        Task {
            if let data = try? await BistSektorEngine.shared.analyze() {
                await MainActor.run { self.result = data }
            }
        }
    }
    
    private func rotationColor(_ rotation: SektorRotasyon) -> Color {
        switch rotation {
        case .riskOn, .buyume: return .green
        case .teknoloji: return .cyan
        case .defansif: return .yellow
        case .riskOff, .belirsiz: return .red
        case .karisik: return .orange
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 3. BIST MONEY FLOW CARD (DEEP DIVE)
// ═══════════════════════════════════════════════════════════════════

struct BistMoneyFlowCard: View {
    let symbol: String
    @State private var result: BistMoneyFlowResult?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PARA AKIŞI & HACİM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    if let r = result {
                        Text(r.flowStatus.rawValue)
                            .font(.headline)
                            .bold()
                            .foregroundColor(flowColor(r.flowStatus))
                    } else {
                        Text("Analiz ediliyor...")
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundColor(.blue)
            }
            .padding(16)
            
            Divider().background(Color.white.opacity(0.1))
            
            if let r = result {
                // Visual Flow Meter
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.red.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                    
                    Circle()
                        .fill(flowColor(r.flowStatus))
                        .frame(width: 12, height: 12)
                        .shadow(color: flowColor(r.flowStatus), radius: 5)
                    
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
                
                // Deep Dive Metrics
                VStack(alignment: .leading, spacing: 0) {
                    Text("AKILLI PARA ANALİZİ")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                    
                    ForEach(r.metrics) { metric in
                        MetricInsightRow(metric: metric)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(hex: "08080A"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear { loadData() }
    }
    
    private func loadData() {
        Task {
            if let data = try? await BistMoneyFlowEngine.shared.analyze(symbol: symbol) {
                await MainActor.run { self.result = data }
            }
        }
    }
    
    private func flowColor(_ status: FlowStatus) -> Color {
        switch status {
        case .strongInflow, .inflow: return .green
        case .neutral: return .yellow
        case .outflow, .strongOutflow: return .red
        }
    }
}

// BistRejimCard: Kaldırıldı — REJİM modülü artık BistMacroSummaryCard + SirkiyeDashboard + Oracle + Sektör kullanıyor

// Helper
extension Double {
    // Already exists in project likely, can add format helper if needed
}
