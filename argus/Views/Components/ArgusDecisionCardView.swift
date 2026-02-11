import SwiftUI

struct ArgusDecisionCardView: View {
    let decision: ArgusDecisionResult
    let explanation: ArgusExplanation?
    let isLoading: Bool
    var onRetry: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.cyan)
                Text("KARAR ÖZETİ")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(decision.generatedAt, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // Score & Action Section
            HStack(alignment: .center, spacing: 20) {
                // Left: Action & Grade
                VStack(alignment: .leading, spacing: 4) {
                    Text(actionText)
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(actionColor)
                    
                    HStack {
                        Text("Not:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        // Letter Grade removed
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(actionColor.opacity(0.2))
                            .cornerRadius(8)
                            .foregroundColor(actionColor)
                    }
                }
                
                Spacer()
                
                // Right: Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(decision.finalScoreCore) / 100.0)
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [.cyan, actionColor]), center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 70, height: 70)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(decision.finalScoreCore))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("/100")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(gradient: Gradient(colors: [actionColor.opacity(0.1), Color.clear]), startPoint: .leading, endPoint: .trailing)
            )
            
            Divider().background(Color.gray.opacity(0.3))
            
            // AI Explanation Section
            if let exp = explanation {
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(exp.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    // Summary
                    Text(exp.summary)
                        .font(.system(.footnote, design: .monospaced)) // Terminal Style
                        .foregroundColor(.white) // Plain White
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    // Bullets
                    ForEach(exp.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Text(">>") // Terminal arrow
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                            Text(bullet)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    // Risk Note
                    if let risk = exp.riskNote, !risk.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(risk)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.top, 4)
                    }
                    
                    // Offline / Retry Button
                    if exp.isOffline, let retry = onRetry {
                        Button(action: retry) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Analizi Tekrar Dene")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            } else if isLoading {
                // Skeleton Loader
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 16).frame(width: 200)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 12).frame(width: 150)
                    
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Argus yapay zekası analizi yorumluyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding(.top, 8)
                }
                .padding()
            } else {
                // Empty or failed state (should rarely happen if ViewModel handles fallback)
                Text("Detaylı yorum alınamadı.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Derived Helpers
    var actionText: String {
        switch decision.finalActionCore {
        case .buy: return "AL"
        case .sell: return "SAT"
        case .hold: return "BEKLE"
        case .wait: return "GÖZLEMLE"
        case .skip: return "PAS"
        }
    }
    
    var actionColor: Color {
        switch decision.finalActionCore {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .yellow
        case .wait: return .gray
        case .skip: return .gray
        }
    }
}
