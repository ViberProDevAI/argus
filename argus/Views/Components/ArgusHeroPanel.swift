import SwiftUI


struct ArgusHeroPanel: View {
    let symbol: String
    let quote: Quote?
    let decision: ArgusDecisionResult?
    let explanation: ArgusExplanation?
    let isLoading: Bool
    let viewModel: TradingViewModel? // Injected for real data
    
    // Alt sistem skorlarını güvenli bir şekilde çekmek için
    var atlasScore: Double { decision?.atlasScore ?? 0 }
    var hermesScore: Double { decision?.hermesScore ?? 0 }
    var orionScore: Double { decision?.orionScore ?? 0 }
    var aetherScore: Double { decision?.aetherScore ?? 0 }
    var demeterScore: Double { decision?.demeterScore ?? 0 }
    var athenaScore: Double { decision?.athenaScore ?? 0 }
    
    var finalScore: Double { decision?.finalScoreCore ?? 0 }
    
    // Sheet States
    @State private var showOrionDetail = false
    @State private var showAetherDetail = false
    @State private var showAtlasDetail = false
    @State private var showHermesDetail = false
    @State private var showAthenaDetail = false
    @State private var showChironDetail = false
    @State private var showArgusDetail = false
    
    var body: some View {
        VStack(spacing: 24) {
            // MARK: - 1. Merkezi Skor Göstergesi (Gauge)
            ZStack {
                // Arka Plan Çemberi
                Circle()
                    .stroke(Theme.border, lineWidth: 8)
                    .frame(width: 180, height: 180)
                
                // İlerleme Çemberi
                Circle()
                    .trim(from: 0, to: CGFloat(finalScore) / 100.0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                ArgusScoreSystem.color(for: finalScore).opacity(0.8),
                                ArgusScoreSystem.color(for: finalScore)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.5), value: finalScore)
                
                // Merkez Metin
                VStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        Text(String(format: "%.1f", finalScore / 10.0))
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                            .foregroundColor(ArgusScoreSystem.color(for: finalScore))
                            .shadow(color: ArgusScoreSystem.color(for: finalScore).opacity(0.5), radius: 10)
                        
                        Text("/ 10")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text("ARGUS SKOR")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                        .padding(.top, 4)
                }
            } // End ZStack
            .padding(.top, 10)
            .onTapGesture {
                showArgusDetail = true
            }
            
            // MARK: - Chiron Strip (New)
            if let chiron = decision?.chironResult {
                Button(action: { showChironDetail = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.tint)
                        
                        Text(chiron.regime.descriptor)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(chiron.explanationTitle)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.tint.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showChironDetail) {
                    ChironDetailView()
                }
            }
            VStack(spacing: 8) {
                HStack {
                    Text(ArgusScoreSystem.label(for: finalScore))
                        .font(.title3)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f/10", finalScore / 10.0))
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.cardBackground)
                            .frame(height: 10)
                        
                        Capsule()
                            .fill(ArgusScoreSystem.color(for: finalScore))
                            .frame(width: geo.size.width * CGFloat(finalScore) / 100.0, height: 10)
                            .animation(.spring(), value: finalScore)
                    }
                }
                .frame(height: 10)
            } // End VStack
            .padding(.horizontal)
            // MARK: - Action Module (Apply Signal)
            if let d = decision, let vm = viewModel, let q = quote {
                let action = d.finalActionCore
                
                // Only show if Action is decisive (BUY/SELL)
                if action == .buy || action == .sell {
                    Button(action: {
                        if action == .buy {
                            // Logic: Allocating a fixed standard lot (e.g. $1000) or 5% of Buying Power
                            // For simplicity and safety in manual click: Buy $1000 worth
                            let targetAmount = 1000.0
                            let price = q.currentPrice
                            if price > 0 {
                                let qty = targetAmount / price
                                vm.buy(symbol: symbol, quantity: qty, source: .user, rationale: "Argus Sinyali ile Alım")
                            }
                        } else {
                            // Sell Logic: Close entire position
                            vm.closeAllPositions(for: symbol)
                        }
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }) {
                        HStack {
                            Image(systemName: action == .buy ? "bolt.fill" : "xmark.circle.fill")
                            Text(action == .buy ? "Sinyali Uygula: 1000$ AL" : "Sinyali Uygula: SAT")
                                .font(.headline)
                                .bold()
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(action == .buy ? Theme.positive : Theme.negative)
                        .cornerRadius(12)
                        .shadow(color: (action == .buy ? Theme.positive : Theme.negative).opacity(0.4), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                }
            }
        } // End Main VStack
        .padding(.vertical, 20)
        .background(Theme.background)
        // New Argus Score Sheet (Only one remaining here)
        .sheet(isPresented: $showArgusDetail) {
            ArgusDetailSheet(
                decision: decision,
                explanation: explanation,
                symbol: symbol,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Argus Detail Sheet
struct ArgusDetailSheet: View {
    let decision: ArgusDecisionResult?
    let explanation: ArgusExplanation?
    let symbol: String
    let viewModel: TradingViewModel?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Decision Card
                        if let decision = decision {
                            ArgusDecisionCardView(
                                decision: decision,
                                explanation: explanation,
                                isLoading: false
                            )
                        } else {
                            Text("Karar verisi bulunamadı.")
                                .foregroundColor(.gray)
                        }
                        
                        // 2. Module Breakdown
                        if let vm = viewModel {
                            VStack(alignment: .leading) {
                                Text("SKOR BİLEŞENLERİ")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.leading)
                                
                                ModuleSummaryCard(symbol: symbol, viewModel: vm)
                            }
                        }
                        
                        // 3. Info
                        VStack(spacing: 12) {
                            Image(systemName: "brain.head.profile.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.tint)
                                .opacity(0.3)
                            
                            Text("Argus Karar Motoru v2.1")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Argus, 6 farklı analiz motorunun (Atlas, Orion, Aether, Hermes, Chiron, Athena) ortak aklını temsil eder. Nihai karar, bu motorların ağırlıklı ortalaması ve risk bariyerleri (Chiron) ile şekillenir.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 30)
                    }
                    .padding()
                }
            }
            .navigationTitle("Argus Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - System Score Card Component
struct SystemScoreCard: View {
    let name: String
    let score: Double
    let mode: ArgusMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    ArgusEyeView(mode: mode, size: 40)
                        .frame(width: 40, height: 40)
                        .background(mode.color.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(String(format: "%.1f/10", score / 10.0))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            
            // Forensic Overlay (Only if Score is 0 or Missing)
            if score == 0 {
                Divider().background(Color.white.opacity(0.1))
                DebugTracePanel(engine: engineForMode(mode))
            }
        }
        .background(Theme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.border.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func engineForMode(_ mode: ArgusMode) -> EngineTag {
        switch mode {
        case .atlas: return .atlas
        case .aether: return .aether
        case .hermes: return .hermes
        case .orion: return .orion
        case .demeter: return .demeter
        case .athena: return .athena
        case .poseidon: return .poseidon
        case .phoenix: return .phoenix
        case .scout: return .scout
        case .council: return .heimdall // Council maps to Core System
        case .argus: return .heimdall // Main System
        case .offline: return .heimdall // System Offline/Idle
        }
    }
}
