import SwiftUI

// MARK: - Chiron Performance View (Argus 3.0 Refactor)
/// Displays scientific performance metrics from Argus Ledger (SQLite)
/// Replaces legacy RAM-based ChironDecisionLog
struct ChironPerformanceView: View {
    @State private var tradeHistory: [TradeRecord] = []
    @State private var learningEvents: [LearningEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Learning Events (Weight Updates)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.purple)
                        Text("Observatory: Öğrenme Günlüğü")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    if learningEvents.isEmpty {
                        Text("Henüz kaydedilmiş ağırlık değişimi yok.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(learningEvents.prefix(3)) { event in
                            PerformanceLearningCard(event: event)
                        }
                    }
                }
                .padding()
                .background(Theme.cardBackground)
                .cornerRadius(12)
                
                // 2. Trade History (Ledger)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                            .foregroundColor(.blue)
                        Text("İşlem Geçmişi (Argus Ledger)")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView().tint(.white)
                            .padding()
                    } else if tradeHistory.isEmpty {
                        Text("Henüz kapanmış işlem kaydı yok.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(tradeHistory) { trade in
                            TradeHistoryCard(trade: trade, lesson: nil)
                        }
                    }
                }
            }
            .padding()
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        // Fetch real data from SQLite
        self.tradeHistory = await ArgusLedger.shared.getClosedTrades(limit: 20)
        self.learningEvents = await ArgusLedger.shared.loadLearningEvents(limit: 5)
        isLoading = false
    }
}

// MARK: - Subviews

struct PerformanceLearningCard: View {
    let event: LearningEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.reason)
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                Spacer()
                Text(event.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text(event.summaryText)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.purple)
        }
        .padding(8)
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.3), lineWidth: 1))
    }
}

