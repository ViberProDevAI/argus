import SwiftUI

// MARK: - Argus Lab View (Argus 3.0)
/// Birleşik UI: Açık/Kapalı işlemler, Öğrenmeler, Sistem Sağlığı

struct ArgusLabView: View {
    @StateObject private var viewModel = ArgusLabViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            Picker("", selection: $selectedTab) {
                Text("Açık").tag(0)
                Text("Kapalı").tag(1)
                Text("Öğrenmeler").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            TabView(selection: $selectedTab) {
                OpenTradesListView(trades: viewModel.openTrades)
                    .tag(0)
                
                ClosedTradesListView(trades: viewModel.closedTrades, lessons: viewModel.lessons)
                    .tag(1)
                
                LessonsListView(lessons: viewModel.lessons)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("🧪 Argus Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear { viewModel.refresh() }
    }
}

// MARK: - Open Trades List

struct OpenTradesListView: View {
    let trades: [TradeRecord]
    
    var body: some View {
        ScrollView {
            if trades.isEmpty {
                ArgusLabEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Açık İşlem Yok",
                    message: "AutoPilot aktif olduğunda işlemler burada görünecek."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(trades) { trade in
                        TradeCard(trade: trade, isOpen: true)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Closed Trades List

struct ClosedTradesListView: View {
    let trades: [TradeRecord]
    let lessons: [LessonRecord]
    
    init(trades: [TradeRecord], lessons: [LessonRecord] = []) {
        self.trades = trades
        self.lessons = lessons
    }
    
    var body: some View {
        ScrollView {
            if trades.isEmpty {
                ArgusLabEmptyState(
                    icon: "checkmark.circle",
                    title: "Kapalı İşlem Yok",
                    message: "Kapanan işlemler burada listenecek."
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(trades) { trade in
                        // TradeHistoryCard ile lesson eşleştir
                        let matchingLesson = lessons.first { $0.tradeId == trade.id }
                        TradeHistoryCard(trade: trade, lesson: matchingLesson)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Lessons List

struct LessonsListView: View {
    let lessons: [LessonRecord]
    
    var body: some View {
        ScrollView {
            if lessons.isEmpty {
                ArgusLabEmptyState(
                    icon: "books.vertical",
                    title: "Henüz Öğrenme Yok",
                    message: "İşlemler kapandıkça sistem otomatik olarak ders çıkaracak."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(lessons) { lesson in
                        ArgusLabLessonCard(lesson: lesson)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Trade Card

struct TradeCard: View {
    let trade: TradeRecord
    let isOpen: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(trade.symbol)
                    .font(.headline)
                    .bold()
                
                Spacer()
                
                if isOpen {
                    Text("AÇIK")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(8)
                } else {
                    let pnl = trade.pnlPercent ?? 0
                    Text(String(format: "%+.2f%%", pnl))
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(pnl >= 0 ? Color.green : Color.red)
                        .cornerRadius(8)
                }
            }
            
            // Details
            HStack {
                VStack(alignment: .leading) {
                    Text("Giriş: $\(String(format: "%.2f", trade.entryPrice))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let exit = trade.exitPrice {
                        Text("Çıkış: $\(String(format: "%.2f", exit))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let signal = trade.dominantSignal {
                    Text(signal)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(4)
                }
            }
            
            // Reason
            if let reason = trade.entryReason {
                Text(reason)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Lesson Card

struct ArgusLabLessonCard: View {
    let lesson: LessonRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text("Öğrenilen Ders")
                    .font(.headline)
                
                Spacer()
                
                if let dev = lesson.deviationPercent {
                    Text("Sapma: \(String(format: "%.1f", dev))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(lesson.lessonText)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            // Weight changes if any
            if let changes = lesson.weightChanges, !changes.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(changes.keys), id: \.self) { key in
                        if let value = changes[key] {
                            Text("\(key): \(value > 0 ? "+" : "")\(String(format: "%.2f", value))")
                                .font(.caption2)
                                .foregroundColor(value > 0 ? .green : .red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Empty State

struct ArgusLabEmptyState: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ArgusLabView()
}
