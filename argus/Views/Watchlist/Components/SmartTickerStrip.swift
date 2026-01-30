import SwiftUI

struct SmartTickerStrip: View {
    @ObservedObject var viewModel: TradingViewModel
    
    // Core Barometers
    let indices = ["SPY", "QQQ", "GLD", "BTC-USD", "VIX"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 1. Spacer for Left Padding
                Color.clear.frame(width: 4)
                
                // 2. Indices
                ForEach(indices, id: \.self) { symbol in
                    NavigationLink(destination: StockDetailView(symbol: symbol, viewModel: viewModel)) {
                        SmartTickerCard(
                            symbol: symbol,
                            quote: viewModel.quotes[symbol],
                            isLoading: viewModel.quotes[symbol] == nil
                        )
                    }
                    .onAppear {
                        if viewModel.quotes[symbol] == nil {
                            viewModel.refreshSymbol(symbol)
                        }
                    }
                }
                
                // 3. Safe Assets (SafeUniverse)
                ForEach(SafeUniverseService.shared.universe) { asset in
                    // Avoid duplicates if indices list covers it
                    if !indices.contains(asset.symbol) {
                        NavigationLink(destination: StockDetailView(symbol: asset.symbol, viewModel: viewModel)) {
                            SmartTickerCard(
                                symbol: asset.symbol,
                                nameOverride: asset.name,
                                quote: viewModel.quotes[asset.symbol],
                                isLoading: viewModel.quotes[asset.symbol] == nil,
                                isSafeAsset: true
                            )
                        }
                    }
                }
                
                // 4. Spacer for Right Padding
                Color.clear.frame(width: 4)
            }
        }
    }
}

struct SmartTickerCard: View {
    let symbol: String
    var nameOverride: String? = nil
    let quote: Quote?
    let isLoading: Bool
    var isSafeAsset: Bool = false
    
    var displayName: String {
        if let n = nameOverride { return n }
        // Simple mapping for clean UI
        switch symbol {
        case "SPY": return "S&P 500"
        case "QQQ": return "NASDAQ"
        case "GLD": return "GOLD"
        case "BTC-USD": return "BITCOIN"
        case "VIX": return "KORKU"
        default: return symbol
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text(displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                
                Spacer()
                
                if isSafeAsset {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.primary)
                }
            }
            
            // Value
            if let q = quote {
                Text(String(format: "%.2f", q.currentPrice))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                
                HStack(spacing: 2) {
                    Image(systemName: q.change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8))
                    Text(String(format: "%.2f%%", q.percentChange))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(q.change >= 0 ? Theme.positive : Theme.negative)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(q.change >= 0 ? Theme.positive.opacity(0.1) : Theme.negative.opacity(0.1))
                .cornerRadius(4)
                
            } else {
                Text("...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(height: 34) // Placeholder height
            }
        }
        .padding(10)
        .frame(width: 100, height: 80)
        .background(.ultraThinMaterial) // Glassmorphism
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.textSecondary.opacity(0.1), lineWidth: 1)
        )
    }
}
