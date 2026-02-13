import SwiftUI

struct ConfidenceBar: View {
    let rawConfidence: Double
    let calibratedConfidence: Double
    let showLabel: Bool
    
    init(
        rawConfidence: Double,
        calibratedConfidence: Double,
        showLabel: Bool = true
    ) {
        self.rawConfidence = rawConfidence
        self.calibratedConfidence = calibratedConfidence
        self.showLabel = showLabel
    }
    
    private var adjustment: Double {
        calibratedConfidence - rawConfidence
    }
    
    private var adjustmentColor: Color {
        if adjustment > 0.05 {
            return InstitutionalTheme.Colors.positive
        } else if adjustment < -0.05 {
            return InstitutionalTheme.Colors.negative
        }
        return InstitutionalTheme.Colors.neutral
    }
    
    private var statusText: String {
        if abs(adjustment) < 0.05 {
            return "Dogru"
        } else if adjustment > 0 {
            return "Dusuk tahmin"
        } else {
            return "Yuksek tahmin"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showLabel {
                HStack {
                    Text("Guven Kalibrasyonu")
                        .font(InstitutionalTheme.Typography.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(statusText)
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(adjustmentColor)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                    
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(InstitutionalTheme.Colors.primary.opacity(0.4))
                        .frame(width: geo.size.width * rawConfidence)
                    
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(adjustmentColor)
                        .frame(width: geo.size.width * calibratedConfidence)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("Ham: %\(Int(rawConfidence * 100))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                Spacer()
                Text("Kalibre: %\(Int(calibratedConfidence * 100))")
                    .font(InstitutionalTheme.Typography.micro)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
    }
}

struct ConfidenceBucketView: View {
    let bucket: ConfidenceBucket
    
    private var expectedWinRate: Double {
        (bucket.range.lowerBound + bucket.range.upperBound) / 2
    }
    
    private var deviation: Double {
        bucket.winRate - expectedWinRate
    }
    
    private var statusColor: Color {
        if bucket.totalDecisions < 10 {
            return InstitutionalTheme.Colors.textTertiary
        }
        if deviation > 0.05 {
            return InstitutionalTheme.Colors.positive
        } else if deviation < -0.05 {
            return InstitutionalTheme.Colors.negative
        }
        return InstitutionalTheme.Colors.neutral
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Text(bucket.displayRange)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .frame(width: 60, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(InstitutionalTheme.Colors.surface3)
                    
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(statusColor)
                        .frame(width: geo.size.width * bucket.winRate)
                }
            }
            .frame(height: 6)
            
            Text("%\(Int(bucket.winRate * 100))")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(statusColor)
                .frame(width: 40, alignment: .trailing)
            
            Text("(\(bucket.totalDecisions))")
                .font(InstitutionalTheme.Typography.micro)
                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct CalibrationSummaryCard: View {
    let stats: CalibrationStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Text("Guven Kalibrasyon Ozeti")
                    .font(InstitutionalTheme.Typography.bodyStrong)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toplam Karar")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("\(stats.totalDecisions)")
                        .font(InstitutionalTheme.Typography.headline)
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Basari Orani")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("%\(Int(stats.overallWinRate * 100))")
                        .font(InstitutionalTheme.Typography.headline)
                        .foregroundColor(stats.overallWinRate > 0.5 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ort. PnL")
                        .font(InstitutionalTheme.Typography.micro)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    Text("%\(String(format: "%.1f", stats.avgPnL))")
                        .font(InstitutionalTheme.Typography.headline)
                        .foregroundColor(stats.avgPnL >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                }
            }
            
            Text(stats.summary)
                .font(InstitutionalTheme.Typography.caption)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .padding(InstitutionalCardScale.insight.padding)
        .institutionalCard(scale: .insight)
    }
}

#Preview {
    VStack(spacing: 20) {
        ConfidenceBar(rawConfidence: 0.75, calibratedConfidence: 0.62)
        ConfidenceBar(rawConfidence: 0.45, calibratedConfidence: 0.52)
    }
    .padding()
    .background(InstitutionalTheme.Colors.background)
}
