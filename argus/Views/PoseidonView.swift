import SwiftUI

struct PoseidonView: View {
    let score: WhaleScore

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Büyük Balık Avı")
                    .font(.title3)
                    .bold()
                Spacer()
                Image(systemName: "water.waves") // Poseidon Trident icon proxy
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            // 1. Whale Score Gauge (Big Number)
            VStack {
                Text("\(Int(score.totalScore))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(score.sentimentColor)
                
                Text("Balina Skoru")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(score.summary)
                    .font(.footnote)
                    .bold()
                    .padding(.top, 4)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.secondaryBackground)
            .cornerRadius(16)
            .padding(.horizontal)
            
            // 2. Components Grid
            HStack(spacing: 12) {
                PoseidonMetricCard(title: "Insider", value: String(format: "%.0f", score.insiderScore))
                PoseidonMetricCard(title: "Dark Pool", value: String(format: "%.0f", score.darkPoolScore))
                PoseidonMetricCard(title: "Kurumsal", value: String(format: "%.0f", score.institutionalScore))
            }
            .padding(.horizontal)
            
            // 3. Insider Radar
            VStack(alignment: .leading, spacing: 12) {
                Text("Insider Radarı")
                    .font(.headline)
                    .padding(.horizontal)
                
                // Demo Data for UI (Service not fully hooked to UI yet, need to pass simulateInsiders result to View model then View)
                // For now, static or pass via WhaleScore if we update model to holding list
                Text("Veri bekleniyor... (Simülasyon Aktif)")
                    .font(.caption)
                    .italic()
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding(.top)
        .background(Theme.background)
    }
}

struct PoseidonMetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}
