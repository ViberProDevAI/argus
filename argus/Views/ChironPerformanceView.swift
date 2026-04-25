import SwiftUI

// MARK: - Chiron Performance View (Argus 3.0 Refactor)
/// Displays scientific performance metrics from Argus Ledger (SQLite)
/// Replaces legacy RAM-based ChironDecisionLog
struct ChironPerformanceView: View {
    @State private var tradeHistory: [TradeRecord] = []
    @State private var learningEvents: [LearningEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            ArgusNavHeader(
                title: "CHIRON PERFORMANS",
                subtitle: "ÖĞRENME · İŞLEM · LEDGER",
                leadingDeco: .bars3([.holo, .text, .text])
            )
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Learning Events (Weight Updates)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MotorLogo(.chiron, size: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                ArgusSectionCaption("ÖĞRENME GÜNLÜĞÜ")
                                Text("OBSERVATORY · AĞIRLIK GÜNCELLEMELERİ")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .tracking(0.6)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            }
                            Spacer()
                            ArgusChip("\(learningEvents.count)", tone: .motor(.chiron))
                        }
                        ArgusHair()
                        if learningEvents.isEmpty {
                            Text("Henüz kaydedilmiş ağırlık değişimi yok.")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(learningEvents.prefix(3)) { event in
                                PerformanceLearningCard(event: event)
                            }
                        }
                    }
                    .padding()
                    .background(InstitutionalTheme.Colors.surface1)
                    .cornerRadius(InstitutionalTheme.Radius.lg)

                    // 2. Trade History (Ledger)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            MotorLogo(.chiron, size: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                ArgusSectionCaption("İŞLEM GEÇMİŞİ")
                                Text("ARGUS LEDGER · KAPALI POZİSYON")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .tracking(0.6)
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            }
                            Spacer()
                            if !tradeHistory.isEmpty {
                                ArgusChip("\(tradeHistory.count)", tone: .neutral)
                            }
                        }
                        .padding(.horizontal)
                        ArgusHair().padding(.horizontal)

                        if isLoading {
                            ProgressView().tint(SanctumTheme.hologramBlue)
                                .padding()
                        } else if tradeHistory.isEmpty {
                            Text("Henüz kapanmış işlem kaydı yok.")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
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
        }
        .background(InstitutionalTheme.Colors.background.ignoresSafeArea())
        .navigationBarHidden(true)
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

