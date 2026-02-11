import SwiftUI

// MARK: - 1. Agora Decision Trace Card (The "Why")
// MARK: - 1. Agora Decision Trace Card (The "Why")
struct AgoraTraceCard: View {
    let trace: AgoraTrace?
    
    // Helpers for extracting data safely
    var tierLabel: String {
        guard let sizeR = trace?.finalDecision.executionPlan?.targetSizeR else { return "N/A" }
        if sizeR >= 1.0 { return "Tier 1" }
        if sizeR >= 0.5 { return "Tier 2" }
        return "Tier 3"
    }
    
    var claimantName: String {
        trace?.debate.claimant?.module.rawValue ?? "AutoPilot"
    }
    
    var supporterCount: Int {
        trace?.debate.opinions.filter { $0.stance == .support }.count ?? 0
    }
    
    var dissenterCount: Int {
        trace?.debate.opinions.filter { $0.stance == .object }.count ?? 0
    }
    
    var isApproved: Bool {
        trace?.riskEvaluation.isApproved ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "text.magnifyingglass")
                    .foregroundColor(Theme.tint)
                Text("Karar Protokolü")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if let t = trace {
                    Text(t.finalDecision.action.rawValue.uppercased())
                        .font(.caption)
                        .bold()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(t.finalDecision.action == .buy ? Theme.positive : Theme.tint)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            if let t = trace {
                // Timeline
                VStack(alignment: .leading, spacing: 0) {
                    // 1. Data Scan
                    TraceStepRow(
                        icon: "server.rack",
                        title: "Veri Analizi",
                        detail: "Tazelik: \(Int(t.dataHealth.freshnessScore))% • Eksik: \(Int(t.dataHealth.healthScore))%",
                        isActive: true
                    )
                    
                    // Connection Line
                    TraceLine()
                    
                    // 2. Debate
                    TraceStepRow(
                        icon: "person.3.sequence.fill",
                        title: "Münazara",
                        detail: "Öneri: \(claimantName) • Destek: \(supporterCount) • İtiraz: \(dissenterCount)",
                        isActive: true
                    )
                    
                    TraceLine()
                    
                    // 3. Risk Check
                    TraceStepRow(
                        icon: "shield.checkered",
                        title: "Risk Kontrolü (Chiron)",
                        detail: isApproved ? "Onaylandı" : "VETO: \(t.riskEvaluation.reason)",
                        isActive: true,
                        isError: !isApproved
                    )
                    
                    TraceLine()
                    
                    // 4. Result
                    TraceStepRow(
                        icon: "gavel",
                        title: "Sonuç",
                        detail: "\(tierLabel) • Hedef: \(String(format: "%.2f", t.finalDecision.executionPlan?.riskPlan.takeProfit ?? 0))",
                        isActive: true,
                        isLast: true
                    )
                }
            } else {
                Text("Bu sembol için henüz aktif bir karar kaydı yok.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
}

struct TraceStepRow: View {
    let icon: String
    let title: String
    let detail: String
    let isActive: Bool
    var isError: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isError ? Theme.negative : (isActive ? Theme.primary : Theme.textSecondary.opacity(0.3)))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}

struct TraceLine: View {
    var body: some View {
        Rectangle()
            .fill(Theme.textSecondary.opacity(0.2))
            .frame(width: 2, height: 16)
            .padding(.leading, 11) // Center with 24px circle
    }
}

// MARK: - 2. Risk Summary Card (Chiron)
struct RiskSummaryCard: View {
    let riskReport: String? // Or structured Risk Object
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.shield")
                    .foregroundColor(Theme.tint)
                Text("Risk ve Boyutlandırma")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            // Mock Data or Passed Data
            // In real implementation, pass specific risk struct
            VStack(alignment: .leading, spacing: 8) {
                RiskRow(label: "Mevcut Risk", value: "2.3R / 2.5R (Limit)")
                RiskRow(label: "İşlem Riski", value: "+0.50R")
                RiskRow(label: "Tier", value: "Tier 2 (Standart)")
            }
            
            if let report = riskReport, report.contains("VETO") {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text(report)
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(8)
                .background(Theme.negative)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
}

struct RiskRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// MARK: - 3. Universe Info Card
struct UniverseInfoCard: View {
    let source: UniverseSource?
    let firstSeen: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe.europe.africa.fill")
                    .foregroundColor(Theme.tint)
                Text("İzleme Nedeni")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Kaynak")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(source?.rawValue ?? "Bilinmiyor")
                        .font(.body)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("İlk Tespit")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    Text(firstSeen?.formatted(date: .abbreviated, time: .omitted) ?? "-")
                        .font(.body)
                        .bold()
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
}

// MARK: - 4. Correlation Card
struct CorrelationCard: View {
    // Mock Data for now
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(Theme.tint)
                Text("Benzer Hareketler")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            Text("Sonuç üretmek için yeterli veri yok (min 60 bar gerekli).")
                .font(.caption)
                .italic()
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
}

// MARK: - 5. Phoenix Channel Card
struct PhoenixChannelCard: View {
    let advice: PhoenixAdvice
    var onRunBacktest: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.and.down.circle")
                    .foregroundColor(Theme.tint)
                Text("PHOENIX KANALI")
                    .font(.headline)
                    .bold()
                
                Spacer()
                
                if let run = onRunBacktest {
                    Button(action: run) {
                        Text("GEÇMİŞ TEST")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.tint.opacity(0.1))
                            .foregroundColor(Theme.tint)
                            .cornerRadius(4)
                    }
                }
                Text("Phoenix Kanal Analizi")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            HStack(spacing: 16) {
                // Visual Indicator
                    VStack {
                        Text("Üst Bant")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        Text(String(format: "%.2f", advice.channelUpper ?? 0))
                            .font(.headline)
                            .padding(4)
                            .background(Theme.negative.opacity(0.1))
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(LinearGradient(colors: [Theme.negative.opacity(0.3), Theme.positive.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 4, height: 40)
                        
                        Text(String(format: "%.2f", advice.channelLower ?? 0))
                            .font(.headline)
                            .padding(4)
                            .background(Theme.positive.opacity(0.1))
                            .cornerRadius(4)
                        Text("Alt Bant")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }              
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Konum:")
                            .foregroundColor(Theme.textSecondary)
                        Text(advice.triggers.touchLowerBand ? "DİP BÖLGE" : "KANAL İÇİ")
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                    }
                    HStack {
                        Text("Tetikleyici:")
                            .foregroundColor(Theme.textSecondary)
                        Text(advice.triggers.rsiReversal ? "RSI DÖNÜŞ" : (advice.triggers.bullishDivergence ? "PU" : "YOK"))
                            .bold()
                            .foregroundColor(Theme.tint)
                    }
                    
                    Divider()
                    
                    Text(advice.reasonShort)
                        .font(.caption)
                        .italic()
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
}

// MARK: - 6. Transaction History Card
struct TransactionHistoryCard: View {
    let transactions: [Transaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Theme.textSecondary)
                Text("İşlem Geçmişi")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
            }
            
            if transactions.isEmpty {
                Text("Bu sembolde geçmiş işlem yok.")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            } else {
                ForEach(transactions.prefix(5)) { tx in
                    HStack {
                        Text(tx.type.rawValue == "BUY" ? "ALIM" : "SATIM")
                            .font(.caption)
                            .bold()
                            .foregroundColor(tx.type.rawValue == "BUY" ? Theme.positive : Theme.negative)
                        
                        Text(tx.date.formatted(date: .numeric, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.0f", tx.amount)) adet @ \(String(format: "%.2f", tx.price))")
                            .font(.caption)
                            .foregroundColor(Theme.textPrimary)
                    }
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Theme.secondaryBackground)
        .cornerRadius(16)
    }
}
