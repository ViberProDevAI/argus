import SwiftUI
import Charts

struct CrystalWatchlistRow: View {
    let symbol: String
    let quote: Quote?
    let candles: [Candle]?
    let forecast: PrometheusForecast? // New property
    
    // Derived
    var changeColor: Color {
        guard let q = quote else { return Theme.textSecondary }
        return q.change >= 0 ? Theme.positive : Theme.negative
    }
    
    // Logo Helper (Duplicated logic from MarketRow, should be centralized but kept here for self-containment)

    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Identity
            HStack(spacing: 12) {
                CompanyLogoView(symbol: symbol, size: 36, cornerRadius: 18)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol)
                        .font(.custom("Inter-Bold", size: 15))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(quote?.shortName ?? "Yükleniyor")
                        .font(.custom("Inter-Regular", size: 11))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 2. PROMETHEUS FORECAST (Replaces Sparkline)
            if let f = forecast {
                PrometheusBadge(forecast: f)
                    .frame(width: 80, alignment: .center) // Sabit genislik
            } else {
                // Placeholder if no forecast yet
                Text("-")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary.opacity(0.3))
                    .frame(width: 80, alignment: .center)
            }
            
            // 3. Data Pill
            if let q = quote {
                let isBist = symbol.uppercased().hasSuffix(".IS")
                let currencySymbol = isBist ? "₺" : "$"
                let priceFormat = "%.2f"
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "\(currencySymbol)\(priceFormat)", q.currentPrice))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(String(format: "%.2f%%", q.percentChange))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(changeColor)
                        .cornerRadius(6)
                }
            } else {
                // Skeleton
                 VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 50, height: 16)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.secondaryBackground).frame(width: 40, height: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Make full row tappable
    }
}
