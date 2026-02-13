import SwiftUI

struct SectionMetricChip: View {
    let label: String
    let metric: AtlasMetric
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Divider()
                .frame(height: 12)
                .overlay(InstitutionalTheme.Colors.borderSubtle)
            VStack(alignment: .leading, spacing: 1) {
                Text(metric.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
                Text(metric.formattedValue)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.26), lineWidth: 1)
        )
    }
}

