import SwiftUI

struct TradeDetailSheet: View {
    let trade: Trade
    @ObservedObject var viewModel: TradingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Header Info
                        VStack(spacing: 8) {
                            CompanyLogoView(symbol: trade.symbol, size: 80)
                            Text(trade.symbol)
                                .font(.title)
                                .bold()
                                .foregroundColor(Theme.textPrimary)
                            
                            if let quote = viewModel.quotes[trade.symbol] {
                                Text("$\(String(format: "%.2f", quote.currentPrice))")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        .padding(.top)
                        
                        // 2. PnL Card
                        if let quote = viewModel.quotes[trade.symbol] {
                            let pnl = (quote.currentPrice - trade.entryPrice) * trade.quantity
                            let pct = (pnl / (trade.entryPrice * trade.quantity)) * 100
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Net Kâr/Zarar")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                    Text("$\(String(format: "%.2f", pnl))")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(pnl >= 0 ? Theme.positive : Theme.negative)
                                }
                                Spacer()
                                Text(String(format: "%.2f%%", pct))
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(pnl >= 0 ? Theme.positive : Theme.negative)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background((pnl >= 0 ? Theme.positive : Theme.negative).opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding()
                            .background(Theme.cardBackground)
                            .cornerRadius(16)
                        }
                        
                        // 3. Karar Mantığı (Decision Logic)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Karar Analizi", systemImage: "brain.head.profile")
                                    .font(.headline)
                                    .foregroundColor(Theme.tint)
                                Spacer()
                                
                                // Source Badge
                                Text(trade.source == .autoPilot ? "OTOPİLOT" : "MANUEL")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(trade.source == .autoPilot ? Theme.tint.opacity(0.2) : Color.gray.opacity(0.2))
                                    .foregroundColor(trade.source == .autoPilot ? Theme.tint : .gray)
                                    .cornerRadius(6)
                            }
                            
                            // "Why" - Neden?
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NEDEN?")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(Theme.textSecondary)
                                
                                Text(trade.rationale ?? "Gerekçe belirtilmemiş.")
                                    .font(.body)
                                    .foregroundColor(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Divider().background(Theme.secondaryBackground)
                            
                            // "How" - Nasıl? (Modüller)
                            if let context = trade.decisionContext {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("NASIL? (Etken Modüller)")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    // Module Votes
                                    HStack(spacing: 8) {
                                        if let atlas = context.moduleVotes.atlas { ModuleBadge(name: "Atlas", score: atlas.confidence * 100) }
                                        if let orion = context.moduleVotes.orion { ModuleBadge(name: "Orion", score: orion.confidence * 100) }
                                        if let aether = context.moduleVotes.aether { ModuleBadge(name: "Aether", score: aether.confidence * 100) }
                                        if let hermes = context.moduleVotes.hermes { ModuleBadge(name: "Hermes", score: hermes.confidence * 100) }
                                    }
                                }
                            }
                            
                            // "Targets" - Hedefler
                            if trade.stopLoss != nil || trade.takeProfit != nil {
                                Divider().background(Theme.secondaryBackground)
                                HStack(spacing: 16) {
                                    // Stop Loss
                                    if let sl = trade.stopLoss {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("S.L. (Stop)")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                            Text("$\(String(format: "%.2f", sl))")
                                                .font(.headline)
                                                .foregroundColor(Theme.negative)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Theme.secondaryBackground)
                                        .cornerRadius(12)
                                    }
                                    
                                    // Take Profit
                                    if let tp = trade.takeProfit {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("T.P. (Hedef)")
                                                .font(.caption)
                                                .foregroundColor(Theme.textSecondary)
                                            Text("$\(String(format: "%.2f", tp))")
                                                .font(.headline)
                                                .foregroundColor(Theme.positive)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Theme.secondaryBackground)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Theme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Theme.tint.opacity(0.3), lineWidth: 1)
                        )

                        // 4. Argus Voice Report (Detailed)
                        if let report = trade.voiceReport {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Argus Sesli Notu", systemImage: "waveform")
                                    .font(.headline)
                                    .foregroundColor(Theme.textSecondary)
                                
                                Text(report)
                                    .font(.subheadline)
                                    .italic()
                                    .foregroundColor(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .background(Theme.cardBackground.opacity(0.5))
                            .cornerRadius(16)
                        }
                        
                        Spacer()
                        
                        // 4. Manual Close Button
                        Button(action: closePosition) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Pozisyonu Kapat")
                                    .bold()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.negative)
                            .cornerRadius(16)
                            .shadow(color: Theme.negative.opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    func closePosition() {
        if let price = viewModel.quotes[trade.symbol]?.currentPrice {
            viewModel.sell(tradeId: trade.id, currentPrice: price)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct ModuleBadge: View {
    let name: String
    let score: Double
    
    var color: Color {
        if score >= 70 { return Theme.positive }
        if score <= 40 { return Theme.negative }
        return .orange
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(name.prefix(1))
                .font(.caption2)
                .bold()
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(color)
                .clipShape(Circle())
            
            Text("\(Int(score))")
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
