import SwiftUI

struct DebateSimulatorView: View {
    let trace: AgoraTrace
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header: The Verdict
                    VStack(spacing: 8) {
                        Image(systemName: "hammer.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.tint)
                            .padding()
                            .background(Theme.tint.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("Münazara Sonucu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(trace.finalDecision.action == .buy ? "ALIM ONAYI" : (trace.finalDecision.action == .sell ? "SATIŞ ONAYI" : "BEKLEME"))
                            .font(.title2)
                            .bold()
                            .foregroundColor(trace.finalDecision.action == .buy ? .green : (trace.finalDecision.action == .sell ? .red : .orange))
                            
                        Text(trace.debate.consensusParams.deliberationText)
                            .font(.body)
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    Divider()
                    
                    // The Debate Flow (Chat Style)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ARGUS KONSEYİ TUTANAKLARI")
                            .font(.caption)
                            .bold()
                            .tracking(2)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                        
                        // 1. Claimant (Who started it?)
                        if let claimant = trace.debate.claimant {
                            DebateBubble(
                                engine: claimant.module.rawValue,
                                message: "Bu hissede fırsat görüyorum. \(claimant.evidence.first ?? "")",
                                type: .claim,
                                score: claimant.confidence
                            )
                        }
                        
                        // 2. Supporters & Dissenters
                        ForEach(trace.debate.opinions.filter { $0.module != trace.debate.claimant?.module }) { opinion in
                            DebateBubble(
                                engine: opinion.module.rawValue,
                                message: opinion.stance == .support 
                                    ? "Katılıyorum. \(opinion.evidence.first ?? "")" 
                                    : "İtiraz ediyorum! \(opinion.evidence.first ?? "")",
                                type: opinion.stance == .support ? .support : .dissent,
                                score: opinion.confidence
                            )
                        }
                        
                        // 3. Risk Gate (Final Boss)
                        if !trace.riskEvaluation.isApproved {
                            DebateBubble(
                                engine: "Chiron (Risk Valisi)",
                                message: "VETO! \(trace.riskEvaluation.reason). İşlem çok riskli.",
                                type: .dissent,
                                score: 100
                            )
                        } else {
                            DebateBubble(
                                engine: "Chiron (Risk Valisi)",
                                message: "Risk kontrolleri geçildi. Bütçe uygun (\(String(format: "%.1f", trace.riskEvaluation.deltaR))R).",
                                type: .support,
                                score: 100
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Münazara Kayıtları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

enum DebateBubbleType {
    case claim, support, dissent
}

struct DebateBubble: View {
    let engine: String
    let message: String
    let type: DebateBubbleType
    let score: Double
    
    var color: Color {
        switch type {
        case .claim: return .blue
        case .support: return .green
        case .dissent: return .red
        }
    }
    
    var icon: String {
        switch type {
        case .claim: return "hand.raised.fill"
        case .support: return "hand.thumbsup.fill"
        case .dissent: return "hand.thumbsdown.fill"
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(engine)
                        .font(.caption)
                        .bold()
                        .foregroundColor(color)
                    Spacer()
                    Text("%\(Int(score)) Güven")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .padding(10)
                    .background(Theme.secondaryBackground)
                    .cornerRadius(12, corners: [.topRight, .bottomLeft, .bottomRight])
            }
        }
    }
}


