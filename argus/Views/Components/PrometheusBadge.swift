import SwiftUI

struct PrometheusBadge: View {
    let forecast: PrometheusForecast?
    
    // Basit ve net tasarim
    // [ P ] [ +5.2% ]
    
    var body: some View {
        if let f = forecast, f.isValid {
            // Valid forecast - show actual data
            HStack(spacing: 4) {
                // P Icon
                Text("P")
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.purple.opacity(0.8)) // Prometheus - Fire/Purple theme
                    .clipShape(Circle())
                
                // Percent
                Text(String(format: "%+.1f%%", f.changePercent))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color(for: f.changePercent))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)
        } else {
            // Invalid or nil forecast - show disabled placeholder
            HStack(spacing: 4) {
                Text("P")
                    .font(.system(size: 10, weight: .black, design: .serif))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                
                Text("---%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.02))
            .cornerRadius(4)
        }
    }
    
    func color(for percent: Double) -> Color {
        if percent >= 2 { return .green }
        if percent <= -2 { return .red }
        return .gray
    }
}
