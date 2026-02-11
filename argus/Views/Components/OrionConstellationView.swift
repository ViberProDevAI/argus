import SwiftUI

// MARK: - PROCESSOR MODELS

enum ProcessorNodeType: String {
    case trend = "TREND"
    case momentum = "MOMENTUM"
    case volume = "HACİM"
    case consensus = "KONSENSÜS" // New Integrated Node
    case price = "FİYAT" // The Result
}

enum OrionCircuitStatus {
    case active     // Green/Flowing
    case resistance // Red/Blocked
    case neutral    // Grey/Idle
}

struct ProcessorNode: Identifiable {
    let id = UUID()
    let type: ProcessorNodeType
    var position: CGPoint
    let status: OrionCircuitStatus
    let value: String
    let details: String
}

// MARK: - ORION PROCESSOR VIEW (Logic Circuit)

struct OrionConstellationView: View {
    let orion: OrionScoreResult
    let candles: [Candle]
    
    // Animation States
    @State private var flowPhase: Double = 0
    @State private var selectedNode: ProcessorNode? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            
            // 1. THE CIRCUIT BOARD (CANVAS)
            ZStack {
                // Dark Tech Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                Canvas { context, size in
                    // --- 1. DEFINE POSITIONS (Left to Right Flow) ---
                    // Inputs (Left column)
                    let inputX = size.width * 0.2
                    let trendPos = CGPoint(x: inputX, y: size.height * 0.25)
                    let momPos = CGPoint(x: inputX, y: size.height * 0.5)
                    let volPos = CGPoint(x: inputX, y: size.height * 0.75)
                    
                    // Processing (Center) - The Consensus Engine
                    let corePos = CGPoint(x: size.width * 0.55, y: size.height * 0.5)
                    
                    // Output (Right) - Price/Verdict
                    let outputPos = CGPoint(x: size.width * 0.85, y: size.height * 0.5)
                    
                    let nodes = [
                        createNode(type: .trend, pos: trendPos),
                        createNode(type: .momentum, pos: momPos),
                        createNode(type: .volume, pos: volPos),
                        createNode(type: .consensus, pos: corePos),
                        createNode(type: .price, pos: outputPos)
                    ]
                    
                    // --- 2. DRAW CIRCUIT TRACES (WIRES) ---
                    // From Inputs to Core
                    drawCircuit(context: context, from: trendPos, to: corePos, status: checkTrendStatus())
                    drawCircuit(context: context, from: momPos, to: corePos, status: checkMomentumStatus())
                    drawCircuit(context: context, from: volPos, to: corePos, status: checkVolumeStatus())
                    
                    // From Core to Output
                    drawCircuit(context: context, from: corePos, to: outputPos, status: checkConsensusStatus(), width: 4)
                    
                    // --- 3. DRAW NODES ---
                    for node in nodes {
                        drawNode(context: context, node: node)
                    }
                    
                }
                .frame(height: 280)
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { value in
                        handleTap(at: value.location, size: CGSize(width: UIScreen.main.bounds.width - 32, height: 280))
                    }
                )
            }
            .frame(height: 280)
            .padding(.horizontal)
            
            // 2. INTERACTIVE INFO PANEL (The "Terminal Console")
            if let selected = selectedNode {
                ProcessorInfoPanel(node: selected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Detay görmek için devre bileşenlerine dokunun.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                flowPhase = 1.0
            }
        }
    }
    
    // MARK: - DRAWING LOGIC
    
    private func drawCircuit(context: GraphicsContext, from: CGPoint, to: CGPoint, status: OrionCircuitStatus, width: CGFloat = 2) {
        var path = Path()
        path.move(to: from)
        
        // Circuit style routing (Right-angle turns)
        let midX = (from.x + to.x) / 2
        path.addLine(to: CGPoint(x: midX, y: from.y))
        path.addLine(to: CGPoint(x: midX, y: to.y))
        path.addLine(to: to)
        
        // Color
        let color: Color
        switch status {
        case .active: color = .green
        case .resistance: color = .red
        case .neutral: color = .gray
        }
        
        // Glow Effect
        context.stroke(path, with: .color(color.opacity(0.5)), lineWidth: width + 4)
        context.stroke(path, with: .color(color), lineWidth: width)
        
        // Data Flow Animation (Packet)
        if status != .neutral {
            // Sample points along path for animation is complex in Canvas without Path interpolation helper.
            // Simplified: Just flash the line opacity or dash phase
            // For true packet animation, we need a parametric path function.
            // visual hack: draw a small circle at lerped position between midpoints
            // Keeping it simple: Dashed animated line
            if status == .active {
                 context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 1, dash: [4, 4], dashPhase: flowPhase * 20))
            }
        }
    }
    
    private func drawNode(context: GraphicsContext, node: ProcessorNode) {
        let size: CGFloat = node.type == .consensus ? 60 : 45
        let rect = CGRect(x: node.position.x - size/2, y: node.position.y - size/2, width: size, height: size)
        
        // Node Status Color
        let color: Color
        switch node.status {
        case .active: color = .green
        case .resistance: color = .red
        case .neutral: color = .gray
        }
        
        // Fill
        context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Color(red: 0.1, green: 0.1, blue: 0.15)))
        context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(color), lineWidth: 2)
        
        // Label inside
        var text = Text(node.type.rawValue.prefix(1)).font(.system(size: 14, weight: .bold)).foregroundColor(color)
        if node.type == .consensus {
            text = Text(node.value).font(.system(size: 12, weight: .black)).foregroundColor(.white)
        }
        
        context.draw(text, at: node.position, anchor: .center)
        
        // Label below
        let label = Text(node.type.rawValue)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.gray)
        context.draw(label, at: CGPoint(x: node.position.x, y: node.position.y + size/2 + 8), anchor: .center)
    }
    
    // MARK: - DATA MAPPING
    
    private func createNode(type: ProcessorNodeType, pos: CGPoint) -> ProcessorNode {
        let status: OrionCircuitStatus
        let val: String
        let det: String
        
        switch type {
        case .trend:
            status = checkTrendStatus()
            val = String(format: "%.1f", orion.components.trend)
            det = status == .active ? "Trend Yükselişte: Fiyat ortalamaların üzerinde güvenle ilerliyor." : "Trend Zayıf: Yön belirsiz veya düşüş eğilimi var."
        case .momentum:
            status = checkMomentumStatus()
            val = String(format: "%.0f", orion.components.momentum)
            det = status == .active ? "Momentum Güçlü: Alıcılar istekli, hareket arkasında rüzgar var." : "Momentum Düşük: Yükseliş olsa bile 'yakıtsız' kalabilir (Uyumsuzluk)."
        case .volume:
            status = checkVolumeStatus()
            val = "Vol"
            det = "Hacim Dengeli: Fiyat hareketlerini destekleyen makul bir işlem hacmi var."
        case .consensus: // The Central Brain
            status = checkConsensusStatus()
            val = "\(Int(orion.score))"
            det = "Teknik Konsensüs: Tüm sensörlerden gelen veriler işlendi. Genel kanı: \(orion.score > 50 ? "POZİTİF" : "NEGATİF")."
        case .price:
            status = .neutral
            val = String(format: "%.2f", candles.last?.close ?? 0)
            det = "Son Fiyat İşlemi."
        }
        
        return ProcessorNode(type: type, position: pos, status: status, value: val, details: det)
    }
    
    // Status Logic
    func checkTrendStatus() -> OrionCircuitStatus { orion.components.trend > 15 ? .active : .neutral }
    func checkMomentumStatus() -> OrionCircuitStatus { orion.components.momentum > 50 ? .active : .resistance }
    func checkVolumeStatus() -> OrionCircuitStatus { .active } // Mock
    func checkConsensusStatus() -> OrionCircuitStatus { orion.score > 60 ? .active : (orion.score < 40 ? .resistance : .neutral) }
    
    // MARK: - INTERACTION
    
    private func handleTap(at location: CGPoint, size: CGSize) {
        // Simple hit test based on known layout regions
        let w = size.width
        let h = size.height
        
        // Re-create simple zones logic
        if location.x < w * 0.35 {
            if location.y < h * 0.35 { selectedNode = createNode(type: .trend, pos: .zero) }
            else if location.y < h * 0.65 { selectedNode = createNode(type: .momentum, pos: .zero) }
            else { selectedNode = createNode(type: .volume, pos: .zero) }
        } else if location.x > w * 0.45 && location.x < w * 0.65 {
            selectedNode = createNode(type: .consensus, pos: .zero)
        } else if location.x > w * 0.75 {
            selectedNode = createNode(type: .price, pos: .zero)
        }
    }
}

// MARK: - INFO PANEL

struct ProcessorInfoPanel: View {
    let node: ProcessorNode
    
    var color: Color {
        switch node.status {
        case .active: return .green
        case .resistance: return .red
        case .neutral: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 40, height: 40)
                Image(systemName: getIcon(for: node.type))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(node.type.rawValue)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(node.details)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }
    
    func getIcon(for type: ProcessorNodeType) -> String {
        switch type {
        case .trend: return "chart.line.uptrend.xyaxis"
        case .momentum: return "speedometer"
        case .volume: return "barometer"
        case .consensus: return "cpu"
        case .price: return "banknote"
        }
    }
}
