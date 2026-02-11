import SwiftUI

// MARK: - REUSABLE HOLO SHEET (The "Jilet Gibi" Animation)
struct ModuleHoloSheet: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    let onClose: () -> Void
    
    // State for async data loading
    @State private var chironPulseWeights: ChironModuleWeights?
    @State private var chironCorseWeights: ChironModuleWeights?
    
    var body: some View {
        VStack(spacing: 0) {
            // Holo Header
            HStack {
                Image(systemName: module.icon)
                    .foregroundColor(module.color)
                    .font(.title3)
                Text(module.rawValue)
                    .font(.headline)
                    .bold()
                    .tracking(2)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding()
            .background(
                LinearGradient(colors: [module.color.opacity(0.2), .black], startPoint: .top, endPoint: .bottom)
            )
            
            Divider().background(module.color)
            
            // Holo Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(module.description)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    // DYNAMIC CONTENT BASED ON MODULE
                    // (Note: Using the logic previously embedded in Sanctum)
                    SanctumContentLogic(module: module, viewModel: viewModel, symbol: symbol)
                }
                .padding(.vertical)
            }
        }
        .task {
            // Data pre-fetching if needed
            if module == .atlas {
                if viewModel.getFundamentalScore(for: symbol) == nil {
                    await viewModel.calculateFundamentalScore(for: symbol, assetType: .stock)
                }
            } else if module == .orion {
                if viewModel.orionScores[symbol] == nil {
                    // Trigger Orion 2.0 MTF Analysis
                    await viewModel.ensureOrionAnalysis(for: symbol)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Material.ultraThinMaterial)
        .background(Color.black.opacity(0.8))
        .edgesIgnoringSafeArea(.bottom)
    }
}

// Helper struct to render content, extracted from Sanctum logic
private struct SanctumContentLogic: View {
    let module: ArgusSanctumView.ModuleType
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        Group {
            switch module {
            case .atlas:
                // 🆕 BIST vs Global kontrolü (.IS suffix veya bilinen BIST sembolü)
                if symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol) {
                    // BIST sembolü için .IS suffix ekle (gerekirse)
                    let bistSymbol = symbol.uppercased().hasSuffix(".IS") ? symbol : "\(symbol.uppercased()).IS"
                    BISTBilancoDetailView(sembol: bistSymbol)
                } else {
                    AtlasV2DetailView(symbol: symbol)
                }
            case .orion:
                OrionContent(viewModel: viewModel, symbol: symbol)
            default:
                VStack {
                    Text("Bu modülün detay görünümü hazırlanıyor...")
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
    }
}

// Extracted Content Views
private struct AtlasContent: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        if let result = viewModel.getFundamentalScore(for: symbol) {
            let score = Int(result.totalScore)
            VStack(alignment: .leading, spacing: 12) {
                // Score Header
                HStack {
                    Text("Temel Puan")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(score)")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(score > 60 ? .green : (score > 40 ? .yellow : .red))
                }
                .padding(.horizontal)
                
                Divider().background(Color.white.opacity(0.1))
                
                // Highlights
                if !result.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(result.highlights.prefix(4), id: \.self) { highlight in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                                Text(highlight).font(.caption).foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Breakdown Chart
                VStack(spacing: 8) {
                    breakdownRow("Karlılık", score: result.profitabilityScore ?? 0, max: 25)
                    breakdownRow("Büyüme", score: result.growthScore ?? 0, max: 25)
                    breakdownRow("Kaldıraç", score: result.leverageScore ?? 0, max: 25)
                    breakdownRow("Nakit", score: result.cashQualityScore ?? 0, max: 25)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        } else {
            ProgressView().padding()
        }
    }
    
    func breakdownRow(_ title: String, score: Double, max: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundColor(.gray)
                Spacer()
                Text("\(Int(score))/\(Int(max))").font(.caption).bold().foregroundColor(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.3))
                    Capsule().fill(Color.yellow)
                        .frame(width: geo.size.width * (score / max))
                }
            }
            .frame(height: 4)
        }
    }
}

private struct OrionContent: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    
    var body: some View {
        if let orion = viewModel.orionScores[symbol] {
            VStack(alignment: .leading, spacing: 16) {
                // Score Gauge
                HStack {
                    Text("Teknik Puan")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        Circle().trim(from: 0, to: orion.score / 100)
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(orion.score))")
                            .font(.title2).bold().foregroundColor(.white)
                    }
                    .frame(width: 60, height: 60)
                }
                .padding(.horizontal)
                
                // Components
                VStack(spacing: 12) {
                    componentRow("Yapı (Structure)", val: orion.components.structure, max: 35, color: .cyan)
                    componentRow("Trend", val: orion.components.trend, max: 25, color: .green)
                    componentRow("Momentum", val: orion.components.momentum, max: 25, color: .orange)
                    componentRow("Pattern", val: orion.components.pattern, max: 15, color: .purple)
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
        } else {
            ProgressView().padding()
        }
    }
    
    func componentRow(_ title: String, val: Double, max: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.1f", val)).font(.caption).bold().foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * (val / max))
                }
            }
            .frame(height: 4)
        }
    }
}
