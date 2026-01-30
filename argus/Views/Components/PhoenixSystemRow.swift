import SwiftUI

struct PhoenixSystemRow: View {
    let advice: PhoenixAdvice
    
    var statusColor: Color {
        return advice.status == .active ? Theme.tint : .gray
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon & Animation Container
            ZStack {
                if advice.status == .active {
                    NeuralPulseView(color: statusColor)
                        .frame(width: 36, height: 36)
                }
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundColor(statusColor)
            }
            .frame(width: 40, height: 40)
            
            // Text Content
            VStack(alignment: .leading, spacing: 2) {
                Text("Phoenix Sistemi")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(Theme.textPrimary)
                
                Text(advice.reasonShort)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            // Score / Confidence
            HStack(spacing: 4) {
                Text("\(Int(advice.confidence))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(advice.status == .active ? statusColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
