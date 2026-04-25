import SwiftUI

struct TitanAnalysisCard: View {
    let result: ArgusEtfEngine.TitanResult
    
    var ringColor: Color {
        let score = result.score
        if score >= 70 { return InstitutionalTheme.Colors.positive }
        if score <= 30 { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.warning
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Titan Analizi ⚡️")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Spacer()
                Text(result.log.date, style: .date)
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: result.score / 100.0)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(result.score))")
                            .font(InstitutionalTheme.Typography.title)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text("Puan")
                            .font(InstitutionalTheme.Typography.micro)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 8) {
                    ContextRow(icon: "chart.line.uptrend.xyaxis", title: "Trend:", value: result.log.technicalContext, color: InstitutionalTheme.Colors.textPrimary)
                    ContextRow(icon: "globe", title: "Makro:", value: result.log.macroContext, color: InstitutionalTheme.Colors.textPrimary)
                    ContextRow(icon: "shazam.logo", title: "Kalite:", value: result.log.qualityContext, color: InstitutionalTheme.Colors.textSecondary)
                }
            }
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
        .overlay(
            RoundedRectangle(cornerRadius: InstitutionalTheme.Radius.lg)
                .stroke(ringColor.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ContextRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.primary)
                .frame(width: 16)
            
            Text(title)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .bold()
                .foregroundColor(color)
        }
    }
}

struct FundProfileCard: View {
    let profile: ETFProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fon Profili ")
                .font(InstitutionalTheme.Typography.bodyStrong)
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            
            if let p = profile {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ProfileItem(label: "Sektör", value: p.sector ?? "-")
                    ProfileItem(label: "Yönetim Ücreti", value: p.expenseRatio != nil ? String(format: "%.2f%%", p.expenseRatio!) : "N/A")
                    ProfileItem(label: "Bölge", value: p.domicile ?? "Global")
                    ProfileItem(label: "Varlık Tipi", value: "ETF")
                }
                
                if !p.description.isEmpty {
                    Text(p.description)
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(3)
                        .padding(.top, 8)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .institutionalCard(scale: .insight, elevated: false)
    }
}

struct ProfileItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(InstitutionalTheme.Typography.caption)
                .bold()
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
        }
    }
}
