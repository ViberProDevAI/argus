import Foundation

/// Generates premium quality Daily and Weekly summaries for the user.
/// Aggregates Trade Log, Decision Trace, Market Atmosphere, and Alkindus Insights.
/// "Aşırı öğretici" - Her rapor bir öğrenme fırsatı
actor ReportEngine {
    static let shared = ReportEngine()

    private let storagePath: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("reports")
    }()

    private init() {
        try? FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
    }

    // MARK: - Report Storage

    struct StoredReport: Codable {
        let id: UUID
        let type: ReportType
        let date: Date
        let content: String
        let metrics: ReportMetrics
    }

    struct ReportMetrics: Codable {
        let totalTrades: Int
        let winRate: Double
        let totalPnL: Double
        let topInsight: String?
    }

    enum ReportType: String, Codable {
        case daily = "GÜNLÜK"
        case weekly = "HAFTALIK"
    }

    /// Saves report to persistent storage
    private func saveReport(_ report: StoredReport) async {
        let filename = "\(report.type.rawValue)_\(ISO8601DateFormatter().string(from: report.date)).json"
        let fileURL = storagePath.appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: fileURL)
    }

    /// Gets recent reports
    func getRecentReports(limit: Int = 10) async -> [StoredReport] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storagePath, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }

        var reports: [StoredReport] = []
        for file in files.suffix(limit) {
            guard let data = try? Data(contentsOf: file),
                  let report = try? JSONDecoder().decode(StoredReport.self, from: data) else { continue }
            reports.append(report)
        }
        return reports.sorted { $0.date > $1.date }
    }
    
    // MARK: - Daily Report (Enhanced with Alkindus)

    func generateDailyReport(
        date: Date = Date(),
        trades: [Transaction],
        decisions: [AgoraTrace],
        atmosphere: (aether: Double?, demeter: CorrelationMatrix?)
    ) async -> String {

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy, EEEE"
        formatter.locale = Locale(identifier: "tr_TR")
        let dateStr = formatter.string(from: date)

        var report = """
## [RAPOR] ARGUS GUNLUK ANALIZ | \(dateStr)

"""

        // 1. Alkindus Ogrenme Ozeti
        report += """
## [OGREN] BUGUN OGRENDIKLERIN (ALKINDUS)

"""

        let insights = await AlkindusInsightGenerator.shared.getTodaysInsights()

        print("[RAPOR] ReportEngine: Daily - Alkindus Insights count: \(insights.count)")
        if insights.isEmpty {
            report += "   Henüz yeterli veri biriktirilmedi. Alkindus öğrenmeye devam ediyor...\n"
        } else {
            for insight in insights.prefix(5) {
                let icon = insightEmoji(for: insight.category)
                let importance = insight.importance == .critical ? "[!]" : (insight.importance == .high ? "[*]" : "")
                report += "   \(icon) \(importance)\(insight.title)\n"
                report += "      └─ \(insight.detail)\n\n"
            }
        }

        // Temporal pattern advice
        if let timeAdvice = await AlkindusTemporalAnalyzer.shared.getCurrentTimeAdvice() {
            report += "   [TIME] Zaman Örüntüsü: \(timeAdvice)\n\n"
        }

        // 2. Makro Atmosfer
        report += """

## [MAKRO] ORTAM (AETHER)

"""
        if let aether = atmosphere.aether {
            let (regime, explanation) = explainRegime(score: aether)
            report += """
   Rejim: \(regime) | Skor: \(Int(aether))/100

   [?] Ne Anlama Geliyor?
   \(explanation)

"""
        } else {
            report += "   Veri bekleniyor...\n\n"
        }

        // 3. İşlem Özeti
        report += """
## [ISLEM] GUNUN ISLEMLERI

"""
        let todayTrades = trades.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if todayTrades.isEmpty {
            report += "   Bugün işlem yapılmadı.\n\n"
        } else {
            let buys = todayTrades.filter { $0.type == .buy }
            let sells = todayTrades.filter { $0.type == .sell }
            let totalPnL = sells.compactMap { $0.pnl }.reduce(0, +)
            let winCount = sells.filter { ($0.pnl ?? 0) > 0 }.count
            let lossCount = sells.filter { ($0.pnl ?? 0) < 0 }.count
            let winRate = sells.count > 0 ? Double(winCount) / Double(sells.count) * 100 : 0

            report += """
   [STATS] Özet İstatistikler
   ├─ Alım: \(buys.count) | Satım: \(sells.count)
   ├─ Net K/Z: \(totalPnL >= 0 ? "+" : "")\(String(format: "%.2f", totalPnL))
   └─ Başarı: %\(String(format: "%.0f", winRate)) (\(winCount)W/\(lossCount)L)

   [LIST] Her İşlemin Detayı:
"""
            for trade in todayTrades.prefix(8) {
                let timeF = DateFormatter()
                timeF.dateFormat = "HH:mm"
                let time = timeF.string(from: trade.date)
                let arrow = trade.type == .buy ? "[+]" : "[-]"
                let currency = trade.symbol.hasSuffix(".IS") ? "₺" : "$"

                report += "   \(time) \(arrow) \(trade.symbol.padding(toLength: 8, withPad: " ", startingAt: 0)) \(currency)\(String(format: "%.2f", trade.price))"

                if trade.type == .sell, let pnl = trade.pnl {
                    let pnlStr = pnl >= 0 ? "+\(String(format: "%.2f", pnl))" : String(format: "%.2f", pnl)
                    report += " -> \(pnlStr)"
                }
                report += "\n"
            }
            report += "\n"
        }

        // 4. Karar Motoru Analizi
        report += """
## [KARAR] KARAR MOTORU ANALIZI (ARGUS)

"""
        let todayDecisions = decisions.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        let approved = todayDecisions.filter { $0.finalDecision.action == .buy || $0.finalDecision.action == .sell }
        let vetoed = todayDecisions.filter {
            $0.finalDecision.action == .hold && ($0.debate.claimant?.preferredAction == .buy || $0.debate.claimant?.preferredAction == .sell)
        }

        report += """
   Toplam Analiz: \(todayDecisions.count) | Onay: \(approved.count) | Veto: \(vetoed.count)

"""

        if !vetoed.isEmpty {
            report += "   [X] VETO EDİLEN İŞLEMLER (Neden yapılmadı?)\n"
            report += "   ┌──────────┬──────┬────────────────────────────────┐\n"
            report += "   │ Sembol   │ Yön  │ Neden                          │\n"
            report += "   ├──────────┼──────┼────────────────────────────────┤\n"

            for d in vetoed.prefix(5) {
                let dir = d.debate.claimant?.preferredAction == .buy ? "AL" : "SAT"
                let reason = (!d.riskEvaluation.isApproved) ? d.riskEvaluation.reason : d.finalDecision.rationale
                let shortReason = String(reason.prefix(30))
                report += "   │ \(d.symbol.padding(toLength: 8, withPad: " ", startingAt: 0)) │ \(dir.padding(toLength: 4, withPad: " ", startingAt: 0)) │ \(shortReason.padding(toLength: 30, withPad: " ", startingAt: 0)) │\n"
            }
            report += "   └──────────┴──────┴────────────────────────────────┘\n\n"

            report += "   [?] Neden Önemli?\n"
            report += "      Veto edilen işlemler, sistemin sizi koruma mekanizmasıdır.\n"
            report += "      Risk yönetimi, kar etmekten daha önemlidir.\n\n"
        }

        // 5. Eğitici Kapanış
        report += """
## [DERS] GUNUN DERSI

   \(getDailyLesson(trades: todayTrades, decisions: todayDecisions))

═══════════════════════════════════════════════════════════════
                    Argus Terminal | Alkindus Öğrenme Sistemi
                    Bu rapor yatırım tavsiyesi değildir.
═══════════════════════════════════════════════════════════════
"""

        // Save report
        let totalPnL = todayTrades.compactMap { $0.pnl }.reduce(0, +)
        let winCount = todayTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let winRate = todayTrades.count > 0 ? Double(winCount) / Double(todayTrades.count) : 0

        let stored = StoredReport(
            id: UUID(),
            type: .daily,
            date: date,
            content: report,
            metrics: ReportMetrics(
                totalTrades: todayTrades.count,
                winRate: winRate,
                totalPnL: totalPnL,
                topInsight: insights.first?.title
            )
        )
        await saveReport(stored)

        return report
    }

    // MARK: - Weekly Report (Enhanced with Alkindus)

    func generateWeeklyReport(
        date: Date = Date(),
        trades: [Transaction],
        decisions: [AgoraTrace]
    ) async -> String {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let weekEnd = date

        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        let rangeStr = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"

        var report = """
## [HAFTA] ARGUS HAFTALIK PERFORMANS | \(rangeStr)

"""

        // 1. Alkindus Haftalık Öğrenmeler
        report += """
## [OGREN] BU HAFTA OGRENDIKLERIN (ALKINDUS)

"""

        let recentInsights = await AlkindusInsightGenerator.shared.getRecentInsights(days: 7)
        print("[RAPOR] ReportEngine: Weekly - Alkindus Insights count: \(recentInsights.count)")
        if recentInsights.isEmpty {
            report += "   Yeterli öğrenme verisi henüz biriktirilmedi.\n\n"
        } else {
            // Group by category
            let grouped = Dictionary(grouping: recentInsights, by: { $0.category })
            for (category, categoryInsights) in grouped.prefix(4) {
                report += "   [*] \(category.rawValue)\n"
                for insight in categoryInsights.prefix(2) {
                    report += "      • \(insight.detail)\n"
                }
                report += "\n"
            }
        }

        // Temporal patterns
        let anomalies = await AlkindusTemporalAnalyzer.shared.getTemporalAnomalies()
        if !anomalies.isEmpty {
            report += "   [TIME] Kesfedilen Zaman Oruntuleri:\n"
            for anomaly in anomalies.prefix(3) {
                let direction = anomaly.deviation > 0 ? "[+]" : "[-]"
                report += "      \(direction) \(anomaly.message)\n"
            }
            report += "\n"
        }

        // 2. Performans Özeti
        report += """
## [STATS] HAFTALIK PERFORMANS OZETI

"""
        let weeklyTrades = trades.filter { $0.date >= weekStart && $0.date <= weekEnd }
        let weeklyDecisions = decisions.filter { $0.timestamp >= weekStart && $0.timestamp <= weekEnd }

        if weeklyTrades.isEmpty {
            report += "   Bu hafta işlem gerçekleştirilmedi.\n\n"
        } else {
            let sells = weeklyTrades.filter { $0.type == .sell }
            let totalPnL = sells.compactMap { $0.pnl }.reduce(0, +)
            let winCount = sells.filter { ($0.pnl ?? 0) > 0 }.count
            let lossCount = sells.filter { ($0.pnl ?? 0) < 0 }.count
            let winRate = sells.count > 0 ? Double(winCount) / Double(sells.count) * 100 : 0
            let hasBist = weeklyTrades.contains { $0.symbol.hasSuffix(".IS") }
            let currency = hasBist ? "₺" : "$"

            report += """
   ┌────────────────────┬────────────────────┐
   │ Net Kar/Zarar      │ \(currency)\(String(format: "%15.2f", totalPnL)) │
   ├────────────────────┼────────────────────┤
   │ Toplam İşlem       │ \(String(format: "%18d", weeklyTrades.count)) │
   │ Başarı Oranı       │ \(String(format: "%17.1f", winRate))% │
   │ Kazanan/Kaybeden   │ \(String(format: "%11d", winCount))W / \(String(format: "%dL", lossCount).padding(toLength: 4, withPad: " ", startingAt: 0)) │
   └────────────────────┴────────────────────┘

"""

            // Best and worst trades
            if let best = sells.max(by: { ($0.pnl ?? 0) < ($1.pnl ?? 0) }), let bestPnL = best.pnl, bestPnL > 0 {
                report += "   [BEST] Haftanin Yildizi: \(best.symbol) (+\(currency)\(String(format: "%.2f", bestPnL)))\n"
            }
            if let worst = sells.min(by: { ($0.pnl ?? 0) < ($1.pnl ?? 0) }), let worstPnL = worst.pnl, worstPnL < 0 {
                report += "   [WORST] En Kotu Islem: \(worst.symbol) (\(currency)\(String(format: "%.2f", worstPnL)))\n"
            }
            report += "\n"
        }

        // 3. Karar Kalitesi Analizi
        report += """
## [KARAR] KARAR KALITESI ANALIZI

"""
        let vetoes = weeklyDecisions.filter { !$0.riskEvaluation.isApproved }

        report += "   Değerlendirilen Fırsat: \(weeklyDecisions.count)\n"
        report += "   Veto Edilen: \(vetoes.count)\n\n"

        if !vetoes.isEmpty {
            var reasons: [String: Int] = [:]
            for v in vetoes {
                reasons[v.riskEvaluation.reason, default: 0] += 1
            }

            report += "   [INFO] En Sik Veto Sebepleri:\n"
            for (reason, count) in reasons.sorted(by: { $0.value > $1.value }).prefix(3) {
                report += "      • \(reason): \(count) kez\n"
            }
            report += "\n"
        }

        // 4. Eğitici Özet
        report += """
## [DERS] HAFTANIN DERSLERI

   \(getWeeklyLessons(trades: weeklyTrades, decisions: weeklyDecisions))

═══════════════════════════════════════════════════════════════
                    Argus Terminal | Alkindus Öğrenme Sistemi
═══════════════════════════════════════════════════════════════
"""

        // Save report
        let totalPnL = weeklyTrades.compactMap { $0.pnl }.reduce(0, +)
        let winCount = weeklyTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let winRate = weeklyTrades.count > 0 ? Double(winCount) / Double(weeklyTrades.count) : 0

        let stored = StoredReport(
            id: UUID(),
            type: .weekly,
            date: date,
            content: report,
            metrics: ReportMetrics(
                totalTrades: weeklyTrades.count,
                winRate: winRate,
                totalPnL: totalPnL,
                topInsight: recentInsights.first?.title
            )
        )
        await saveReport(stored)

        return report
    }

    // MARK: - Helper Functions

    private func insightEmoji(for category: AlkindusInsightGenerator.InsightCategory) -> String {
        switch category {
        case .correlation: return "[LINK]"
        case .anomaly: return "[!]"
        case .trend: return "[TREND]"
        case .performance: return "[PERF]"
        case .regime: return "[REJIM]"
        case .warning: return "[UYARI]"
        case .discovery: return "[KESIF]"
        }
    }

    private func explainRegime(score: Double) -> (String, String) {
        if score > 70 {
            return ("RISK-ON (Boğa)", """
      Piyasa risk iştahı yüksek. Yatırımcılar agresif pozisyonlar alıyor.
      Bu ortamda momentum stratejileri iyi çalışır, ancak dikkatli ol -
      aşırı iyimserlik genellikle düzeltmelerin habercisidir.
""")
        } else if score > 55 {
            return ("TEMKINLI BOĞA", """
      Piyasa pozitif ama temkinli. Seçici olmak önemli.
      Kaliteli hisselerde fırsat aranabilir, ama pozisyon boyutu küçük tutulmalı.
""")
        } else if score > 45 {
            return ("NÖTR", """
      Piyasa kararsız. Net bir yön yok.
      Bu ortamda en iyisi beklemek veya çok seçici olmak.
      İşlem sayısını minimumda tut.
""")
        } else if score > 30 {
            return ("TEMKİNLİ AYI", """
      Piyasa negatif eğilimli. Risk algısı yükseliyor.
      Defansif sektörlere yönel, nakit pozisyonunu artır.
      Short pozisyonlar değerlendirilebilir.
""")
        } else {
            return ("RISK-OFF (Ayı)", """
      Piyasa ciddi stres altında. Korku hakim.
      Nakit en değerli pozisyon olabilir.
      Kontrarian fırsatlar için sabırlı ol - panik satışları fırsat yaratır.
""")
        }
    }

    private func getDailyLesson(trades: [Transaction], decisions: [AgoraTrace]) -> String {
        let lessons = [
            "Sabırlı olmak, işlem yapmak kadar önemlidir.",
            "Risk yönetimi, kâr etmekten önce gelir.",
            "Piyasa her zaman haklıdır - ego değil, veri takip et.",
            "Küçük kayıplar normal, büyük kayıplar affedilmez.",
            "En iyi işlem bazen hiç işlem yapmamaktır.",
            "Trend dostundur - ona karşı savaşma.",
            "Diversifikasyon riski azaltır, ama aşırısı getiriyi de azaltır.",
            "Duygusal kararlar portföy katilidir."
        ]

        // Context-aware lesson
        let sells = trades.filter { $0.type == .sell }
        let losses = sells.filter { ($0.pnl ?? 0) < 0 }

        if losses.count > sells.count / 2 && !sells.isEmpty {
            return "Bugün kayıplar ağır bastı. Hatırla: Her kayıp bir öğrenme fırsatıdır.\n      Pozisyon boyutunu kontrol altında tutmak, büyük kayıpları önler."
        }

        let vetoes = decisions.filter { !$0.riskEvaluation.isApproved }
        if vetoes.count > decisions.count / 2 && !decisions.isEmpty {
            return "Sistem bugün çok sayıda fırsatı reddetti. Bu iyi bir şey!\n      Seçici olmak, uzun vadede kazandırır."
        }

        return lessons.randomElement() ?? lessons[0]
    }

    private func getWeeklyLessons(trades: [Transaction], decisions: [AgoraTrace]) -> String {
        let sells = trades.filter { $0.type == .sell }
        let totalPnL = sells.compactMap { $0.pnl }.reduce(0, +)
        let winRate = sells.isEmpty ? 0 : Double(sells.filter { ($0.pnl ?? 0) > 0 }.count) / Double(sells.count)

        var lessons: [String] = []

        if totalPnL > 0 {
            lessons.append("[+] Pozitif hafta! Ama dikkat - basari kibire yol acmasin.")
        } else if totalPnL < 0 {
            lessons.append("[-] Negatif hafta. Kayiplari analiz et, ama kendini yipratma.")
        }

        if winRate < 0.4 && !sells.isEmpty {
            lessons.append("[STATS] Win rate dusuk. Giris noktalarini gozden gecir.")
        } else if winRate > 0.6 && !sells.isEmpty {
            lessons.append("[PERF] Win rate yuksek! Stratejin calisiyor.")
        }

        if trades.isEmpty {
            lessons.append("[INFO] Islem yapmamak da bir stratejidir. Bazen beklemek en iyi hamledir.")
        }

        return lessons.joined(separator: "\n   ")
    }
}
