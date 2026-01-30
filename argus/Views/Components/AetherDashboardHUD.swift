import SwiftUI

struct AetherDashboardHUD: View {
    let rating: MacroEnvironmentRating?
    let onTap: () -> Void
    
    // Animation States
    @State private var animateRings: Bool = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background Gradient Mesh
                LinearGradient(
                    colors: [Color(hex: "0a1220"), Color(hex: "05080f")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                
                if let r = rating {
                    HStack(spacing: 0) {
                        // MARK: - Central Score (Big Reactor) - LEFT SIDE
                        ZStack {
                            // Glow
                            Circle()
                                .fill(scoreColor(r.numericScore).opacity(0.1))
                                .frame(width: 80, height: 80)
                                .blur(radius: 15)
                            
                            // Tracks
                            ZStack {
                                Circle()
                                    .trim(from: 0.15, to: 0.85) // Open bottom
                                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .rotationEffect(.degrees(90))
                                
                                Circle()
                                    .trim(from: 0.15, to: 0.15 + (0.7 * (animateRings ? r.numericScore / 100 : 0)))
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [scoreColor(r.numericScore).opacity(0.5), scoreColor(r.numericScore)]),
                                            center: .center
                                        ),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(90))
                                    .animation(.easeOut(duration: 1.5), value: animateRings)
                            }
                            .frame(width: 90, height: 90)
                            
                            // Inner Data
                            VStack(spacing: 2) {
                                Text("\(Int(r.numericScore))")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: scoreColor(r.numericScore).opacity(0.5), radius: 5)
                                
                                Text(r.regime.displayName.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(scoreColor(r.numericScore))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: 70)
                            }
                        }
                        .frame(width: 110) // Fixed width for left side
                        
                        // Spacer
                        Spacer()
                        
                        // MARK: - 3-Part Tachometer (Right Side)
                        VStack(spacing: 12) {
                            // Header
                            HStack {
                                Image(systemName: "globe.americas.fill")
                                    .font(.caption2)
                                    .foregroundColor(.cyan)
                                Text("AETHER MACRO SYSTEM")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .tracking(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                // 1. Leading
                                ArcGauge(
                                    label: "LEADING",
                                    score: r.leadingScore ?? 50,
                                    color: .green,
                                    icon: "binoculars.fill",
                                    animate: animateRings
                                )
                                
                                // 2. Coincident
                                ArcGauge(
                                    label: "COINCIDENT",
                                    score: r.coincidentScore ?? 50,
                                    color: .yellow,
                                    icon: "waveform.path.ecg",
                                    animate: animateRings
                                )
                                
                                // 3. Lagging
                                ArcGauge(
                                    label: "LAGGING",
                                    score: r.laggingScore ?? 50,
                                    color: .red,
                                    icon: "rearview.camera.fill",
                                    animate: animateRings
                                )
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(16)
                } else {
                    // Loading / Empty State
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(.cyan)
                        Text("Aether Atmosfer Verisi İndiriliyor...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .frame(height: 140)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateRings = true
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 60 { return .green }
        if score >= 40 { return .yellow }
        return .red
    }
}

// Improved Arc Gauge that avoids overlaps
struct ArcGauge: View {
    let label: String
    let score: Double
    let color: Color
    let icon: String
    let animate: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background Arc (220 degrees)
                Circle()
                    .trim(from: 0.2, to: 0.8) // Open bottom wide
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
                
                // Active Arc
                Circle()
                    .trim(from: 0.2, to: 0.2 + (0.6 * (animate ? score / 100 : 0)))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.3), color]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
                    .animation(.easeOut(duration: 1.0).delay(0.2), value: animate)
                
                // Inner Value
                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Image(systemName: icon)
                        .font(.system(size: 8))
                        .foregroundColor(color.opacity(0.8))
                        .padding(.top, 2)
                }
            }
            .frame(height: 48) // Fixed height container
            
            // Label outside the gauge stack
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.5) // Allow shrinking for "COINCIDENT"
                .frame(width: 50)
        }
    }
}

// Preview Provider
struct AetherDashboardHUD_Previews: PreviewProvider {
    static var previews: some View {
        let mockRating = MacroEnvironmentRating(
            equityRiskScore: 70, volatilityScore: 80, safeHavenScore: 60, cryptoRiskScore: 85, interestRateScore: 50, currencyScore: 60,
            inflationScore: 40, laborScore: 80, growthScore: 70, creditSpreadScore: 90, claimsScore: 85,
            leadingScore: 82, coincidentScore: 65, laggingScore: 45,
            leadingContribution: 0.4, coincidentContribution: 0.3, laggingContribution: 0.3,
            numericScore: 78, letterGrade: "B+", regime: .riskOn, summary: "Pozitif", details: "Detay"
        )
        
        AetherDashboardHUD(rating: mockRating) {}
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color.black)
    }
}
