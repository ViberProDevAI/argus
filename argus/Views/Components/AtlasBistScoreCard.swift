import SwiftUI

// MARK: - Atlas BIST Puanlama Kartı
// Kullanıcıya hangi metriklere bakıldığını, kaç puan verildiğini
// ve bunun ne anlama geldiğini öğretici şekilde gösterir

struct AtlasBistScoreCard: View {
    let symbol: String
    @State private var result: AtlasBistResult?
    @State private var isLoading = true
    @State private var error: String?
    @State private var expandedComponent: String?
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(.yellow)
                    Text("BIST Temel Analiz")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else if let result = result {
                        // Toplam Puan Badge
                        HStack(spacing: 4) {
                            Text("\(Int(result.totalScore))")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                            Text("/100")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(scoreColor(result.totalScore))
                    }
                }
                
                if let result = result {
                    // Kalite Bandı
                    HStack {
                        Text("Kalite:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(result.qualityBand)
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(scoreColor(result.totalScore).opacity(0.2))
                            .foregroundColor(scoreColor(result.totalScore))
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text(result.verdict)
                            .font(.caption)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(verdictColor(result.verdict).opacity(0.3))
                            .foregroundColor(verdictColor(result.verdict))
                            .cornerRadius(8)
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Bileşen Skorları
                    ForEach(result.components.all) { component in
                        ComponentRow(
                            component: component,
                            isExpanded: expandedComponent == component.name,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedComponent = expandedComponent == component.name ? nil : component.name
                                }
                            }
                        )
                    }
                    
                    // Dönem Bilgisi
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Dönem: \(result.financials.period)")
                            .font(.caption2)
                        Spacer()
                        Text("Son güncelleme: Şimdi")
                            .font(.caption2)
                    }
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                    
                } else if !isLoading {
                    if let error = error {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analiz Hatası")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("Mali veri bulunamadı")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onAppear { loadData() }
        }
    }
    
    private func loadData() {
        Task {
            do {
                let data = try await AtlasBistScoringEngine.shared.analyze(symbol: symbol)
                await MainActor.run {
                    self.result = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = error.localizedDescription
                    print("⚠️ AtlasBist yüklenemedi: \(error)")
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
    
    private func verdictColor(_ verdict: String) -> Color {
        if verdict.contains("AL") { return .green }
        if verdict.contains("TUT") { return .yellow }
        return .red
    }
}

// MARK: - Bileşen Satırı (Genişleyebilir)
struct ComponentRow: View {
    let component: AtlasBistScoreComponent
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Ana Satır
            Button(action: onTap) {
                HStack {
                    // İkon
                    Image(systemName: iconForComponent(component.name))
                        .font(.caption)
                        .foregroundColor(colorForComponent(component.name))
                        .frame(width: 20)
                    
                    // İsim
                    Text(component.name)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    // Ağırlık
                    Text("(\(Int(component.weight * 100))%)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Skor Bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorForScore(component.score))
                            .frame(width: CGFloat(component.score / 100) * 80, height: 8)
                    }
                    
                    // Puan
                    Text("\(Int(component.score))")
                        .font(.caption)
                        .bold()
                        .foregroundColor(colorForScore(component.score))
                        .frame(width: 30, alignment: .trailing)
                    
                    // Genişlet İkonu
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Genişletilmiş Detay
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Açıklama
                    Text(component.summary)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 24)
                    
                    // Metrikler Çizelgesi
                    ForEach(component.metrics) { metric in
                        MetricDetailRow(metric: metric)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForComponent(_ name: String) -> String {
        switch name {
        case "Karlılık": return "chart.line.uptrend.xyaxis"
        case "Borç & Risk": return "shield.lefthalf.filled"
        case "Değerleme": return "tag.fill"
        case "Temettü": return "banknote.fill"
        case "Analist Konsensüsü": return "person.3.fill"
        default: return "chart.bar.fill"
        }
    }
    
    private func colorForComponent(_ name: String) -> Color {
        switch name {
        case "Karlılık": return .green
        case "Borç & Risk": return .blue
        case "Değerleme": return .orange
        case "Temettü": return .yellow
        case "Analist Konsensüsü": return .purple
        default: return .gray
        }
    }
    
    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
}

// MARK: - Metrik Detay Satırı (Öğretici)
struct MetricDetailRow: View {
    let metric: AtlasBistMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Metrik Adı
                Text(metric.name)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Değer
                Text(formatValue(metric.value, for: metric.name))
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                
                // Puan / Max
                Text("\(Int(metric.score))/\(Int(metric.maxScore))")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(scoreColor(metric.percentage).opacity(0.2))
                    .foregroundColor(scoreColor(metric.percentage))
                    .cornerRadius(4)
            }
            
            // Açıklama
            Text(metric.explanation)
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Formül (Öğretici)
            HStack(spacing: 4) {
                Image(systemName: "function")
                    .font(.system(size: 8))
                Text(metric.formula)
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(.cyan.opacity(0.7))
            .padding(.top, 2)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .padding(.leading, 24)
    }
    
    private func formatValue(_ value: Double, for name: String) -> String {
        if name.contains("Oran") || name.contains("Özkaynak") {
            return String(format: "%.2f", value)
        } else if name.contains("%") || name.contains("Marj") || name.contains("Verim") || name.contains("Potansiyel") {
            return String(format: "%.1f%%", value)
        } else if name.contains("F/K") || name.contains("PD/DD") {
            return String(format: "%.1fx", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func scoreColor(_ percentage: Double) -> Color {
        switch percentage {
        case 70...: return .green
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        AtlasBistScoreCard(symbol: "THYAO.IS")
            .padding()
    }
    .background(Theme.background)
}
