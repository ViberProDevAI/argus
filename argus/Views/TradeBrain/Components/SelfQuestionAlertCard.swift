import SwiftUI

struct SelfQuestionAlertCard: View {
    let analysis: ContradictionAnalysis
    
    private var severityColor: Color {
        switch analysis.severity {
        case .high: return InstitutionalTheme.Colors.negative
        case .medium: return InstitutionalTheme.Colors.warning
        case .low: return InstitutionalTheme.Colors.neutral
        }
    }
    
    private var severityIcon: String {
        switch analysis.severity {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "info.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: severityIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(severityColor)
                
                Text("Modul Celiskisi")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(analysis.severity.rawValue)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(severityColor.opacity(0.2))
                    )
            }
            
            if analysis.hasContradictions {
                ForEach(analysis.contradictions.prefix(2)) { contradiction in
                    ContradictionRow(contradiction: contradiction)
                }
                
                if let outcome = analysis.historicalOutcome {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text(outcome.summary)
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                            .fill(InstitutionalTheme.Colors.surface3.opacity(0.5))
                    )
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Onerilen Guven Dususu")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        Text("%\(Int(analysis.suggestedConfidenceDrop * 100))")
                            .font(InstitutionalTheme.Typography.caption)
                            .foregroundColor(severityColor)
                    }
                    
                    Spacer()
                    
                    Text(analysis.recommendation)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(InstitutionalTheme.Colors.positive)
                    Text(analysis.recommendation)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding(InstitutionalCardScale.standard.padding)
        .institutionalCard(scale: .standard, elevated: true)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.md, style: .continuous)
                .stroke(analysis.hasContradictions ? severityColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct ContradictionRow: View {
    let contradiction: Contradiction
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(contradiction.module1)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(contradiction.stance1)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.positive)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface3.opacity(0.5))
            )
            
            Text("vs")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
            
            VStack(spacing: 2) {
                Text(contradiction.module2)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Text(contradiction.stance2)
                    .font(InstitutionalTheme.Typography.caption)
                    .foregroundColor(InstitutionalTheme.Colors.negative)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.sm, style: .continuous)
                    .fill(InstitutionalTheme.Colors.surface3.opacity(0.5))
            )
        }
        
        Text(contradiction.description)
            .font(InstitutionalTheme.Typography.caption)
            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            .padding(.top, 4)
    }
}

#Preview {
    VStack(spacing: 16) {
        SelfQuestionAlertCard(
            analysis: ContradictionAnalysis(
                contradictions: [
                    Contradiction(
                        module1: "Orion",
                        stance1: "AL",
                        module2: "Aether",
                        stance2: "Risk Off",
                        description: "Teknik alim sinyali ama makro risk off"
                    )
                ],
                severity: .medium,
                historicalOutcome: ContradictionOutcome(
                    module1: "Orion",
                    module2: "Aether",
                    winRate: 0.35,
                    avgPnL: -2.5,
                    sampleSize: 23
                ),
                suggestedConfidenceDrop: 0.15,
                recommendation: "Gecmis veriler bu celiskide yuksek kayip riski gosteriyor"
            )
        )
        
        SelfQuestionAlertCard(
            analysis: ContradictionAnalysis(
                contradictions: [],
                severity: .low,
                historicalOutcome: nil,
                suggestedConfidenceDrop: 0,
                recommendation: "Celiski tespit edilmedi"
            )
        )
    }
    .padding()
    .background(InstitutionalTheme.Colors.background)
}
