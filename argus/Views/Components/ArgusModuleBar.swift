import SwiftUI

struct ArgusModuleBar: View {
    let onSelectAtlas: () -> Void
    let onSelectOrion: () -> Void
    let onSelectAether: () -> Void
    let onSelectHermes: () -> Void
    
    // Context
    let assetType: SafeAssetType // Added context
    
    // Optional Scores for badging
    let atlasScore: Double?
    let orionScore: Double?
    let aetherScore: Double?
    let hermesScore: Double?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            
            // Atlas (Fundamental)
            // Logic: Only fully active for Stocks.
            // For ETFs: Active if we have holdings data.
            // For Commodities/Crypto: Disabled/NA.
            if assetType == .stock || (assetType == .etf) {
                ModuleCard(
                    module: .atlas,
                    score: atlasScore,
                    action: onSelectAtlas,
                    isDisabled: atlasScore == nil && assetType == .etf ? false : false // Allow clicking to see "No Holdings" msg
                )
            } else {
                 // Commodities/Crypto/Indices -> Show "N/A" Card
                 DisabledModuleCard(module: .atlas, reason: "N/A")
            }
            
            ModuleCard(
                module: .orion,
                score: orionScore,
                action: onSelectOrion
            )
            
            ModuleCard(
                module: .aether,
                score: aetherScore,
                action: onSelectAether
            )
            
            ModuleCard(
                module: .hermes,
                score: hermesScore,
                action: onSelectHermes
            )
        }
    }
}

struct DisabledModuleCard: View {
    let module: ArgusModule
    let reason: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ArgusEyeView(mode: .offline, size: 24)
                    
                    Text(ArgusScoreSystem.moduleTitle(module))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.secondaryBackground.opacity(0.5))
        .cornerRadius(16)
    }
}

struct ModuleCard: View {
    let module: ArgusModule
    let score: Double?
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 0) {
                // Left: Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ArgusEyeView(mode: module.toArgusVisualMode, size: 24)
                        
                        Text(ArgusScoreSystem.moduleTitle(module))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Text(ArgusScoreSystem.moduleSubtitle(module))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Right: Score
                if let s = score {
                    ZStack {
                        Circle()
                            .stroke(ArgusScoreSystem.color(for: s).opacity(0.3), lineWidth: 2)
                            .background(Circle().fill(ArgusScoreSystem.color(for: s).opacity(0.1)))
                            .frame(width: 36, height: 36)
                        
                        Text("\(Int(s))")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(ArgusScoreSystem.color(for: s))
                    }
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(12)
            .background(Theme.secondaryBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
        }
    }
}
