import SwiftUI

// MARK: - Badge View (Market List)
struct DemeterBadgeView: View {
    let score: DemeterScore?
    
    var body: some View {
        if let score = score {
            HStack(spacing: 4) {
                Image(systemName: "leaf.fill")
                    .font(.caption2)
                    .foregroundColor(.brown)
                Text("\(Int(score.totalScore))")
                    .font(.caption2.bold())
                    .foregroundStyle(Color(score.colorName))
                
                if !score.activeShocks.isEmpty && score.shockImpactScore < 50 {
                    Text("!")
                        .font(.caption2.bold())
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Detail Panel (Stock Detail)
struct DemeterPanel: View {
    let score: DemeterScore
    @State private var showingDetail = false
    
    // Helper to get shock info
    var primaryShock: (title: String, badge: String, color: Color)? {
        if let shock = score.activeShocks.first {
            // Map shock type to simple title
            let title = "\(shock.type.displayName) Etkisi"
            let badge = "Baskı" // Simplified for now, logic needed if positive
            let color = Color.orange
            return (title, badge, color)
        }
        return nil
    }
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                
                // Header Row
                HStack {
                    // Badge
                    if let shock = primaryShock {
                        Text(shock.badge)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(shock.color.opacity(DesignTokens.Opacity.glassCard))
                            .foregroundColor(shock.color)
                            .cornerRadius(4)
                        
                        Text(shock.title)
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        // Neutral State
                        Text("Dengeli")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(DesignTokens.Opacity.glassCard))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                        
                        Text("Sektör Nötr")
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("Detay")
                        .font(.caption)
                        .foregroundColor(Theme.tint)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Theme.tint)
                }
                
                // Info Row
                if score.activeShocks.first != nil {
                   HStack(spacing: 6) {
                       Image(systemName: "clock") // SF Symbol: Time
                           .font(.caption2)
                           .foregroundColor(.gray)
                       Text("Etki penceresi: 1–4 hafta")
                           .font(.caption)
                           .foregroundColor(.gray)
                       
                       Text("•")
                           .foregroundColor(.gray)
                       
                       Image(systemName: "arrow.down.right") // SF Symbol: Threshold
                            .font(.caption2)
                            .foregroundColor(.orange)
                       Text("Eşik aşıldı")
                           .font(.caption)
                           .foregroundColor(.orange)
                   }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("Majör bir şok tespit edilmedi.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Theme.secondaryBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingDetail) {
            SectorDetailView(score: score)
        }
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(DesignTokens.Opacity.glassCard))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.gray)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.secondaryBackground)
        .cornerRadius(8)
    }
}
