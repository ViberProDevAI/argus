import SwiftUI

struct PriceAlertSettingsView: View {
    @ObservedObject var alertManager = AlertManager.shared
    
    var body: some View {
        List {
            Section(header: Text("Durum")) {
                if alertManager.isScanning {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Piyasa Taranıyor...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: {
                        Task {
                            // Fetch real watchlist
                            let storedWatchlist = ArgusStorage.shared.loadWatchlist()
                            await alertManager.scanWatchlist(symbols: storedWatchlist.isEmpty ? ["AAPL", "BTC-USD"] : storedWatchlist)
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Şimdi Tara")
                        }
                    }
                }
            }
            
            Section(header: Text("Son Sinyaller")) {
                if alertManager.alerts.isEmpty {
                    Text("Henüz sinyal yok.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(alertManager.alerts) { alert in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(alert.symbol)
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(alert.type == .buy ? "AL" : "SAT")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(4)
                                    .background(alert.type == .buy ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .foregroundColor(alert.type == .buy ? .green : .red)
                                    .cornerRadius(4)
                                
                                Text("%\(Int(alert.score)) Güven")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Fiyat Alarmları")
        .listStyle(InsetGroupedListStyle())
    }
}
