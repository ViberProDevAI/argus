import SwiftUI

struct ArgusInfoSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        HStack {
                            ArgusEyeView(mode: .argus, size: 60)
                            VStack(alignment: .leading) {
                                Text("ARGUS")
                                    .font(.largeTitle)
                                    .bold()
                                    .tracking(2)
                                    .foregroundColor(Theme.tint)
                                Text("TEMEL ANALİZ MOTORU")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.gray)
                                    .tracking(1)
                            }
                        }
                        .padding(.bottom)
                        
                        // Description
                        InfoSection(title: "Argus Nedir?", text: "Argus, şirketin finansal tablolarını (bilanço, gelir tablosu, nakit akışı) derinlemesine analiz eden yapay zeka destekli bir temel analiz motorudur. Gerçek borsa verilerini kullanır.")
                        
                        InfoSection(title: "Skor Nasıl Hesaplanır?", text: "0 ile 100 arasında bir puan üretilir. Bu puan 4 ana kategorinin ağırlıklı ortalamasıdır:\n\n• Karlılık (%30)\n• Büyüme (%25)\n• Borç/Risk (%25)\n• Nakit Kalitesi (%20)")
                        
                        // Score Ranges
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Skor Anlamları")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ScoreRangeRow(range: "70 - 100", label: "Güçlü / Alınabilir", color: Theme.positive)
                            ScoreRangeRow(range: "50 - 69", label: "Nötr / İzle", color: Theme.warning)
                            ScoreRangeRow(range: "0 - 49", label: "Riskli / Zayıf", color: Theme.negative)
                        }
                        .padding()
                        .background(Theme.secondaryBackground)
                        .cornerRadius(12)
                        
                        InfoSection(title: "Veri Güvenilirliği", text: "Argus, Alpha Vantage ve Finnhub üzerinden sağlanan resmi ve gerçek finansal raporları kullanır. Asla tahmin veya uydurma veri içermez.")
                        
                        Spacer()
                    }
                    .padding(24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Kapat") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct InfoSection: View {
    let title: String
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(text)
                .font(.body)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ScoreRangeRow: View {
    let range: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(range)
                .font(.subheadline)
                .bold()
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            Text(label)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
            
            Spacer()
            
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        }
    }
}
