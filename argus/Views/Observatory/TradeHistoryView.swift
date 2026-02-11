import SwiftUI

// MARK: - Trade History View
/// Forward test verilerini gösteren UI - Chiron öğrenme geçmişi
struct TradeHistoryView: View {
    @State private var trades: [TradeOutcomeRecord] = []
    @State private var isLoading = true
    @State private var selectedFilter: TradeFilter = .all
    
    enum TradeFilter: String, CaseIterable {
        case all = "Tümü"
        case wins = "Kazançlar"
        case losses = "Kayıplar"
    }
    
    var filteredTrades: [TradeOutcomeRecord] {
        switch selectedFilter {
        case .all: return trades
        case .wins: return trades.filter { $0.pnlPercent > 0 }
        case .losses: return trades.filter { $0.pnlPercent <= 0 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Stats
            TradeStatsHeader(trades: trades)
                .padding()
                .background(Color.black.opacity(0.3))
            
            // Filter Picker
            Picker("Filtre", selection: $selectedFilter) {
                ForEach(TradeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Trade List
            if isLoading {
                Spacer()
                ProgressView("Trade geçmişi yükleniyor...")
                    .foregroundColor(.gray)
                Spacer()
            } else if filteredTrades.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Henüz trade kaydı yok")
                        .foregroundColor(.gray)
                    Text("Forward test verileri burada görünecek")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                Spacer()
            } else {
                List(filteredTrades, id: \.id) { trade in
                    TradeRowView(trade: trade)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Trade Geçmişi")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .task {
            await loadTrades()
        }
        .refreshable {
            await loadTrades()
        }
    }
    
    private func loadTrades() async {
        isLoading = true
        trades = await ChironDataLakeService.shared.loadAllTradeHistory()
        isLoading = false
    }
}

// MARK: - Stats Header
struct TradeStatsHeader: View {
    let trades: [TradeOutcomeRecord]
    
    var winCount: Int { trades.filter { $0.pnlPercent > 0 }.count }
    var lossCount: Int { trades.filter { $0.pnlPercent <= 0 }.count }
    var winRate: Double {
        guard !trades.isEmpty else { return 0 }
        return Double(winCount) / Double(trades.count) * 100
    }
    var avgPnl: Double {
        guard !trades.isEmpty else { return 0 }
        return trades.map { $0.pnlPercent }.reduce(0, +) / Double(trades.count)
    }
    var totalPnl: Double {
        trades.map { $0.pnlPercent }.reduce(0, +)
    }
    
    var body: some View {
        HStack(spacing: 20) {
            TradeStatBox(title: "Toplam", value: "\(trades.count)", color: .cyan)
            TradeStatBox(title: "Kazanç", value: "%\(String(format: "%.1f", winRate))", color: winRate >= 50 ? .green : .orange)
            TradeStatBox(title: "Ort. PnL", value: "\(avgPnl >= 0 ? "+" : "")\(String(format: "%.1f", avgPnl))%", color: avgPnl >= 0 ? .green : .red)
            TradeStatBox(title: "Top. PnL", value: "\(totalPnl >= 0 ? "+" : "")\(String(format: "%.1f", totalPnl))%", color: totalPnl >= 0 ? .green : .red)
        }
    }
}

struct TradeStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Trade Row
struct TradeRowView: View {
    let trade: TradeOutcomeRecord
    
    var isWin: Bool { trade.pnlPercent > 0 }
    
    var body: some View {
        HStack(spacing: 12) {
            // Indicator
            Circle()
                .fill(isWin ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            // Symbol & Engine
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.symbol)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(trade.engine.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.7))
            }
            
            Spacer()
            
            // Entry -> Exit
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.2f", trade.entryPrice)) → \(String(format: "%.2f", trade.exitPrice))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                Text(formatDate(trade.exitDate))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            
            // PnL
            Text("\(isWin ? "+" : "")\(String(format: "%.1f", trade.pnlPercent))%")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isWin ? .green : .red)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isWin ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TradeHistoryView()
    }
}
