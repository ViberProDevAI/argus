import SwiftUI

// MARK: - Center Core View
/// Argus Sanctum'un merkez dial/compass gorsel bileşeni.
/// Konsey kararlni ve modul secimlerini gosterir.
struct CenterCoreView: View {
    let symbol: String
    @ObservedObject var viewModel: TradingViewModel
    @Binding var showDecision: Bool
    
    // Dial Interaction State
    @State private var knobRotation: Double = 0.0
    @State private var isDragging: Bool = false
    @State private var focusedModuleName: String? = nil
    
    // Haptics
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        ZStack {
            // 1. Base Compass Ring (Static)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 220, height: 220)
                
                // Ticks (Static)
                ForEach(0..<12) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 8)
                        .offset(y: -110)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            }
            
            // 2. Interactive Dial Ring (The Knob)
            ZStack {
                // Ring
                Circle()
                    .stroke(Color(hex: "4A90E2").opacity(isDragging ? 0.8 : 0.4), style: StrokeStyle(lineWidth: isDragging ? 3 : 1, dash: []))
                    .frame(width: 180, height: 180)
                
                // The Handle / Notch
                Circle()
                    .fill(Color(hex: "4A90E2"))
                    .frame(width: 12, height: 12)
                    .offset(y: -90)
                    .shadow(color: Color(hex: "4A90E2").opacity(0.5), radius: 5)
                
                // Active Sector Indicator (Cone)
                if isDragging {
                    Path { path in
                        path.move(to: CGPoint(x: 90, y: 90))
                        path.addArc(center: CGPoint(x: 90, y: 90), radius: 90, startAngle: .degrees(-15), endAngle: .degrees(15), clockwise: false)
                    }
                    .fill(Color(hex: "4A90E2").opacity(0.1))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                }
            }
            .rotationEffect(.degrees(knobRotation))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        let vector = CGVector(dx: value.location.x - 90, dy: value.location.y - 90)
                        let angle = atan2(vector.dy, vector.dx) * 180 / .pi + 90
                        let normalizedAngle = angle < 0 ? angle + 360 : angle
                        
                        let snapInterval: Double = 45
                        let nextSnap = round(normalizedAngle / snapInterval) * snapInterval
                        
                        if abs(nextSnap - knobRotation) > 1 {
                             impactFeedback.impactOccurred(intensity: 0.5)
                        }
                        
                        self.knobRotation = normalizedAngle
                        self.focusedModuleName = determineModule(angle: normalizedAngle)
                    }
                    .onEnded { _ in
                        withAnimation {
                            isDragging = false
                            let snapInterval: Double = 45
                            self.knobRotation = round(self.knobRotation / snapInterval) * snapInterval
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            if !isDragging {
                                withAnimation {
                                    self.focusedModuleName = nil
                                }
                            }
                        }
                    }
            )
            
            // 3. Inner Data Display
            Circle()
                .fill(Color(hex: "1C1C1E").opacity(0.95))
                .frame(width: 120, height: 120)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .onTapGesture {
                    if focusedModuleName != nil {
                        withAnimation(.spring()) {
                            focusedModuleName = nil
                        }
                        impactFeedback.impactOccurred(intensity: 0.5)
                    } else {
                        showDecision = true
                        impactFeedback.impactOccurred(intensity: 0.7)
                    }
                }
            
            // LAYER 2: Text Overlays
            if let moduleName = focusedModuleName {
                moduleDetailView(moduleName: moduleName)
            } else {
                councilDecisionView
            }
        }
        .onAppear {
            showDecision = false
        }
    }
    
    // MARK: - Module Detail View
    @ViewBuilder
    private func moduleDetailView(moduleName: String) -> some View {
        VStack(spacing: 4) {
            Text(moduleName)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "4A90E2"))
            
            if let decision = viewModel.grandDecisions[symbol] {
                if let bist = decision.bistDetails {
                    viewForBistModule(moduleName: moduleName, bist: bist)
                } else {
                    viewForGlobalModule(moduleName: moduleName, decision: decision)
                }
            } else {
                Text("VERI YOK")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8).cornerRadius(8))
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Council Decision View
    private var councilDecisionView: some View {
        VStack(spacing: 4) {
            Text("KONSEY")
                .font(.system(size: 8, design: .monospaced))
                .tracking(2)
                .foregroundColor(.gray)
            
            if let decision = viewModel.grandDecisions[symbol] {
                Text(decision.action.rawValue)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        decision.action == .aggressiveBuy || decision.action == .accumulate ? .green :
                        (decision.action == .liquidate || decision.action == .trim ? .red : .yellow)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .minimumScaleFactor(0.8)
                
                Text("\(Int(decision.confidence * 100))% GUVEN")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                if !decision.vetoes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.shield")
                            .font(.system(size: 8))
                        Text(decision.vetoes.first?.module ?? "")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.top, 2)
                }
            } else {
                ProgressView().scaleEffect(0.8).tint(.white)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Module Determination
    private func determineModule(angle: Double) -> String {
        let isBist = symbol.uppercased().hasSuffix(".IS")
        
        let bistModules: [SanctumBistModuleType] = [.grafik, .bilanco, .oracle, .sirkiye, .kulis, .moneyflow]
        let globalModules: [SanctumModuleType] = [.orion, .atlas, .aether, .hermes]
        
        let sectors = isBist ? bistModules.count : globalModules.count
        let sectorAngle = 360.0 / Double(sectors)
        
        let index = Int((angle + (sectorAngle/2)).truncatingRemainder(dividingBy: 360) / sectorAngle)
        
        if isBist {
            if index < bistModules.count {
                let module = bistModules[index]
                switch module {
                case .grafik: return "ORION"
                case .bilanco: return "ATLAS"
                case .sirkiye: return "AETHER"
                case .kulis: return "HERMES"
                case .moneyflow: return "POSEIDON"
                case .oracle: return "ORACLE"
                default: return "ORION"
                }
            }
        } else {
            if index < globalModules.count {
                return globalModules[index].rawValue
            }
        }
        
        return "ORION"
    }

    // MARK: - Helper Views
    
    @ViewBuilder
    private func viewForBistModule(moduleName: String, bist: BistDecisionResult) -> some View {
        if let mod = getBistModuleResult(moduleName: moduleName, bist: bist) {
            Text(mod.action.rawValue)
                 .font(.system(size: 14, weight: .bold, design: .monospaced))
                 .foregroundColor(
                     mod.action == .buy ? .green :
                     (mod.action == .sell ? .red : .yellow)
                 )
            Text(String(format: "%.0f PUAN", mod.score))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
        } else {
            Text("--")
                .font(.system(size: 14, design: .monospaced))
        }
    }
    
    private func getBistModuleResult(moduleName: String, bist: BistDecisionResult) -> BistModuleResult? {
        switch moduleName {
        case "ORION": return bist.grafik
        case "ATLAS": return bist.bilanco
        case "AETHER": return bist.rejim
        case "HERMES": return bist.kulis
        case "ATHENA": return bist.faktor
        case "DEMETER": return bist.sektor
        case "POSEIDON": return bist.akis
        case "CHIRON": return nil
        default: return nil
        }
    }
    
    @ViewBuilder
    private func viewForGlobalModule(moduleName: String, decision: ArgusGrandDecision) -> some View {
        let data = getGlobalData(module: moduleName, decision: decision)
        
        if data.action != "--" {
            Text(data.action)
                 .font(.system(size: 14, weight: .bold, design: .monospaced))
                 .foregroundColor(data.color)
            Text(String(format: "%.0f%% GUVEN", data.confidence * 100))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
        } else {
            Text("--")
                .font(.system(size: 14, design: .monospaced))
        }
    }
    
    private func getGlobalData(module: String, decision: ArgusGrandDecision) -> (action: String, confidence: Double, color: Color) {
        if module == "ORION" {
            let col: Color = decision.orionDecision.action == .buy ? .green : (decision.orionDecision.action == .sell ? .red : .yellow)
            return (decision.orionDecision.action.rawValue, decision.orionDecision.netSupport, col)
        } else if module == "ATLAS", let atlas = decision.atlasDecision {
            let col: Color = atlas.action == .buy ? .green : (atlas.action == .sell ? .red : .yellow)
            return (atlas.action.rawValue, atlas.netSupport, col)
        } else if module == "AETHER" {
            let col: Color = decision.aetherDecision.stance == .riskOn ? .green : (decision.aetherDecision.stance == .riskOff ? .red : .yellow)
            return (decision.aetherDecision.stance.rawValue, decision.aetherDecision.netSupport, col)
        } else if module == "HERMES", let hermes = decision.hermesDecision {
             return (hermes.sentiment.rawValue, hermes.netSupport, .white)
        }
        return ("--", 0, .gray)
    }

    struct Style {
        static let dashStroke = StrokeStyle(lineWidth: 1, dash: [4, 4])
    }
}
