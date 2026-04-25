import Foundation

/// Günlük / haftalık kullanıcı raporları.
///
/// 2026-04-22 rewrite: Önceki sürüm ASCII tablo (`┌─┐ │ └─┘`) ve
/// `[STATS]`/`[OGREN]` tag gürültüsüyle doluydu — "AI imzası gibi"
/// görünüyordu. Bu sürüm:
/// - Doğal Türkçe başlıklar (markdown `## ...`)
/// - İşaretlenebilir madde listesi (`-`, `•`)
/// - Metrik satırı: `**Label:** value` — parser bunu pill olarak çizer
/// - ASCII tablo yok
/// - Emoji/etiket gürültüsü yok
/// - Veri odaklı cümleler: "Bugün X sinyal değerlendirildi, Y onay aldı"
actor ReportEngine {
    static let shared = ReportEngine()

    private let storagePath: URL = {
        FileManager.default.documentsURL.appendingPathComponent("reports")
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

    private func saveReport(_ report: StoredReport) async {
        let filename = "\(report.type.rawValue)_\(ISO8601DateFormatter().string(from: report.date)).json"
        let fileURL = storagePath.appendingPathComponent(filename)
        guard let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: fileURL)
    }

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

    // MARK: - Daily Report

    func generateDailyReport(
        date: Date = Date(),
        trades: [Transaction],
        decisions: [AgoraTrace],
        atmosphere: (aether: Double?, demeter: CorrelationMatrix?)
    ) async -> String {

        let dateStr = longDateString(date)
        let insights = await AlkindusInsightGenerator.shared.getTodaysInsights()
        let timeAdvice = await AlkindusTemporalAnalyzer.shared.getCurrentTimeAdvice()

        let todayTrades = trades.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        let buys = todayTrades.filter { $0.type == .buy }
        let sells = todayTrades.filter { $0.type == .sell }
        let totalPnL = sells.compactMap { $0.pnl }.reduce(0, +)
        let winCount = sells.filter { ($0.pnl ?? 0) > 0 }.count
        let lossCount = sells.filter { ($0.pnl ?? 0) < 0 }.count
        let winRate = sells.isEmpty ? 0 : Double(winCount) / Double(sells.count) * 100
        let pnlCurrency = todayTrades.first?.symbol.hasSuffix(".IS") == true ? "₺" : "$"

        let todayDecisions = decisions.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
        let approved = todayDecisions.filter { $0.finalDecision.action == .buy || $0.finalDecision.action == .sell }
        let vetoed = todayDecisions.filter {
            $0.finalDecision.action == .hold &&
            ($0.debate.claimant?.preferredAction == .buy || $0.debate.claimant?.preferredAction == .sell)
        }

        var md = "# Günlük Rapor · \(dateStr)\n\n"

        // —— 1. Net özet (TL;DR)
        md += "## Özet\n\n"
        if todayTrades.isEmpty {
            md += "Bugün hiç işlem yok. "
            if !todayDecisions.isEmpty {
                md += "Ama motor boş durmadı: \(todayDecisions.count) fırsat değerlendirildi, sistem \(vetoed.count) tanesini elemeye aldı.\n\n"
            } else {
                md += "Piyasa izlendi, aktif karar akışı olmadı.\n\n"
            }
        } else {
            let pnlSign = totalPnL >= 0 ? "+" : ""
            md += "Bugün **\(todayTrades.count) işlem** açıldı veya kapandı. "
            if !sells.isEmpty {
                md += "Kapanan pozisyonlar: **\(pnlSign)\(pnlCurrency)\(formatNumber(totalPnL, decimals: 2))** net K/Z "
                md += "(%\(Int(winRate.rounded())) başarı, \(winCount) kazanan / \(lossCount) kaybeden).\n\n"
            } else {
                md += "Bugün kapanış olmadı; \(buys.count) yeni alım hattı açıldı.\n\n"
            }
        }

        md += "**Net K/Z:** \(totalPnL >= 0 ? "+" : "")\(pnlCurrency)\(formatNumber(totalPnL, decimals: 2))\n"
        md += "**Başarı:** %\(Int(winRate.rounded()))\n"
        md += "**İşlem:** \(todayTrades.count)\n"
        md += "**Onay / Veto:** \(approved.count) / \(vetoed.count)\n\n"

        // —— 2. Alkindus içgörüleri
        md += "## Bugün ne öğrendik?\n\n"
        if insights.isEmpty {
            md += "Alkindus henüz yeterli veri biriktirmedi; kararlar birikince özgün içgörüler burada görünecek.\n\n"
        } else {
            for insight in insights.prefix(5) {
                let prefix = insight.importance == .critical ? "⚠︎ " :
                             (insight.importance == .high ? "◆ " : "• ")
                md += "\(prefix)**\(insight.title)** — \(insight.detail)\n"
            }
            md += "\n"
        }
        if let timeAdvice {
            md += "**Zaman örüntüsü:** \(timeAdvice)\n\n"
        }

        // —— 3. Piyasa ortamı
        md += "## Piyasa ortamı\n\n"
        if let aether = atmosphere.aether {
            let regime = regimeLabel(score: aether)
            md += "**Rejim:** \(regime)\n"
            md += "**Aether skoru:** \(Int(aether))/100\n\n"
            md += regimeNarrative(score: aether) + "\n\n"
        } else {
            md += "Aether verisi henüz güncellenmedi.\n\n"
        }

        // —— 4. İşlem detayı
        if !todayTrades.isEmpty {
            md += "## İşlemler\n\n"
            let timeF = DateFormatter()
            timeF.dateFormat = "HH:mm"
            for t in todayTrades.prefix(12) {
                let time = timeF.string(from: t.date)
                let action = t.type == .buy ? "AL" : "SAT"
                let cur = t.symbol.hasSuffix(".IS") ? "₺" : "$"
                var line = "- `\(time)` · **\(action)** \(t.symbol) · \(cur)\(formatNumber(t.price, decimals: 2))"
                if t.type == .sell, let pnl = t.pnl {
                    let sign = pnl >= 0 ? "+" : ""
                    line += " → \(sign)\(cur)\(formatNumber(pnl, decimals: 2))"
                }
                md += line + "\n"
            }
            if todayTrades.count > 12 {
                md += "- _+ \(todayTrades.count - 12) işlem daha_\n"
            }
            md += "\n"
        }

        // —— 5. Karar motoru
        if !todayDecisions.isEmpty {
            md += "## Karar motoru\n\n"
            md += "\(todayDecisions.count) fırsat değerlendirildi. **\(approved.count) onaylandı**, **\(vetoed.count) veto** edildi.\n\n"

            if !vetoed.isEmpty {
                md += "### En dikkat çeken vetolar\n\n"
                for d in vetoed.prefix(5) {
                    let dir = d.debate.claimant?.preferredAction == .buy ? "AL" : "SAT"
                    let reason = !d.riskEvaluation.isApproved
                        ? d.riskEvaluation.reason
                        : d.finalDecision.rationale
                    md += "- **\(d.symbol)** (\(dir)) — \(reason)\n"
                }
                md += "\nVeto, sistemin **korumacı refleksidir**. Reddettiği her işlem, ileride kapanacak bir pozisyondan kaçınma ihtimali taşır.\n\n"
            }
        }

        // —— 6. Günün dersi
        md += "## Günün dersi\n\n"
        md += dailyLesson(trades: todayTrades, decisions: todayDecisions) + "\n"

        // Save
        let stored = StoredReport(
            id: UUID(),
            type: .daily,
            date: date,
            content: md,
            metrics: ReportMetrics(
                totalTrades: todayTrades.count,
                winRate: winRate / 100.0,
                totalPnL: totalPnL,
                topInsight: insights.first?.title
            )
        )
        await saveReport(stored)

        return md
    }

    // MARK: - Weekly Report

    func generateWeeklyReport(
        date: Date = Date(),
        trades: [Transaction],
        decisions: [AgoraTrace]
    ) async -> String {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let rangeStr = "\(shortDateString(weekStart)) – \(shortDateString(date))"

        let weeklyTrades = trades.filter { $0.date >= weekStart && $0.date <= date }
        let weeklyDecisions = decisions.filter { $0.timestamp >= weekStart && $0.timestamp <= date }
        let sells = weeklyTrades.filter { $0.type == .sell }
        let totalPnL = sells.compactMap { $0.pnl }.reduce(0, +)
        let winCount = sells.filter { ($0.pnl ?? 0) > 0 }.count
        let lossCount = sells.filter { ($0.pnl ?? 0) < 0 }.count
        let winRate = sells.isEmpty ? 0 : Double(winCount) / Double(sells.count) * 100
        let hasBist = weeklyTrades.contains { $0.symbol.hasSuffix(".IS") }
        let currency = hasBist ? "₺" : "$"

        let recentInsights = await AlkindusInsightGenerator.shared.getRecentInsights(days: 7)
        let anomalies = await AlkindusTemporalAnalyzer.shared.getTemporalAnomalies()

        var md = "# Haftalık Rapor · \(rangeStr)\n\n"

        // —— 1. Özet
        md += "## Özet\n\n"
        if weeklyTrades.isEmpty {
            md += "Bu hafta işlem gerçekleşmedi. "
            if !weeklyDecisions.isEmpty {
                md += "Motor \(weeklyDecisions.count) fırsatı inceledi; hiçbiri kriteri karşılamadı.\n\n"
            } else {
                md += "Portföy beklemede kaldı.\n\n"
            }
        } else {
            let pnlSign = totalPnL >= 0 ? "+" : ""
            md += "Bu hafta **\(weeklyTrades.count) işlem** kaydedildi. "
            if !sells.isEmpty {
                md += "Kapanışlar: **\(pnlSign)\(currency)\(formatNumber(totalPnL, decimals: 2))** net, **%\(Int(winRate.rounded())) başarı** (\(winCount)K / \(lossCount)L).\n\n"
            }
        }

        md += "**Net K/Z:** \(totalPnL >= 0 ? "+" : "")\(currency)\(formatNumber(totalPnL, decimals: 2))\n"
        md += "**Başarı:** %\(Int(winRate.rounded()))\n"
        md += "**İşlem:** \(weeklyTrades.count)\n"
        md += "**Fırsat:** \(weeklyDecisions.count)\n\n"

        // —— 2. Yıldız + darbe
        if !sells.isEmpty {
            md += "## Haftanın sayfaları\n\n"
            if let best = sells.max(by: { ($0.pnl ?? 0) < ($1.pnl ?? 0) }),
               let bestPnL = best.pnl, bestPnL > 0 {
                md += "- ✨ **Yıldız:** \(best.symbol) — +\(currency)\(formatNumber(bestPnL, decimals: 2))\n"
            }
            if let worst = sells.min(by: { ($0.pnl ?? 0) < ($1.pnl ?? 0) }),
               let worstPnL = worst.pnl, worstPnL < 0 {
                md += "- ⛔︎ **Darbe:** \(worst.symbol) — \(currency)\(formatNumber(worstPnL, decimals: 2))\n"
            }
            md += "\n"
        }

        // —— 3. Bu hafta öğrendiklerim
        md += "## Bu hafta öğrendiklerim\n\n"
        if recentInsights.isEmpty {
            md += "Yedi günlük pencerede yeterli öğrenme verisi birikmedi.\n\n"
        } else {
            let grouped = Dictionary(grouping: recentInsights, by: { $0.category })
            for (category, list) in grouped.prefix(4) {
                md += "### \(category.rawValue)\n"
                for i in list.prefix(2) {
                    md += "- \(i.detail)\n"
                }
                md += "\n"
            }
        }

        if !anomalies.isEmpty {
            md += "### Zaman örüntüleri\n"
            for a in anomalies.prefix(3) {
                let sign = a.deviation > 0 ? "↑" : "↓"
                md += "- \(sign) \(a.message)\n"
            }
            md += "\n"
        }

        // —— 4. Karar kalitesi
        let vetoes = weeklyDecisions.filter { !$0.riskEvaluation.isApproved }
        md += "## Karar kalitesi\n\n"
        md += "Hafta boyunca **\(weeklyDecisions.count) fırsat** incelendi, **\(vetoes.count) tanesi veto** edildi.\n\n"
        if !vetoes.isEmpty {
            var reasons: [String: Int] = [:]
            for v in vetoes {
                reasons[v.riskEvaluation.reason, default: 0] += 1
            }
            md += "### En sık veto sebepleri\n"
            for (reason, count) in reasons.sorted(by: { $0.value > $1.value }).prefix(3) {
                md += "- **\(count)×** \(reason)\n"
            }
            md += "\n"
        }

        // —— 5. Haftanın dersleri
        md += "## Haftanın dersleri\n\n"
        md += weeklyLessons(trades: weeklyTrades, decisions: weeklyDecisions)
        md += "\n"

        let stored = StoredReport(
            id: UUID(),
            type: .weekly,
            date: date,
            content: md,
            metrics: ReportMetrics(
                totalTrades: weeklyTrades.count,
                winRate: winRate / 100.0,
                totalPnL: totalPnL,
                topInsight: recentInsights.first?.title
            )
        )
        await saveReport(stored)

        return md
    }

    // MARK: - Helpers

    private func longDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy, EEEE"
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: date)
    }

    private func shortDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: date)
    }

    private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
        let abs = Swift.abs(value)
        if abs >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        }
        if abs >= 10_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.\(decimals)f", value)
    }

    private func regimeLabel(score: Double) -> String {
        switch score {
        case 70...:  return "Risk-on"
        case 55...:  return "Temkinli boğa"
        case 45..<55: return "Nötr / kararsız"
        case 30..<45: return "Temkinli ayı"
        default:      return "Risk-off"
        }
    }

    private func regimeNarrative(score: Double) -> String {
        switch score {
        case 70...:
            return "Risk iştahı yüksek; momentum tarafında pozisyon avantajlı. Yine de aşırı iyimserlik genelde düzeltme habercisidir — pozisyon büyüklüğü disiplinli tutulmalı."
        case 55...:
            return "Piyasa pozitif ama temkinli. Kaliteli isimlerde seçici alım mantıklı, boyut ölçülü kalmalı."
        case 45..<55:
            return "Net yön yok. Bu ortamda sabır, agresyondan daha karlı. İşlem sayısı düşük tutulmalı."
        case 30..<45:
            return "Risk algısı yükseliyor. Defansif sektörler ve nakit pozisyonu ön plana çıkıyor."
        default:
            return "Piyasa stres altında. Nakit pozisyonu en değerli varlık olabilir. Panik satışları kontrarian fırsat yaratır, ama sabır şart."
        }
    }

    private func dailyLesson(trades: [Transaction], decisions: [AgoraTrace]) -> String {
        let sells = trades.filter { $0.type == .sell }
        let losses = sells.filter { ($0.pnl ?? 0) < 0 }
        if !sells.isEmpty && losses.count > sells.count / 2 {
            return "Bugün kayıplar ağır bastı. Her kayıp bir veri noktasıdır; pozisyon boyutunu disiplinde tutmak büyük hasarı önler."
        }
        let vetoes = decisions.filter { !$0.riskEvaluation.isApproved }
        if !decisions.isEmpty && vetoes.count > decisions.count / 2 {
            return "Sistem bugün çoğu fırsatı geri çevirdi. Seçicilik uzun vadede getiri üretir."
        }
        let fallbacks = [
            "Sabır, işlem yapmak kadar değerli.",
            "Risk yönetimi, kâr etmekten önce gelir.",
            "Piyasa her zaman haklıdır — ego değil veri takip edilir.",
            "Küçük kayıplar doğal, büyük kayıplar affedilmez.",
            "Bazen en iyi işlem, hiç işlem yapmamaktır.",
            "Trend dosttur; karşıya oynamak pahalıdır.",
            "Duygusal karar portföyün en sessiz katilidir."
        ]
        return fallbacks.randomElement() ?? fallbacks[0]
    }

    private func weeklyLessons(trades: [Transaction], decisions: [AgoraTrace]) -> String {
        let sells = trades.filter { $0.type == .sell }
        let totalPnL = sells.compactMap { $0.pnl }.reduce(0, +)
        let winRate = sells.isEmpty ? 0 : Double(sells.filter { ($0.pnl ?? 0) > 0 }.count) / Double(sells.count)

        var bullets: [String] = []
        if totalPnL > 0 {
            bullets.append("Pozitif hafta. Başarı, disiplini gevşetme zemini değil; pozisyon boyutu aynı tutulmalı.")
        } else if totalPnL < 0 {
            bullets.append("Negatif hafta. Kaybı analiz et — sistemik mi, tek seferlik mi ayırt et.")
        }
        if !sells.isEmpty {
            if winRate < 0.4 {
                bullets.append("Başarı oranı düşük. Giriş noktaları ve entry filtresi gözden geçirilmeli.")
            } else if winRate > 0.6 {
                bullets.append("Başarı oranı yüksek. Strateji tutuyor; taşmadan sürdürmek en büyük iş.")
            }
        }
        if trades.isEmpty {
            bullets.append("İşlem yapmamak da bir stratejidir — kötü fırsattan kaçınmak, iyi fırsatı aramak kadar değerli.")
        }
        if bullets.isEmpty {
            bullets.append("Haftanın tablosu dengeli. Disiplin bozulmadıkça bu nötrlük zararsızdır.")
        }
        return bullets.map { "- \($0)" }.joined(separator: "\n")
    }
}
