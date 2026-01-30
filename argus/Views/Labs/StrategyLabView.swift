import SwiftUI

struct StrategyLabView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Aktif Stratejiler")) {
                    StrategyRow(name: "Momentum Hunter", signal: "AL", performance: "+12.4%")
                    StrategyRow(name: "Dip Finder v2", signal: "NÖTR", performance: "+5.1%")
                    StrategyRow(name: "Volatility Breakout", signal: "SAT", performance: "-1.2%")
                }
                
                Section(header: Text("Geliştirme Ortamı")) {
                    Text("Yeni Strateji Oluştur")
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Strateji Merkezi")
        }
    }
}

struct StrategyRow: View {
    let name: String
    let signal: String
    let performance: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text("Sinyal: \(signal)")
                    .font(.caption)
                    .foregroundColor(signal == "AL" ? .green : (signal == "SAT" ? .red : .gray))
            }
            Spacer()
            Text(performance)
                .font(.subheadline)
                .bold()
                .foregroundColor(performance.hasPrefix("+") ? .green : .red)
        }
    }
}
