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
                    
                    // Öne Çıkanlar & Uyarılar
                    if !result.highlights.isEmpty || !result.warnings.isEmpty {
                        highlightsCard(result)
                    }
                    
                    // VALUE ALERT SYSTEM (BIST-ÖZEL)
                    if symbol.hasSuffix(".IS") {
                        valueAlertCard(result)
                    }
                    
                    // Bölüm Kartları
                    sectionCard(
                        title: "Değerleme",
                        icon: "dollarsign.circle.fill",
                        iconColor: .green,
                        score: result.valuationScore,
                        metrics: result.valuation.allMetrics,
                        sectionId: "valuation"
                    )
                    
                    sectionCard(
                        title: "Karlılık",
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .blue,
                        score: result.profitabilityScore,
                        metrics: result.profitability.allMetrics,
                        sectionId: "profitability"
                    )
                    
                    sectionCard(
                        title: "Büyüme",
                        icon: "arrow.up.right.circle.fill",
                        iconColor: .purple,
                        score: result.growthScore,
                        metrics: result.growth.allMetrics,
                        sectionId: "growth"
                    )
                    
                    sectionCard(
                        title: "Finansal Sağlık",
                        icon: "shield.checkered",
                        iconColor: .cyan,
                        score: result.healthScore,
                        metrics: result.health.allMetrics,
                        sectionId: "health"
                    )
                    
                    sectionCard(
                        title: "Nakit Kalitesi",
                        icon: "banknote.fill",
                        iconColor: .green,
                        score: result.cashScore,
                        metrics: result.cash.allMetrics,
                        sectionId: "cash"
                    )
                    
                    sectionCard(
                        title: "Temetü",
                        icon: "gift.fill",
                        iconColor: .pink,
                        score: result.dividendScore,
                        metrics: result.dividend.allMetrics,
                        sectionId: "dividend"
                    )
                    
                    // YENİ: Risk Kartı
                    sectionCard(
                        title: "Risk Analizi",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
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
        .navigationTitle("Atlas Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Header Card
    
    private func headerCard(_ result: AtlasV2Result) -> some View {
        VStack(spacing: 16) {
            // Şirket İsmi ve Sembol
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.profile.name)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text(result.symbol)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Sektör Badge
                        if let sector = result.profile.sector {
                            Text(sector)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
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
                        .foregroundColor(.secondary)
                }
            }
            
            // Endüstri Bilgisi (varsa)
            if let industry = result.profile.industry {
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(industry)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            Divider()
            
            // Genel Skor Ring
            HStack(spacing: 24) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
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
                            .foregroundColor(.secondary)
                    }
                }
                
                // Kalite Bandı
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kalite Bandı")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(result.qualityBand.rawValue)
                            .font(.title.bold())
                            .foregroundColor(scoreColor(result.totalScore))
                        Text("(\(result.qualityBand.description))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(result.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: scoreColor(result.totalScore).opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(scoreColor(result.totalScore).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Highlights Card
    
    private func highlightsCard(_ result: AtlasV2Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Öne Çıkanlar
            ForEach(result.highlights, id: \.self) { highlight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(highlight)
                        .font(.subheadline)
                }
            }
            
            // Uyarılar
            ForEach(result.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    // MARK: - Section Card
    
    private func sectionCard(title: String, icon: String = "", iconColor: Color = .white, score: Double, metrics: [AtlasMetric], sectionId: String) -> some View {
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
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Mini Progress Bar
                    miniProgressBar(score: score)
                    
                    // Score
                    Text("\(Int(score))")
                        .font(.headline)
                        .foregroundColor(scoreColor(score))
                    
                    // Chevron
                    Image(systemName: expandedSections.contains(sectionId) ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Expanded Content
            if expandedSections.contains(sectionId) {
                VStack(spacing: 16) {
                    ForEach(metrics) { metric in
                        metricRow(metric)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                // transition kaldırıldı - performans optimizasyonu
            }
        }
        .background(cardBackground)
    }
    
    // MARK: - Metric Row
    
    private func metricRow(_ metric: AtlasMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Üst satır: İsim, Değer, Durum
            HStack {
                Text(metric.name)
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                Text(metric.formattedValue)
                    .font(.subheadline.bold())
                
                Text(metric.status.emoji)
            }
            
            // Sektör karşılaştırması
            if let sectorAvg = metric.sectorAverage {
                HStack {
                    Text("Sektör Ort:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(AtlasMetric.format(sectorAvg))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Açıklama
            Text(metric.explanation)
                .font(.caption)
                .foregroundColor(explanationColor(metric.status))
            
            // Eğitici not (varsa)
            if !metric.educationalNote.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(metric.educationalNote)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.top, 4)
            }
            
            Divider()
        }
    }
    
    // MARK: - Summary Card
    
    private func summaryCard(_ result: AtlasV2Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.orange)
                Text("Yatırımcı İçin Özet")
                    .font(.headline)
            }
            
            Text(result.summary)
                .font(.subheadline)
            
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
                    .padding()
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    // MARK: - Value Alert System (BIST-ÖZEL)
    
    private func valueAlertCard(_ result: AtlasV2Result) -> some View {
        VStack(spacing: 8) {
            // Deep Value Detection
            if isDeepValue(result) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("⭐ DERİN DEĞER FIRSATI")
                        .font(.caption).bold().foregroundColor(.yellow)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(6)
            }
            
            // Value Trap Detection
            if isValueTrap(result) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("⚠️ VALUE TRAP UYARISI")
                        .font(.caption).bold().foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.2))
                .cornerRadius(6)
            }
            
            // High Dividend Warning
            if isHighDividendRisky(result) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("⚠️ SÜRDÜRÜLEMEZ TEMETTÜ")
                        .font(.caption).bold().foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
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
}

// MARK: - Helpers Extension
extension AtlasV2DetailView {
    
    private func miniScoreCard(_ title: String, _ score: Double) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(Int(score))")
                .font(.headline)
                .foregroundColor(scoreColor(score))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Atlas analiz ediliyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(.red)
            Text("Analiz Hatası")
            .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Debug Info Button
            if let detailedError = detailedError {
                DisclosureGroup("Debug Detayları") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detailedError)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
    
    private func miniProgressBar(score: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 6)
                
                Capsule()
                .fill(scoreColor(score))
                .frame(width: geo.size.width * (score / 100), height: 6)
            }
        }
        .frame(width: 60, height: 6)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
            case 70...: return .green
            case 50..<70: return .yellow
            case 30..<50: return .orange
            default: return .red
        }
    }
    
    private func explanationColor(_ status: AtlasMetricStatus) -> Color {
        switch status {
            case .excellent, .good: return .green
            case .neutral: return .primary
            case .warning: return .orange
            case .bad, .critical: return .red
            case .noData: return .secondary
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

// MARK: - BIST SECTOR COMPARISON CARD (NEW)
struct BistSectorComparisonCard: View {
    let symbol: String
    let result: AtlasV2Result
    @State private var sectorAverage: BistSectorAverage?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("SEKTÖR KIYASLAMASI")
                    .font(.caption).bold().foregroundColor(.gray)
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
                Text("Sektör verisi yükleniyor...")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .onAppear { loadSectorData() }
    }
    
    private func loadSectorData() {
        Task {
            // Simüle edilmiş sector average ( gerçek API'den gelecek)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 saniye
            
            await MainActor.run {
                self.sectorAverage = BistSectorAverage(
                    profitabilityAvg: 65.0,
                    valuationAvg: 58.0,
                    growthAvg: 52.0,
                    healthAvg: 60.0,
                    cashAvg: 48.0,
                    dividendAvg: 45.0
                )
                self.isLoading = false
            }
        }
    }
}

struct SectorMetricComparison: View {
    let label: String
    let current: Double
    let average: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2).foregroundColor(.gray)
            
            HStack(spacing: 4) {
                Text(String(format: "%.0f", current))
                    .font(.caption).bold().foregroundColor(.white)
                
                if current > average {
                    Image(systemName: "arrow.up.right.fill")
                        .font(.caption2).foregroundColor(.green)
                } else if current < average {
                    Image(systemName: "arrow.down.right.fill")
                        .font(.caption2).foregroundColor(.red)
                } else {
                    Image(systemName: "equal")
                        .font(.caption2).foregroundColor(.gray)
                }
            }
            
            // Comparison bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                HStack(spacing: 0) {
                    Capsule()
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: CGFloat(current / 100) * 40, height: 4)
                    
                    Capsule()
                        .fill(Color.orange.opacity(0.5))
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
