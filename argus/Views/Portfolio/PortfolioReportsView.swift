import SwiftUI

// MARK: - Structured Report Data
struct PortfolioReportData: Identifiable {
    let id = UUID()
    let title: String
    let dateRange: String
    let sections: [ReportSection]
}

struct ReportSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [ReportItem]
}

enum ReportItem: Identifiable {
    var id: String {
        switch self {
        case .stat(let s): return s.id.uuidString
        case .trade(let t): return t.id.uuidString
        case .veto(let v): return v.id.uuidString
        case .text(let t): return t
        }
    }
    
    case stat(ReportStatItem)
    case trade(ReportTradeItem)
    case veto(ReportVetoItem)
    case text(String)
}

struct ReportStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let color: Color?
    let icon: String?
}

struct ReportTradeItem: Identifiable {
    let id = UUID()
    let symbol: String
    let action: String // "AL" / "SAT"
    let price: Double
    let quantity: Double
    let isBuy: Bool
}

struct ReportVetoItem: Identifiable {
    let id = UUID()
    let symbol: String
    let direction: String
    let reason: String
}

// MARK: - Reports View
struct PortfolioReportsView: View {
    @ObservedObject var viewModel: TradingViewModel
    var mode: TradeMarket = .global
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // DAILY REPORT CARD
                ReportCardV2(
                    title: "GÜN SONU",
                    subtitle: formattedDate(Date()),
                    icon: "sun.max.fill",
                    color: mode == .global ? .orange : .red,
                    reportText: mode == .global ? viewModel.dailyReport : viewModel.bistDailyReport
                )
                
                // WEEKLY REPORT CARD
                ReportCardV2(
                    title: "HAFTALIK",
                    subtitle: weekRangeString(),
                    icon: "calendar",
                    color: mode == .global ? .purple : .orange,
                    reportText: mode == .global ? viewModel.weeklyReport : viewModel.bistWeeklyReport
                )
            }
            .padding(.horizontal)
        }
        .onAppear {
            Task {
                await viewModel.refreshReports()
            }
        }
        .refreshable {
            await viewModel.refreshReports()
        }

        .onChange(of: viewModel.transactionHistory.count) { _ in
            print("📊 UI: Transaction count changed, refreshing reports...")
            Task { await viewModel.refreshReports() }
        }
        .onChange(of: viewModel.bistBalance) { _ in
            // Balance changed (likely trade closed), refresh reports
            Task { await viewModel.refreshReports() }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        f.locale = Locale(identifier: "tr_TR")
        return f.string(from: date)
    }
    
    private func weekRangeString() -> String {
        let calendar = Calendar.current
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        f.locale = Locale(identifier: "tr_TR")
        return "\(f.string(from: weekStart)) - \(f.string(from: Date()))"
    }
}

// MARK: - Report Card V2
struct ReportCardV2: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let reportText: String?
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.textSecondary)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary.opacity(0.7))
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(reportText != nil ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
            }
            
            Divider()
                .background(Theme.border)
            
            // Summary
            if let text = reportText {
                VStack(alignment: .leading, spacing: 6) {
                    // Extract key stats
                    ForEach(extractKeyStats(from: text), id: \.self) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color.opacity(0.3))
                                .frame(width: 4, height: 4)
                            Text(stat)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Hazırlanıyor...")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            // Open Button
            Button(action: { isExpanded = true }) {
                HStack(spacing: 4) {
                    Text("Raporu Aç")
                        .font(.system(size: 10, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(DesignTokens.Opacity.glassCard))
                .cornerRadius(6)
            }
            .disabled(reportText == nil)
            .opacity(reportText == nil ? 0.5 : 1)
        }
        .padding(12)
        .frame(width: 180, height: 160)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $isExpanded) {
            ReportDetailSheetV2(
                title: title,
                subtitle: subtitle,
                color: color,
                text: reportText ?? ""
            )
        }
    }
    
    private func extractKeyStats(from text: String) -> [String] {
        // Extract lines that look like stats (contain ":" or start with "- **")
        let lines = text.components(separatedBy: .newlines)
        var stats: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- **") {
                // Remove markdown formatting
                var cleaned = trimmed
                    .replacingOccurrences(of: "- **", with: "")
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "*", with: "")
                
                if cleaned.count < 50 {
                    stats.append(cleaned)
                }
            }
        }
        
        return Array(stats.prefix(3))
    }
}

// MARK: - Report Detail Sheet V2
struct ReportDetailSheetV2: View {
    let title: String
    let subtitle: String
    let color: Color
    let text: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let sections = parseSections(from: text)
                    
                    if sections.isEmpty {
                        // Fallback: Show raw text if parsing failed
                        Text(text)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .padding()
                    } else {
                        // Parsed sections
                        ForEach(sections) { section in
                            SectionCard(section: section, accentColor: color)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("\(title) Raporu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(color)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func parseSections(from text: String) -> [ParsedSection] {
        var sections: [ParsedSection] = []
        var currentSection: ParsedSection?
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Section header (## Title)
            if trimmed.hasPrefix("## ") {
                if let current = currentSection {
                    sections.append(current)
                }
                let title = trimmed.replacingOccurrences(of: "## ", with: "")
                    .replacingOccurrences(of: "*", with: "")
                currentSection = ParsedSection(title: title, items: [])
            }
            // Subsection (### Title)
            else if trimmed.hasPrefix("### ") {
                let subTitle = trimmed.replacingOccurrences(of: "### ", with: "")
                    .replacingOccurrences(of: "*", with: "")
                currentSection?.items.append(.header(subTitle))
            }
            // List item (- item)
            else if trimmed.hasPrefix("- ") {
                let item = trimmed.replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "*", with: "")
                currentSection?.items.append(.bullet(item))
            }
            // Regular text
            else if !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("---") {
                let cleaned = trimmed
                    .replacingOccurrences(of: "**", with: "")
                    .replacingOccurrences(of: "*", with: "")
                if !cleaned.isEmpty {
                    currentSection?.items.append(.text(cleaned))
                }
            }
        }
        
        if let current = currentSection {
            sections.append(current)
        }
        
        return sections
    }
}

struct ParsedSection: Identifiable {
    let id = UUID()
    let title: String
    var items: [ParsedItem]
}

enum ParsedItem: Identifiable {
    var id: String {
        switch self {
        case .header(let h): return "h_\(h)"
        case .bullet(let b): return "b_\(b)"
        case .text(let t): return "t_\(t)"
        }
    }
    
    case header(String)
    case bullet(String)
    case text(String)
}

struct SectionCard: View {
    let section: ParsedSection
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3, height: 18)
                    .cornerRadius(2)
                
                Text(section.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Items
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.items) { item in
                    switch item {
                    case .header(let h):
                        Text(h)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(accentColor)
                            .padding(.top, 4)
                        
                    case .bullet(let b):
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundColor(accentColor.opacity(0.6))
                                .padding(.top, 6)
                            
                            Text(b)
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textPrimary)
                        }
                        
                    case .text(let t):
                        Text(t)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    PortfolioReportsView(viewModel: TradingViewModel())
        .background(Theme.background)
}
