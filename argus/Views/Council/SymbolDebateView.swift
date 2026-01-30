import SwiftUI

// MARK: - Symbol Debate View (Council Room)
struct SymbolDebateView: View {
    let decision: ArgusGrandDecision
    @ObservedObject var viewModel: TradingViewModel // Added ViewModel Dependency
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("COUNCIL ROOM")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(2)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. FINAL VERDICT
                        VStack(spacing: 12) {
                            Circle()
                                .fill(decisionActionColor(decision.action))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: decisionActionIcon(decision.action))
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                )
                                .shadow(color: decisionActionColor(decision.action).opacity(0.5), radius: 20, x: 0, y: 0)
                            
                            Text(decision.action.rawValue)
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.black)
                                .foregroundColor(.white)
                            
                            Text(decision.reasoning)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            HStack {
                                Label("Confidence: %\(Int(decision.confidence * 100))", systemImage: "gauge.with.needle")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(20)
                        }
                        .padding(.top, 24)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // 2. VETOES (Top Priority)
                        if !decision.vetoes.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("VETO ALERTS", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                                
                                ForEach(decision.vetoes, id: \.module) { veto in
                                    HStack(spacing: 12) {
                                        Image(systemName: "hand.raised.fill")
                                            .foregroundColor(.red)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(veto.module.uppercased())
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.red.opacity(0.8))
                                            
                                            Text(veto.reason)
                                                .font(.caption)
                                                .foregroundColor(.white)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // 3. VOTING BREAKDOWN
                        VStack(alignment: .leading, spacing: 12) {
                            Label("VOTE BREAKDOWN", systemImage: "checklist")
                                .font(.headline)
                                .foregroundColor(Theme.tint)
                                .padding(.horizontal)
                            
                            ForEach(decision.contributors, id: \.module) { vote in
                                VoteRow(vote: vote)
                            }
                        }
                        
                        // 4. PATTERN CONTEXT (Orion V3)
                        if let patterns = decision.patterns, !patterns.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("DETECTED PATTERNS", systemImage: "chart.xyaxis.line")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(patterns) { pattern in
                                            PatternChip(pattern: pattern)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // 5. DETAILED AI REPORT
                        NavigationLink(destination: ArgusAnalystReportView(symbol: decision.symbol, viewModel: viewModel)) {
                           HStack {
                               Image(systemName: "doc.text.magnifyingglass")
                                   .font(.headline)
                               Text("Yapay Zeka Raporunu Oku")
                                   .font(.headline)
                                   .bold()
                           }
                           .foregroundColor(.black)
                           .padding()
                           .frame(maxWidth: .infinity)
                           .background(Theme.tint)
                           .cornerRadius(12)
                           .padding(.horizontal)
                        }
                        .padding(.top, 10)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
    
    // Helpers
    func decisionActionColor(_ action: ArgusAction) -> Color {
        switch action {
        case .aggressiveBuy: return .green
        case .accumulate: return .blue
        case .neutral: return .gray
        case .trim: return .orange
        case .liquidate: return .red
        }
    }
    
    func decisionActionIcon(_ action: ArgusAction) -> String {
        switch action {
        case .aggressiveBuy: return "bolt.fill"
        case .accumulate: return "plus.circle.fill"
        case .neutral: return "eye.fill"
        case .trim: return "scissors"
        case .liquidate: return "xmark.octagon.fill"
        }
    }
}

// Subview for Vote Row
struct VoteRow: View {
    let vote: ModuleContribution
    
    var voteColor: Color {
        switch vote.action {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .gray
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Placeholder
            ZStack {
                Circle()
                    .fill(Color(hex: "1C1C1E"))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().stroke(voteColor.opacity(0.3), lineWidth: 1)
                    )
                
                Text(String(vote.module.prefix(1)))
                    .font(.headline)
                    .foregroundColor(voteColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(vote.module)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(vote.action.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(voteColor.opacity(0.2))
                        .foregroundColor(voteColor)
                        .cornerRadius(4)
                }
                
                Text(vote.reasoning)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Momentum Bar if confidence boosting
                if vote.confidence > 1.0 {
                    HStack {
                        Image(systemName: "cellularbars")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Momentum Boost Active")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding()
        .background(Color(hex: "151517"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// Subview for Pattern Chip
struct PatternChip: View {
    let pattern: OrionChartPattern
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pattern.type.icon)
                .font(.caption)
                .foregroundColor(pattern.type.isBullish ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.type.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("%\(Int(pattern.confidence)) Güven")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pattern.type.isBullish ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}
