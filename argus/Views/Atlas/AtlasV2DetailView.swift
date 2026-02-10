import SwiftUI

// MARK: - Atlas V2 Detail View
// Şirketi A'dan Z'ye öğreten eğitici arayüz

struct AtlasV2DetailView: View {
    let symbol: String
    @State private var result: AtlasV2Result?
    @State private var isLoading = true
    @State private var error: String?
    @State private var detailedError: String? // Additional debug info
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else if let result = result {
                    // Başlık ve Genel Skor
                    headerCard(result)
                    educationalRationaleCard(result)
                    
                    // Öne Çıkanlar & Uyarılar
                    if !result.highlights.isEmpty || !result.warnings.isEmpty {
                        highlightsCard(result)
                    }
                    
                    // VALUE ALERT SYSTEM (BIST-ÖZEL)
                    if symbol.hasSuffix(".IS"), hasValueAlerts(result) {
                        valueAlertCard(result)
                    }
                    
                    // Bölüm Kartları
                    sectionCard(
                        title: "Değerleme",
                        icon: "dollarsign.circle.fill",
                        iconColor: InstitutionalTheme.Colors.warning,
                        score: result.valuationScore,
                        metrics: result.valuation.allMetrics,
                        sectionId: "valuation"
                    )
                    
                    sectionCard(
                        title: "Karlılık",
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: InstitutionalTheme.Colors.positive,
                        score: result.profitabilityScore,
                        metrics: result.profitability.allMetrics,
                        sectionId: "profitability"
                    )
                    
                    sectionCard(
                        title: "Büyüme",
                        icon: "arrow.up.right.circle.fill",
                        iconColor: InstitutionalTheme.Colors.primary,
                        score: result.growthScore,
                        metrics: result.growth.allMetrics,
                        sectionId: "growth"
                    )
                    
                    sectionCard(
                        title: "Finansal Sağlık",
                        icon: "shield.checkered",
                        iconColor: InstitutionalTheme.Colors.primary,
                        score: result.healthScore,
                        metrics: result.health.allMetrics,
                        sectionId: "health"
                    )
                    
                    sectionCard(
                        title: "Nakit Kalitesi",
                        icon: "banknote.fill",
                        iconColor: InstitutionalTheme.Colors.positive,
                        score: result.cashScore,
                        metrics: result.cash.allMetrics,
                        sectionId: "cash"
                    )
                    
                    sectionCard(
                        title: "Temettü",
                        icon: "gift.fill",
                        iconColor: InstitutionalTheme.Colors.warning,
                        score: result.dividendScore,
                        metrics: result.dividend.allMetrics,
                        sectionId: "dividend"
                    )
                    
                    // YENİ: Risk Kartı
                    sectionCard(
                        title: "Risk Analizi",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: InstitutionalTheme.Colors.negative,
                        score: 100 - (result.risk.beta.value ?? 1.0) * 20,
                        metrics: result.risk.allMetrics,
                        sectionId: "risk"
                    )
                    
                    // Özet
                    summaryCard(result)
                }
            }
            .padding()
        }
        .background(InstitutionalTheme.Colors.background)
        .navigationTitle("Atlas Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Header Card
    
    private func headerCard(_ result: AtlasV2Result) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("ATLAS ÇEKİRDEĞİ")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    .tracking(1.1)
                Spacer()
                Text(result.qualityBand.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor(result.totalScore).opacity(0.16))
                    .foregroundColor(scoreColor(result.totalScore))
                    .clipShape(Capsule())
            }

            // Şirket İsmi ve Sembol
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.profile.name)
                        .font(.title2.bold())
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    HStack(spacing: 8) {
                        Text(result.symbol)
                            .font(.subheadline)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        
                        // Sektör Badge
                        if let sector = result.profile.sector {
                            Text(sector)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(InstitutionalTheme.Colors.primary.opacity(0.16))
                                .foregroundColor(InstitutionalTheme.Colors.primary)
                                .cornerRadius(4)
                        }
                    }
                }
                Spacer()
                
                // Piyasa Değeri
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.profile.formattedMarketCap)
                        .font(.headline)
                    Text(result.profile.marketCapTier)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            
            // Endüstri Bilgisi (varsa)
            if let industry = result.profile.industry {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(industry)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                }
            }
            
            Divider()
            
            // Genel Skor Ring
            HStack(spacing: 24) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: result.totalScore / 100)
                        .stroke(
                            LinearGradient(
                                colors: [scoreColor(result.totalScore), scoreColor(result.totalScore).opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(result.totalScore))")
                            .font(.title.bold())
                        Text("/100")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                
                // Kalite Bandı
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kalite Bandı")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    HStack {
                        Text(result.qualityBand.rawValue)
                            .font(.title.bold())
                            .foregroundColor(scoreColor(result.totalScore))
                        Text("(\(result.qualityBand.description))")
                            .font(.subheadline)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(scoreColor(result.totalScore).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Highlights Card
    
    private func highlightsCard(_ result: AtlasV2Result) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !result.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                        Text("Pozitif Sinyaller")
                            .font(.caption.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(result.highlights.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                    }
                    ForEach(result.highlights, id: \.self) { highlight in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(InstitutionalTheme.Colors.positive.opacity(0.9))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(highlight)
                                .font(.subheadline)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(10)
                .background(InstitutionalTheme.Colors.positive.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(InstitutionalTheme.Colors.warning)
                        Text("Kritik Notlar")
                            .font(.caption.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Spacer()
                        Text("\(result.warnings.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(InstitutionalTheme.Colors.warning)
                    }
                    ForEach(result.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(InstitutionalTheme.Colors.warning.opacity(0.95))
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(warning)
                                .font(.subheadline)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        }
                    }
                }
                .padding(10)
                .background(InstitutionalTheme.Colors.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    // MARK: - Section Card
    
    private func sectionCard(title: String, icon: String = "", iconColor: Color = InstitutionalTheme.Colors.textPrimary, score: Double, metrics: [AtlasMetric], sectionId: String) -> some View {
        VStack(spacing: 0) {
            // Header
            Button {
                // FIX: withAnimation kaldırıldı - main thread blocking önleniyor
                if expandedSections.contains(sectionId) {
                    expandedSections.remove(sectionId)
                } else {
                    expandedSections.insert(sectionId)
                }
            } label: {
                HStack {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.caption.weight(.semibold))
                            .frame(width: 24, height: 24)
                            .background(iconColor.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .foregroundColor(iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        Text(sectionSubtitle(sectionId))
                            .font(.caption2)
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    // Mini Progress Bar
                    miniProgressBar(score: score)
                    
                    // Score
                    Text("\(Int(score))")
                        .font(.headline)
                        .foregroundColor(scoreColor(score))
                        .monospacedDigit()
                    
                    // Chevron
                    Image(systemName: expandedSections.contains(sectionId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if let strongest = metrics.max(by: { $0.score < $1.score }),
               let weakest = metrics.min(by: { $0.score < $1.score }) {
                HStack(spacing: 8) {
                    SectionMetricChip(
                        label: "Güçlü",
                        metric: strongest,
                        color: InstitutionalTheme.Colors.positive
                    )
                    SectionMetricChip(
                        label: "İzle",
                        metric: weakest,
                        color: explanationColor(weakest.status)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, expandedSections.contains(sectionId) ? 8 : 12)
            }

            let sectionDrivers = topDrivers(from: metrics, limit: 3)
            if !sectionDrivers.isEmpty {
                sectionDriverStrip(sectionDrivers)
                    .padding(.horizontal)
                    .padding(.bottom, expandedSections.contains(sectionId) ? 8 : 12)
            }
            
            // Expanded Content
            if expandedSections.contains(sectionId) {
                VStack(spacing: 16) {
                    ForEach(metrics) { metric in
                        metricRow(metric)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .padding(.top, 4)
                // transition kaldırıldı - performans optimizasyonu
            }
        }
        .background(cardBackground)
    }
    
    // MARK: - Metric Row
    
    private func metricRow(_ metric: AtlasMetric) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Üst satır: İsim, Değer, Durum
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    Text("Skor \(Int(metric.score)) / 100")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }
                
                Spacer()
                
                Text(metric.formattedValue)
                    .font(.subheadline.bold())
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
                
                Text(metric.status.label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(explanationColor(metric.status).opacity(0.16))
                    .foregroundColor(explanationColor(metric.status))
                    .clipShape(Capsule())
            }

            metricScoreBar(metric.score, color: explanationColor(metric.status))
            
            // Sektör karşılaştırması
            if let sectorAvg = metric.sectorAverage {
                HStack(spacing: 8) {
                    Text("Sektör Ort:")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Text(AtlasMetric.format(sectorAvg))
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    if let deltaText = metricDeltaText(metric) {
                        Text(deltaText)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(explanationColor(metric.status))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(explanationColor(metric.status).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Açıklama
            Text(metric.explanation)
                .font(.caption)
                .foregroundColor(explanationColor(metric.status))
                .lineSpacing(1)
            
            // Eğitici not (varsa)
            if !metric.educationalNote.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                    Text(metric.educationalNote)
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .italic()
                }
                .padding(.top, 4)
            }

            if let formula = metric.formula, !formula.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(InstitutionalTheme.Colors.primary)
                    Text(formula)
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
            
            Divider().background(InstitutionalTheme.Colors.borderSubtle)
        }
        .padding(10)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    // MARK: - Summary Card
    
    private func summaryCard(_ result: AtlasV2Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(InstitutionalTheme.Colors.warning)
                Text("Yatırımcı İçin Özet")
                    .font(.headline)
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            }
            
            Text(result.summary)
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            // Alt bölüm skorları grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                miniScoreCard("Karlılık", result.profitabilityScore)
                miniScoreCard("Değerleme", result.valuationScore)
                miniScoreCard("Sağlık", result.healthScore)
                miniScoreCard("Büyüme", result.growthScore)
                miniScoreCard("Nakit", result.cashScore)
                miniScoreCard("Temettü", result.dividendScore)
            }
            
            // BIST SECTOR COMPARISON (NEW)
            if symbol.hasSuffix(".IS") {
                BistSectorComparisonCard(symbol: symbol, result: result)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    // MARK: - Value Alert System (BIST-ÖZEL)
    
    private func valueAlertCard(_ result: AtlasV2Result) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Value Alert Sistemi")
                .font(.caption.weight(.bold))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)

            // Deep Value Detection
            if isDeepValue(result) {
                alertLine(
                    title: "DERİN DEĞER FIRSATI",
                    icon: "star.fill",
                    color: InstitutionalTheme.Colors.warning
                )
            }
            
            // Value Trap Detection
            if isValueTrap(result) {
                alertLine(
                    title: "VALUE TRAP UYARISI",
                    icon: "exclamationmark.triangle.fill",
                    color: InstitutionalTheme.Colors.negative
                )
            }
            
            // High Dividend Warning
            if isHighDividendRisky(result) {
                alertLine(
                    title: "SÜRDÜRÜLEMEZ TEMETTÜ",
                    icon: "exclamationmark.octagon.fill",
                    color: InstitutionalTheme.Colors.warning
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
    }
    
    private func isDeepValue(_ result: AtlasV2Result) -> Bool {
        guard let pe = result.valuation.allMetrics.first(where: { $0.name.contains("F/K") }),
              let peVal = pe.value else { return false }
        return peVal < 5.0 && result.profitabilityScore > 60
    }
    
    private func isValueTrap(_ result: AtlasV2Result) -> Bool {
        guard let pb = result.valuation.allMetrics.first(where: { $0.name.contains("PD/DD") }),
              let pbVal = pb.value else { return false }
        return pbVal < 1.0 && result.profitabilityScore < 40
    }
    
    private func isHighDividendRisky(_ result: AtlasV2Result) -> Bool {
        guard let div = result.dividend.allMetrics.first(where: { $0.name.contains("Verim") }),
              let divVal = div.value else { return false }
        return divVal > 10.0 && result.cashScore < 40
    }

    private func hasValueAlerts(_ result: AtlasV2Result) -> Bool {
        isDeepValue(result) || isValueTrap(result) || isHighDividendRisky(result)
    }

    private func alertLine(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(color.opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - Helpers Extension
extension AtlasV2DetailView {
    
    private func miniScoreCard(_ title: String, _ score: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(score))")
                    .font(.headline)
                    .foregroundColor(scoreColor(score))
                    .monospacedDigit()
                Text(sectionGrade(score))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(scoreColor(score))
            }
            metricScoreBar(score, color: scoreColor(score))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metricScoreBar(_ score: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 5)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * min(max(score / 100.0, 0), 1), height: 5)
            }
        }
        .frame(height: 5)
    }

    private func sectionGrade(_ score: Double) -> String {
        switch score {
            case 85...: return "A+"
            case 70..<85: return "A"
            case 55..<70: return "B"
            case 40..<55: return "C"
            case 25..<40: return "D"
            default: return "F"
        }
    }

    private func metricDeltaText(_ metric: AtlasMetric) -> String? {
        guard let value = metric.value, let sector = metric.sectorAverage, sector != 0 else { return nil }
        let delta = ((value - sector) / abs(sector)) * 100
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(Int(delta.rounded()))%"
    }

    @ViewBuilder
    private func educationalRationaleCard(_ result: AtlasV2Result) -> some View {
        let drivers = topDrivers(from: combinedMetrics(from: result), limit: 5)
        if !drivers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NEDEN BÖYLE?")
                        .font(.caption.weight(.bold))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text("İlk \(min(3, drivers.count)) etken")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(drivers.prefix(3))) { driver in
                            AtlasDriverChip(
                                title: driver.name,
                                subtitle: driver.explanation,
                                impactText: String(format: "%+.0f", driver.score - 50),
                                tint: driverColor(for: driver.impact)
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    let slices = donutSlices(from: Array(drivers.prefix(4)))
                    ZStack {
                        Circle()
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 9)
                            .frame(width: 72, height: 72)
                        ForEach(slices) { slice in
                            Circle()
                                .trim(from: slice.start, to: slice.end)
                                .stroke(slice.color, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        Text("Katkı")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("KATKI DAĞILIMI")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(InstitutionalTheme.Colors.textTertiary)
                        ForEach(Array(drivers.prefix(3))) { driver in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(driverColor(for: driver.impact))
                                    .frame(width: 6, height: 6)
                                Text(driver.name)
                                    .font(.caption2)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text(String(format: "%+.0f", driver.score - 50))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(driverColor(for: driver.impact))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding()
            .background(cardBackground)
        }
    }

    private func sectionDriverStrip(_ drivers: [AtlasDriverInsight]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(drivers) { driver in
                    AtlasDriverChip(
                        title: driver.name,
                        subtitle: driver.explanation,
                        impactText: String(format: "%+.0f", driver.score - 50),
                        tint: driverColor(for: driver.impact)
                    )
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func topDrivers(from metrics: [AtlasMetric], limit: Int) -> [AtlasDriverInsight] {
        metrics
            .map { metric in
                AtlasDriverInsight(
                    id: metric.id,
                    name: metric.name,
                    impact: max(-1, min(1, (metric.score - 50.0) / 50.0)),
                    score: metric.score,
                    explanation: metric.explanation
                )
            }
            .sorted { abs($0.impact) > abs($1.impact) }
            .prefix(limit)
            .map { $0 }
    }

    private func donutSlices(from drivers: [AtlasDriverInsight]) -> [AtlasDonutSlice] {
        let magnitudes = drivers.map { max(abs($0.impact), 0.05) }
        let total = max(magnitudes.reduce(0, +), 0.001)
        var cursor = 0.0

        return zip(drivers, magnitudes).map { driver, magnitude in
            let start = cursor / total
            cursor += magnitude
            let end = cursor / total
            return AtlasDonutSlice(
                id: driver.id,
                start: start,
                end: end,
                color: driverColor(for: driver.impact)
            )
        }
    }

    private func combinedMetrics(from result: AtlasV2Result) -> [AtlasMetric] {
        result.valuation.allMetrics
            + result.profitability.allMetrics
            + result.growth.allMetrics
            + result.health.allMetrics
            + result.cash.allMetrics
            + result.dividend.allMetrics
            + result.risk.allMetrics
    }

    private func driverColor(for impact: Double) -> Color {
        if impact > 0.08 { return InstitutionalTheme.Colors.positive }
        if impact < -0.08 { return InstitutionalTheme.Colors.negative }
        return InstitutionalTheme.Colors.warning
    }
    
    // MARK: - Helper Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(InstitutionalTheme.Colors.primary)
            Text("Atlas analiz ediliyor...")
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .background(cardBackground)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(InstitutionalTheme.Colors.negative)
            Text("Analiz Hatası")
            .font(.headline)
            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            // Debug Info Button
            if let detailedError = detailedError {
                DisclosureGroup("Debug Detayları") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detailedError)
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .background(cardBackground)
    }
    
    private func miniProgressBar(score: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                .fill(InstitutionalTheme.Colors.borderSubtle)
                .frame(height: 6)
                
                Capsule()
                .fill(scoreColor(score))
                .frame(width: geo.size.width * (score / 100), height: 6)
            }
        }
        .frame(width: 60, height: 6)
    }

    private func sectionSubtitle(_ sectionId: String) -> String {
        switch sectionId {
            case "valuation": return "F/K, PD/DD ve iskonto profili"
            case "profitability": return "Marjlar, verimlilik ve getiri kalitesi"
            case "growth": return "Gelir ve kâr büyüme ivmesi"
            case "health": return "Borçluluk, kaldıraç ve bilanço dengesi"
            case "cash": return "Nakit üretimi ve sürdürülebilirlik"
            case "dividend": return "Temettü verimi ve devamlılık riski"
            case "risk": return "Beta, oynaklık ve kırılganlık haritası"
            default: return "Çekirdek metrikler"
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(InstitutionalTheme.Colors.surface1)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: InstitutionalTheme.Colors.background.opacity(0.35), radius: 8, x: 0, y: 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
            case 70...: return InstitutionalTheme.Colors.positive
            case 50..<70: return InstitutionalTheme.Colors.warning
            case 30..<50: return InstitutionalTheme.Colors.warning.opacity(0.85)
            default: return InstitutionalTheme.Colors.negative
        }
    }
    
    private func explanationColor(_ status: AtlasMetricStatus) -> Color {
        switch status {
            case .excellent, .good: return InstitutionalTheme.Colors.positive
            case .neutral: return InstitutionalTheme.Colors.textPrimary
            case .warning: return InstitutionalTheme.Colors.warning
            case .bad, .critical: return InstitutionalTheme.Colors.negative
            case .noData: return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        // FIX: Timeout ekleyerek sonsuz beklemeyi önle
        let symbolToAnalyze = symbol
        
        // 60 saniye timeout ile analiz yap (increased from 30 to 60)
        print(" AtlasV2DetailView: Starting analysis for \(symbol)...")
        let loadTask = Task { () -> Result<AtlasV2Result, Error> in
            do {
                // Timeout protection - increased timeout for better reliability
                let result = try await withTimeout(seconds: 60) {
                    try await AtlasV2Engine.shared.analyze(symbol: symbolToAnalyze)
                }
                print("✅ AtlasV2DetailView: Analysis completed for \(symbol)")
                return .success(result)
            } catch {
                // Timeout veya diğer hatalar
                print("❌ AtlasV2DetailView: Analysis failed for \(symbol): \(error)")
                return .failure(error)
            }
        }
        
        let taskResult = await loadTask.value
        
        await MainActor.run {
            switch taskResult {
                case .success(let analysisResult):
                self.result = analysisResult
                self.isLoading = false
                case .failure(let err):
                self.error = err.localizedDescription
                self.detailedError = String(describing: err)
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Timeout Helper
    
    private enum TimeoutError: Error {
        case timeout
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Ana işlem
            group.addTask {
                try await operation()
            }
            
            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError.timeout
            }
            
            // İlk tamamlanan task'ı al
            guard let result = try await group.next() else {
                throw TimeoutError.timeout
            }
            
            // Diğer task'ı iptal et
            group.cancelAll()
            
            return result
        }
    }
}

private struct AtlasDriverInsight: Identifiable {
    let id: String
    let name: String
    let impact: Double
    let score: Double
    let explanation: String
}

private struct AtlasDonutSlice: Identifiable {
    let id: String
    let start: CGFloat
    let end: CGFloat
    let color: Color

    init(id: String, start: Double, end: Double, color: Color) {
        self.id = id
        self.start = CGFloat(start)
        self.end = CGFloat(end)
        self.color = color
    }
}

private struct AtlasDriverChip: View {
    let title: String
    let subtitle: String
    let impactText: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(tint)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Text(impactText)
                .font(.caption2.weight(.bold))
                .foregroundColor(tint)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - BIST SECTOR COMPARISON CARD (NEW)
struct SectionMetricChip: View {
    let label: String
    let metric: AtlasMetric
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Divider()
                .frame(height: 12)
                .overlay(InstitutionalTheme.Colors.borderSubtle)
            VStack(alignment: .leading, spacing: 1) {
                Text(metric.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .lineLimit(1)
                Text(metric.formattedValue)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InstitutionalTheme.Colors.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.26), lineWidth: 1)
        )
    }
}

struct BistSectorComparisonCard: View {
    let symbol: String
    let result: AtlasV2Result
    @State private var sectorAverage: BistSectorAverage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(InstitutionalTheme.Colors.primary)
                Text("SEKTÖR KIYASLAMASI")
                    .font(.caption).bold().foregroundColor(InstitutionalTheme.Colors.textSecondary)
                Spacer()
                
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                }
            }
            
            if let sectorAvg = sectorAverage {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    SectorMetricComparison(
                        label: "Karlılık",
                        current: result.profitabilityScore,
                        average: sectorAvg.profitabilityAvg
                    )
                    
                    SectorMetricComparison(
                        label: "Değerleme",
                        current: result.valuationScore,
                        average: sectorAvg.valuationAvg
                    )
                    
                    SectorMetricComparison(
                        label: "Büyüme",
                        current: result.growthScore,
                        average: sectorAvg.growthAvg
                    )
                    
                    SectorMetricComparison(
                        label: "Sağlık",
                        current: result.healthScore,
                        average: sectorAvg.healthAvg
                    )
                    
                    SectorMetricComparison(
                        label: "Nakit",
                        current: result.cashScore,
                        average: sectorAvg.cashAvg
                    )
                    
                    SectorMetricComparison(
                        label: "Temettü",
                        current: result.dividendScore,
                        average: sectorAvg.dividendAvg
                    )
                }
            } else {
                Text("Sektör kıyas verisi şu an mevcut değil.")
                    .font(.caption)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .background(InstitutionalTheme.Colors.surface2)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InstitutionalTheme.Colors.primary.opacity(0.25), lineWidth: 1)
        )
        .onAppear { loadSectorData() }
    }
    
    private func loadSectorData() {
        // Mock veri yerine boş geçilir; gerçek veri kaynağı bağlandığında burada yüklenecek.
        isLoading = false
        sectorAverage = nil
    }
}

struct SectorMetricComparison: View {
    let label: String
    let current: Double
    let average: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
            
            HStack(spacing: 4) {
                Text(String(format: "%.0f", current))
                    .font(.caption).bold().foregroundColor(InstitutionalTheme.Colors.textPrimary)
                
                if current > average {
                    Image(systemName: "arrow.up.right.fill")
                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.positive)
                } else if current < average {
                    Image(systemName: "arrow.down.right.fill")
                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.negative)
                } else {
                    Image(systemName: "equal")
                        .font(.caption2).foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
            }
            
            // Comparison bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InstitutionalTheme.Colors.borderSubtle)
                    .frame(height: 4)
                
                HStack(spacing: 0) {
                    Capsule()
                        .fill(InstitutionalTheme.Colors.primary.opacity(0.7))
                        .frame(width: CGFloat(current / 100) * 40, height: 4)
                    
                    Capsule()
                        .fill(InstitutionalTheme.Colors.warning.opacity(0.6))
                        .frame(width: CGFloat(average / 100) * 40, height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct BistSectorAverage: Sendable {
    let profitabilityAvg: Double
    let valuationAvg: Double
    let growthAvg: Double
    let healthAvg: Double
    let cashAvg: Double
    let dividendAvg: Double
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AtlasV2DetailView(symbol: "AAPL")
    }
}
