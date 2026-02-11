import SwiftUI

struct SanctumContributionCard: View {
    let decision: ArgusGrandDecision
    let isBist: Bool
    
    private var education: CouncilEducationStage {
        decision.educationStage
    }
    
    private var rows: [ContributionRowModel] {
        isBist ? bistRows : globalRows
    }
    
    private var maxMagnitude: Double {
        max(rows.map { abs($0.impactPoints) }.max() ?? 0, 1)
    }
    
    private var netImpact: Double {
        rows.map(\.impactPoints).reduce(0, +)
    }
    
    private var netColor: Color {
        if netImpact > 0 { return SanctumTheme.auroraGreen }
        if netImpact < 0 { return SanctumTheme.crimsonRed }
        return SanctumTheme.titanGold
    }
    
    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("KONSEY KATKI DAGILIMI")
                        .font(InstitutionalTheme.Typography.micro)
                        .tracking(1.2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(String(format: "NET %+.1f", netImpact))
                        .font(InstitutionalTheme.Typography.dataSmall)
                        .foregroundColor(netColor)
                }
                
                HStack(spacing: 8) {
                    Text(education.badgeText)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(education.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(education.color.opacity(0.14))
                        .clipShape(Capsule())
                    
                    Text(education.title.uppercased())
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    Spacer(minLength: 0)
                }
                
                Text(education.disclaimer)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                
                ForEach(rows) { row in
                    ContributionImpactRow(
                        row: row,
                        maxMagnitude: maxMagnitude
                    )
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface1.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }
    
    private var globalRows: [ContributionRowModel] {
        let weights: [String: Double] = [
            "ORION": 0.35,
            "ATLAS": 0.25,
            "AETHER": 0.20,
            "HERMES": 0.10
        ]
        
        let colors: [String: Color] = [
            "ORION": SanctumTheme.orionColor,
            "ATLAS": SanctumTheme.atlasColor,
            "AETHER": SanctumTheme.aetherColor,
            "HERMES": SanctumTheme.hermesColor
        ]
        
        let order = ["ORION", "ATLAS", "AETHER", "HERMES"]
        let byModule = Dictionary(uniqueKeysWithValues: decision.contributors.map { ($0.module.uppercased(), $0) })
        
        return order.map { module in
            let contribution = byModule[module]
            let action = contribution?.action ?? .hold
            let confidence = min(max(contribution?.confidence ?? 0, 0), 1)
            let direction = directionValue(for: action)
            let impactPoints = direction * confidence * (weights[module] ?? 0) * 100.0
            
            return ContributionRowModel(
                id: module,
                module: module,
                action: action.rawValue,
                confidence: confidence,
                impactPoints: impactPoints,
                color: colors[module] ?? InstitutionalTheme.Colors.textSecondary,
                reasoning: contribution?.reasoning ?? "Veri bekleniyor."
            )
        }
    }
    
    private var bistRows: [ContributionRowModel] {
        guard let bist = decision.bistDetails else { return [] }
        
        let modules: [(String, BistModuleResult, Color)] = [
            ("TAHTA", bist.grafik, SanctumTheme.orionColor),
            ("KASA", bist.bilanco, SanctumTheme.atlasColor),
            ("KULIS", bist.kulis, SanctumTheme.hermesColor),
            ("REJIM", bist.rejim, SanctumTheme.aetherColor)
        ]
        
        return modules.map { moduleName, result, color in
            ContributionRowModel(
                id: moduleName,
                module: moduleName,
                action: result.action.rawValue,
                confidence: min(max(abs(result.supportLevel), 0), 1),
                impactPoints: result.supportLevel * 25.0,
                color: color,
                reasoning: result.commentary
            )
        }
    }
    
    private func directionValue(for action: ProposedAction) -> Double {
        switch action {
        case .buy: return 1
        case .sell: return -1
        case .hold: return 0
        }
    }
}

private struct ContributionImpactRow: View {
    let row: ContributionRowModel
    let maxMagnitude: Double
    
    private var normalizedMagnitude: Double {
        min(abs(row.impactPoints) / maxMagnitude, 1)
    }
    
    private var impactColor: Color {
        if row.impactPoints > 0 { return SanctumTheme.auroraGreen }
        if row.impactPoints < 0 { return SanctumTheme.crimsonRed }
        return InstitutionalTheme.Colors.textSecondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(row.module)
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(row.color)
                
                Text(row.action)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(row.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(row.color.opacity(0.14))
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(String(format: "%+.1f", row.impactPoints))
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(impactColor)
            }
            
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(InstitutionalTheme.Colors.surface3)
                    Capsule()
                        .fill(impactColor.opacity(0.85))
                        .frame(width: max(proxy.size.width * normalizedMagnitude, 2))
                }
            }
            .frame(height: 6)
            
            HStack(spacing: 6) {
                Text("Guven %\(Int(row.confidence * 100))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                
                Text("|")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                
                Text(row.reasoning)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

private struct ContributionRowModel: Identifiable {
    let id: String
    let module: String
    let action: String
    let confidence: Double
    let impactPoints: Double
    let color: Color
    let reasoning: String
}
