import SwiftUI

// MARK: - Premium Report Card
struct PremiumReportCard: View {
    let theme = Theme.self

    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let reportText: String?
    
    @State private var isExpanded = false
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                }
                
                Spacer()
                
                Circle()
                    .fill(reportText != nil ? .green : .gray)
                    .frame(width: 6, height: 6)
            }
            
            Divider()
                .background(Theme.border)
            
            if let text = reportText {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(extractKeyStats(from: text), id: \.self) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color.opacity(0.4))
                                .frame(width: 4, height: 4)
                            
                            Text(stat)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Hazırlanıyor...")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            Button(action: { 
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { 
                    isExpanded = true 
                }
            }) {
                HStack(spacing: 4) {
                    Text("Raporu Aç")
                        .font(.system(size: 10, weight: .semibold))
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundColor(reportText != nil ? color : Theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(reportText != nil ? Color.black.opacity(DesignTokens.Opacity.glassCard) : Theme.cardBackground)
            .cornerRadius(6)
            .disabled(reportText == nil)
            .opacity(reportText == nil ? 0.5 : 1)
        }
        .padding(12)
        .frame(width: 180, height: 160)
        .background(Theme.surface)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 2)
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double.random(in: 0...0.2)), value: isVisible)
        .sheet(isPresented: $isExpanded) {
            VStack(spacing: 20) {
                Text("Rapor detayları yakında eklenecek...")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("Premium özellikler geliştiriliyor...")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }
    
    private func extractKeyStats(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var stats: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- **") {
                var cleaned = trimmed
                    .replacingOccurrences(of: "- **", with: "")
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "*", with: "")
                
                if cleaned.count < 50 {
                    stats.append(cleaned)
                }
            }
        }
        
        return Array(stats.prefix(3))
    }
}
