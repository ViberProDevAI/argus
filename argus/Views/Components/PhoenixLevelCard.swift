import SwiftUI

struct PhoenixLevelCard: View {
    let advice: PhoenixAdvice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("PHOENIX SEVİYELERİ")
                    .font(.caption)
                    .bold()
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                
                // Timeframe Badge
                Text(advice.timeframe.localizedName)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.tint.opacity(0.1))
                    .cornerRadius(4)
                    .foregroundColor(Theme.tint)
            }
            
            if advice.status == .active {
                contentView
            } else {
                errorView
            }
        }
        .padding(16)
        .background(Theme.cardBackground)
        .cornerRadius(16)
    }
    
    private var contentView: some View {
        VStack(spacing: 12) {
            
            // Confidence Meter
            HStack {
                Text("Senaryo Güveni")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Text("\(Int(advice.confidence))%")
                    .font(.caption)
                    .bold()
                    .foregroundColor(confidenceColor)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2)).frame(height: 4)
                    Capsule().fill(confidenceColor).frame(width: geo.size.width * (advice.confidence / 100.0), height: 4)
                }
            }
            .frame(height: 4)
            
            Divider().background(Color.gray.opacity(0.2))
            
            // Zones Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Entry Zone
                vDataBlock(title: "GİRİŞ BÖLGESİ", value: formatRange(low: advice.entryZoneLow, high: advice.entryZoneHigh), color: .green)
                
                // Invalidation
                vDataBlock(title: "İPTAL SEVİYESİ", value: String(format: "%.2f", advice.invalidationLevel ?? 0), color: .red)

                // T1
                vDataBlock(title: "HEDEF 1 (ORTA)", value: String(format: "%.2f", advice.targets.first ?? 0), color: .blue)
                
                // T2
                vDataBlock(title: "HEDEF 2 (ÜST)", value: String(format: "%.2f", advice.targets.last ?? 0), color: .purple)
            }
            
            Divider().background(Color.gray.opacity(0.2))
            
            // Reason
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                Text(advice.reasonShort)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            
            // Triggers (Mini Icons)
            HStack(spacing: 12) {
                if advice.triggers.touchLowerBand {
                    triggerIcon(icon: "arrow.down.to.line", color: .green, label: "Kanal")
                }
                if advice.triggers.rsiReversal {
                    triggerIcon(icon: "bolt.fill", color: .yellow, label: "RSI")
                }
                if advice.triggers.bullishDivergence {
                    triggerIcon(icon: "arrow.up.right", color: .orange, label: "Div")
                }
                if !advice.triggers.touchLowerBand && !advice.triggers.rsiReversal && !advice.triggers.bullishDivergence {
                    Text("Aktif Tetikleyici Yok")
                        .font(.caption2)
                        .italic()
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                }
                Spacer()
            }
            .padding(.top, 4)
        }
    }
    
    private var errorView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.yellow)
            Text(advice.reasonShort.isEmpty ? "Yetersiz Veri" : advice.reasonShort)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var confidenceColor: Color {
        if advice.confidence >= 70 { return .green }
        if advice.confidence >= 40 { return .yellow }
        return .red
    }
    
    private func formatRange(low: Double?, high: Double?) -> String {
        guard let l = low, let h = high else { return "-" }
        return "\(String(format: "%.2f", l)) - \(String(format: "%.2f", h))"
    }
    
    private func vDataBlock(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
    }
    
    private func triggerIcon(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
        }
        .foregroundColor(color)
        .padding(4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}
