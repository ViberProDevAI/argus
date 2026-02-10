import SwiftUI

// MARK: - Enums
enum ArgusModule: String, CaseIterable {
    case atlas = "Atlas"
    case orion = "Orion"
    case aether = "Aether"
    case demeter = "Demeter"
    case hermes = "Hermes"
    
    /// Custom neon asset icon
    var assetIcon: String? {
        switch self {
        case .orion: return "OrionIcon"
        case .atlas: return "AtlasIcon"
        case .aether: return "AetherIcon"
        case .hermes: return "HermesIcon"
        case .demeter: return "DemeterIcon"
        default: return nil
        }
    }

    /// SF Symbol fallback icon
    var icon: String {
        switch self {
        case .atlas: return "building.columns.fill"
        case .orion: return "chart.xyaxis.line"
        case .aether: return "cloud.sun.fill"
        case .demeter: return "leaf.fill"
        case .hermes: return "newspaper.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .atlas: return .blue
        case .orion: return .purple
        case .aether: return .orange
        case .demeter: return .green
        case .hermes: return .pink
        }
    }
}

// MARK: - ArgusModule Icon View Helper
extension ArgusModule {
    @ViewBuilder
    func iconView(size: CGFloat = 20) -> some View {
        if let asset = assetIcon {
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: icon)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Enums Extension
extension ArgusModule {
    var toArgusVisualMode: ArgusMode {
        switch self {
        case .atlas: return .atlas
        case .orion: return .orion
        case .aether: return .aether
        case .demeter: return .demeter
        case .hermes: return .hermes
        }
    }
}

struct ArgusSolarCardView: View {
    let decision: ArgusDecisionResult
    let explanation: ArgusExplanation?
    let isLoading: Bool
    var showScoreInCenter: Bool = true // Default true for detailed view
    
    @State private var argusMode: ArgusTimeframeMode = .core
    @State private var selectedModule: ArgusModule? = nil // Nil means "Overview"
    
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            solarSystemView
                .frame(height: 240)
                .padding(.vertical, 10)
            
            Divider().background(Color.gray.opacity(0.3))
            
            infoView
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
        }
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Subcomponents
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                // Use Mini animated eye in header too? Maybe static for performance, sticking to SF Symbol in header is cleaner.
                Image(systemName: "eye.fill")
                    .foregroundColor(.cyan)
                Text("ARGUS KARARI")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Mode Toggle
            HStack(spacing: 0) {
                ForEach(ArgusTimeframeMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.spring()) {
                            argusMode = mode
                            selectedModule = nil // Reset to overview when mode changes
                        }
                    }) {
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(argusMode == mode ? Color.cyan.opacity(0.3) : Color.clear)
                            .foregroundColor(argusMode == mode ? .cyan : .gray)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
    
    private var solarSystemView: some View {
        ZStack {
            // Orbit Path
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                .frame(width: 200, height: 200)
            
            // Center (Argus - The Brain)
            ZStack {
                // Use the Animated Eye View - ELLIPTICAL MODE
                // User requested "more elliptical"
                ArgusEyeView(mode: .argus, size: 70, isElliptical: true)
                    .shadow(color: .cyan.opacity(0.6), radius: 15)
                
                // Score Text (Only visible if Overview is active AND showScoreInCenter is true)
                if selectedModule == nil && showScoreInCenter {
                    VStack(spacing: 0) {
                        Text("\(Int(currentScore))")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                            .offset(y: 45) // Push below eye
                    }
                }
            }
            .onTapGesture {
                withAnimation { selectedModule = nil }
            }
            
            // Orbiting Planets
            ForEach(0..<ArgusModule.allCases.count, id: \.self) { index in
                let module = ArgusModule.allCases[index]
                PlanetView(module: module, score: getScore(for: module), isSelected: selectedModule == module)
                    .modifier(PlanetOrbitModifier(index: index, total: ArgusModule.allCases.count, rotation: rotation))
                    .onTapGesture {
                        withAnimation { selectedModule = module }
                    }
            }
            .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    struct PlanetOrbitModifier: ViewModifier {
        let index: Int
        let total: Int
        let rotation: Double
        
        func body(content: Content) -> some View {
            let angle = (Double(index) / Double(total)) * 2 * .pi
            return content
                .offset(x: 100 * cos(angle), y: 100 * sin(angle))
                .rotationEffect(.degrees(-rotation))
        }
    }
    
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let module = selectedModule {
                // Module Specific Text
                HStack {
                    // Custom neon icon or SF Symbol fallback
                    module.iconView(size: 20)
                        .foregroundColor(module.color)
                    Text(module.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(getScore(for: module)))/100")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Text(getModuleDescription(module))
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
            } else {
                // Overview (Core vs Pulse)
                HStack(spacing: 12) {
                    Text(currentAction.rawValue) // AL/SAT
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(actionColor)
                    
                    Text(currentGrade) // A+
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(actionColor.opacity(0.2))
                        .cornerRadius(6)
                        .foregroundColor(actionColor)
                    
                    Spacer()
                }
                
                // AI Explanation (Title + Summary)
                if let exp = explanation {
                    Text(exp.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(exp.summary)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                } else if isLoading {
                    HStack {
                        ProgressView().scaleEffect(0.5)
                        Text("Yapay zeka analiz ediyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    var currentScore: Double {
        argusMode == .core ? decision.finalScoreCore : decision.finalScorePulse
    }
    
    var currentGrade: String {
        argusMode == .core ? decision.letterGradeCore : decision.letterGradePulse
    }
    
    var currentAction: SignalAction {
        argusMode == .core ? decision.finalActionCore : decision.finalActionPulse
    }
    
    var actionColor: Color {
        switch currentAction {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .yellow
        case .wait: return .gray
        case .skip: return .gray
        }
    }
    
    func getScore(for module: ArgusModule) -> Double {
        switch module {
        case .atlas: return decision.atlasScore
        case .orion: return decision.orionScore
        case .aether: return decision.aetherScore
        case .demeter: return decision.demeterScore ?? 0
        case .hermes: return decision.hermesScore
        }
    }
    
    func getModuleDescription(_ module: ArgusModule) -> String {
        switch module {
        case .atlas: return "Temel Analiz (Atlas): Bilanço, karlılık ve borç yapısının puanı."
        case .orion: return "Teknik Analiz (Orion): Trend, momentum ve volatilite göstergeleri."
        case .aether: return "Makro Rejim (Aether): Piyasanın genel risk iştahı ve hava durumu."
        case .demeter: return "Sektör Analizi (Demeter): Sektörel güç ve göreceli performans."
        case .hermes: return "Haber Akışı (Hermes): Güncel haberlerin yatırımcı algısına etkisi."
        }
    }
}

// MARK: - Subviews
struct PlanetView: View {
    let module: ArgusModule
    let score: Double
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Animated Eye View for Planet
            ArgusEyeView(mode: module.toArgusVisualMode, size: isSelected ? 48 : 36)
                .shadow(color: isSelected ? module.color.opacity(0.8) : .clear, radius: 10)
            
            // Score Badge (only if selected)
            if isSelected {
                Text("\(Int(score))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .offset(y: 30)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}
