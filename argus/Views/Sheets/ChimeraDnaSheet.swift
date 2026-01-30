import SwiftUI

// MARK: - Chimera DNA Sheet
struct ChimeraDnaSheet: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.dismiss) var dismiss
    
    private var chimeraResult: ChimeraFusionResult {
        let orion = viewModel.orionScores[symbol]
        let hermesInsight = viewModel.newsInsightsBySymbol[symbol]?.first
        let hermesImpact = hermesInsight?.impactScore ?? 50.0
        let fundScore = viewModel.getFundamentalScore(for: symbol)?.totalScore
        let price = viewModel.quotes[symbol]?.currentPrice ?? 0.0
        let regime = ChironRegimeEngine.shared.globalResult.regime
        
        return ChimeraSynergyEngine.shared.fuse(
            symbol: symbol,
            orion: orion,
            hermesImpactScore: hermesImpact,
            titanScore: fundScore,
            currentPrice: price,
            marketRegime: regime
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0F172A").ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("CHIMERA DNA")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(.cyan)
                        
                        Text(symbol)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("Piyasa Rejimi: \(chimeraResult.regimeContext)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // Radar Chart
                    ChimeraRadarView(dna: chimeraResult.dna)
                        .frame(height: 250)
                        .padding(.horizontal)
                    
                    // Score & Driver
                    HStack(spacing: 40) {
                        VStack(spacing: 4) {
                            Text("SKOR")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(String(format: "%.0f", chimeraResult.finalScore))
                                .font(.system(size: 32, weight: .black, design: .monospaced))
                                .foregroundColor(scoreColor)
                        }
                        
                        VStack(spacing: 4) {
                            Text("SÜRÜCÜ")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(chimeraResult.primaryDriver)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Signals
                    if !chimeraResult.signals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AKILLI SİNYALLER")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ForEach(chimeraResult.signals) { signal in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(signal.severity > 0.7 ? Color.red : Color.orange)
                                        .frame(width: 10, height: 10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(signal.title)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        
                                        Text(signal.description)
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                .padding()
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        Text("Şu an aktif sinyal yok")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private var scoreColor: Color {
        if chimeraResult.finalScore >= 70 { return .green }
        if chimeraResult.finalScore >= 50 { return .yellow }
        return .red
    }
}
