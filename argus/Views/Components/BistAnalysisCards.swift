import SwiftUI

// MARK: -  Grafik Eğitici Kartı (SAR TRY, TSI, RSI)
// Teknik analiz verilerini "Veri → Hesaplama → Sonuç" formatında gösterir

struct GrafikEducationalCard: View {
    let symbol: String
    @State private var orionResult: OrionBistResult?
    @State private var rsiValue: Double?
    @State private var macdValue: Double?
    @State private var isLoading = true
    @State private var isExpanded = true
    
    var body: some View {
        GlassCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.cyan)
                    Text("Teknik Analiz Göstergeleri")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    
                    if isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else if let r = orionResult {
                        Text(r.signal.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(signalColor(r.signal).opacity(0.2))
                            .foregroundColor(signalColor(r.signal))
                            .cornerRadius(8)
                    }
                }
                
                if !isLoading {
                    // 1️⃣ SAR TRY (Parabolic SAR)
                    IndicatorRow(
                        icon: "arrow.triangle.swap",
                        title: "SAR TRY (Parabolic SAR)",
                        value: orionResult?.sarStatus ?? "N/A",
                        color: orionResult?.sarStatus.contains("AL") == true ? .green : .red,
                        explanation: sarExplanation,
                        formula: "SAR(n+1) = SAR(n) + AF × (EP - SAR(n))"
                    )
                    
                    // 2️⃣ TSI (True Strength Index)
                    IndicatorRow(
                        icon: "gauge.with.dots.needle.50percent",
                        title: "TSI (Momentum)",
                        value: String(format: "%.1f", orionResult?.tsiValue ?? 0),
                        color: tsiColor(orionResult?.tsiValue ?? 0),
                        explanation: tsiExplanation,
                        formula: "TSI = 100 × EMA(EMA(ΔFiyat)) / EMA(EMA(|ΔFiyat|))"
                    )
                    
                    // 3️⃣ RSI
                    if let rsi = rsiValue {
                        IndicatorRow(
                            icon: "speedometer",
                            title: "RSI (14)",
                            value: String(format: "%.0f", rsi),
                            color: rsiColor(rsi),
                            explanation: rsiExplanation(rsi),
                            formula: "RSI = 100 - (100 / (1 + RS))"
                        )
                    }
                    
                    // 4️⃣ Sonuç Puanı
                    if let r = orionResult {
                        Divider().background(Color.white.opacity(0.2))
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "target")
                                        .font(.caption2)
                                        .foregroundColor(.cyan)
                                    Text("TOPLAM SKOR")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                Text("\(Int(r.score))/100")
                                    .font(.title2.bold())
                                    .foregroundColor(signalColor(r.signal))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("SİNYAL")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(r.signal.rawValue)
                                    .font(.headline)
                                    .foregroundColor(signalColor(r.signal))
                            }
                        }
                        .padding()
                        .background(signalColor(r.signal).opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
        }
        .onAppear { loadData() }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        Task {
            var bistCandles: [BistCandle] = []
            
            // 1. Önce BorsaPy (İş Yatırım) dene
            do {
                let data = try await BorsaPyProvider.shared.getBistHistory(symbol: symbol, days: 60)
                if !data.isEmpty {
                    print("✅ GrafikEducationalCard: BorsaPy'dan \(symbol) için \(data.count) mum alındı")
                    bistCandles = data.map { BistCandle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                }
            } catch {
                print("⚠️ GrafikEducationalCard: BorsaPy başarısız (\(symbol)), Yahoo'ya fallback...")
            }
            
            // 2. BorsaPy başarısız olduysa HeimdallOrchestrator (Yahoo) fallback
            if bistCandles.isEmpty {
                do {
                    let yahooCandles = try await HeimdallOrchestrator.shared.requestCandles(symbol: symbol, timeframe: "1D", limit: 60)
                    if !yahooCandles.isEmpty {
                        print("✅ GrafikEducationalCard: Yahoo'dan \(symbol) için \(yahooCandles.count) mum alındı")
                        bistCandles = yahooCandles.map { BistCandle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                    }
                } catch {
                    print("❌ GrafikEducationalCard: Yahoo da başarısız (\(symbol)): \(error.localizedDescription)")
                }
            }
            
            // 3. Hala veri yoksa çık
            guard !bistCandles.isEmpty else {
                print("❌ GrafikEducationalCard: \(symbol) için hiçbir kaynaktan veri alınamadı")
                await MainActor.run { self.isLoading = false }
                return
            }
            
            // 4. Orion BIST analizi
            let result = OrionBistEngine.shared.analyze(candles: bistCandles)
            print("✅ GrafikEducationalCard: Orion analizi tamamlandı - Skor: \(result.score)")
            
            // 5. RSI hesapla
            let candles = bistCandles.map { Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
            let closes = candles.map { $0.close }
            let rsiValues = IndicatorService.calculateRSI(values: closes, period: 14)
            let currentRSI = rsiValues.last.flatMap { $0 }
            
            await MainActor.run {
                self.orionResult = result
                self.rsiValue = currentRSI
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Explanations
    private var sarExplanation: String {
        guard let sar = orionResult?.sarStatus else { return "" }
        if sar.contains("AL") {
            return "Fiyat SAR'ın üzerinde → Yükseliş trendi devam ediyor. SAR noktaları fiyatın altında."
        } else {
            return "Fiyat SAR'ın altında → Düşüş trendi hakim. SAR noktaları fiyatın üzerinde."
        }
    }
    
    private var tsiExplanation: String {
        guard let tsi = orionResult?.tsiValue else { return "" }
        if tsi > 20 { return "Güçlü pozitif momentum. Alıcılar kontrolde." }
        if tsi > 0 { return "Pozitif momentum ama zayıf. Trend doğrulanmadı." }
        if tsi > -20 { return "Negatif momentum ama güçlü değil. Satış baskısı sınırlı." }
        return "Güçlü negatif momentum. Satıcılar kontrolde."
    }
    
    private func rsiExplanation(_ rsi: Double) -> String {
        if rsi > 70 { return "⚠️ Aşırı alım bölgesi! Düzeltme riski yüksek." }
        if rsi > 50 { return "Alıcı baskısı hakim. Trend yukarı yönlü." }
        if rsi > 30 { return "Satıcı baskısı hakim. Trend aşağı yönlü." }
        return "⚠️ Aşırı satım bölgesi! Tepki yükselişi gelebilir."
    }
    
    // MARK: - Colors
    private func signalColor(_ signal: OrionBistSignal) -> Color {
        switch signal {
        case .buy: return .green
        case .sell: return .red
        case .hold: return .yellow
        }
    }
    
    private func tsiColor(_ tsi: Double) -> Color {
        if tsi > 20 { return .green }
        if tsi > 0 { return .yellow }
        if tsi > -20 { return .orange }
        return .red
    }
    
    private func rsiColor(_ rsi: Double) -> Color {
        if rsi > 70 { return .red }
        if rsi > 50 { return .green }
        if rsi > 30 { return .orange }
        return .green
    }
}

// MARK: - Indicator Row (Reusable)
struct IndicatorRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let explanation: String
    let formula: String
    
    @State private var showFormula = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(color)
            }
            
            // Explanation
            Text(explanation)
                .font(.caption)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            
            // Formula (Tıkla göster)
            Button(action: { withAnimation { showFormula.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "function")
                        .font(.caption2)
                    Text(showFormula ? "Formülü gizle" : "Formülü göster")
                        .font(.caption2)
                }
                .foregroundColor(.cyan.opacity(0.7))
            }
            
            if showFormula {
                Text(formula)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(8)
                    .background(Color.cyan.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Orion Rölatif Güç Kartı
// BIST hisselerinin endekse göre performansını gösterir

struct OrionRelativeStrengthCard: View {
    let symbol: String
    @State private var result: RelativeStrengthResult?
    @State private var isLoading = true
    @State private var isExpanded = false
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.purple)
                        Text("Endekse Göre Performans")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else if let r = result {
                            Text(r.statusText)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(r.status).opacity(0.2))
                                .foregroundColor(statusColor(r.status))
                                .cornerRadius(8)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if let r = result {
                    // Ana Metrikler (Her zaman görünür)
                    HStack(spacing: 16) {
                        MetricMiniCard(title: "RS", value: String(format: "%.2f", r.relativeStrength), color: rsColor(r.relativeStrength))
                        MetricMiniCard(title: "Beta", value: String(format: "%.2f", r.beta), color: betaColor(r.beta))
                        MetricMiniCard(title: "Mom.", value: String(format: "%.1f%%", r.momentum), color: momentumColor(r.momentum))
                    }
                    
                    // Genişletilmiş Detay
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(Color.white.opacity(0.2))
                            
                            // Sektör Bilgisi
                            HStack {
                                Text("Sektör:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(r.sector)
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            
                            // Detaylı Metrikler
                            ForEach(r.metrics) { metric in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(metric.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(metric.score))/\(Int(metric.maxScore))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Text(metric.explanation)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    
                                    // Formül
                                    HStack(spacing: 4) {
                                        Image(systemName: "function")
                                            .font(.system(size: 10))
                                            .foregroundColor(.cyan.opacity(0.7))
                                        Text(metric.formula)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.cyan.opacity(0.7))
                                    }
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(16)
            .background(Theme.cardBackground)
            .cornerRadius(16)
            .onAppear { loadData() }
        }
    }
    
    private func loadData() {
        Task {
            // XU100 mumlarını çek
            var xu100Candles: [Candle]? = nil
            if let xu100 = try? await BorsaPyProvider.shared.getBistHistory(symbol: "XU100", days: 60) {
                xu100Candles = xu100.map { Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
            }
            
            // Hisse mumlarını çek
            if let stockData = try? await BorsaPyProvider.shared.getBistHistory(symbol: symbol, days: 60) {
                let stockCandles = stockData.map { Candle(date: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
                
                if let data = try? await OrionRelativeStrengthEngine.shared.analyze(symbol: symbol, candles: stockCandles, benchmarkCandles: xu100Candles) {
                    await MainActor.run {
                        self.result = data
                        self.isLoading = false
                    }
                    return
                }
            }
            
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func statusColor(_ status: RSStatus) -> Color {
        switch status {
        case .outperforming: return .green
        case .stable: return .blue
        case .neutral: return .yellow
        case .underperforming: return .red
        }
    }
    
    private func rsColor(_ rs: Double) -> Color {
        if rs > 1.1 { return .green }
        if rs > 0.95 { return .yellow }
        return .red
    }
    
    private func betaColor(_ beta: Double) -> Color {
        if beta < 0.9 { return .blue }
        if beta < 1.2 { return .yellow }
        return .orange
    }
    
    private func momentumColor(_ m: Double) -> Color {
        if m > 5 { return .green }
        if m > 0 { return .yellow }
        return .red
    }
}

// MARK: - Hermes Analist Kartı

struct HermesAnalystCard: View {
    let symbol: String
    let currentPrice: Double
    var newsDecision: HermesDecision? = nil // Opsiyonel haber verisi
    
    @State private var result: HermesAnalystResult?
    @State private var isLoading = true
    @State private var isExpanded = false
    
    var isBist: Bool {
        symbol.uppercased().hasSuffix(".IS") || SymbolResolver.shared.isBistSymbol(symbol)
    }
    
    var body: some View {
        if isBist {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(SanctumTheme.hermesColor)
                        Text("Analist Konsensüsü")
                            .font(.headline)
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        if isLoading {
                            ProgressView().scaleEffect(0.7)
                        } else if let r = result, r.consensus.totalAnalysts > 0 {
                            Text(r.verdict)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(verdictColor(r.verdict).opacity(0.2))
                                .foregroundColor(verdictColor(r.verdict))
                                .cornerRadius(8)
                        } else if newsDecision != nil {
                            // Veri yok ama haber var -> "Kulis Modu" Badge
                            Text("KULİS MODU")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(InstitutionalTheme.Colors.primary.opacity(0.16))
                                .foregroundColor(InstitutionalTheme.Colors.primary)
                                .cornerRadius(4)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                if let r = result, r.consensus.totalAnalysts > 0 {
                    // --- STANDART MOD (Analist Verisi Var) ---
                    
                    // Konsensüs Bar
                    HStack(spacing: 2) {
                        // AL
                        if r.consensus.buyCount > 0 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.positive)
                                .frame(width: CGFloat(r.consensus.buyCount) / CGFloat(r.consensus.totalAnalysts) * 200)
                        }
                        // TUT
                        if r.consensus.holdCount > 0 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.warning)
                                .frame(width: CGFloat(r.consensus.holdCount) / CGFloat(r.consensus.totalAnalysts) * 200)
                        }
                        // SAT
                        if r.consensus.sellCount > 0 {
                            Rectangle()
                                .fill(InstitutionalTheme.Colors.negative)
                                .frame(width: CGFloat(r.consensus.sellCount) / CGFloat(r.consensus.totalAnalysts) * 200)
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    // Analist Sayıları
                    HStack {
                        Label("\(r.consensus.buyCount) AL", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.positive)
                        Spacer()
                        Label("\(r.consensus.holdCount) TUT", systemImage: "minus")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.warning)
                        Spacer()
                        Label("\(r.consensus.sellCount) SAT", systemImage: "arrow.down")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                    }
                    
                    // Hedef Fiyat
                    if let target = r.consensus.averageTargetPrice {
                        HStack {
                            Text("Hedef Fiyat:")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Spacer()
                            Text("₺\(String(format: "%.2f", target))")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            
                            if let upside = r.upsidePotential {
                                Text("(\(upside >= 0 ? "+" : "")\(String(format: "%.1f", upside))%)")
                                    .font(.caption)
                                    .foregroundColor(upside >= 0 ? InstitutionalTheme.Colors.positive : InstitutionalTheme.Colors.negative)
                            }
                        }
                    }
                    
                    // Genişletilmiş Detay
                    if isExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(InstitutionalTheme.Colors.borderSubtle)
                            
                            ForEach(r.metrics) { metric in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(metric.name)
                                            .font(.caption)
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        Spacer()
                                        Text(metric.value)
                                            .font(.caption)
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                        Text("\(Int(metric.score))/\(Int(metric.maxScore))")
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(InstitutionalTheme.Colors.warning.opacity(0.2))
                                            .foregroundColor(InstitutionalTheme.Colors.warning)
                                            .cornerRadius(4)
                                    }
                                    Text(metric.explanation)
                                        .font(.caption2)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                                .padding(8)
                                .background(InstitutionalTheme.Colors.surface2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                                )
                                .cornerRadius(8)
                            }
                        }
                        .transition(.opacity)
                    }
                } else if !isLoading {
                    // --- LITE MOD (Analist Yok, Haber Var) ---
                    if let news = newsDecision {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(SanctumTheme.titanGold)
                                Text("Analist verisi yetersiz, ancak piyasa dedikoduları var:")
                                    .font(.caption)
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            }
                            
                            // Sentiment Göstergesi
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(sentimentColor(news.sentiment).opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: sentimentIcon(news.sentiment))
                                        .font(.title3)
                                        .foregroundColor(sentimentColor(news.sentiment))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(news.sentiment.displayTitle)
                                        .font(.headline)
                                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                    Text(news.isHighImpact ? "Yüksek Piyasa Etkisi" : "Normal Piyasa Algısı")
                                        .font(.caption2)
                                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                }
                            }
                            
                            // Başlıklar
                            if !news.keyHeadlines.isEmpty {
                                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                                Text("Öne Çıkan Başlıklar")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                                
                                ForEach(news.keyHeadlines.prefix(3), id: \.self) { headline in
                                    HStack(alignment: .top, spacing: 6) {
                                        Circle()
                                            .fill(InstitutionalTheme.Colors.primary)
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 6)
                                        Text(headline)
                                            .font(.caption2)
                                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(InstitutionalTheme.Colors.surface2)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(InstitutionalTheme.Colors.primary.opacity(0.25), lineWidth: 1)
                        )
                        
                    } else {
                        // --- VERİ YOK MODU ---
                        HStack {
                            Image(systemName: "eye.slash")
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Text("Bu hisse için analist veya haber verisi bulunamadı")
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(InstitutionalTheme.Colors.surface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .institutionalCard(scale: .insight, elevated: false)
            .onAppear { loadData() }
        }
    }
    
    // ... existing loadData ...
    private func loadData() {
        Task {
            if let data = try? await HermesAnalystEngine.shared.analyze(symbol: symbol, currentPrice: currentPrice) {
                await MainActor.run {
                    self.result = data
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    private func verdictColor(_ verdict: String) -> Color {
        if verdict.contains("AL") { return InstitutionalTheme.Colors.positive }
        if verdict.contains("Nötr") || verdict.contains("TUT") { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
    
    // Lite Mod Yardımcıları
    private func sentimentColor(_ sentiment: NewsSentiment) -> Color {
        switch sentiment {
        case .strongPositive, .weakPositive: return InstitutionalTheme.Colors.positive
        case .weakNegative, .strongNegative: return InstitutionalTheme.Colors.negative
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
    
    private func sentimentIcon(_ sentiment: NewsSentiment) -> String {
        switch sentiment {
        case .strongPositive, .weakPositive: return "arrow.up.right.circle.fill"
        case .weakNegative, .strongNegative: return "arrow.down.right.circle.fill"
        default: return "minus.circle.fill"
        }
    }
}

// MARK: - Yardımcı View'lar

struct MetricMiniCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(InstitutionalTheme.Colors.surface2)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: -  Universal BIST Modül Detay Kartı
// Backend'deki BistModuleResult verilerini direkt gösterir

struct BistModuleDetailCard: View {
    let moduleResult: BistModuleResult
    let moduleColor: Color
    let moduleIcon: String
    
    // Modüle özel ek bilgiler
    var extraInfo: [ExtraInfoItem] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1️⃣ HEADER: Skor + Aksiyon
            HStack {
                // Skor Gauge
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    if moduleResult.score > 0 {
                        Circle()
                            .trim(from: 0, to: moduleResult.score / 100)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 0) {
                            Text("\(Int(moduleResult.score))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(scoreColor)
                            Text("/100")
                                .font(.system(size: 9))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                    } else {
                        // Veri Yok Durumu
                        VStack(spacing: 0) {
                            Text("--")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                            Text("Veri Yok")
                                .font(.system(size: 8))
                                .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Aksiyon Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("KARAR")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    Text(actionText)
                        .font(.headline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(actionColor.opacity(0.2))
                        .foregroundColor(actionColor)
                        .cornerRadius(8)
                }
            }
            
            // 2️⃣ YORUM (Commentary) - Açıklama
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundColor(moduleColor)
                    Text("Analiz Özeti")
                        .font(.subheadline.bold())
                        .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                }
                
                Text(moduleResult.commentary)
                    .font(.body)
                    .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .background(InstitutionalTheme.Colors.surface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                    )
                    .cornerRadius(12)
            }
            
            // 3️⃣ DESTEK SEVİYESİ (Support Meter)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Destek Seviyesi")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text(supportText)
                        .font(.caption.bold())
                        .foregroundColor(supportColor)
                }
                
                // Support Bar (-1 to +1 visualized)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                            .frame(height: 8)
                        
                        // Center marker
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderStrong)
                            .frame(width: 2, height: 12)
                            .offset(x: geo.size.width / 2 - 1)
                        
                        // Support indicator
                        let normalizedSupport = (moduleResult.supportLevel + 1) / 2 // Convert -1...1 to 0...1
                        RoundedRectangle(cornerRadius: 4)
                            .fill(supportColor)
                            .frame(width: max(4, geo.size.width * normalizedSupport), height: 8)
                    }
                }
                .frame(height: 12)
                
                // Legend
                HStack {
                    Text("İTİRAZ")
                        .font(.system(size: 9))
                        .foregroundColor(InstitutionalTheme.Colors.negative.opacity(0.8))
                    Spacer()
                    Text("NÖTR")
                        .font(.system(size: 9))
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text("DESTEK")
                        .font(.system(size: 9))
                        .foregroundColor(InstitutionalTheme.Colors.positive.opacity(0.8))
                }
            }
            
            // 4️⃣ EK BİLGİLER (Varsa)
            if !extraInfo.isEmpty {
                Divider().background(InstitutionalTheme.Colors.borderSubtle)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        Text("Detay Metrikleri")
                            .font(.caption.bold())
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                    
                    ForEach(extraInfo) { info in
                        HStack {
                            Image(systemName: info.icon)
                                .foregroundColor(info.color)
                                .frame(width: 20)
                            Text(info.label)
                                .font(.caption)
                                .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                            Spacer()
                            Text(info.value)
                                .font(.caption.bold())
                                .foregroundColor(info.color)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .institutionalCard(scale: .insight, elevated: false)
    }
    
    // MARK: - Computed Properties
    
    private var scoreColor: Color {
        if moduleResult.score >= 70 { return InstitutionalTheme.Colors.positive }
        if moduleResult.score >= 40 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
    
    private var actionText: String {
        switch moduleResult.action {
        case .buy: return " AL"
        case .sell: return " SAT"
        case .hold: return "⏸️ BEKLE"
        }
    }
    
    private var actionColor: Color {
        switch moduleResult.action {
        case .buy: return InstitutionalTheme.Colors.positive
        case .sell: return InstitutionalTheme.Colors.negative
        case .hold: return InstitutionalTheme.Colors.warning
        }
    }
    
    private var supportText: String {
        if moduleResult.supportLevel > 0.5 { return "Güçlü Destek" }
        if moduleResult.supportLevel > 0.1 { return "Hafif Destek" }
        if moduleResult.supportLevel > -0.1 { return "Nötr" }
        if moduleResult.supportLevel > -0.5 { return "Hafif İtiraz" }
        return "Güçlü İtiraz"
    }
    
    private var supportColor: Color {
        if moduleResult.supportLevel > 0.3 { return InstitutionalTheme.Colors.positive }
        if moduleResult.supportLevel > -0.3 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
}

// Extra Info Item for Module Details
struct ExtraInfoItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String
    let color: Color
}

// MARK: -  Global Modül Detay Kartı
// CouncilDecision verilerini gösterir (Orion, Atlas, Aether, Hermes için)

struct GlobalModuleDetailCard: View {
    let moduleName: String
    let decision: CouncilDecision
    let moduleColor: Color
    let moduleIcon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1️⃣ HEADER: Net Destek + Aksiyon
            HStack {
                // Net Support Gauge
                ZStack {
                    Circle()
                        .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: max(0, decision.netSupport))
                        .stroke(supportColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Text("\(Int(decision.netSupport * 100))")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(supportColor)
                        Text("%")
                            .font(.system(size: 9))
                            .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Aksiyon Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("SİNYAL")
                        .font(.caption2)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    
                    Text(actionText)
                        .font(.headline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(actionColor.opacity(0.2))
                        .foregroundColor(actionColor)
                        .cornerRadius(8)
                    
                    Text(decision.signalStrength)
                        .font(.caption2)
                        .foregroundColor(signalStrengthColor)
                }
            }
            
            // 2️⃣ WINNING PROPOSAL (Ana Öneri)
            if let proposal = decision.winningProposal {
                    VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(moduleColor)
                        Text("Kazanan Öneri")
                            .font(.subheadline.bold())
                            .foregroundColor(InstitutionalTheme.Colors.textPrimary)
                    }
                    
                    Text(cleanReasoning(proposal.reasoning))
                        .font(.body)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                        .background(InstitutionalTheme.Colors.surface2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(InstitutionalTheme.Colors.borderSubtle, lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
            }
            
            // 3️⃣ OYLAMA DURUMU
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Oylama")
                        .font(.caption)
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                    Spacer()
                    Text("Onay: \(Int(decision.approveWeight * 100))% | Veto: \(Int(decision.vetoWeight * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(InstitutionalTheme.Colors.textSecondary)
                }
                
                // Vote Bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        // Approve
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.positive)
                            .frame(width: geo.size.width * decision.approveWeight)
                        
                        // Veto
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.negative)
                            .frame(width: geo.size.width * decision.vetoWeight)
                        
                        // Neutral
                        Rectangle()
                            .fill(InstitutionalTheme.Colors.borderSubtle)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)
            }
            
            // 4️⃣ VETO REASONS (Varsa)
            if !decision.vetoReasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                        Text("Veto Gerekçeleri")
                            .font(.caption.bold())
                            .foregroundColor(InstitutionalTheme.Colors.negative)
                    }
                    
                    ForEach(decision.vetoReasons.prefix(3), id: \.self) { reason in
                        Text("• \(reason)")
                            .font(.caption)
                            .foregroundColor(InstitutionalTheme.Colors.negative.opacity(0.85))
                    }
                }
                .padding()
                .background(InstitutionalTheme.Colors.negative.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(InstitutionalTheme.Colors.negative.opacity(0.24), lineWidth: 1)
                )
                .cornerRadius(12)
            }
        }
        .padding(16)
        .institutionalCard(scale: .insight, elevated: false)
    }
    
    // Helper to clean raw strings
    private func cleanReasoning(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "weak_positive", with: "Olumlu (Zayıf)")
            .replacingOccurrences(of: "strong_positive", with: "Güçlü Olumlu")
            .replacingOccurrences(of: "weak_negative", with: "Olumsuz (Zayıf)")
            .replacingOccurrences(of: "strong_negative", with: "Güçlü Olumsuz")
            .replacingOccurrences(of: "neutral", with: "Nötr")
    }
    
    // MARK: - Computed Properties
    
    private var supportColor: Color {
        if decision.netSupport >= 0.5 { return InstitutionalTheme.Colors.positive }
        if decision.netSupport >= 0.2 { return InstitutionalTheme.Colors.warning }
        return InstitutionalTheme.Colors.negative
    }
    
    private var actionText: String {
        switch decision.action {
        case .buy: return " AL"
        case .sell: return " SAT"
        case .hold: return "⏸️ BEKLE"
        }
    }
    
    private var actionColor: Color {
        switch decision.action {
        case .buy: return InstitutionalTheme.Colors.positive
        case .sell: return InstitutionalTheme.Colors.negative
        case .hold: return InstitutionalTheme.Colors.warning
        }
    }
    
    private var signalStrengthColor: Color {
        switch decision.signalStrength {
        case "GÜÇLÜ": return InstitutionalTheme.Colors.positive
        case "ZAYIF": return InstitutionalTheme.Colors.warning
        default: return InstitutionalTheme.Colors.textSecondary
        }
    }
}

// Orion UI Bileşenleri OrionDetailView.swift'te tanımlı - duplikasyon kaldırıldı
// LinearGauge, StructureLinearMap, Sparkline → OrionDetailView.swift
