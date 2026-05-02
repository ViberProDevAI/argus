import SwiftUI

private enum ReportPeriod {
    case daily
    case weekly

    /// Sentence case başlık (2026-04-30 H-47 sade dil).
    var title: String {
        switch self {
        case .daily:  return "Gün sonu"
        case .weekly: return "Haftalık"
        }
    }

    /// SF Symbol — sade kullanım için saklı, button'da kullanılmıyor artık.
    var icon: String {
        switch self {
        case .daily:  return "sun.max"
        case .weekly: return "calendar"
        }
    }
}

private enum ReportLoadState {
    case loading
    case ready
}

private struct ReportMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let icon: String
    let color: Color
}

private struct ReportSnapshot {
    let state: ReportLoadState
    let metrics: [ReportMetric]
    let highlights: [String]

    static func loading(period: ReportPeriod) -> ReportSnapshot {
        let placeholder = "--"
        let thirdLabel = period == .daily ? "İşlem" : "Fırsat"

        return ReportSnapshot(
            state: .loading,
            metrics: [
                ReportMetric(label: "Net K/Z", value: placeholder, icon: "banknote", color: InstitutionalTheme.Colors.textSecondary),
                ReportMetric(label: "Başarı", value: placeholder, icon: "target", color: InstitutionalTheme.Colors.textSecondary),
                ReportMetric(label: thirdLabel, value: placeholder, icon: "chart.bar", color: InstitutionalTheme.Colors.textSecondary)
            ],
            highlights: ["Rapor hazırlanıyor..."]
        )
    }
}

// MARK: - Reports View (Minimal Two-Button Layout)
struct PortfolioReportsView: View {
    @ObservedObject var viewModel: TradingViewModel
    var mode: TradeMarket = .global

    @State private var showDailyReport = false
    @State private var showWeeklyReport = false

    private var dailyText: String? {
        mode == .global ? viewModel.dailyReport : viewModel.bistDailyReport
    }
    private var weeklyText: String? {
        mode == .global ? viewModel.weeklyReport : viewModel.bistWeeklyReport
    }

    var body: some View {
        HStack(spacing: 10) {
            ReportButton(
                period: .daily,
                subtitle: formattedDate(Date()),
                color: mode == .global ? InstitutionalTheme.Colors.warning : Color(red: 1.0, green: 0.23, blue: 0.19),
                reportText: dailyText
            ) {
                showDailyReport = true
            }

            ReportButton(
                period: .weekly,
                subtitle: weekRangeString(),
                color: mode == .global ? InstitutionalTheme.Colors.primary : InstitutionalTheme.Colors.warning,
                reportText: weeklyText
            ) {
                showWeeklyReport = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onAppear {
            Task { await viewModel.refreshReports() }
        }
        .refreshable {
            await viewModel.refreshReports()
        }
        .onChange(of: viewModel.transactionHistory.count) {
            Task { await viewModel.refreshReports() }
        }
        .onChange(of: viewModel.bistBalance) {
            Task { await viewModel.refreshReports() }
        }
        .sheet(isPresented: $showDailyReport) {
            ReportDetailSheetV2(
                title: ReportPeriod.daily.title,
                subtitle: formattedDate(Date()),
                color: mode == .global ? InstitutionalTheme.Colors.warning : Color(red: 1.0, green: 0.23, blue: 0.19),
                text: dailyText ?? "",
                period: .daily,
                market: mode
            )
        }
        .sheet(isPresented: $showWeeklyReport) {
            ReportDetailSheetV2(
                title: ReportPeriod.weekly.title,
                subtitle: weekRangeString(),
                color: mode == .global ? InstitutionalTheme.Colors.primary : InstitutionalTheme.Colors.warning,
                text: weeklyText ?? "",
                period: .weekly,
                market: mode
            )
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }

    private func weekRangeString() -> String {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: Date()))"
    }
}

// MARK: - Report Button (2026-04-30 H-47 sade)
//
// Tinted icon circle + caps mono ".black" başlık + mono semibold subtitle +
// tinted dot + arrow + per-button color border kalktı. Yerine sade kart:
// sentence case başlık + alt satır "tarih · durum" muted. Renkli border yok,
// hazır/yükleniyor durumu satır metnine entegre.
private struct ReportButton: View {
    let period: ReportPeriod
    let subtitle: String
    let color: Color
    let reportText: String?
    let action: () -> Void

    private var isReady: Bool {
        guard let text = reportText?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !text.isEmpty
    }

    private var statusText: String {
        isReady ? "hazır" : "hazırlanıyor…"
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(period.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("\(subtitle) · \(statusText)")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if isReady {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(InstitutionalTheme.Colors.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .opacity(isReady ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
    }
}

// MARK: - Report Detail Sheet
private struct ReportDetailSheetV2: View {
    let title: String
    let subtitle: String
    let color: Color
    let text: String
    let period: ReportPeriod
    let market: TradeMarket

    @Environment(\.dismiss) private var dismiss

    private var snapshot: ReportSnapshot {
        ReportParser.snapshot(from: text, period: period, market: market)
    }

    private var parsedSections: [ParsedSection] {
        ReportParser.parseSections(from: text)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                InstitutionalTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ReportHeroHeader(
                            title: title,
                            subtitle: subtitle,
                            color: color,
                            metrics: snapshot.metrics
                        )

                        if parsedSections.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ham metin")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                Text(text)
                                    .font(.system(size: 13))
                                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    .textSelection(.enabled)
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(InstitutionalTheme.Colors.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            ForEach(parsedSections) { section in
                                SectionCard(section: section, accentColor: color)
                            }
                        }

                        // Yasal uyarı
                        Text("Bu rapor yatırım tavsiyesi değildir. Argus, Alkindus öğrenme sistemi üstünden geçmiş verileri özetler.")
                            .font(.system(size: 10))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(color)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ReportHeroHeader: View {
    let title: String
    let subtitle: String
    let color: Color
    let metrics: [ReportMetric]

    // 2026-04-30 H-47 — sade. ArgusDot + caps black mono başlık + tinted
    // metric kartları + tinted color border kalktı. Sentence "Gün sonu"
    // 17pt medium + alt satır subtitle + dikey-ayraçlı 3 sütun stat
    // (LiquidDashboardHeader / tradeBrainBand ile aynı dil).
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }

            HStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.element.id) { idx, metric in
                    statColumn(metric: metric, leadingDivider: idx > 0)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Sade metric sütunu — kart yerine dikey ayraç.
    @ViewBuilder
    private func statColumn(metric: ReportMetric, leadingDivider: Bool) -> some View {
        HStack(spacing: 0) {
            if leadingDivider {
                Rectangle()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(width: 0.5)
                    .padding(.vertical, 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(metric.label)
                    .font(.system(size: 11))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Text(metric.value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(metric.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ParsedSection: Identifiable {
    let id = UUID()
    let title: String
    var items: [ParsedItem]
}

private enum ParsedItem: Identifiable {
    case emphasis(String)
    case bullet(String)
    case metric(label: String, value: String)
    case paragraph(String)

    var id: String {
        switch self {
        case .emphasis(let value): return "em_\(value)"
        case .bullet(let value): return "bl_\(value)"
        case .metric(let label, let value): return "mt_\(label)_\(value)"
        case .paragraph(let value): return "pg_\(value)"
        }
    }
}

private struct SectionCard: View {
    let section: ParsedSection
    let accentColor: Color

    // 2026-04-30 H-47 — sade. Tinted icon circle + caps mono başlık +
    // per-card border + per-metric tinted card kalktı. Yerine sade kart:
    // sentence case başlık + grouped item list + hairline ayrım.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InstitutionalTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.items) { item in
                    switch item {
                    case .emphasis(let value):
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(value)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                        .fixedSize(horizontal: false, vertical: true)

                    case .bullet(let value):
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                            Text(value)
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                    case .metric(let label, let value):
                        HStack {
                            Text(label)
                                .font(.system(size: 13))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text(value)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 6)
                        .overlay(
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.borderSubtle)
                                .frame(height: 0.5),
                            alignment: .bottom
                        )

                    case .paragraph(let value):
                        Text(value)
                            .font(.system(size: 13))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Parser
private enum ReportParser {
    private static let tokensToRemove = [
        "[RAPOR]", "[OGREN]", "[MAKRO]", "[ISLEM]", "[KARAR]", "[DERS]", "[STATS]", "[LIST]",
        "[INFO]", "[TIME]", "[BEST]", "[WORST]", "[HAFTA]", "[*]", "[+]", "[-]", "[!]"
    ]

    static func snapshot(from text: String?, period: ReportPeriod, market: TradeMarket) -> ReportSnapshot {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return .loading(period: period)
        }

        let lines = text.components(separatedBy: .newlines)
        let currency = text.contains("₺") || market == .bist ? "₺" : "$"

        let netPnl = extractNetPnL(lines: lines)
        let successRate = extractSuccessRate(lines: lines)
        let tradeCount = extractTradeCount(lines: lines)
        let opportunityCount = extractOpportunityCount(lines: lines)
        let vetoCount = extractVetoCount(lines: lines)

        let netMetric = ReportMetric(
            label: "Net K/Z",
            value: formatPnL(netPnl, currency: currency),
            icon: "banknote",
            color: pnlColor(netPnl)
        )

        let successMetric = ReportMetric(
            label: "Başarı",
            value: successRate != nil ? "%\(Int((successRate ?? 0).rounded()))" : "--",
            icon: "target",
            color: successColor(successRate)
        )

        let thirdMetric: ReportMetric
        if let vetoCount {
            thirdMetric = ReportMetric(
                label: "Veto",
                value: "\(vetoCount)",
                icon: "shield",
                color: vetoCount == 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.warning
            )
        } else {
            let value = period == .daily ? tradeCount : (opportunityCount ?? tradeCount)
            let label = period == .daily ? "İşlem" : "Fırsat"
            thirdMetric = ReportMetric(
                label: label,
                value: value != nil ? "\(value!)" : "--",
                icon: "chart.bar",
                color: InstitutionalTheme.Colors.textPrimary
            )
        }

        let highlights = extractHighlights(lines: lines)

        return ReportSnapshot(
            state: .ready,
            metrics: [netMetric, successMetric, thirdMetric],
            highlights: highlights.isEmpty ? ["Öne çıkan satır bulunamadı. Rapor detayını açarak tüm içeriği inceleyebilirsin."] : highlights
        )
    }

    static func parseSections(from text: String) -> [ParsedSection] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [ParsedSection] = []
        var current = ParsedSection(title: "Rapor Özeti", items: [])

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard !isSeparatorLine(trimmed) else { continue }

            if trimmed.hasPrefix("## ") {
                if !current.items.isEmpty {
                    sections.append(current)
                }
                let rawTitle = String(trimmed.dropFirst(3))
                current = ParsedSection(title: normalizeHeading(rawTitle), items: [])
                continue
            }

            if trimmed.hasPrefix("### ") {
                let subtitle = normalizeSentence(String(trimmed.dropFirst(4)))
                if !subtitle.isEmpty {
                    current.items.append(.emphasis(subtitle))
                }
                continue
            }

            if let rowMetric = parseTableMetricRow(trimmed) {
                current.items.append(.metric(label: rowMetric.0, value: rowMetric.1))
                continue
            }

            if let colonMetric = parseColonMetric(trimmed) {
                current.items.append(.metric(label: colonMetric.0, value: colonMetric.1))
                continue
            }

            if isBulletLine(trimmed) {
                let bullet = normalizeSentence(trimmed)
                if bullet.count > 2 {
                    current.items.append(.bullet(bullet))
                }
                continue
            }

            let paragraph = normalizeSentence(trimmed)
            if paragraph.count > 2 {
                current.items.append(.paragraph(paragraph))
            }
        }

        if !current.items.isEmpty {
            sections.append(current)
        }

        return sections
    }

    private static func extractNetPnL(lines: [String]) -> Double? {
        if let line = firstLine(containing: "Net K/Z", in: lines) {
            if let value = extractNumber(after: "Net K/Z", from: line) ?? extractFirstNumber(from: line) {
                return value
            }
        }

        if let line = firstLine(containing: "Net Kar/Zarar", in: lines) {
            return extractNumber(after: "Net Kar/Zarar", from: line) ?? extractFirstNumber(from: line)
        }

        return nil
    }

    private static func extractSuccessRate(lines: [String]) -> Double? {
        if let line = firstLine(containing: "Başarı:", in: lines) {
            return extractNumber(after: "Başarı:", from: line) ?? extractFirstNumber(from: line)
        }

        if let line = firstLine(containing: "Başarı Oranı", in: lines) {
            return extractNumber(after: "Başarı Oranı", from: line) ?? extractFirstNumber(from: line)
        }

        return nil
    }

    private static func extractTradeCount(lines: [String]) -> Int? {
        if let line = firstLine(containing: "Toplam İşlem", in: lines) {
            return extractFirstInt(from: line)
        }

        if let line = lines.first(where: { $0.contains("Alım:") && $0.contains("Satım:") }) {
            let buys = extractInt(after: "Alım:", from: line)
            let sells = extractInt(after: "Satım:", from: line)
            if let buys, let sells {
                return buys + sells
            }
        }

        return nil
    }

    private static func extractOpportunityCount(lines: [String]) -> Int? {
        if let line = firstLine(containing: "Değerlendirilen Fırsat", in: lines) {
            return extractInt(after: "Değerlendirilen Fırsat", from: line) ?? extractFirstInt(from: line)
        }

        if let line = firstLine(containing: "Toplam Analiz", in: lines) {
            return extractInt(after: "Toplam Analiz", from: line) ?? extractFirstInt(from: line)
        }

        return nil
    }

    private static func extractVetoCount(lines: [String]) -> Int? {
        if let line = firstLine(containing: "Veto:", in: lines) {
            return extractInt(after: "Veto:", from: line) ?? extractFirstInt(from: line)
        }

        if let line = firstLine(containing: "Veto Edilen", in: lines) {
            return extractInt(after: "Veto Edilen", from: line) ?? extractFirstInt(from: line)
        }

        return nil
    }

    private static func extractHighlights(lines: [String]) -> [String] {
        var highlights: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard !isSeparatorLine(trimmed) else { continue }

            let normalized = normalizeSentence(trimmed)
            guard normalized.count > 18 else { continue }
            guard normalized.count < 140 else { continue }

            if trimmed.contains("[BEST]") || trimmed.contains("[WORST]") || trimmed.contains("[TIME]") || trimmed.contains("└─") {
                highlights.append(normalized)
                continue
            }

            if isBulletLine(trimmed) {
                highlights.append(normalized)
                continue
            }

            if normalized.localizedCaseInsensitiveContains("zaman örüntüsü") ||
                normalized.localizedCaseInsensitiveContains("haftanın") ||
                normalized.localizedCaseInsensitiveContains("günün dersi") ||
                normalized.localizedCaseInsensitiveContains("neden önemli") {
                highlights.append(normalized)
            }
        }

        let unique = Array(NSOrderedSet(array: highlights)) as? [String] ?? highlights
        return Array(unique.prefix(3))
    }

    private static func parseTableMetricRow(_ line: String) -> (String, String)? {
        guard line.contains("│") else { return nil }

        let components = line
            .split(separator: "│")
            .map { normalizeSentence(String($0)) }
            .filter { !$0.isEmpty }

        guard components.count >= 2 else { return nil }
        guard !components[0].contains("──") else { return nil }

        let label = components[0]
        let value = components[1]

        guard label.count >= 2, value.count >= 1 else { return nil }
        return (label, value)
    }

    private static func parseColonMetric(_ line: String) -> (String, String)? {
        let normalized = normalizeSentence(line)

        guard normalized.contains(":") else { return nil }
        let parts = normalized.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        guard parts[0].count <= 30 else { return nil }
        guard parts[1].count <= 40 else { return nil }
        guard !parts[1].contains("|") else { return nil }

        return (parts[0], parts[1])
    }

    private static func isBulletLine(_ line: String) -> Bool {
        let candidates = ["- ", "• ", "└─", "[+", "[-", "[!", "[*"]
        return candidates.contains { line.hasPrefix($0) }
    }

    private static func normalizeHeading(_ raw: String) -> String {
        let plain = normalizeSentence(raw)
        let upper = plain.uppercased()

        if upper.contains("GUNLUK") || upper.contains("GÜNLÜK") { return "Günlük Özet" }
        if upper.contains("HAFTALIK PERFORMANS") { return "Haftalık Performans" }
        if upper.contains("BUGUN OGRENDIKLERIN") || upper.contains("BUGÜN ÖĞRENDİKLERİN") { return "Bugün Öğrendiklerin" }
        if upper.contains("BU HAFTA OGRENDIKLERIN") || upper.contains("BU HAFTA ÖĞRENDİKLERİN") { return "Bu Hafta Öğrenilenler" }
        if upper.contains("ORTAM") || upper.contains("MAKRO") { return "Makro Ortam" }
        if upper.contains("ISLEMLER") || upper.contains("İŞLEMLER") { return "İşlem Özeti" }
        if upper.contains("KARAR MOTORU") { return "Karar Motoru Analizi" }
        if upper.contains("KARAR KALITESI") || upper.contains("KARAR KALİTESİ") { return "Karar Kalitesi" }
        if upper.contains("GUNUN DERSI") || upper.contains("GÜNÜN DERSİ") { return "Günün Dersi" }
        if upper.contains("HAFTANIN DERSLERI") || upper.contains("HAFTANIN DERSLERİ") { return "Haftanın Dersleri" }

        return plain
    }

    private static func normalizeSentence(_ raw: String) -> String {
        var value = raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "└─", with: "")
            .replacingOccurrences(of: "├─", with: "")
            .replacingOccurrences(of: "┌", with: "")
            .replacingOccurrences(of: "┐", with: "")
            .replacingOccurrences(of: "└", with: "")
            .replacingOccurrences(of: "┘", with: "")

        for token in tokensToRemove {
            value = value.replacingOccurrences(of: token, with: "")
        }

        while value.contains("  ") {
            value = value.replacingOccurrences(of: "  ", with: " ")
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isSeparatorLine(_ line: String) -> Bool {
        let separators = CharacterSet(charactersIn: "═─-")
        return !line.unicodeScalars.filter { !separators.contains($0) }.isEmpty ? false : true
    }

    private static func firstLine(containing keyword: String, in lines: [String]) -> String? {
        lines.first { $0.localizedCaseInsensitiveContains(keyword) }
    }

    private static func extractFirstNumber(from line: String) -> Double? {
        let normalized = line.replacingOccurrences(of: ",", with: ".")
        guard let regex = try? NSRegularExpression(pattern: "[-+]?\\d+(?:\\.\\d+)?") else { return nil }
        guard let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) else {
            return nil
        }

        guard let range = Range(match.range, in: normalized) else { return nil }
        return Double(normalized[range])
    }

    private static func extractFirstInt(from line: String) -> Int? {
        let normalized = line.replacingOccurrences(of: ",", with: "")
        guard let regex = try? NSRegularExpression(pattern: "\\d+") else { return nil }
        guard let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) else {
            return nil
        }

        guard let range = Range(match.range, in: normalized) else { return nil }
        return Int(normalized[range])
    }

    private static func extractNumber(after label: String, from line: String) -> Double? {
        guard let range = line.range(of: label, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        let tail = String(line[range.upperBound...])
        return extractFirstNumber(from: tail)
    }

    private static func extractInt(after label: String, from line: String) -> Int? {
        guard let range = line.range(of: label, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        let tail = String(line[range.upperBound...])
        return extractFirstInt(from: tail)
    }

    private static func formatPnL(_ value: Double?, currency: String) -> String {
        guard let value else { return "--" }

        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(currency)\(String(format: "%.2f", abs(value)))"
    }

    private static func pnlColor(_ value: Double?) -> Color {
        guard let value else { return InstitutionalTheme.Colors.textSecondary }
        if value > 0 { return InstitutionalTheme.Colors.positive }
        if value < 0 { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.textSecondary
    }

    private static func successColor(_ value: Double?) -> Color {
        guard let value else { return InstitutionalTheme.Colors.textSecondary }
        if value >= 60 { return InstitutionalTheme.Colors.positive }
        if value >= 45 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}

#Preview {
    PortfolioReportsView(viewModel: TradingViewModel())
        .background(InstitutionalTheme.Colors.background)
}
