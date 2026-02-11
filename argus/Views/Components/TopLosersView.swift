import SwiftUI

struct TopLosersView: View {
    @ObservedObject var viewModel: TradingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("En Çok Düşenler (Günün Kaybedenleri)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if !viewModel.topLosers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.topLosers, id: \.symbol) { quote in
                            LoserCard(symbol: quote.symbol ?? "N/A", quote: quote)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Veri yok veya yüklenemedi.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(action: {
                            Task { await viewModel.fetchTopLosers() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Theme.tint)
                        }
                    }
                }
                .padding(.horizontal)
                .frame(height: 50)
            }
        }
        .padding(.vertical, 8)
    }

}

struct LoserCard: View {
    let symbol: String
    let quote: Quote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(symbol)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.2f", quote.currentPrice))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Image(systemName: "arrow.down.right.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                
                Text(String(format: "%.2f%%", quote.percentChange))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .frame(width: 140, height: 70)
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
