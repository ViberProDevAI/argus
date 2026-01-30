import SwiftUI

struct SanctumTradePanel: View {
    let symbol: String
    let currentPrice: Double
    let onBuy: () -> Void
    let onSell: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Price Display (Mini)
            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.gray)
                Text(String(format: "%.2f", currentPrice))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.leading, 8)
            
            Spacer()
            
            // Sell Button
            Button(action: onSell) {
                Text("SAT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 44)
                    .background(SanctumTheme.crimsonRed.opacity(0.8))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // Buy Button
            Button(action: onBuy) {
                Text("AL")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 80, height: 44)
                    .background(SanctumTheme.auroraGreen)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: SanctumTheme.auroraGreen.opacity(0.4), radius: 8, x: 0, y: 0)
            }
        }
        .padding(12)
        .background(
            ZStack {
                // Glassmorphism Background
                Rectangle()
                    .fill(Color(hex: "0F172A").opacity(0.8))
                
                Rectangle()
                    .stroke(LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .background(.ultraThinMaterial)
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
    }
}
