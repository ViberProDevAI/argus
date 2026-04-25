import SwiftUI

// MARK: - Trade History Card (Araştırma Raporundaki Mockup - Birebir)
/// Kullanıcının istediği "ne öğrendik" kartı.

struct TradeHistoryCard: View {
    let trade: TradeRecord
    let lesson: LessonRecord?
    
    // Computed
    private var pnlPercent: Double { trade.pnlPercent ?? 0 }
    private var isProfit: Bool { pnlPercent > 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // HEADER
            headerSection
            
            Divider().background(Color.white.opacity(0.1))
            
            // DETAYLAR
            detailsSection
            
            Divider().background(Color.white.opacity(0.1))
            
            // GİRİŞ SEBEBİ
            entryReasonSection
            
            Divider().background(Color.white.opacity(0.1))
            
            // NE ÖĞRENDİK
            if let lesson = lesson {
                lessonSection(lesson: lesson)
                
                Divider().background(Color.white.opacity(0.1))
                
                // SİSTEM AYARI
                if let changes = lesson.weightChanges, !changes.isEmpty {
                    weightAdjustmentSection(changes: changes)
                }
            } else {
                noLessonSection
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.cyan)
            
            Text("\(trade.symbol) İşlem Özeti")
                .font(.headline)
                .bold()
            
            Spacer()
            
            Text(isProfit ? "KARLI" : "ZARARLI")
                .font(.caption)
                .bold()
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isProfit ? Color.green : Color.red)
                .cornerRadius(8)
        }
        .padding()
    }
    
    // MARK: - Details
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text("Giriş: \(formattedDate(trade.entryDate)) @ $\(String(format: "%.2f", trade.entryPrice))")
                        .font(.subheadline)
                } icon: {
                    Text("")
                }
                
                Spacer()
            }
            
            if let exitDate = trade.exitDate, let exitPrice = trade.exitPrice {
                HStack {
                    Label {
                        Text("Çıkış: \(formattedDate(exitDate)) @ $\(String(format: "%.2f", exitPrice))")
                            .font(.subheadline)
                    } icon: {
                        Text("")
                    }
                    
                    Spacer()
                }
            }
            
            HStack {
                Label {
                    Text("Getiri: \(String(format: "%+.2f", pnlPercent))%")
                        .font(.headline)
                        .bold()
                        .foregroundColor(isProfit ? .green : .red)
                } icon: {
                    Text("")
                }
                
                Spacer()
            }
        }
        .padding()
    }
    
    // MARK: - Entry Reason
    
    private var entryReasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("")
                Text("Giriş Sebebi:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(trade.entryReason ?? "Bilgi yok")
                .font(.subheadline)
            
            if let dominant = trade.dominantSignal {
                HStack {
                    Text("Baskın Sinyal:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(dominant)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Lesson
    
    private func lessonSection(lesson: LessonRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("")
                Text("NE ÖĞRENDİK?")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.orange)
            }
            
            Text(lesson.lessonText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let deviation = lesson.deviationPercent {
                HStack {
                    Text("⚠️ Sapma:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.2f", deviation))%")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
    
    // MARK: - Weight Adjustment
    
    private func weightAdjustmentSection(changes: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("")
                Text("SİSTEM AYARI")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.cyan)
            }
            
            ForEach(Array(changes.keys.sorted()), id: \.self) { key in
                if let value = changes[key] {
                    HStack {
                        Text("•")
                        Text("\(key) Ağırlığı:")
                            .font(.caption)
                        
                        Spacer()
                        
                        Text(value > 0 ? "+\(String(format: "%.2f", value))" : String(format: "%.2f", value))
                            .font(.caption)
                            .bold()
                            .foregroundColor(value > 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(Color.cyan.opacity(0.1))
    }
    
    // MARK: - No Lesson
    
    private var noLessonSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("")
                Text("NE ÖĞRENDİK?")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
            }
            
            Text("Henüz analiz yapılmadı.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        TradeHistoryCard(
            trade: TradeRecord(
                id: UUID(),
                symbol: "AAPL",
                status: "CLOSED",
                entryDate: Date().addingTimeInterval(-86400 * 4),
                entryPrice: 185.50,
                entryReason: "Orion Momentum (82) + Atlas Kalite (75)",
                exitDate: Date(),
                exitPrice: 189.25,
                pnlPercent: 2.02,
                dominantSignal: "Orion",
                decisionId: nil
            ),
            lesson: LessonRecord(
                id: UUID(),
                tradeId: UUID(),
                createdAt: Date(),
                lessonText: "Makro rejim (Aether: Risk-Off) momentum sinyalinin güvenilirliğini düşürdü. Gelecekte benzer rejimlerde Quality ağırlığı artırılmalı.",
                deviationPercent: 1.48,
                weightChanges: ["Momentum": -0.02, "Quality": 0.02]
            )
        )
        .padding()
    }
    .background(Color.black)
}
