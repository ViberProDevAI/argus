import SwiftUI

struct ModuleSummaryCard: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    
    // Callbacks for Sheet Navigation
    var onAtlasTap: (() -> Void)?
    var onOrionTap: (() -> Void)?
    var onAetherTap: (() -> Void)?
    var onHermesTap: (() -> Void)?
    var onDemeterTap: (() -> Void)?
    var onAthenaTap: (() -> Void)? // Added Athena
    var onChironTap: (() -> Void)? // Added Chiron
    var onPhoenixTap: (() -> Void)? // Added Phoenix
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SİSTEM ANALİZİ")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                Spacer()
            }
            
            VStack(spacing: 0) {
                if let decision = viewModel.argusDecisions[symbol] {
                    // Atlas (Fundamental)
                    CompactModuleRow(
                        name: "Atlas",
                        score: decision.atlasScore,
                        tag: atlasTag(decision.atlasScore),
                        mode: .atlas
                    )
                    .onTapGesture { onAtlasTap?() }
                    
                    Divider().padding(.leading, 56)
                    
                    // Orion (Technical)
                    CompactModuleRow(
                        name: "Orion",
                        score: decision.orionScore,
                        tag: orionTag(decision.orionScore),
                        mode: .orion
                    )
                    .onTapGesture { onOrionTap?() }
                    
                    Divider().padding(.leading, 56)
                    
                    // Phoenix (AI Scenario) - ALWAYS VISIBLE
                    CompactModuleRow(
                        name: "Phoenix",
                        score: decision.phoenixAdvice?.confidence ?? 0,
                        tag: phoenixTag(decision.phoenixAdvice),
                        mode: .phoenix
                    )
                    .onTapGesture { onPhoenixTap?() }
                    
                    Divider().padding(.leading, 56)
                    
                    // Aether (Macro)
                    CompactModuleRow(
                        name: "Aether",
                        score: decision.aetherScore,
                        tag: aetherTag(decision.aetherScore),
                        mode: .aether
                    )
                    .onTapGesture { onAetherTap?() }
                    
                    Divider().padding(.leading, 56)
                    
                    // Hermes (Sentiment)
                    CompactModuleRow(
                        name: "Hermes",
                        score: decision.hermesScore,
                        tag: hermesTag(decision.hermesScore),
                        mode: .hermes
                    )
                    .onTapGesture { onHermesTap?() }
                    
                    Divider().padding(.leading, 56)
                    
                    // Athena (Smart Beta)
                    CompactModuleRow(
                        name: "Athena",
                        score: decision.athenaScore,
                        tag: "Faktör Uyumu", // Or logic based on score
                        mode: .athena
                    )
                    .onTapGesture { onAthenaTap?() }
                    
                    Divider().padding(.leading, 56)
                    
                    // Chiron (Risk)
                    if let chiron = decision.chironResult {
                         CompactModuleRow(
                            name: "Chiron",
                            score: 100, 
                            tag: chiron.regime.descriptor,
                            mode: .demeter, // Using Demeter mode for Chiron visualization (or Generic)
                            hideScore: true
                        )
                        .onTapGesture { onChironTap?() }
                    } else {
                        CompactModuleRow(
                            name: "Chiron",
                            score: 62, 
                            tag: "Risk Dengeli",
                            mode: .demeter,
                            isRawDecimal: true
                        )
                        .onTapGesture { onChironTap?() }
                    }
                } else {
                    Text("Sistem analizi bekleniyor...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                }
                
                // Demeter (Sector) separator if needed
                if viewModel.argusDecisions[symbol] != nil && viewModel.getDemeterScore(for: symbol) != nil {
                     Divider().padding(.leading, 56)
                }
                
                // Demeter (Sector)
                if let demeter = viewModel.getDemeterScore(for: symbol) {
                    CompactModuleRow(
                        name: "Demeter",
                        score: demeter.totalScore,
                        tag: demeterTag(demeter.totalScore),
                        mode: .demeter // Correct mapping
                    )
                    .onTapGesture { onDemeterTap?() }
                }
            }
            .background(Theme.secondaryBackground)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }
    
    // Tag Logic helpers
    func atlasTag(_ score: Double) -> String {
        return score > 70 ? "Sağlam" : (score > 40 ? "Makul" : "Zayıf")
    }
    func orionTag(_ score: Double) -> String {
        return score > 60 ? "Trend Korunuyor" : (score > 40 ? "Yön Belirsiz" : "Trend Zayıf")
    }
    func aetherTag(_ score: Double) -> String {
        return score > 60 ? "Pozitif Rejim" : "Nötr Rejim"
    }
    func hermesTag(_ score: Double) -> String {
        return score > 60 ? "Olumlu Akış" : "Sessiz"
    }
    func demeterTag(_ score: Double) -> String {
        return score > 50 ? "Sektör Güçlü" : "Sektör Baskısı"
    }
    func phoenixTag(_ advice: PhoenixAdvice?) -> String {
        guard let ph = advice else { return "Veri Bekleniyor" }
        return ph.status == .active ? "Sinyal Aktif" : "Beklemede"
    }
}

struct CompactModuleRow: View {
    let name: String
    let score: Double
    let tag: String
    let mode: ArgusMode
    var isRawDecimal: Bool = false
    var hideScore: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Animated Argus Eye Icon
            ArgusEyeView(mode: mode, size: 32)
                .frame(width: 32, height: 32)
            
            // Name
            Text(name)
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textPrimary)
                .frame(width: 60, alignment: .leading)
            
            // Score + Tag
            HStack(spacing: 6) {
                if !hideScore {
                    if isRawDecimal {
                        Text(String(format: "%.2f", score / 100.0))
                            .font(.custom("Menlo", size: 12))
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        Text("\(Int(score))")
                            .font(.custom("Menlo", size: 12))
                            .bold()
                            .foregroundColor(scoreColor(score))
                    }
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(tag)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle()) // Hit testing
    }
    
    func scoreColor(_ s: Double) -> Color {
        s > 60 ? .green : (s > 40 ? .orange : .red)
    }
}
