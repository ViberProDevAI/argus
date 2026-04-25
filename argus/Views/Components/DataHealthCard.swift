import SwiftUI

struct DataHealthCard: View {
    let symbol: String
    let confidence: Double // 0-100
    let provider: String
    let isLive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "shield.checkerboard")
                    .foregroundColor(InstitutionalTheme.Colors.holo)
                Text("Veri Güven Skoru")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Text("\(Int(confidence))%")
                    .font(.title3)
                    .bold()
                    .foregroundColor(Theme.colorForScore(confidence))
            }
            
            Divider().background(InstitutionalTheme.Colors.border)
            
            // Details
            HStack(spacing: 16) {
                // Source
                VStack(alignment: .leading) {
                    Text("KAYNAK")
                        .font(.caption)
                        .bold()
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(provider)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                // Status
                VStack(alignment: .leading) {
                    Text("DURUM")
                        .font(.caption)
                        .bold()
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isLive ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(isLive ? "Canlı Akış" : "Gecikmeli")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            
            // Footer Note
            if confidence < 80 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Dikkat: Bazı temel veriler eksik olabilir.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(InstitutionalTheme.Colors.surface1)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(InstitutionalTheme.Colors.border, lineWidth: 1)
        )
    }
}
