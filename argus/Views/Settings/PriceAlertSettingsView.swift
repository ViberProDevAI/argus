import SwiftUI
import Combine

// MARK: - Local scan model (PriceAlertSettingsView only)

private struct PriceAlertItem: Identifiable {
    let id = UUID()
    let symbol: String
    let date: Date
    let message: String
    let type: AlertType
    let score: Double

    enum AlertType { case buy, sell, neutral }
}

@MainActor
private final class PriceAlertScanService: ObservableObject {
    @Published var alerts: [PriceAlertItem] = []
    @Published var isScanning = false

    func scanWatchlist(symbols: [String]) async {
        isScanning = true
        alerts = []

        for symbol in symbols {
            do {
                let candles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1D", limit: 365)
                let config = BacktestConfig(strategy: .orionV2)
                let result = await ArgusBacktestEngine.shared.runBacktest(
                    symbol: symbol,
                    config: config,
                    candles: candles,
                    financials: nil
                )
                let score = result.winRate
                if result.totalReturn > 10 && score > 60 {
                    let item = PriceAlertItem(symbol: symbol, date: Date(),
                                             message: "Güçlü AL Sinyali (Güven: %\(Int(score)))",
                                             type: .buy, score: score)
                    alerts.append(item)
                } else if result.totalReturn < -10 && score < 40 {
                    let item = PriceAlertItem(symbol: symbol, date: Date(),
                                             message: "Güçlü SAT Sinyali (Getiri: %\(Int(result.totalReturn)))",
                                             type: .sell, score: 100 - score)
                    alerts.append(item)
                }
            } catch {
                print("PriceAlertScan error for \(symbol): \(error)")
            }
        }

        isScanning = false
        saveToWidget()
    }

    private func saveToWidget() {
        let widgetData = alerts.prefix(3).map { alert in
            ["symbol": alert.symbol, "score": alert.score,
             "type": alert.type == .buy ? "buy" : "sell",
             "message": alert.message] as [String: Any]
        }
        if let ud = UserDefaults(suiteName: "group.com.argus.Algo-Trading") {
            ud.set(widgetData, forKey: "widgetSignals")
        }
    }
}

// MARK: - View

struct PriceAlertSettingsView: View {
    @StateObject private var scanner = PriceAlertScanService()
    @State private var infoMessage: String?

    // 2026-05-09: Settings → Fiyat alarmları NavigationLink ile push'lanıyor
    // ama leadingDeco `.bars3` olduğundan geri butonu yoktu. Kullanıcı geri
    // dönemiyordu. `\.dismiss` ile push'u doğru pop'layan back chevron'a
    // geçildi.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "FİYAT ALARMLARI",
                subtitle: "WATCHLIST · TARAYICI · SİNYAL",
                leadingDeco: .back(onTap: { dismiss() }),
                actions: [
                    .custom(sfSymbol: scanner.isScanning ? "stop.circle" : "arrow.clockwise",
                            action: {
                                guard !scanner.isScanning else { return }
                                Task {
                                    let storedWatchlist = ArgusStorage.shared.loadWatchlist()
                                    if storedWatchlist.isEmpty {
                                        infoMessage = "İzleme listesi boş. Önce hisse ekleyin."
                                        return
                                    }
                                    await scanner.scanWatchlist(symbols: storedWatchlist)
                                }
                            })
                ]
            )

            List {
                Section(header: Text("Durum")) {
                    if scanner.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Piyasa Taranıyor...")
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    } else {
                        Button(action: {
                            Task {
                                let storedWatchlist = ArgusStorage.shared.loadWatchlist()
                                if storedWatchlist.isEmpty {
                                    infoMessage = "İzleme listesi boş. Önce hisse ekleyin."
                                    return
                                }
                                await scanner.scanWatchlist(symbols: storedWatchlist)
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
                    if scanner.alerts.isEmpty {
                        Text("Henüz sinyal yok.")
                            .foregroundColor(DesignTokens.Colors.textSecondary)
                            .italic()
                    } else {
                        ForEach(scanner.alerts) { alert in
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
                                        .foregroundColor(DesignTokens.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationBarHidden(true)
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .alert("Bilgi", isPresented: Binding(get: { infoMessage != nil }, set: { _ in infoMessage = nil })) {
            Button("Tamam") { }
        } message: {
            Text(infoMessage ?? "")
        }
    }
}
