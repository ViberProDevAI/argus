import SwiftUI

struct SirkiyeDashboardView: View {
    @ObservedObject var viewModel: TradingViewModel
    @State private var rotateOrbit = false
    @State private var showDetails = false
    @State private var xu100Value: Double = 0
    @State private var xu100Change: Double = 0
    @State private var fallbackMacroScore: Double = 50
    @State private var fallbackMacroReady = false
    
    // Gerçek veriyi ViewModel'den al
    var atmosphere: (score: Double, mode: MarketMode, reason: String) {
        if let decision = viewModel.bistAtmosphere {
            let score = decision.netSupport * 100.0
            let reason = decision.winningProposal?.reasoning ?? "Analiz tamamlandı"
            return (score, decision.marketMode, reason)
        } else {
            return (fallbackMacroScore, modeFrom(score: fallbackMacroScore), "TCMB makro snapshot")
        }
    }
    
    var statusIndicator: (color: Color, text: String) {
        if viewModel.bistAtmosphere != nil {
            return (InstitutionalTheme.Colors.positive, "Canlı Veri")
        } else if fallbackMacroReady {
            return (InstitutionalTheme.Colors.primary, "Makro Canlı")
        } else {
            return (InstitutionalTheme.Colors.warning, "Güncelleniyor...")
        }
    }
    
    var xu100DisplayValue: String {
        if xu100Value > 0 {
            return String(format: "%.0f", xu100Value)
        }
        return "---"
    }
    
    var xu100ChangeText: String {
        if xu100Value > 0 {
            let sign = xu100Change >= 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", xu100Change))%"
        }
        return ""
    }
    
    var xu100ChangeColor: Color {
        return xu100Change >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative
    }
    
    var body: some View {
        Button(action: { showDetails = true }) {
            HStack(spacing: 0) {
                // Left: Cortex Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(atmosphere.score / 100.0))
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: modeColors), center: .center),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    // Skor göstergesi
                    Text("\(Int(atmosphere.score))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                }
                .padding(.leading, 16)
                .padding(.vertical, 16)
                
                // Center: Text Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("SİRKİYE KORTEKS")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text(modeDisplayText)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle().fill(statusIndicator.color).frame(width: 6, height: 6)
                        Text(statusIndicator.text)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 12)
                
                Spacer()
                
                // Right: XU100 Endeks Değeri (Gerçek Veri)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("BIST 100")
                        .font(.caption2).bold().foregroundColor(.secondary)
                    
                    Text(xu100DisplayValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if !xu100ChangeText.isEmpty {
                        Text(xu100ChangeText)
                            .font(.caption2).bold()
                            .foregroundColor(xu100ChangeColor)
                    }
                }
                .padding(.trailing, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
            )
            .padding(.horizontal, 16)
        }
        .onAppear { 
            rotateOrbit = true
            // İlk yüklemede atmosferi ve XU100'ü güncelle
            Task {
                if viewModel.bistAtmosphere == nil {
                    await viewModel.refreshBistAtmosphere()
                }
                await loadFallbackMacroScore()
                await loadXU100()
            }
        }
        .sheet(isPresented: $showDetails) {
            NavigationStack {
                SirkiyeAetherView(linkedDecision: viewModel.bistAtmosphere)
            }
        }
    }
    
    // MARK: - XU100 Loader
    private func loadXU100() async {
        do {
            let quote = try await BorsaPyProvider.shared.getXU100()
            await MainActor.run {
                xu100Value = quote.last
                xu100Change = quote.changePercent
            }
        } catch {
            print("⚠️ XU100 yüklenemedi: \(error)")
        }
    }

    private func loadFallbackMacroScore() async {
        let macro = await SirkiyeAetherEngine.shared.analyze(forceRefresh: true)
        await MainActor.run {
            fallbackMacroScore = max(0, min(100, macro.overallScore))
            fallbackMacroReady = true
        }
    }
    
    // MARK: - Helper Properties
    
    private var modeColors: [Color] {
        switch atmosphere.mode {
        case .panic: return [InstitutionalTheme.Colors.negative, InstitutionalTheme.Colors.warning]
        case .extremeFear: return [InstitutionalTheme.Colors.negative, InstitutionalTheme.Colors.textSecondary]
        case .fear: return [InstitutionalTheme.Colors.warning, InstitutionalTheme.Colors.textSecondary]
        case .neutral: return [InstitutionalTheme.Colors.primary, InstitutionalTheme.Colors.textSecondary]
        case .greed: return [InstitutionalTheme.Colors.positive, InstitutionalTheme.Colors.primary]
        case .extremeGreed: return [InstitutionalTheme.Colors.positive, InstitutionalTheme.Colors.warning]
        case .complacency: return [InstitutionalTheme.Colors.textSecondary, InstitutionalTheme.Colors.textTertiary]
        }
    }
    
    private var scoreColor: Color {
        if atmosphere.score >= 70 { return InstitutionalTheme.Colors.positive }
        else if atmosphere.score >= 50 { return InstitutionalTheme.Colors.primary }
        else if atmosphere.score >= 30 { return InstitutionalTheme.Colors.warning }
        else { return InstitutionalTheme.Colors.negative }
    }
    
    private var modeDisplayText: String {
        switch atmosphere.mode {
        case .panic: return "PANİK MOD"
        case .extremeFear: return "AŞIRI KORKU"
        case .fear: return "KORKU MOD"
        case .neutral: return "NÖTR ATMOSFER"
        case .greed: return "AÇGÖZLÜ MOD"
        case .extremeGreed: return "AŞIRI AÇGÖZLÜLÜK"
        case .complacency: return "REHAVET"
        }
    }

    private func modeFrom(score: Double) -> MarketMode {
        switch score {
        case ..<25: return .panic
        case ..<40: return .extremeFear
        case ..<50: return .fear
        case ..<60: return .neutral
        case ..<75: return .greed
        case ..<90: return .extremeGreed
        default: return .complacency
        }
    }
    
    private var stanceText: String {
        guard let decision = viewModel.bistAtmosphere else { return "BEKLENİYOR" }
        switch decision.stance {
        case .riskOff: return "RİSK KAPALI"
        case .defensive: return "DEFANSİF"
        case .cautious: return "TEDBİRLİ"
        case .riskOn: return "RİSK AÇIK"
        }
    }
    
    private var stanceColor: Color {
        guard let decision = viewModel.bistAtmosphere else { return .gray }
        switch decision.stance {
        case .riskOff: return .red
        case .defensive: return .orange
        case .cautious: return .yellow
        case .riskOn: return .green
        }
    }
}

// Custom Badge Helper
extension View {
    func paddingbadge(_ color: Color) -> some View {
        self.padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}
