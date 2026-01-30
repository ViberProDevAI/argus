import SwiftUI

struct HermesEventTeachingCard: View {
    @ObservedObject var viewModel: TradingViewModel
    let symbol: String
    let scope: HermesEventScope
    var injectedEvent: HermesEvent? = nil // Optional injection
    
    private var events: [HermesEvent] {
        switch scope {
        case .global:
            if let events = viewModel.hermesEventsBySymbol[symbol], !events.isEmpty {
                return events
            }
            return viewModel.hermesEventsBySymbol["GENERAL"] ?? []
        case .bist:
            return viewModel.kulisEventsBySymbol[symbol] ?? []
        }
    }
    
    private var effectiveEvent: HermesEvent? {
        if let injected = injectedEvent { return injected }
        return events.sorted { $0.finalScore > $1.finalScore }.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(Theme.tint)
                Text(scope == .bist ? "Kulis Ders Notu" : "Hermes Ders Notu")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            if let event = effectiveEvent {
                Text(event.headline)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    capsule("Etki \(Int(event.finalScore))")
                    capsule("Ufuk \(event.horizonHint.rawValue)")
                    capsule("Güven \(String(format: "%.2f", event.confidence))")
                }
                
                Text("Sentiment: \(sentimentLabel(for: event))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Ders Notu: \(event.rationaleShort)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                
                if let quote = event.evidenceQuotes.first, !quote.isEmpty {
                    Text("Kanıt: \"\(quote)\"")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HermesWhyScoreView(event: event)
                HermesCalibrationSummaryView(
                    scope: scope,
                    eventType: event.eventType,
                    horizon: event.horizonHint,
                    flags: event.riskFlags
                )
                HermesTeachingGuideView(event: event, scope: scope)
                HermesDelayBoardView(scope: scope)
            } else {
                Text("Şu an analiz edilebilir haber bulunamadı.")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 6) {
                    HermesInfoRow(icon: "newspaper.fill", text: "Hermes haberleri analiz eder ve etkisini puanlar.")
                    HermesInfoRow(icon: "lightbulb.fill", text: "Puanlar zamanla kalibre edilir ve güncellenir.")
                    HermesInfoRow(icon: "clock.fill", text: "Geç gelen haberler otomatik kırpılır.")
                }
                
                HermesTeachingGuideView(event: nil, scope: scope)
                HermesDelayBoardView(scope: scope)
            }
        }
        .padding()
        .background(Theme.secondaryBackground.opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.tint.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func capsule(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
    }
    
    private func sentimentLabel(for event: HermesEvent) -> String {
        if let label = event.sentimentLabel {
            return label.displayTitle
        }
        switch event.polarity {
        case .positive: return "Olumlu"
        case .negative: return "Olumsuz"
        case .mixed: return "Karma"
        }
    }
}

private struct HermesDelayBoardView: View {
    let scope: HermesEventScope
    
    @State private var sources: [HermesDelaySourceStat] = []
    
    private var title: String {
        scope == .bist ? "Kulis gecikme tablosu" : "Hermes gecikme tablosu"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            if sources.isEmpty {
                Text("Kaynak gecikme verisi birikiyor.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                let maxAvg = max(sources.map { $0.summary.averageMinutes }.max() ?? 1.0, 1.0)
                ForEach(sources.indices, id: \.self) { index in
                    let item = sources[index]
                    let avg = Int(item.summary.averageMinutes.rounded())
                    let p90 = Int(item.summary.p90Minutes.rounded())
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.source.capitalized)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                            Text("Ort \(avg)dk · P90 \(p90)dk")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        HStack(spacing: 8) {
                            HermesDelayBar(
                                value: item.summary.averageMinutes,
                                maxValue: maxAvg
                            )
                            .frame(height: 6)
                            
                            HermesDelaySparkline(values: item.recentSamples)
                                .frame(width: 54, height: 16)
                        }
                    }
                    if index < sources.count - 1 {
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.18))
        .cornerRadius(10)
        .task(id: scope.rawValue) {
            sources = HermesDelayStatsService.shared.topSources(scope: scope)
        }
    }
}

private struct HermesDelayBar: View {
    let value: Double
    let maxValue: Double
    
    private var ratio: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Theme.tint.opacity(0.8))
                    .frame(width: proxy.size.width * ratio)
            }
        }
    }
}

private struct HermesDelaySparkline: View {
    let values: [Double]
    
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let width = proxy.size.width
            let maxValue = max(values.max() ?? 0, 1)
            
            Path { path in
                guard values.count > 1 else { return }
                for (index, value) in values.enumerated() {
                    let x = width * (CGFloat(index) / CGFloat(values.count - 1))
                    let ratio = CGFloat(min(max(value / maxValue, 0), 1))
                    let y = height * (1.0 - ratio)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Theme.tint.opacity(0.8), lineWidth: 1.2)
        }
    }
}

private struct HermesTeachingGuideView: View {
    let event: HermesEvent?
    let scope: HermesEventScope
    
    private var modeTitle: String {
        scope == .bist ? "Kulis okuma rehberi" : "Hermes okuma rehberi"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(modeTitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            Text("1) Haber türünü bul: fiyat etkisi ilk ipucudur.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            Text("2) Güven + gecikme: düşük güven/uzun gecikme puanı törpüler.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            Text("3) Etki ufku: intraday kısa, multiweek uzun izdir.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            
            if let event {
                Text("Mini örnek")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                
                let tone = event.polarity == .positive ? "olumlu" : (event.polarity == .negative ? "olumsuz" : "karma")
                let rumorTag = event.riskFlags.contains(.rumor) ? " (kulis/dedikodu)" : ""
                Text("“\(event.headline)” → \(event.eventType.displayTitleTR)\(rumorTag). Beklenen etki: \(tone), skor: \(Int(event.finalScore)).")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Adım adım analiz")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                
                let delayMinutes = Int(event.ingestDelayMinutes.rounded())
                let groupLabel = event.riskFlags.contains(.rumor) ? "kulis/dedikodu" : (event.riskFlags.contains(.lowReliability) ? "düşük güven" : "çekirdek")
                Text("1) Tür: \(event.eventType.displayTitleTR) → tarihsel etki kalıbı seçilir.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text("2) Güven/şiddet: \(Int(event.confidence * 100))% güven, \(Int(event.severity))/100 şiddet.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text("3) Gecikme: \(delayMinutes) dk → etki kırpılır.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text("4) Kalibrasyon: \(groupLabel) grubunun geçmiş isabetine göre skor ayarlanır.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.18))
        .cornerRadius(10)
    }
}

struct HermesWhyScoreView: View {
    let event: HermesEvent
    
    var body: some View {
        let ageMinutes = event.ingestDelayMinutes > 0 ? event.ingestDelayMinutes : max(0.0, Date().timeIntervalSince(event.publishedAt) / 60.0)
        let delayPenalty = HermesEventScoring.delayFactor(ageMinutes: ageMinutes)
        let riskText = event.riskFlags.isEmpty ? "Yok" : event.riskFlags.map { $0.rawValue }.joined(separator: ", ")
        
        VStack(alignment: .leading, spacing: 6) {
            Text("Neden bu puan?")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            Text("Bu haber \(event.eventType.displayTitleTR) türünde; genelde fiyatı \(event.polarity == .positive ? "olumlu" : (event.polarity == .negative ? "olumsuz" : "karma")) etkiler.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            
            Text("Şiddet: \(Int(event.severity))/100, Kaynak güveni: \(Int(event.sourceReliability))/100.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            
                Text("Haber bize \(Int(ageMinutes)) dk gecikmeli düştü; bu yüzden etki %\(Int(delayPenalty * 100)) kırpıldı.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
                
                let sourceDelayText = HermesDelayStatsService.shared.describe(source: event.sourceName)
                Text("Kaynak gecikmesi: \(sourceDelayText)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            
            Text("Ek uyarılar: \(riskText)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

struct HermesCalibrationSummaryView: View {
    let scope: HermesEventScope
    let eventType: HermesEventType
    let horizon: HermesEventHorizon
    let flags: [HermesRiskFlag]
    
    @State private var summary: HermesCalibrationSummary?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Öğrenme özeti")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            if let summary = summary {
                if summary.totalCount < 5 {
                    Text("Hermes bu türde veri biriktiriyor (\(summary.totalCount) olay). Biraz daha örnek gördükçe puanları düzeltir.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                } else {
                    Text("Bu türde son \(summary.totalCount) olayda isabet %\(Int(summary.hitRate * 100)). Ortalama hata: \(Int(summary.meanAbsError)) puan.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                }
                
                Text("Puan düzeltme çarpanı: \(String(format: "%.2f", summary.multiplier))x.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
                
                let benchmarkText = summary.benchmarkCandidates.isEmpty ? "Bilinmiyor" : summary.benchmarkCandidates.joined(separator: ", ")
                Text("Kalibrasyon penceresi: T+\(summary.primaryDays) / T+\(summary.secondaryDays) gün. Benchmark: \(benchmarkText).")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                if let group = summary.calibrationGroup {
                    let label = group == "rumor" ? "Kulis (dedikodu)" : (group == "lowrel" ? "Kulis (düşük güven)" : "Kulis (çekirdek)")
                    Text("Kalibrasyon modu: \(label).")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HermesCalibrationTimelineView(summary: summary)
            } else {
                Text("Öğrenme verisi hazırlanıyor.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .task(id: eventType.rawValue + scope.rawValue + horizon.rawValue + flags.map { $0.rawValue }.joined()) {
            summary = await HermesCalibrationService.shared.summary(scope: scope, eventType: eventType, horizon: horizon, flags: flags)
        }
    }
}

private struct HermesCalibrationTimelineView: View {
    let summary: HermesCalibrationSummary
    
    private var progress: Double {
        if summary.totalCount <= 0 { return 0 }
        return min(Double(summary.totalCount) / 30.0, 1.0)
    }
    
    private var lastUpdateText: String {
        guard let date = summary.lastUpdated else { return "Henüz yok" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Öğrenme ilerlemesi")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    let step = Double(index + 1) / 5.0
                    Circle()
                        .fill(step <= progress ? Theme.tint : Color.white.opacity(DesignTokens.Opacity.glassCard))
                        .frame(width: 6, height: 6)
                }
                
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Theme.tint)
                            .frame(width: proxy.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            
            Text("Son kalibrasyon: \(lastUpdateText)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}
