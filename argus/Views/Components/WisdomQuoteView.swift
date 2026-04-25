import SwiftUI

// MARK: - Loading Quote View
struct LoadingQuoteView: View {
    @State private var quote: WisdomQuote?
    
    var body: some View {
        VStack(spacing: 8) {
            if let quote = quote {
                Text(quote.quote)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(.gray)
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("- \(quote.author)")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            quote = WisdomService.shared.getQuote(for: .accumulate)
        }
    }
}

// MARK: - Empty Portfolio Quote
struct EmptyPortfolioQuote: View {
    @State private var quote: WisdomQuote?
    
    var body: some View {
        VStack(spacing: 8) {
            if let quote = quote {
                Text(quote.quote)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.gray)
                    .italic()
                    .multilineTextAlignment(.center)
                
                Text("- \(quote.author)")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .padding(.top, 12)
        .onAppear {
            quote = WisdomService.shared.getQuote(for: .accumulate)
        }
    }
}

// MARK: - Daily Quote Card
struct DailyQuoteCard: View {
    @State private var quote: WisdomQuote?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GÜNÜN SÖZÜ")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            if let quote = quote {
                Text(quote.quote)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                    .italic()
                
                Text("- \(quote.author)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            quote = WisdomService.shared.getDailyQuote()
        }
    }
}

// MARK: - Wisdom Quote Strip (Council Card)
struct WisdomQuoteStrip: View {
    let action: ArgusAction
    @State private var quote: WisdomQuote?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let quote = quote {
                Text(quote.quote)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.white)
                    .italic()
                    .lineLimit(2)
                
                Text("- \(quote.author)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .onAppear {
            quote = WisdomService.shared.getQuote(for: action)
        }
    }
}
