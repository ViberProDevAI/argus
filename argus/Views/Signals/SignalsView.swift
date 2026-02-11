import SwiftUI

struct SignalsView: View {
    @ObservedObject var viewModel: TradingViewModel
    @ObservedObject private var localization = LocalizationManager.shared // Observe
    @State private var isScanning = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Info
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(Theme.tint)
                        Text("ai_signals_header".localized())
                            .font(.headline)
                        Spacer()
                        
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            HStack(spacing: 16) {
                                // Live Tracker Journal
                                NavigationLink(destination: SignalJournalView()) {
                                    Image(systemName: "list.bullet.clipboard")
                                        .foregroundColor(Theme.tint)
                                }
                                
                                Button(action: scan) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(Theme.tint)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Macro Warning Banner
                    if let macro = viewModel.macroRating {
                        HStack(spacing: 12) {
                            Image(systemName: macro.regime == .riskOn ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .font(.title2)
                                .foregroundColor(macro.regime == .riskOn ? .green : (macro.regime == .neutral ? .yellow : .red))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ARGUS AETHER: \(macro.letterGrade) – \(macro.regime.displayName)")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text(macro.summary)
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding()
                        .background(
                            (macro.regime == .riskOn ? Theme.positive : (macro.regime == .neutral ? Theme.warning : Theme.negative))
                                .opacity(DesignTokens.Opacity.glassCard)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(macro.regime == .riskOn ? Theme.positive : (macro.regime == .neutral ? Theme.warning : Theme.negative), lineWidth: 1)
                                .padding(.horizontal)
                                .opacity(0.3)
                        )
                    }
                    
                    if viewModel.aiSignals.isEmpty {
                        SignalsEmptyStateView(action: scan, isScanning: isScanning)
                    } else {
                        // 1. GÜÇLÜ AL SİNYALLERİ (Skor > 85)
                        let strongBuySignals = viewModel.aiSignals.filter { $0.action == .buy && $0.confidenceScore >= 85 }
                        if !strongBuySignals.isEmpty {
                            SignalSection(title: "strong_buy_signals".localized(), signals: strongBuySignals, color: Theme.positive, viewModel: viewModel)
                        }
                        
                        // 2. AL SİNYALLERİ (Skor 70-85)
                        let buySignals = viewModel.aiSignals.filter { $0.action == .buy && $0.confidenceScore < 85 }
                        if !buySignals.isEmpty {
                            SignalSection(title: "buy_signals".localized(), signals: buySignals, color: .green, viewModel: viewModel)
                        }
                        
                        // 3. SAT SİNYALLERİ
                        let sellSignals = viewModel.aiSignals.filter { $0.action == .sell }
                        if !sellSignals.isEmpty {
                            SignalSection(title: "sell_signals".localized(), signals: sellSignals, color: Theme.negative, viewModel: viewModel)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("signals_title".localized())
            .background(Theme.background)
            .onAppear {
                // Eğer sinyal yoksa otomatik tara
                if viewModel.aiSignals.isEmpty {
                    scan()
                }
            }
        }
    }
    
    private func scan() {
        isScanning = true
        Task {
            // ViewModel üzerinden sinyal üretimini tetikle
            await viewModel.generateAISignals()
            isScanning = false
        }
    }
}

// MARK: - Subviews

struct SignalSection: View {
    let title: String
    let signals: [AISignal]
    let color: Color
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .bold()
                .foregroundColor(color)
                .padding(.horizontal)
            
            ForEach(signals) { signal in
                NavigationLink(destination: StockDetailView(symbol: signal.symbol, viewModel: viewModel)) {
                    AISignalCard(signal: signal, orion: viewModel.orionScores[signal.symbol])
                }
            }
        }
    }
}

struct AISignalCard: View {
    let signal: AISignal
    // Optional Orion Result (passed via environment or view model lookup in parent)
    var orion: OrionScoreResult? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // Score Circle (Orion or AI Confidence)
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .foregroundColor(displayColor.opacity(0.3))
                
                Circle()
                    .trim(from: 0, to: CGFloat(displayScore) / 100.0)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundColor(displayColor)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(displayScore))")
                        .font(.caption)
                        .bold()
                        .foregroundColor(displayColor)
                    if let o = orion {
                        Text(orionGrade(o.score))
                            .font(.system(size: 8))
                            .bold()
                            .foregroundColor(displayColor)
                    }
                }
            }
            .frame(width: 50, height: 50)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(signal.symbol)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(signal.action.rawValue)
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(displayColor.opacity(0.2))
                        .foregroundColor(displayColor)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(timeAgo(signal.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let o = orion {
                    // Orion Summary
                    HStack(spacing: 8) {
                        Text("Orion Tech: \(orionGrade(o.score))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        // Removed invalid fundamental/aether references
                    }
                } else {
                    Text(signal.strategyName)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                }
                
                Text(orion != nil ? "\(orion!.verdict): \(orion!.components.trendDesc)" : signal.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    var displayScore: Double {
        return orion?.score ?? signal.confidenceScore
    }
    
    var displayColor: Color {
        if let o = orion {
            return Theme.colorForScore(o.score)
        }
        return actionColor(signal.action)
    }
    
    func actionColor(_ action: SignalAction) -> Color {
        switch action {
        case .buy: return Theme.positive
        case .sell: return Theme.negative
        case .hold: return .gray
        case .wait: return .gray
        case .skip: return .gray
        }
    }
    
    func orionGrade(_ score: Double) -> String {
        switch score {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct SignalsEmptyStateView: View {
    let action: () -> Void
    let isScanning: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(isScanning ? "scanning".localized() : "no_signals".localized())
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isScanning ? "Stratejiler geçmiş veriler üzerinde test ediliyor.\nLütfen bekleyin." : "İzleme listendeki hisseler için güçlü bir sinyal bulunamadı.\nTekrar taramak için butona bas.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !isScanning {
                Button(action: action) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("scan_market".localized())
                    }
                    .bold()
                    .padding()
                    .background(Theme.tint)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.top, 50)
    }
}
