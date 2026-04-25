import SwiftUI

struct SanctumSignalCapsule: View {
    let signal: ArgusGrandDecision?
    let dataHealth: DataHealth?
    
    private var education: CouncilEducationStage? {
        signal?.educationStage
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Data Quality Orb
            HStack(spacing: 4) {
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: healthColor.opacity(0.5), radius: 4)
                
                // Quality Score is Int (0-100)
                Text("KALİTE %\(dataHealth?.qualityScore ?? 0)")
                    .font(InstitutionalTheme.Typography.dataSmall)
                    .foregroundColor(healthColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(healthColor.opacity(0.12))
            
            Divider()
                .frame(height: 16)
                .background(InstitutionalTheme.Colors.borderSubtle)
            
            // 2. Signal Action
            HStack(spacing: 4) {
                Text(education?.badgeText ?? "SEVIYE -")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(signalColor)
                
                if let title = education?.title {
                    Text(title.uppercased())
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                if let confidence = signal?.confidence {
                    Text(String(format: "%.0f", confidence * 100))
                        .font(InstitutionalTheme.Typography.dataSmall)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary.opacity(0.85))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(signalColor.opacity(0.12))
        }
        .background(
            Capsule()
                .strokeBorder(LinearGradient(colors: [healthColor.opacity(0.3), signalColor.opacity(0.3)], startPoint: .leading, endPoint: .trailing), lineWidth: 1)
                .background(InstitutionalTheme.Colors.surface1)
        )
        .clipShape(Capsule())
    }
    
    private var healthColor: Color {
        let score = dataHealth?.qualityScore ?? 0
        if score >= 80 { return SanctumTheme.auroraGreen }
        if score >= 50 { return SanctumTheme.titanGold }
        return SanctumTheme.crimsonRed
    }
    
    private var signalColor: Color {
        education?.color ?? InstitutionalTheme.Colors.textSecondary
    }
}
