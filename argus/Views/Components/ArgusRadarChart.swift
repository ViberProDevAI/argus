import SwiftUI

/// Argus Radar Chart - Referans görsele yakın, temiz tasarım
struct ArgusRadarChart: View {
    // MARK: - Data
    let scores: RadarScores
    let chironWeights: ChironWeightsData?
    
    // MARK: - Callbacks
    var onModuleTap: ((RadarModule) -> Void)?
    
    // MARK: - State
    @State private var animationProgress: Double = 0
    
    // MARK: - Constants
    // Sıralama: Orion sağ üstte, saat yönünde
    private let modules: [RadarModule] = [.atlas, .aether, .phoenix, .hermes, .orion]
    private let gridLevels = 4
    private let chartSize: CGFloat = 160  // Küçültüldü
    
    var body: some View {
        VStack(spacing: 8) {
            // Title
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text("ARGUS RADAR")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .foregroundColor(.orange)
            }
            
            // Radar Chart with labels integrated
            ZStack {
                // Background Grid
                RadarGridShape(sides: modules.count, levels: gridLevels)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                
                // Score Polygon (main)
                RadarPolygonShape(
                    values: modules.map { (scores.score(for: $0) / 100.0) * animationProgress },
                    sides: modules.count
                )
                .fill(Color.orange.opacity(0.2))
                
                RadarPolygonShape(
                    values: modules.map { (scores.score(for: $0) / 100.0) * animationProgress },
                    sides: modules.count
                )
                .stroke(Color.orange, lineWidth: 2)
                
                // Corner dots
                ForEach(Array(modules.enumerated()), id: \.offset) { index, module in
                    let normalizedScore = scores.score(for: module) / 100.0
                    let angle = angleFor(index: index)
                    let radius = (chartSize / 2) * normalizedScore * animationProgress
                    
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .offset(
                            x: cos(angle - .pi / 2) * radius,
                            y: sin(angle - .pi / 2) * radius
                        )
                }
                
                // Center: Average Score
                VStack(spacing: 0) {
                    Text("\(Int(averageScore))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(averageScore))
                }
                
                // Module Labels - positioned outside chart
                ForEach(Array(modules.enumerated()), id: \.offset) { index, module in
                    ModuleLabelSimple(
                        module: module,
                        score: scores.score(for: module),
                        angle: angleFor(index: index),
                        radius: chartSize / 2 + 35,
                        onTap: { onModuleTap?(module) }
                    )
                }
            }
            .frame(width: chartSize + 100, height: chartSize + 90)
        }
        .padding(.top, 10)
        .padding(.bottom, 16)  // Alt boşluk artırıldı
        .padding(.horizontal, 8)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - Helpers
    
    private var averageScore: Double {
        let total = modules.reduce(0.0) { $0 + scores.score(for: $1) }
        return total / Double(modules.count)
    }
    
    private func angleFor(index: Int) -> Double {
        let anglePerModule = (2 * .pi) / Double(modules.count)
        return anglePerModule * Double(index)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Simple Module Label

private struct ModuleLabelSimple: View {
    let module: RadarModule
    let score: Double
    let angle: Double
    let radius: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: module.icon)
                    .font(.system(size: 12))
                    .foregroundColor(module.color)
                
                Text(module.shortName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("\(Int(score))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(scoreColor)
            }
        }
        .buttonStyle(.plain)
        .offset(
            x: cos(angle - .pi / 2) * radius,
            y: sin(angle - .pi / 2) * radius
        )
    }
    
    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Radar Grid Shape

struct RadarGridShape: Shape {
    let sides: Int
    let levels: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        
        // Draw concentric polygons
        for level in 1...levels {
            let radius = maxRadius * CGFloat(level) / CGFloat(levels)
            addPolygon(to: &path, center: center, radius: radius, sides: sides)
        }
        
        // Draw radial lines
        for i in 0..<sides {
            let angle = (2 * .pi * CGFloat(i) / CGFloat(sides)) - .pi / 2
            path.move(to: center)
            path.addLine(to: CGPoint(
                x: center.x + cos(angle) * maxRadius,
                y: center.y + sin(angle) * maxRadius
            ))
        }
        
        return path
    }
    
    private func addPolygon(to path: inout Path, center: CGPoint, radius: CGFloat, sides: Int) {
        for i in 0...sides {
            let angle = (2 * .pi * CGFloat(i) / CGFloat(sides)) - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
    }
}

// MARK: - Radar Polygon Shape

struct RadarPolygonShape: Shape {
    var values: [Double]
    let sides: Int
    
    var animatableData: [Double] {
        get { values }
        set { values = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = min(rect.width, rect.height) / 2
        
        guard values.count == sides else { return path }
        
        for (i, value) in values.enumerated() {
            let angle = (2 * .pi * CGFloat(i) / CGFloat(sides)) - .pi / 2
            let radius = maxRadius * CGFloat(max(0.08, min(1.0, value)))
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Data Models

enum RadarModule: String, CaseIterable {
    case orion = "Orion"
    case atlas = "Atlas"
    case aether = "Aether"
    case athena = "Athena"
    case phoenix = "Phoenix"
    case hermes = "Hermes"
    case demeter = "Demeter"
    
    var shortName: String {
        switch self {
        case .orion: return "ORN"
        case .atlas: return "ATL"
        case .aether: return "AET"
        case .athena: return "ATH"
        case .phoenix: return "PHX"
        case .hermes: return "HRM"
        case .demeter: return "DMT"
        }
    }
    
    var icon: String {
        switch self {
        case .orion: return "telescope.fill"
        case .atlas: return "chart.bar.fill"
        case .aether: return "globe.americas.fill"
        case .athena: return "brain.head.profile"
        case .phoenix: return "flame.fill"
        case .hermes: return "newspaper.fill"
        case .demeter: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .orion: return .purple
        case .atlas: return .blue
        case .aether: return .cyan
        case .athena: return .pink
        case .phoenix: return .orange
        case .hermes: return .green
        case .demeter: return .brown
        }
    }
}

struct RadarScores {
    var orion: Double = 50
    var atlas: Double = 50
    var aether: Double = 50
    var athena: Double = 50
    var phoenix: Double = 50
    var hermes: Double = 50
    var demeter: Double = 50
    
    func score(for module: RadarModule) -> Double {
        switch module {
        case .orion: return orion
        case .atlas: return atlas
        case .aether: return aether
        case .athena: return athena
        case .phoenix: return phoenix
        case .hermes: return hermes
        case .demeter: return demeter
        }
    }
    
    func normalizedValues(for modules: [RadarModule]) -> [Double] {
        modules.map { score(for: $0) / 100.0 }
    }
}

struct ChironWeightsData {
    var orion: Double = 0.15
    var atlas: Double = 0.20
    var aether: Double = 0.15
    var athena: Double = 0.10
    var phoenix: Double = 0.10
    var hermes: Double = 0.10
    var demeter: Double = 0.10
    
    func weight(for module: RadarModule) -> Double {
        switch module {
        case .orion: return orion
        case .atlas: return atlas
        case .aether: return aether
        case .athena: return athena
        case .phoenix: return phoenix
        case .hermes: return hermes
        case .demeter: return demeter
        }
    }
    
    static func from(_ weights: ModuleWeights) -> ChironWeightsData {
        ChironWeightsData(
            orion: weights.orion,
            atlas: weights.atlas,
            aether: weights.aether,
            athena: weights.athena ?? 0.1,
            phoenix: weights.phoenix ?? 0.1,
            hermes: weights.hermes ?? 0.1,
            demeter: weights.demeter ?? 0.1
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ArgusRadarChart(
            scores: RadarScores(
                orion: 88,
                atlas: 71,
                aether: 52,
                athena: 66,
                phoenix: 45,
                hermes: 85,
                demeter: 50
            ),
            chironWeights: nil,
            onModuleTap: { module in
                print("Tapped: \(module.rawValue)")
            }
        )
    }
}
