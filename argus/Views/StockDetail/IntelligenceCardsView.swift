import SwiftUI

struct IntelligenceCardsView: View {
    let snapshot: MarketIntelligenceSnapshot?
    let currentPrice: Double
    let isETF: Bool
    
    var body: some View {
        if isETF || snapshot == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                    Text("Piyasa İstihbaratı")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                if let data = snapshot {
                    // Row 1: Analyst Target Logic
                    if let target = data.targetMeanPrice {
                        analystRow(target: target)
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // Row 2: Insider Sentiment logic
                    insiderRow(netSentiment: data.netInsiderBuySentiment)
                }
            }
            .padding()
            .background(Color("CardBackground").opacity(0.1)) // Fallback color if Asset missing
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Subviews
    
    private func analystRow(target: Double) -> some View {
        let upside = ((target - currentPrice) / currentPrice) * 100.0
        let isPositive = upside > 0
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Analist Hedefi (Ort.)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(target, specifier: "%.2f")")
                    .font(.subheadline)
                    .bold()
                Text("(\(isPositive ? "+" : "")\(upside, specifier: "%.1f")%)")
                    .font(.caption)
                    .foregroundColor(isPositive ? .green : .red)
            }
            
            // Progress Bar Visual
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .frame(width: geo.size.width, height: 6)
                        .opacity(0.2)
                        .foregroundColor(.gray)
                        .cornerRadius(3)
                    
                    // Indicator (Clamped)
                    // We assume a range of -50% to +50% for the bar visualization roughly
                    // If target is 150 and price is 100, upside is 50%.
                    // Let's normalize: Center is Price.
                    /*
                     Visualizing Target vs Price is tricky without a Min/Max range.
                     Let's simplify: A bar representing 0 to Target*1.5?
                     Better: Just a simple colored bar indicating the 'gap'.
                     */
                    let width = min(max(abs(upside) * 2, 0), 100) // Scale factor for visibility
                    let barWidth = geo.size.width * (width / 100.0)
                    
                    Rectangle()
                        .frame(width: barWidth, height: 6)
                        .foregroundColor(isPositive ? .green : .red)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
    
    private func insiderRow(netSentiment: Double) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text("İçeriden Öğrenenler (90 Gün)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if netSentiment > 0 {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("Yönetim Alımda (Güven Yüksek)")
                            .font(.callout)
                            .foregroundColor(.green)
                    }
                } else if netSentiment < 0 {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.gray)
                        Text("Yönetim Satışta / Nötr")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.gray)
                        Text("İşlem Yok")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
    }
}
